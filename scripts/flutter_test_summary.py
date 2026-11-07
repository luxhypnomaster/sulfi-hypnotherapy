#!/usr/bin/env python3
"""Expose Flutter JSON failures as GitHub annotations, without downloading logs."""
import json
from pathlib import Path
import sys

source = Path(sys.argv[1])
events = []
raw = []
for line in source.read_text(errors='replace').splitlines():
    try:
        events.append(json.loads(line))
    except json.JSONDecodeError:
        if line.strip():
            raw.append(line)

tests = {}
errors = {}
printed = {}
results = []
for event in events:
    if event.get('type') == 'testStart':
        tests[event['test']['id']] = event['test']['name']
    elif event.get('type') == 'print':
        printed.setdefault(event.get('testID'), []).append(str(event.get('message', '')))
    elif event.get('type') == 'error':
        errors.setdefault(event.get('testID'), []).append(str(event.get('error', 'Unknown error')) + '\n' + str(event.get('stackTrace', '')))
    elif event.get('type') == 'testDone':
        results.append(event)

failed = {r['testID'] for r in results if r.get('result') != 'success' and not r.get('skipped')}
failed.update(errors)
summary = {
    'success': any(e.get('type') == 'done' and e.get('success') is True for e in events),
    'passed': sum(r.get('result') == 'success' and not r.get('hidden') and not r.get('skipped') for r in results),
    'failures': [{'name': tests.get(i, f'test {i}'), 'errors': printed.get(i, [])[-8:] + errors.get(i, [])} for i in sorted(failed, key=str)],
}
if len(sys.argv) > 2:
    Path(sys.argv[2]).write_text(json.dumps(summary, ensure_ascii=False, indent=2))

def escape(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')

print(f"Flutter tests: passed={summary['passed']}, failures={len(summary['failures'])}, success={summary['success']}")
for failure in summary['failures'][:20]:
    message = failure['name'] + '\n' + '\n'.join(failure['errors'])
    print('::error title=Flutter test failure::' + escape(message[:6000]))
if not summary['success'] and not summary['failures']:
    print('::error title=Flutter runner failure::' + escape('\n'.join(raw[-25:])[-6000:]))
