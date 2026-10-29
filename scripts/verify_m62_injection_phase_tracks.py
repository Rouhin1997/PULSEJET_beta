#!/usr/bin/env python3
"""Stage 2B: read-only, independent phase-track test of completed M62 pilot injections.

Build a sparse list of altered 8-bit observational samples at distributed
sample times. For each injected pulsar, independently calculate the predicted
topocentric phase from P0, additional DM, midpoint acceleration and jerk.
Compare first-harmonic coherence of altered samples under correct model
against off-frequency and sign-reversed control tracks.

Important: this is NOT a calibrated S/N, fold, or complete injection audit.
No original, background, or injected filterbank is ever modified.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import time
import numpy as np

from verify_m62_injection_case import header, jread, require, stat

C_M_S = 299792458.0
DM_K_EXACT = 4148.806
DM_K_HISTORICAL = 1.0 / 2.41e-4


def effective_dm_k(pulsar, cfg):
    v = pulsar.get('DM_const', cfg.get('psr_global', {}).get('DM_const', 'exact'))
    if v == 'exact':
        return DM_K_EXACT
    if v == 'historical':
        return DM_K_HISTORICAL
    x = float(v)
    require(math.isfinite(x) and x > 0, 'Invalid DM_const')
    return x


def pulse_phase(time_s, channel, model, freq_mhz, duration_s, cfg, *,
                frequency_offset=0.0, flip_accel=False, flip_jerk=False,
                flip_dm=False, zero_motion=False):
    """Independent first-order polynomial prediction; phase in turns.

    Tracks the injection's topocentric model:
    phi=f0*(u - a*u**2/(2c) - j*u**3/(6c)),
    with u=(t + negative DM delay - ACCEPOCH*T).
    A constant phase origin is immaterial to normalized vector coherence.
    """
    global_cfg = cfg.get('psr_global', {})
    require(model.get('frame', global_cfg.get('frame')) == 'topo', 'Topocentric-only stage')
    require(model.get('DM_ref', global_cfg.get('DM_ref', 'inf')) == 'inf', 'DM_ref=inf required')
    require(not any(k in model for k in ('binary_period', 'pint_polycos', 'FX')),
            'Stage 2B only supports P0+polynomial topocentric sources')
    require('PEPOCH' not in model and 'PEPOCH' not in global_cfg,
            'Unexpected explicit PEPOCH; cannot assume midpoint convention')
    p0 = float(model['P0'])
    require(p0 > 0, 'Invalid P0')
    f0 = 1.0 / p0 + frequency_offset
    dm = float(model.get('DM', global_cfg.get('DM', 0.0)))
    if flip_dm:
        dm = -dm
    k_dm = effective_dm_k(model, cfg)
    frequency = freq_mhz[channel]
    delay = -k_dm * dm / (frequency * frequency)
    accepoch = float(model.get('ACCEPOCH', global_cfg.get('ACCEPOCH', 0.5)))
    u = time_s + delay - accepoch * duration_s
    a = float(model.get('A0', global_cfg.get('A0', 0.0)))
    j = float(model.get('A1', global_cfg.get('A1', 0.0)))
    if zero_motion:
        a, j = 0.0, 0.0
    if flip_accel:
        a = -a
    if flip_jerk:
        j = -j
    return f0 * (u - (a / (2 * C_M_S)) * u * u
                    - (j / (6 * C_M_S)) * u * u * u)


def coherence(phases, weights):
    """Weighted first Fourier circular resultant; [0,1], not calibrated S/N."""
    a = 2 * np.pi * np.remainder(phases, 1.0)
    vector = np.sum(weights * (np.cos(a) + 1j * np.sin(a)))
    return float(abs(vector) / np.sum(weights))


def event_cloud(src, out, h, blocks, samples_per_block):
    """Read small, distributed, identical offsets in input and output."""
    n = h['samples']
    nch = h['fields']['nchans']
    bps = h['bytes_per_sample']
    require(h['fields']['nbits'] == 8 and h['fields'].get('signed', 0) == 0,
            'Unsigned 8-bit filterbank required')
    require(bps == nch, 'nifs=1 is required for direct time x channel mapping')
    count = min(samples_per_block, n)
    stop = max(0, n - count)
    starts = sorted({int(round(i * stop / max(1, blocks - 1)))
                     for i in range(blocks)})
    indices, channels, weights = [], [], []
    changed = positive = negative = 0
    max_abs_delta = 0
    for start in starts:
        with src.open('rb') as fs, out.open('rb') as fo:
            fs.seek(h['header_size'] + start * bps)
            fo.seek(h['header_size'] + start * bps)
            a = np.fromfile(fs, dtype=np.uint8, count=count * bps)
            b = np.fromfile(fo, dtype=np.uint8, count=count * bps)
        require(a.size == count * bps and b.size == count * bps, 'Truncated block')
        delta = b.astype(np.int16) - a.astype(np.int16)
        changed += int(np.count_nonzero(delta))
        positive += int(np.count_nonzero(delta > 0))
        negative += int(np.count_nonzero(delta < 0))
        if np.any(delta):
            max_abs_delta = max(max_abs_delta, int(np.max(np.abs(delta))))
            rows, cols = np.nonzero(delta.reshape(count, nch))
            indices.append(rows.astype(np.int64) + start)
            channels.append(cols.astype(np.int16))
            weights.append(delta.reshape(count, nch)[rows, cols].astype(np.float64))
    require(changed > 0, 'No differences in sampled region; no model test possible')
    return (np.concatenate(indices), np.concatenate(channels),
            np.concatenate(weights),
            dict(distributed_blocks=len(starts),
                 time_samples_per_block=count,
                 bytes_compared_per_file=len(starts) * count * bps,
                 changed_bytes=changed, increased=positive, decreased=negative,
                 max_abs_delta=max_abs_delta))


def audit(case_dir, cfg_path, blocks, samples):
    case = case_dir.resolve(strict=True)
    cfg = jread(cfg_path)
    manifest = jread(case / 'run_manifest.json')
    require(manifest['status'] == 'success', 'Case not completed successfully')
    require(cfg.get('mode') == 'together' and len(cfg.get('pulsars', [])) == 5,
            'Expected five-source pilot case')
    require(manifest.get('pulsars') == cfg['pulsars'], 'Original truth and manifest mismatch')
    require(not cfg.get('generate_fb'), 'Synthetic noise config not allowed')
    require(not any(p.get('binary_period') for p in cfg['pulsars']),
            'Binary/Keplerian campaign unsupported here')
    src = Path(manifest['input_fil']).resolve(strict=True)
    out = Path(manifest['output_fil']).resolve(strict=True)
    require(src != out and out.parent == case, 'Unexpected output path')
    src_stat, out_stat = stat(src), stat(out)
    h = header(src)
    oh = header(out)
    require(h['header_bytes'] == oh['header_bytes'], 'Exact SIGPROC header mismatch')
    require(h['samples'] == oh['samples'] and h['payload_bytes'] == oh['payload_bytes'],
            'SIGPROC sample geometry mismatch')
    require(h['fields']['nchans'] == 256, 'Expected 256-channel M62 observational filterbank')
    ids = [p['ID'] for p in cfg['pulsars']]
    require(len(set(ids)) == 5, 'Expected unique pulsar IDs')
    ts, chans, delta, observations = event_cloud(src, out, h, blocks, samples)
    require(stat(src) == src_stat and stat(out) == out_stat,
            'Filterbank modified during audit')
    dt = h['fields']['tsamp']
    duration = h['samples'] * dt
    chan_freqs = h['fields']['fch1'] + np.arange(h['fields']['nchans']) * h['fields']['foff']
    require(np.all(chan_freqs > 0), 'Invalid observing frequencies')
    sample_times = ts.astype(np.float64) * dt
    # Retain signed increments, consistent with differential injected intensity.
    # The real pilot has positive-only +1 deltas; report any change in that fact.
    model_results = []
    controls = (0.137, -0.283, 0.541, -0.877)
    for model in cfg['pulsars']:
        true = pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg)
        scored = coherence(true, delta)
        nulls = [
            coherence(pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg,
                                 frequency_offset=off), delta)
            for off in controls
        ]
        flips = {}
        a = float(model.get('A0', cfg.get('psr_global', {}).get('A0', 0)))
        j = float(model.get('A1', cfg.get('psr_global', {}).get('A1', 0)))
        dm = float(model.get('DM', cfg.get('psr_global', {}).get('DM', 0)))
        if a:
            flips['acceleration_sign_reversed'] = coherence(
                pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg,
                            flip_accel=True), delta)
        if j:
            flips['jerk_sign_reversed'] = coherence(
                pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg,
                            flip_jerk=True), delta)
        if a or j:
            flips['no_acceleration_or_jerk'] = coherence(
                pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg,
                            zero_motion=True), delta)
        if dm:
            flips['DM_sign_reversed'] = coherence(
                pulse_phase(sample_times, chans, model, chan_freqs, duration, cfg,
                            flip_dm=True), delta)
        model_results.append({
            'id': model['ID'], 'period_seconds': model['P0'], 'dm_added': dm,
            'acceleration_m_s2': a, 'jerk_m_s3': j,
            'truth_coherence': scored, 'off_frequency_controls': nulls,
            'max_off_frequency_control': max(nulls),
            'truth_to_max_off_frequency_ratio': scored / max(1e-12, max(nulls)),
            'counterfactual_coherence': flips,
            'scope': 'differential sample first-harmonic phase-locking, not folded SNR'
        })
    return {
        'status': 'DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS',
        'case': str(case), 'source': str(src), 'injected': str(out),
        'source_epoch_mjd': h['fields']['tstart'], 'observation_seconds': duration,
        'event_cloud': observations, 'phase_tracking': model_results,
        'notes': [
            'Analyzes only distributed changed pixels; not all injected data.',
            'A truth-coherent phase track supports the implemented injection model but is not a calibrated SNR.',
            'Off-frequency controls and sign/DM reversals are diagnostics, not formal significance tests.',
            'SIF injection engine and run-manifest hashes were independently checked in Stage 2A.'
        ]
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case-dir', type=Path, required=True)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--report-dir', type=Path, required=True)
    p.add_argument('--blocks', type=int, default=32)
    p.add_argument('--samples-per-block', type=int, default=4096)
    args = p.parse_args()
    if not 1 <= args.blocks <= 128 or not 1 <= args.samples_per_block <= 32768:
        p.error('Unreasonable sampling plan')
    dest = args.report_dir.resolve()
    if (dest / 'phase_track_result.json').exists():
        p.error('Refusing to overwrite previous result')
    dest.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    try:
        result = audit(args.case_dir, args.config, args.blocks, args.samples_per_block)
    except Exception as exc:
        result = {'status': 'FAIL_OR_INCOMPLETE', 'error': str(exc),
                  'error_type': type(exc).__name__}
        print('FAIL/INCOMPLETE: %s: %s' % (type(exc).__name__, exc),
              file=sys.stderr)
    result['elapsed_seconds'] = round(time.monotonic() - start, 3)
    with (dest / 'phase_track_result.json').open('x') as file:
        json.dump(result, file, indent=2)
        file.write('\n')
    print('RESULT', result['status'], str(dest / 'phase_track_result.json'))
    if 'phase_tracking' in result:
        for m in result['phase_tracking']:
            print('%s truth=%.5f max_offfreq=%.5f ratio=%.2f' %
                  (m['id'], m['truth_coherence'],
                   m['max_off_frequency_control'],
                   m['truth_to_max_off_frequency_ratio']), flush=True)
    return 0 if result['status'] == 'DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
