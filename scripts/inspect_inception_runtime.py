#!/usr/bin/env python3
"""Print SHA256 hashes of actual INCEPTION-Lite source files inside the running SIF.

Run inside the pinned Singularity image. Read-only; no invocation of injection.
This is essential because a repository checkout may differ from the image code.
"""
import hashlib
import json
from pathlib import Path
from inception_lite import runner

root = Path(runner.__file__).resolve().parents[1]
files = [
    'inception_lite/runner.py',
    'injector/SCRIPT_inject_pulsars.py',
    'injector/signal_injector.py',
    'injector/io_tools.py',
    'injector/pulsar_model.py',
    'injector/binary_model.py',
    'injector/observation.py',
    'injector/propagation_effects.py',
    'injector/setup_manager.py',
    'injector/pulsar_par_parser.py',
]
print(json.dumps({
    'runtime_repo_root': str(root),
    'code_sha256': {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in files
    },
}, indent=2, sort_keys=True))
