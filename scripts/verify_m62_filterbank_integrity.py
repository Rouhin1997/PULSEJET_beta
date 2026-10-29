#!/usr/bin/env python3
"""Read-only, byte-exact audit of existing M62 SIGPROC sub-filterbanks.

Uses the original extractor's manifest as a plan, but independently checks
sample boundaries, raw header differences, and every payload byte.
Never rewrites the original or window .fil files.
"""
import argparse
import json
import math
import os
from pathlib import Path
import struct
import sys
import time

INTS = set("machine_id telescope_id data_type nchans nbits nifs scan_number barycentric pulsarcentric nbeams ibeam nsamples".split())
DOUBLES = set("tstart tsamp fch1 foff refdm az_start za_start src_raj src_dej".split())
STRINGS = {"source_name", "rawdatafile"}


def take(f, n):
    data = f.read(n)
    if len(data) != n:
        raise ValueError("Truncated SIGPROC header/data")
    return data


def sigstr(f):
    n = struct.unpack("<i", take(f, 4))[0]
    if not 0 <= n <= 80:
        raise ValueError("Invalid SIGPROC string length: %s" % n)
    return take(f, n).decode("utf-8")


def read_header(path):
    fields, offsets = {}, {}
    with path.open("rb") as f:
        if sigstr(f) != "HEADER_START":
            raise ValueError("%s: no SIGPROC HEADER_START" % path)
        while True:
            key = sigstr(f)
            if key == "HEADER_END":
                break
            if key in fields:
                raise ValueError("%s: duplicate header keyword %s" % (path, key))
            offsets[key] = f.tell()
            if key in INTS:
                fields[key] = struct.unpack("<i", take(f, 4))[0]
            elif key in DOUBLES:
                fields[key] = struct.unpack("<d", take(f, 8))[0]
            elif key in STRINGS:
                fields[key] = sigstr(f)
            elif key == "signed":
                fields[key] = struct.unpack("<b", take(f, 1))[0]
            else:
                raise ValueError("%s: unsupported header keyword %s" % (path, key))
        offset = f.tell()
        f.seek(0)
        raw = take(f, offset)
    return fields, offsets, raw, offset


def before(path):
    s = path.stat()
    if not path.is_file():
        raise ValueError("Not a regular file: %s" % path)
    return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)


def verify_stable(path, snapshot):
    if before(path) != snapshot:
        raise RuntimeError("File metadata changed during audit: %s" % path)


def expect(condition, message):
    if not condition:
        raise ValueError(message)


def compare_payload(original, original_offset, window, window_offset, length, chunk):
    """Streaming comparison: both files are *only* opened rb; no output .fil."""
    checked = 0
    with original.open("rb") as fsrc, window.open("rb") as fout:
        fsrc.seek(original_offset)
        fout.seek(window_offset)
        while checked < length:
            size = min(chunk, length - checked)
            a = take(fsrc, size)
            b = take(fout, size)
            if a != b:
                first = next(i for i, (x, y) in enumerate(zip(a, b)) if x != y)
                raise ValueError(
                    "Payload differs: %s, byte offset %d within segment" %
                    (window, checked + first)
                )
            checked += size
    return checked


