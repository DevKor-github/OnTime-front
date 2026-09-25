#!/usr/bin/env python3
"""SIGKILL/reopen a synthetic host SQLCipher store after deletion commits.

Uses a fake provider and the production shared cleanup primitive. This does not
prove mobile delivery, full app bootstrap, power-loss or syscall interruption.
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
    if not os.environ.get('ONTIME_TEST_SQLCIPHER_LIBRARY'):
        raise RuntimeError('Explicit SQLCipher test library required')
    root = Path(__file__).resolve().parents[2]
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    command = [args.flutter, 'test', '--no-pub', '--reporter', 'expanded',
               'tool/qa/schedule_deletion_crash_probe.dart']
    with tempfile.TemporaryDirectory(prefix='ontime-u01-kill-') as tmp:
        directory = Path(tmp)
        env = {**os.environ, 'U01_PROBE_DIR': tmp, 'U01_PROBE_MODE': 'cut'}
        with (output / 'cut.log').open('w') as log:
            child = subprocess.Popen(command, cwd=root, env=env, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True)
            ready = None
            try:
                deadline = time.monotonic() + 90
                while ready is None:
                    if child.poll() is not None:
                        raise RuntimeError('Probe exited before checkpoint; inspect cut.log')
                    try:
                        ready = json.loads((directory / 'cut-ready').read_text())
                    except (FileNotFoundError, json.JSONDecodeError):
                        if time.monotonic() > deadline:
                            raise TimeoutError('Deletion checkpoint not reached')
                        time.sleep(0.1)
            finally:
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGKILL)
                cut_code = child.wait()
        if ready is None or cut_code != -signal.SIGKILL:
            raise RuntimeError(f'Actual checkpoint SIGKILL not verified: {cut_code}')
        env['U01_PROBE_MODE'] = 'recover'
        with (output / 'recover.log').open('w') as log:
            recovered = subprocess.run(command, cwd=root, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=120)
        text = (output / 'recover.log').read_text()
        if (recovered.returncode != 0 or 'All tests passed!' not in text
                or '[E]' in text or not (directory / 'verified').is_file()):
            raise RuntimeError('Fresh-process recovery failed; inspect recover.log')
        verified = json.loads((directory / 'verified').read_text())
        if ready['cutTestPid'] == verified['recoverTestPid']:
            raise RuntimeError('Recovery must run in a distinct test process')
        result = {'command': command, 'signal': 'SIGKILL', 'cutExitCode': cut_code,
                  'recoverExitCode': recovered.returncode, **ready, **verified}
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
