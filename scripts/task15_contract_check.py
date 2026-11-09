"""Offline schema + negative fixture validation; no network resolution."""
import copy
import json
from pathlib import Path
import yaml
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

root = Path(__file__).resolve().parents[1] / 'docs/task15/SERVER_HANDOFF'
schemas = {p.stem: json.loads(p.read_text()) for p in (root / 'JSON_SCHEMAS').glob('*.json')}
registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas.values())
validators = {}
for name, schema in schemas.items():
    Draft202012Validator.check_schema(schema)
    validators[name] = Draft202012Validator(schema, registry=registry, format_checker=FormatChecker())
examples = json.loads((root / 'EXAMPLES.json').read_text())
for name, example in examples.items():
    validators[name].validate(example)
# Keep compatibility explicit, not arbitrary private fields in the public root.
def rejects(name, value):
    assert list(validators[name].iter_errors(value)), f'{name} accepted forbidden input'
for field in ('readingState', 'readerId', 'privateDraft', 'localPath', 'authorToken'):
    example = copy.deepcopy(examples['DiaryPublication']); example[field] = 'private'
    rejects('DiaryPublication', example)
for bad_hash in ('../private', 'f' * 63, 'GG' * 32):
    link = copy.deepcopy(examples['ContentLink']); link['digest'] = bad_hash
    rejects('ContentLink', link)
example = copy.deepcopy(examples['DiaryPublication']); example['blocks'][1]['media']['localPath'] = '/private'
rejects('DiaryPublication', example)
example = copy.deepcopy(examples['DiaryPublication']); example['publication']['validUntil'] = '09.11.26 12:00'
rejects('DiaryPublication', example)
example = copy.deepcopy(examples['DiaryPublication']); example['publication']['categoryId'] = 'future-category'
validators['DiaryPublication'].validate(example)
api = yaml.safe_load((root / 'API_CONTRACT.yaml').read_text())
assert api['openapi'] == '3.1.0' and not api['servers']
assert '412' in api['paths']['/entries']['post']['responses']
assert '403' in api['paths']['/blobs/{digest}']['get']['responses']
print(f'PASS: {len(schemas)} JSON schemas; {len(examples)} Dart-checked fixtures; 10 negative + unknown-category/OpenAPI checks; no network')