def run(manifest_path, report_dir, chunk_size):
    manifest = json.loads(manifest_path.read_text())
    expect(isinstance(manifest.get("segments"), list) and manifest["segments"], "Missing segments")
    src = Path(manifest["source"]).expanduser().resolve(strict=True)
    expect(src != manifest_path.resolve(), "Invalid source path")
    expect(report_dir.resolve() != src.parent.resolve(), "Report must not be written beside source")
    src_stat = before(src)
    src_fields, src_offsets, src_raw, src_data = read_header(src)

    for key in ("tstart", "tsamp", "nchans", "nbits"):
        expect(key in src_fields, "Missing source field: " + key)
    expect(math.isfinite(src_fields["tstart"]), "Nonfinite source tstart")
    expect(math.isfinite(src_fields["tsamp"]) and src_fields["tsamp"] > 0, "Invalid tsamp")
    bits = src_fields["nchans"] * src_fields["nbits"] * src_fields.get("nifs", 1)
    expect(bits > 0 and bits % 8 == 0, "Not byte-aligned SIGPROC time samples")
    bps = bits // 8
    payload_bytes = src_stat[2] - src_data
    expect(payload_bytes > 0 and payload_bytes % bps == 0, "Bad source payload length")
    nsamp = payload_bytes // bps
    expect(src_fields.get("nsamples", nsamp) in (0, nsamp), "Source nsamples mismatch")
    expect(manifest.get("source_header_bytes") == src_data, "Source header length differs from manifest")
    expect(manifest.get("source_actual_samples") == nsamp, "Source sample count differs from manifest")
    expect(manifest.get("source_header") == src_fields, "Source header fields differ from manifest")
    expect(1 <= len(manifest["segments"]) <= 20, "Unexpected number of segments")

    checks = []
    all_outputs = set()
    nwin = len(manifest["segments"])
    for i, entry in enumerate(manifest["segments"]):
        name = "W%d" % (i + 1)
        output = Path(entry["path"]).expanduser().resolve(strict=True)
        expect(output != src and output not in all_outputs, "Duplicate/invalid output: %s" % output)
        all_outputs.add(output)
        expect(report_dir.resolve() != output.parent.resolve(), "Report must not be written in output directory")
        stop = (i + 1) * nsamp // nwin
        start = i * nsamp // nwin
        count = stop - start
        tstart_expected = src_fields["tstart"] + start * src_fields["tsamp"] / 86400.0
        expected_bytes = src_data + count * bps

        expect(entry["window"] == name, "Unexpected window label at index %d" % i)
        expect(entry["start_sample"] == start, "%s start_sample incorrect" % name)
        expect(entry["nsamples"] == count, "%s nsamples incorrect" % name)
        expect(entry["tstart_mjd"] == tstart_expected, "%s manifest tstart incorrect" % name)
        expect(entry["expected_bytes"] == expected_bytes, "%s manifest expected_bytes incorrect" % name)
        expect(abs(entry["duration_seconds"] - count * src_fields["tsamp"]) < 1e-7,
               "%s manifest duration incorrect" % name)

        out_stat = before(output)
        out_fields, out_offsets, out_raw, out_data = read_header(output)
        expect(out_data == src_data, "%s header size changed" % name)
        expect(out_stat[2] == expected_bytes, "%s file size wrong" % name)
        expected_header = bytearray(src_raw)
        struct.pack_into("<d", expected_header, src_offsets["tstart"], tstart_expected)
        if "nsamples" in src_offsets:
            expect(count <= 2147483647, "%s nsamples overflows i32" % name)
            struct.pack_into("<i", expected_header, src_offsets["nsamples"], count)
        expect(out_raw == bytes(expected_header), "%s header differs beyond permitted tstart/nsamples" % name)
        expected_fields = dict(src_fields)
        expected_fields["tstart"] = tstart_expected
        if "nsamples" in expected_fields:
            expected_fields["nsamples"] = count
        expect(out_fields == expected_fields, "%s decoded fields mismatch" % name)
        expect(out_offsets["tstart"] == src_offsets["tstart"], "%s tstart field offset differs" % name)

        copied = compare_payload(src, src_data + start * bps, output, out_data, count * bps, chunk_size)
        verify_stable(src, src_stat)
        verify_stable(output, out_stat)
        checks.append({
            "window": name, "path": str(output), "start_sample": start,
            "nsamples": count, "tstart_mjd": tstart_expected,
            "bytes_compared": copied, "payload_exact_match": True,
            "header_byte_match_except_tstart_nsamples": True,
            "size_and_metadata_stable": True
        })
        print("PASS %s: %s samples, %s payload bytes compared" % (name, count, copied), flush=True)

    verify_stable(src, src_stat)
    return {
        "status": "PASS", "audit": "existing filterbank extraction, read-only",
        "manifest": str(manifest_path), "source": str(src),
        "source_sample_count": nsamp, "bytes_per_time_sample": bps,
        "total_payload_bytes_compared": sum(x["bytes_compared"] for x in checks),
        "header_validation": "own parser and byte comparison; external parser still pending",
        "injection_engine_validation": "NOT PERFORMED",
        "segments": checks
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--manifest", type=Path, required=True, help="Existing windows_manifest.json")
    p.add_argument("--report-dir", type=Path, required=True, help="New, separate audit workspace")
    p.add_argument("--chunk-mib", type=int, default=4)
    args = p.parse_args()
    if not 1 <= args.chunk_mib <= 64:
        p.error("--chunk-mib must be between 1 and 64")
    report = args.report_dir.expanduser().resolve()
    report.mkdir(parents=True, exist_ok=True)
    manifest = args.manifest.expanduser().resolve(strict=True)
    expect = None
    started = time.time()
    try:
        result = run(manifest, report, args.chunk_mib * 1024 * 1024)
    except Exception as exc:
        result = {
            "status": "FAIL_OR_INCOMPLETE",
            "manifest": str(manifest),
            "error_type": type(exc).__name__, "error": str(exc),
            "injection_engine_validation": "NOT PERFORMED"
        }
        print("FAIL/INCOMPLETE: %s: %s" % (type(exc).__name__, exc), file=sys.stderr, flush=True)
    result["elapsed_seconds"] = round(time.time() - started, 3)
    dest = report / "extraction_audit_result.json"
    if dest.exists():
        raise FileExistsError("Refusing to overwrite previous audit report: %s" % dest)
    with dest.open("x") as f:
        json.dump(result, f, indent=2)
        f.write("\n")
    print("REPORT %s" % dest, flush=True)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
