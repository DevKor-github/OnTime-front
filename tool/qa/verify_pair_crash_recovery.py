#!/usr/bin/env python3
"""Actual host process death with SQLCipher; fixture key storage/native identity.
Does not claim mobile plugin, provider transfer, directory fsync, or power loss.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[2]
    command = ['flutter', 'test', 'tool/qa/recovery_pair_crash_probe.dart', '--reporter', 'expanded']
    results = []
    for point in ['manifest.written', 'record.activated.readBack']:
        with tempfile.TemporaryDirectory(prefix='ontime-pair-kill-') as temporary:
            directory = Path(temporary)
            env = {**os.environ, 'D02_PROBE_DIR': temporary, 'D02_PROBE_POINT': point, 'D02_PROBE_MODE': 'cut'}
            with (output / f'{point}-cut.log').open('w') as log:
                child = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    deadline = time.monotonic() + 90
                    while not (directory / 'cut-ready').exists():
                        if child.poll() is not None:
                            raise RuntimeError(f'{point}: exited before checkpoint; inspect log')
                        if time.monotonic() > deadline:
                            raise TimeoutError(f'{point}: checkpoint timeout')
                        time.sleep(0.1)
                finally:
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
            env['D02_PROBE_MODE'] = 'recover'
            with (output / f'{point}-recover.log').open('w') as log:
                recovered = subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            if recovered.returncode or not (directory / 'verified').exists():
                raise RuntimeError(f'{point}: recovery failed; inspect log')
            results.append({'cut': point, 'signal': 'SIGKILL', **json.loads((directory / 'verified').read_text())})
            print(f'{point}: passed', flush=True)
            (output / 'result.json').write_text(json.dumps({'scope': 'actual host process death; disk fixture key storage and injected process identity',
                'mobileOsVerified': False, 'powerLossVerified': False, 'results': results}, indent=2) + '\n')

if __name__ == '__main__':
    main()
