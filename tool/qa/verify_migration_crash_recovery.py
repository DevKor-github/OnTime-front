#!/usr/bin/env python3
"""SIGKILL/reopen only synthetic host SQLCipher stores; no installed app data."""
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
    parser.add_argument('--flutter', default='flutter')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[2]
    command = [args.flutter, 'test', 'tool/qa/migration_crash_probe.dart', '--no-pub', '--reporter', 'expanded']
    results = []
    for point in ['after-first-ddl', 'before-version', 'after-version', 'after-commit']:
        with tempfile.TemporaryDirectory(prefix='ontime-d04-kill-') as temporary:
            directory = Path(temporary)
            env = {**os.environ, 'D04_PROBE_DIR': temporary, 'D04_PROBE_POINT': point, 'D04_PROBE_MODE': 'cut'}
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
                    ready = (directory / 'cut-ready').read_text()
                    if ready != point:
                        raise RuntimeError(f'{point}: wrong ready checkpoint {ready!r}')
                finally:
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL)
                    cut_code = child.wait()
            if cut_code != -signal.SIGKILL:
                raise RuntimeError(f'{point}: expected actual SIGKILL, got {cut_code}')
            env['D04_PROBE_MODE'] = 'recover'
            with (output / f'{point}-recover.log').open('w') as log:
                recovered = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
                recovered.wait(timeout=120)
            if recovered.returncode or not (directory / 'verified').exists():
                raise RuntimeError(f'{point}: recovery failed; inspect log')
            results.append({'cut': point, 'ready': ready, 'signal': 'SIGKILL', 'cutPid': child.pid, 'cutExitCode': cut_code, 'recoverPid': recovered.pid, 'recoverExitCode': recovered.returncode, 'command': command, **json.loads((directory / 'verified').read_text())})
            print(f'{point}: passed', flush=True)
            (output / 'result.json').write_text(json.dumps({'scope': 'actual host SQLCipher process death', 'results': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
