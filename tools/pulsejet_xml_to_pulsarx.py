#!/usr/bin/env python3
"""Convert polynomial PULSEJET overview.xml into a PulsarX 7-column .cands file.

Physics: PULSEJET's segment-midpoint, zero-relative-velocity polynomial timing:
  t_arr = t_em + [a*tau**2/2 + j*tau**3/6]/c.
At tau=0, f_obs=f0, f1=-a*f0/c, and
f2=f0*(2*(a/c)**2-j/c). The quadratic term is tiny but included.
PulsarX's psrfold_fil accepts: id DM acc F0 F1 F2 S/N.

This prepares candidate inputs; it does NOT fold data. The user must fold
the SAME observation segment as the PULSEJET FFT with --pepoch at the
PULSEJET segment midpoint (MJD). Verify segmentation before running.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

C = 299792458.0


def required_float(element: ET.Element, tag: str) -> float:
    text = element.findtext(tag)
    if text is None:
        raise ValueError(f"Missing <{tag}> inside <{element.tag}>")
    try:
        value = float(text)
    except ValueError as exc:
        raise ValueError(f"Invalid <{tag}>: {text!r}") from exc
    if not math.isfinite(value):
        raise ValueError(f"Non-finite <{tag}>")
    return value


def convert(xml_path: Path, *, allow_legacy: bool = False,
            min_snr: float = -math.inf, limit: int | None = None):
    root = ET.parse(xml_path).getroot()
    if root.tag != "peasoup_search":
        raise ValueError("Not a PULSEJET/Peasoup overview.xml file")

    search = root.find("search_parameters")
    segment = root.find("segment_parameters")
    candidates = root.find("candidates")
    if search is None or segment is None or candidates is None:
        raise ValueError("Missing search_parameters, segment_parameters or candidates")

    mode = search.findtext("polynomial_template_bank_file")
    reference = search.findtext("polynomial_reference_epoch")
    if not mode or mode == "none" or reference != "segment_midpoint":
        if not allow_legacy:
            raise ValueError(
                "Polynomial midpoint metadata not found. This converter is for "
                "Phase-A-updated PULSEJET polynomial searches. For an older "
                "polynomial XML, inspect its timing convention and explicitly "
                "use --allow-legacy only if midpoint timing is confirmed."
            )
    if search.findtext("template_bank_file", "none") not in ("none", ""):
        raise ValueError("Keplerian candidate file cannot be converted as polynomial")
    epoch = required_float(segment, "segment_pepoch")
    if epoch <= 0:
        raise ValueError("Invalid reference MJD")
    start = int(required_float(segment, "segment_start_sample"))
    nsamples = int(required_float(segment, "segment_nsamples"))
    if start < 0 or nsamples <= 0:
        raise ValueError("Invalid segment boundaries")
    tsamp = required_float(root.find("header_parameters"), "tsamp") if root.find("header_parameters") is not None else None
    if tsamp is None or tsamp <= 0:
        raise ValueError("Missing positive sampling time")

    items = []
    for i, entry in enumerate(candidates.findall("candidate")):
        period = required_float(entry, "period")
        dm = required_float(entry, "dm")
        a = required_float(entry, "acc")
        j = required_float(entry, "jerk")
        snr = required_float(entry, "snr")
        if period <= 0 or dm < 0:
            raise ValueError(f"Invalid period or DM in candidate #{i}")
        if snr < min_snr:
            continue
        pb = float(entry.findtext("pb", "0"))
        if math.isfinite(pb) and pb > 0:
            raise ValueError(f"Orbital PB found in candidate #{i}; not polynomial-only")
        f0 = 1.0 / period
        f1 = -a * f0 / C
        f2 = f0 * (2.0 * (a / C)**2 - j / C)
        idx = entry.get("id", str(i))
        if not idx.isdecimal():
            raise ValueError(f"Invalid candidate ID {idx!r}; PulsarX expects an integer")
        items.append(dict(id=int(idx), dm=dm, acc=a, jerk=j,
                          f0=f0, f1=f1, f2=f2, snr=snr))
    items.sort(key=lambda x: (-x["snr"], x["id"]))
    if limit is not None:
        if limit <= 0:
            raise ValueError("--limit must be positive")
        items = items[:limit]
    meta = dict(input_xml=str(xml_path), polynomial_bank=mode,
                reference_epoch_mjd=epoch, reference_epoch_convention=reference,
                start_sample=start, segment_nsamples=nsamples,
                fft_size=search.findtext("size"), tsamp_s=tsamp,
                selected_candidates=len(items),
                model="t_arr=t_em+[a*tau^2/2+j*tau^3/6]/c; zero relative velocity at midpoint",
                pulsarx_columns="id DM acc F0 F1 F2 S/N",
                caution="Match the exact filterbank segment in psrfold_fil; use --pepoch at reference_epoch_mjd")
    return items, meta


def run() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("xml", type=Path, help="PULSEJET polynomial overview.xml")
    p.add_argument("-o", "--output", type=Path, required=True, help="PulsarX .cands file")
    p.add_argument("--manifest", type=Path, help="Optional JSON provenance metadata")
    p.add_argument("--min-snr", type=float, default=-math.inf)
    p.add_argument("--limit", type=int)
    p.add_argument("--allow-legacy", action="store_true",
                   help="Only when the old XML's physical reference convention has been verified")
    args = p.parse_args()
    try:
        items, meta = convert(args.xml, allow_legacy=args.allow_legacy,
                              min_snr=args.min_snr, limit=args.limit)
        if not items:
            raise ValueError("No candidate survived the selection; refusing to write an empty fold list")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", encoding="utf-8") as f:
            f.write("#id DM acc F0 F1 F2 S/N\n")
            for row in items:
                f.write(f'{row["id"]}\t{row["dm"]:.15g}\t{row["acc"]:.15g}\t'
                        f'{row["f0"]:.16g}\t{row["f1"]:.16g}\t'
                        f'{row["f2"]:.16g}\t{row["snr"]:.12g}\n')
        manifest = args.manifest or args.output.with_suffix(".json")
        manifest.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote {len(items)} candidates: {args.output}")
        print(f"Wrote fold provenance: {manifest}")
        print(f"Use PulsarX --pepoch {meta['reference_epoch_mjd']:.13f} (MJD)")
        print("IMPORTANT: Fold the exact PULSEJET segment; check start_sample and fft_size in JSON.")
        return 0
    except (OSError, ET.ParseError, ValueError) as exc:
        p.error(str(exc))


if __name__ == "__main__":
    sys.exit(run())
