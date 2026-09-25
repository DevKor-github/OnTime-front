#!/usr/bin/env python3
"""Run the real gate against isolated valid/invalid inputs and its old generated output."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dart', default='dart')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_path = Path('lib/core/database/schema_contracts.schema.json')
    source = (root / source_path).read_text()
    original = json.loads(source)
    cases = ['valid', 'missing_fixture', 'corrupt_ddl', 'wrong_objects', 'empty_pair', 'duplicate_pair', 'non_integer_pair', 'missing_current', 'duplicate_snapshot', 'stale_generated']
    results = []
    for case in cases:
        with tempfile.TemporaryDirectory(prefix='ontime-d04-gate-') as temporary:
            cwd = Path(temporary)
            shutil.copytree(root / 'test/fixtures/database', cwd / 'test/fixtures/database')
            target = cwd / source_path
            target.parent.mkdir(parents=True)
            data = copy.deepcopy(original)
            if case == 'wrong_objects': data['snapshots'][0]['objects'].pop()
            if case == 'empty_pair': data['pairSupported'] = []
            if case == 'duplicate_pair': data['pairSupported'] = [4, 4]
            if case == 'non_integer_pair': data['pairSupported'] = [4, '4']
            if case == 'missing_current': data['pairSupported'] = [3]
            if case == 'duplicate_snapshot': data['snapshots'].append(copy.deepcopy(data['snapshots'][0]))
            if case == 'stale_generated': data['auditNote'] = 'new valid input without regenerated output'
            target.write_text(source if case == 'valid' else json.dumps(data, ensure_ascii=False, indent=2) + '\n')
            if case == 'missing_fixture': (cwd / 'test/fixtures/database/schema_v1.sql').unlink()
            if case == 'corrupt_ddl': (cwd / 'test/fixtures/database/schema_v1.sql').write_text('PRAGMA user_version=1;')
            command = [args.dart, '--packages=' + str(root / '.dart_tool/package_config.json'), str(root / 'tool/check_database_schema.dart')]
            result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
            (output / f'{case}.log').write_text(result.stdout.replace(str(cwd), '<isolated-input>'))
            expected = result.returncode == 0 if case == 'valid' else result.returncode != 0
            results.append({'case': case, 'exitCode': result.returncode, 'expectedOutcome': expected})
            if not expected: raise RuntimeError(f'{case}: unexpected gate result')
    (output / 'result.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'{len(results)} actual gate command cases passed')


if __name__ == '__main__':
    main()
