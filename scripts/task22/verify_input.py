"""Read-only Task22 ZIP/manifest and committed-document identity check."""
import argparse, hashlib, json, pathlib, zipfile
parser=argparse.ArgumentParser();parser.add_argument('archive');parser.add_argument('--docs',default='docs/task22');args=parser.parse_args()
raw=pathlib.Path(args.archive).read_bytes()
with zipfile.ZipFile(args.archive) as z:
 names=z.namelist();assert len(names)==len(set(names))==13
 assert all(not n.startswith('/') and '..' not in pathlib.PurePosixPath(n).parts for n in names)
 assert z.testzip() is None
 manifest=json.loads(z.read('08_MANIFEST.json'));verified=[]
 for row in manifest['required_files']:
  data=z.read(row['path']);assert len(data)==row['bytes'];assert hashlib.sha256(data).hexdigest()==row['sha256'];assert pathlib.Path(args.docs,row['path']).read_bytes()==data
  verified.append(row['path'])
 assert len(verified)==12
 assert pathlib.Path(args.docs,'08_MANIFEST.json').read_bytes()==z.read('08_MANIFEST.json')
 print(json.dumps({'archiveBytes':len(raw),'archiveSHA256':hashlib.sha256(raw).hexdigest(),'revision':manifest['revision'],'files':len(names),'manifestEntries':len(verified),'crc':'PASS','manifestHashes':'PASS','committedDocsIdentity':'PASS','outerDigestIndependentlyPinned':False,'note':'Observed SHA; owner provided no independent external checksum.'},ensure_ascii=False,indent=2))
