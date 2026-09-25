#!/usr/bin/env python3
"""Kill isolated Flutter test processes at reset cut points, then reopen.

This verifies process death and filesystem recovery on the host. Providers and
deletion adapters are fixtures; it does not verify mobile OS delivery or backup.
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
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = []
    points = ['first-ownership-written', 'intent-renamed', 'database-deleted',
              'completion-renamed', 'marker-removed', 'journal-unlinked',
              'partial-first-pending', 'recoveryMarked', 'quarantinedPending',
              'recoveryVerified', 'recoveryPublished']
    command = [args.flutter, 'test', 'tool/qa/reset_journal_crash_probe.dart',
               '--reporter', 'expanded']
    for point in points:
        with tempfile.TemporaryDirectory(prefix='ontime-reset-kill-') as tmp:
            directory = Path(tmp)
            env = {**os.environ, 'D03_PROBE_DIR': tmp,
                   'D03_PROBE_POINT': point, 'D03_PROBE_MODE': 'cut'}
            with (output / f'{point}-cut.log').open('w') as log:
                child = subprocess.Popen(command, cwd=root, env=env, stdout=log,
                                         stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    deadline = time.monotonic() + 90
                    while not (directory / 'cut-ready').exists():
                        if child.poll() is not None:
                            raise RuntimeError(f'{point}: probe exited before cut; inspect log')
                        if time.monotonic() > deadline:
                            raise TimeoutError(f'{point}: cut point not reached')
                        time.sleep(0.1)
                finally:
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
            env['D03_PROBE_MODE'] = 'recover'
            with (output / f'{point}-recover.log').open('w') as log:
                recovered = subprocess.run(command, cwd=root, env=env, stdout=log,
                                           stderr=subprocess.STDOUT, timeout=120)
            if recovered.returncode or not (directory / 'verified').exists():
                raise RuntimeError(f'{point}: recovery failed; inspect log')
            results.append({'cut': point, 'signal': 'SIGKILL', 'freshProcessPassed': True,
                            'damagedBytesPreparedAsFixture': point in points[6:]})
            print(f'{point}: passed', flush=True)
            (output / 'result.json').write_text(json.dumps({
                'scope': 'host process death; fixture providers and deletion adapters',
                'mobileOsVerified': False, 'powerLossVerified': False,
                'writeSyscallInterruptionVerified': False,
                'results': results,
            }, indent=2) + '\n')


if __name__ == '__main__':
    main()
