"""CPU-only regression tests for the read-only M62 full-payload audit."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXTRACTOR = ROOT / "scripts" / "extract_sigproc_windows.py"
AUDITOR = ROOT / "scripts" / "verify_m62_filterbank_integrity.py"


def write_word(f, s):
    value = s.encode("utf-8")
    f.write(struct.pack("<i", len(value)))
    f.write(value)


def create_fixture(path):
    n = 41
    with path.open("wb") as f:
        write_word(f, "HEADER_START")
        for k, v, fmt in [
            ("source_name", "TEST", None),
            ("tstart", 60000.12345, "<d"),
            ("tsamp", 0.001, "<d"),
            ("fch1", 1400.0, "<d"),
            ("foff", -1.0, "<d"),
            ("nchans", 4, "<i"),
            ("nbits", 8, "<i"),
            ("nifs", 1, "<i"),
            ("nsamples", n, "<i"),
        ]:
            write_word(f, k)
            if fmt:
                f.write(struct.pack(fmt, v))
            else:
                write_word(f, v)
        write_word(f, "HEADER_END")
        f.write(bytes((i * 19 + 11) % 256 for i in range(n * 4)))


def call(*args):
    return subprocess.run([sys.executable, *map(str, args)], capture_output=True, text=True)


class TestM62ReadOnlyAudit(unittest.TestCase):
    def test_pass_and_detect_unsampled_payload_corruption(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            src = root / "observation.fil"
            create_fixture(src)
            src_before = src.read_bytes()
            windows = root / "windows"
            split = call(EXTRACTOR, "--input", src, "--output-dir", windows, "--windows", "4")
            self.assertEqual(split.returncode, 0, split.stderr)
            manifest = windows / "windows_manifest.json"
            background_before = [(windows / ("W%d_M62_background.fil" % i)).read_bytes()
                                 for i in range(1, 5)]
            audit1 = root / "validation_pass"
            proc = call(AUDITOR, "--manifest", manifest, "--report-dir", audit1,
                        "--chunk-mib", "1", "--max-io-mib-s", "0")
            self.assertEqual(proc.returncode, 0, proc.stdout + "\n" + proc.stderr)
            result = json.loads((audit1 / "extraction_audit_result.json").read_text())
            self.assertEqual(result["status"], "PASS")
            self.assertEqual(len(result["segments"]), 4)
            self.assertEqual(src.read_bytes(), src_before)
            self.assertEqual(
                [(windows / ("W%d_M62_background.fil" % i)).read_bytes() for i in range(1, 5)],
                background_before
            )

            # Sample 7 of W1 was not among extractor's first/middle/last checks.
            output = windows / "W1_M62_background.fil"
            header_size = json.loads(manifest.read_text())["source_header_bytes"]
            with output.open("r+b") as f:
                f.seek(header_size + 7 * 4 + 1)
                first = f.read(1)
                f.seek(-1, 1)
                f.write(bytes([first[0] ^ 0x01]))
            audit2 = root / "validation_corrupted"
            broken = call(AUDITOR, "--manifest", manifest, "--report-dir", audit2,
                          "--chunk-mib", "1", "--max-io-mib-s", "0")
            self.assertNotEqual(broken.returncode, 0)
            failed = json.loads((audit2 / "extraction_audit_result.json").read_text())
            self.assertEqual(failed["status"], "FAIL_OR_INCOMPLETE")
            self.assertIn("Payload differs", failed["error"])
            self.assertEqual(src.read_bytes(), src_before)


if __name__ == "__main__":
    unittest.main()
