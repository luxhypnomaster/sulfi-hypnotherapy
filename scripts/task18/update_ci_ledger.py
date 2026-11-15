"""Read only CI run provenance; wall-clock duration is not user quota or billing."""
import datetime,json,pathlib,subprocess
p=pathlib.Path('reports/task18/CI_RUNS_CURRENT_18.json')
previous=json.loads(p.read_text());by={v['id']:v for v in previous['runs']}
v=json.loads(subprocess.check_output(['gh','api','repos/luxhypnomaster/sulfi-hypnotherapy/actions/runs?branch=feat/task18-native-background-transfer&event=workflow_dispatch&per_page=100'],text=True))
for r in v['workflow_runs']:
 assert r['head_branch']=='feat/task18-native-background-transfer'
 by[r['id']]={k:r[k] for k in ['id','html_url','head_sha','status','conclusion','created_at','run_started_at','updated_at']}
 by[r['id']]['resourceMetric']='WALL_CLOCK_ONLY_NOT_BILLING_OR_USER_QUOTA'
previous['checkedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();previous['runs']=sorted(by.values(),key=lambda x:x['id'])
p.write_text(json.dumps(previous,indent=2)+'\n');print(json.dumps({'runs':len(by),'status':'ACTUAL_GITHUB_READ_ONLY_LEDGER','quotaEstimate':False}))
