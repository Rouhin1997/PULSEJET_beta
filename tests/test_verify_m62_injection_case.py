"""Synthetic CPU-only regression for read-only M62 injection audit."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'verify_m62_injection_case.py'


def word(f, value):
    b = value.encode('ascii')
    f.write(struct.pack('<i', len(b)))
    f.write(b)


def write_fil(path, data, epoch=60000.2):
    with path.open('wb') as f:
        word(f, 'HEADER_START')
        for key, value, fmt in [
            ('source_name', 'M62', None), ('tstart', epoch, '<d'),
            ('tsamp', 0.0001, '<d'), ('fch1', 1000.0, '<d'),
            ('foff', -0.1, '<d'), ('nchans', 4, '<i'),
            ('nbits', 8, '<i'), ('nifs', 1, '<i'),
            ('nsamples', len(data)//4, '<i')]:
            word(f, key)
            if fmt is None:
                word(f, value)
            else:
                f.write(struct.pack(fmt, value))
        word(f, 'HEADER_END')
        f.write(data)


def save(path, obj):
    path.write_text(json.dumps(obj, indent=2) + '\n')


class TestStage2(unittest.TestCase):
    def test_metadata_pass_and_header_corruption_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root/'source.fil'
            raw = bytes((i*7 + 11) % 256 for i in range(1024*4))
            write_fil(src, raw)
            case = root/'injections'/'case_0001'
            case.mkdir(parents=True)
            output = case/'injected.fil'
            modified = bytearray(raw)
            modified[11] ^= 2
            modified[128] ^= 3
            write_fil(output, modified)
            ps = [dict(ID='TEST%02d' % i, SNR=20, P0=0.004, DM=i) for i in range(5)]
            cfg = root/'input.json'
            save(cfg, dict(mode='together', seed=17, filterbank=str(src),
                           output_dir=str(case.parent), pulsars=ps))
            seed = int.from_bytes(hashlib.sha256(b'17:case_0001').digest()[:4], 'big')
            ident = 'test_case_0001'
            save(case/'resolved_injection.json', dict(
                psr_global=dict(injection_id=ident, global_seed=seed), pulsars=ps))
            r = case/'report_test.json'
            save(r, dict(injection_report=dict(ID=ident, global_seed=seed,
                fb=str(src), obs_nsamples=1024, obs_nchan=4, obs_dt=0.0001,
                generate_fb=None), pulsars=ps))
            offset = src.stat().st_size - len(raw)
            save(case/'run_manifest.json', dict(
                status='success', case='case_0001', input_fil=str(src), output_fil=str(output),
                report=str(r), injection_id=ident, seed=seed, pulsars=ps,
                header=dict(actual_nsamples=1024, data_offset=offset,
                    tstart=60000.2, tsamp=0.0001, nchans=4, nbits=8),
                inject_command=['injector']))
            cmd = [sys.executable, str(SCRIPT), '--case-dir', str(case),
                   '--config', str(cfg), '--report-dir', str(root/'success'),
                   '--blocks', '4', '--samples-per-block', '32']
            valid = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
            data = json.loads((root/'success'/'injection_integrity_result.json').read_text())
            self.assertEqual(data['status'], 'PASS_METADATA_AND_GEOMETRY')
            self.assertGreater(data['data_sample_comparison']['changed_bytes'], 0)
            write_fil(output, modified, epoch=60000.3)
            cmd[cmd.index('--report-dir') + 1] = str(root/'corrupted')
            invalid = subprocess.run(cmd, capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            failed = json.loads((root/'corrupted'/'injection_integrity_result.json').read_text())
            self.assertEqual(failed['status'], 'FAIL_OR_INCOMPLETE')
            self.assertEqual(src.read_bytes()[-len(raw):], raw)


if __name__ == '__main__':
    unittest.main()
