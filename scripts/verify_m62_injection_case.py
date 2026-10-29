#!/usr/bin/env python3
"""Read-only inspection of COMPLETED INCEPTION-Lite SIGPROC injection cases.

Checks config, resolved truth, runner and injector metadata, raw header fidelity,
file geometry and deterministic spread-out payload samples. No injection, no
modification of input/output .fil. Sampling measures differences; it is NOT
an independent reconstruction of the injected model or S/N calibration.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import time

INTS = set('machine_id telescope_id data_type nchans nbits nifs scan_number barycentric pulsarcentric nbeams ibeam nsamples'.split())
DOUBLES = set('tstart tsamp fch1 foff refdm az_start za_start src_raj src_dej'.split())
STRINGS = {'source_name', 'rawdatafile'}


def require(test, message):
    if not test:
        raise ValueError(message)


def read_exact(f, n):
    b = f.read(n)
    require(len(b) == n, 'Truncated SIGPROC header/payload')
    return b


def word(f):
    n = struct.unpack('<i', read_exact(f, 4))[0]
    require(0 <= n <= 80, 'Invalid SIGPROC word length: %s' % n)
    return read_exact(f, n).decode('utf-8')


def header(path):
    fields = {}
    with path.open('rb') as f:
        require(word(f) == 'HEADER_START', 'No HEADER_START: %s' % path)
        while True:
            k = word(f)
            if k == 'HEADER_END':
                break
            require(k not in fields, 'Duplicate SIGPROC field: %s' % k)
            if k in INTS:
                v = struct.unpack('<i', read_exact(f, 4))[0]
            elif k in DOUBLES:
                v = struct.unpack('<d', read_exact(f, 8))[0]
            elif k in STRINGS:
                v = word(f)
            elif k == 'signed':
                v = struct.unpack('<b', read_exact(f, 1))[0]
            else:
                raise ValueError('Unsupported SIGPROC header key %s in %s' % (k, path))
            fields[k] = v
        size = f.tell()
        f.seek(0)
        raw = read_exact(f, size)
    require(all(k in fields for k in ('tstart', 'tsamp', 'nchans', 'nbits')), 'Missing SIGPROC geometry')
    require(math.isfinite(fields['tstart']) and math.isfinite(fields['tsamp']) and fields['tsamp'] > 0,
            'Invalid timing metadata')
    bits = fields['nchans'] * fields['nbits'] * fields.get('nifs', 1)
    require(bits > 0 and bits % 8 == 0, 'Non-byte-aligned filterbank')
    bps = bits // 8
    payload = path.stat().st_size - size
    require(payload > 0 and payload % bps == 0, 'Malformed filterbank payload length: %s' % path)
    n = payload // bps
    require(fields.get('nsamples', n) in (0, n), 'nsamples disagrees with payload: %s' % path)
    return {'fields': fields, 'header_bytes': raw, 'header_size': size,
            'bytes_per_sample': bps, 'samples': n, 'payload_bytes': payload}


def stat(path):
    s = path.stat()
    require(path.is_file(), 'Not a regular file: %s' % path)
    return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)


def jread(path):
    return json.loads(path.read_text(encoding='utf-8'))


def path_equal(a, b):
    return Path(a).expanduser().resolve(strict=True) == Path(b).expanduser().resolve(strict=True)


def expected_case_seed(seed, name):
    return int.from_bytes(hashlib.sha256(('%s:%s' % (seed, name)).encode()).digest()[:4], 'big')


def compare_samples(background, injected, src_h, out_h, blocks, block_samples):
    """Take deterministic, distributed reads of equal source/output time ranges."""
    ns = src_h['samples']
    count = min(block_samples, ns)
    possible = max(1, ns - count + 1)
    positions = sorted({int(round(i * (possible - 1) / max(1, blocks - 1))) for i in range(blocks)})
    bps = src_h['bytes_per_sample']
    total_values = changed = positive = negative = 0
    total_abs_delta = max_abs_delta = 0
    low_count = high_count = 0
    with background.open('rb') as src, injected.open('rb') as out:
        for start in positions:
            length = count * bps
            src.seek(src_h['header_size'] + start * bps)
            out.seek(out_h['header_size'] + start * bps)
            original = read_exact(src, length)
            after = read_exact(out, length)
            require(len(original) == len(after), 'Payload sample read length changed')
            # Byte-oriented diagnostics are valid per channel value only for unsigned 8-bit.
            total_values += length
            for a, b in zip(original, after):
                if a != b:
                    changed += 1
                    delta = b - a
                    positive += delta > 0
                    negative += delta < 0
                    total_abs_delta += abs(delta)
                    max_abs_delta = max(max_abs_delta, abs(delta))
                low_count += b == 0
                high_count += b == 255
    return {'sampled_blocks': len(positions), 'samples_per_block': count,
            'bytes_read_per_file': total_values, 'changed_bytes': changed,
            'changed_byte_fraction': changed / total_values,
            'positive_byte_differences': positive, 'negative_byte_differences': negative,
            'mean_absolute_byte_delta': total_abs_delta / total_values,
            'max_absolute_byte_delta': max_abs_delta,
            'output_zero_byte_fraction': low_count / total_values,
            'output_255_byte_fraction': high_count / total_values,
            'comparison_scope': 'distributed sampled byte offsets; not a complete payload audit',
            '8bit_caveat': 'For unsigned 8-bit M62 data these are channel values; otherwise interpret as bytes only'}


def audit_case(case_dir, config_path, blocks, block_samples):
    # A completed INCEPTION-Lite case must have run_manifest.json, created LAST.
    manifest_file = case_dir / 'run_manifest.json'
    require(manifest_file.is_file(), 'Incomplete/nonexistent case: no run_manifest.json: %s' % case_dir)
    require(not any(case_dir.glob('*.fil.part')), 'In-progress .fil.part in case directory: %s' % case_dir)
    manifest = jread(manifest_file)
    resolved_path = case_dir / 'resolved_injection.json'
    require(resolved_path.is_file(), 'Missing resolved_injection.json')
    resolved = jread(resolved_path)
    require(manifest.get('status') == 'success', 'Unsuccessful run manifest')
    require(manifest.get('case') == case_dir.name, 'Case ID mismatch')
    source = Path(manifest['input_fil']).resolve(strict=True)
    output = Path(manifest['output_fil']).resolve(strict=True)
    require(output.parent == case_dir.resolve(), 'Output file is outside selected case directory')
    require(output.suffix == '.fil' and source.suffix == '.fil', 'Not a .fil input/output')
    require(source != output, 'Output aliases input')
    report_path = Path(manifest['report']).resolve(strict=True)
    require(report_path.parent == case_dir.resolve(), 'Injection report is outside selected case directory')
    require(report_path.name.startswith('report_') and report_path.suffix == '.json', 'Unexpected injector report')
    inj_report = jread(report_path)
    require('injection_report' in inj_report, 'Missing injector report fields')
    report = inj_report['injection_report']
    require(path_equal(report['fb'], source), 'Injector report input mismatch')
    require(manifest['injection_id'] == resolved['psr_global']['injection_id'] == report['ID'],
            'Injection IDs inconsistent')
    require(manifest['seed'] == resolved['psr_global']['global_seed'] == report['global_seed'],
            'Injection seeds inconsistent')
    pulsars = manifest['pulsars']
    require(isinstance(pulsars, list) and pulsars, 'No pulsars in manifest')
    require(pulsars == resolved['pulsars'], 'Resolved versus manifest pulsars disagree')
    ids = [p['ID'] for p in pulsars]
    require(len(set(ids)) == len(ids), 'Duplicate pulsar IDs')
    require(len(inj_report.get('pulsars', [])) == len(ids), 'Injector report pulsar count mismatch')
    require(set(p['ID'] for p in inj_report['pulsars']) == set(ids), 'Injector report IDs mismatch')
    require(all(p.get('SNR', 0) > 0 for p in pulsars), 'Nonpositive injected SNR')
    require('--generate_fb' not in manifest.get('inject_command', []),
            'Injector was called with synthetic-noise generator')

    config_results = {'provided': bool(config_path)}
    if config_path:
        cfg = jread(config_path)
        require(cfg['mode'] == 'together', 'Expected together injection mode')
        require(path_equal(cfg['filterbank'], source), 'Config background differs')
        require(cfg['pulsars'] == pulsars, 'Config and manifest pulsars disagree')
        require(manifest['seed'] == expected_case_seed(cfg['seed'], case_dir.name), 'Derived case seed mismatch')
        require(not cfg.get('generate_fb'), 'Config requested Gaussian synthetic data')
        require(path_equal(cfg['output_dir'], case_dir.parent), 'Config output directory differs')
        require(len(pulsars) == 5, 'Expected five pulsars per M62 case')
        config_results.update({'path': str(config_path.resolve()), 'mode': 'together',
                               'seed_matches_case_derivation': True, 'pulsars_match': True})

    before_src = stat(source)
    before_out = stat(output)
    src_h, out_h = header(source), header(output)
    require(src_h['fields'] == out_h['fields'], 'Decoded SIGPROC headers differ')
    require(src_h['header_bytes'] == out_h['header_bytes'], 'Raw SIGPROC header bytes differ')
    require(src_h['samples'] == out_h['samples'], 'Time-sample count changed')
    require(src_h['payload_bytes'] == out_h['payload_bytes'], 'Payload size changed')
    require(before_src[2] == before_out[2], 'Total filterbank size differs')
    recorded_header = manifest.get('header', {})
    require(recorded_header.get('actual_nsamples') == src_h['samples'], 'Manifest actual_nsamples mismatch')
    require(recorded_header.get('data_offset') == src_h['header_size'], 'Manifest data offset mismatch')
    for key in ('tstart', 'tsamp', 'nchans', 'nbits'):
        require(recorded_header.get(key) == src_h['fields'][key], 'Manifest header differs for %s' % key)
    require(report['obs_nsamples'] == src_h['samples'], 'Injector report observation samples mismatch')
    require(report['obs_nchan'] == src_h['fields']['nchans'], 'Injector report channel count mismatch')
    require(report['obs_dt'] == src_h['fields']['tsamp'], 'Injector report dt mismatch')
    require(report['generate_fb'] in (None, False), 'Injector report requested synthetic noise')
    require(src_h['fields']['nbits'] == 8, 'This case comparator is scoped to 8-bit M62 .fil')
    require(src_h['fields'].get('signed', 0) == 0, 'Expected unsigned 8-bit M62 data')
    differences = compare_samples(source, output, src_h, out_h, blocks, block_samples)
    require(stat(source) == before_src and stat(output) == before_out,
            'Input or output changed while auditing; abort')
    # The sampled changed fraction is a diagnostic, NOT an acceptance threshold.
    return {'status': 'PASS_METADATA_AND_GEOMETRY',
            'case': str(case_dir), 'source': str(source), 'output': str(output),
            'n_pulsars': len(pulsars), 'ids': ids,
            'source_samples': src_h['samples'], 'source_payload_bytes': src_h['payload_bytes'],
            'raw_header_exact_match': True, 'sample_count_exact_match': True,
            'config_validation': config_results,
            'injector_provenance': manifest.get('provenance', {}),
            'data_sample_comparison': differences,
            'interpretation': 'Metadata/geometry consistency and sampled differences only; injection model not independently reproduced or validated'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case-dir', type=Path, required=True)
    parser.add_argument('--config', type=Path, help='Completed case original or job-resolved JSON configuration')
    parser.add_argument('--report-dir', type=Path, required=True, help='New independent report directory')
    parser.add_argument('--blocks', type=int, default=32)
    parser.add_argument('--samples-per-block', type=int, default=4096)
    a = parser.parse_args()
    if not 1 <= a.blocks <= 2048 or not 1 <= a.samples_per_block <= 65536:
        parser.error('blocks and samples-per-block outside safe limits')
    dest = a.report_dir.expanduser().resolve()
    if (dest / 'injection_integrity_result.json').exists():
        parser.error('Refusing to overwrite existing result')
    dest.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    try:
        result = audit_case(a.case_dir.resolve(strict=True),
                            a.config.resolve(strict=True) if a.config else None,
                            a.blocks, a.samples_per_block)
    except Exception as exc:
        result = {'status': 'FAIL_OR_INCOMPLETE', 'error_type': type(exc).__name__,
                  'error': str(exc), 'case': str(a.case_dir)}
        print('FAIL/INCOMPLETE: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
    result['elapsed_seconds'] = round(time.monotonic() - start, 3)
    with (dest / 'injection_integrity_result.json').open('x') as f:
        json.dump(result, f, indent=2)
        f.write('\n')
    print('RESULT', result['status'], str(dest / 'injection_integrity_result.json'), flush=True)
    return 0 if result['status'] == 'PASS_METADATA_AND_GEOMETRY' else 1


if __name__ == '__main__':
    sys.exit(main())
