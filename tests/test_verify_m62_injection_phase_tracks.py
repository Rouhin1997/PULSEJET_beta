"""Self-contained regression for independent Stage 2B polynomial phase tracks.

Synthetic pulse events are generated from an analytic phase track, not by
calling the INCEPTION-Lite engine or running any injection on cluster data.
The real Stage 2B result remains to be measured separately.
"""
import sys
from pathlib import Path
import unittest
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from verify_m62_injection_phase_tracks import pulse_phase, coherence


class TestM62IndependentPhaseTracks(unittest.TestCase):
    def test_truth_beats_wrong_motion_dispersion_and_frequency(self):
        rng = np.random.default_rng(123)
        duration = 890.0
        t = rng.uniform(0, duration, size=60000)
        ch = rng.integers(0, 256, size=60000)
        frequencies = 580.0 + np.arange(256) * 2.05
        cfg = {'psr_global': {'frame': 'topo', 'ACCEPOCH': 0.5, 'DM_ref': 'inf'}}
        pulse = {'ID': 'synthetic', 'P0': 0.00379, 'DM': 20.0,
                 'A0': 170.0, 'A1': 0.2}
        expected = pulse_phase(t, ch, pulse, frequencies, duration, cfg)
        # Emulate a narrow pulsed excess in 8-bit data: event locations in
        # phase; does not assume any particular per-event amplitude.
        selected = np.abs(np.remainder(expected, 1) - 0.5) < 0.03
        self.assertGreater(int(selected.sum()), 2500)
        weights = np.ones(int(selected.sum()))
        score = coherence(expected[selected], weights)
        self.assertGreater(score, 0.98)
        for variant in [
            {'flip_accel': True},
            {'flip_jerk': True},
            {'flip_dm': True},
            {'frequency_offset': 0.137},
            {'zero_motion': True},
        ]:
            wrong = pulse_phase(t, ch, pulse, frequencies, duration, cfg, **variant)
            self.assertGreater(score, coherence(wrong[selected], weights) + 0.2,
                               'Model does not distinguish %s' % variant)

    def test_polynomial_derivatives_have_intended_sign(self):
        cfg = {'psr_global': {'frame': 'topo', 'ACCEPOCH': 0.5, 'DM_ref': 'inf'}}
        pulse = {'P0': 0.004, 'A0': 250.0, 'A1': -0.3, 'DM': 0.0}
        duration = 800.0
        t = np.array([399.0, 400.0, 401.0])
        chan = np.array([0, 0, 0], dtype=int)
        f = np.array([900.0])
        phase = pulse_phase(t, chan, pulse, f, duration, cfg)
        f0 = 1 / pulse['P0']
        # In the midpoint convention, the first derivative of instantaneous
        # frequency is -f0*a/c; the second is -f0*j/c.
        observed_f1 = phase[0] - 2 * phase[1] + phase[2]
        expected_f1 = -f0 * pulse['A0'] / 299792458.0
        self.assertAlmostEqual(observed_f1, expected_f1, places=9)
        self.assertGreater(phase[2] - phase[1], 0)


if __name__ == '__main__':
    unittest.main()
