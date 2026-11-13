# №16-Г — фактический журнал

Пользовательская квота5ч/неделя: UNKNOWN, владелец проценты не предоставлял. Проценты не оцениваются.

| Стадия | Проверка | Запуски/повторы | Результат/причина |
|---|---|---|---|
|G0|7files/6manifest digests/33criteria; remote PR45/46 + git ancestry|1/0|PASS, baselineBASELINE_16G.md; прошлые audits/CI reused, не повторены|

CI/emulator16G: пока0. Не повторять одинаковый неуспешный harness более2раз без новой гипотезы. Full Flutter/Node regression один раз после G1–G3; адресные P0 tests не пропускать. Старые16V native logs/readbacks reused только с их исходными ограничениями. Owner live/phone QA NOT_RUN.

G1 targeted initial:31PASS/1failure (old startup-GC expectation); crash retest1PASS/1failure (retry retains3orphans, old final file-count expectation). Both failures fixed in assertions to enforce explicit no-GC policy while retaining exact metadata rollback/media-reference checks. Not emulator retries. Storage final11PASS incl hot journal/SIGKILL; native helper localcompile1PASS. Analyze1run found2unused imports+1brace lint; fixed. Full suite not yet run.

G1 native exact-callback CI https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43347643988 source1391b03:1manual attempt, no signing/OAuth/live server, SUCCESS, duration148sec; healthy reopen + RW/RO corrupt fail-closed/SHA PASS. G1COPY11PASS/localcompilePASS, GC-policy crash assertions adapted, final full regression deferred.
G2 targeted auth/queue/role10PASS; extended production Dart→JS program test initial compile failed on nullable phases test setup, fixed by explicit createPhase, program retest1PASS. No production auth rewrite needed: single SDK identity, refresh singleflight,401/403/DNS/abort and account-bound retries reused. Program+module3track+pause/diary text-only update/selectiveCLIENT install controlled PASS; real OAuth/Drive/phone NOT_RUN.

G3 targeted3new program/legacy/widget tests +23existing diary/workspace tests =26PASS,1run/0retries. Internal template wire/table/ID unchanged; user-entered old names preserved. G1 native148sec PASS reused for G4: exact production callback remains unchanged.

G4 preparation: version26 свободен среди existing releases;0.4.18+26 для ограниченного кандидата. Final analyzer PASS после исправления оставшегося brace lint (до этого2partial analyze runs, не выдаются за PASS). Full suite запускается1раз в verify job. Новый native25→26 harness reuse16V; новая обоснованная гипотеза по прежнему XML: Back выходил в Android launcher, теперь resume только при фактическом launcher + history Home.3разных WAV bytes вместо одинакового тона, strong populated baseline, no recorder retries, real Google diary NOT_RUN. Candidate release только после controlled upgrade+CLIENT label PASS; native failure не выкладывает APK.

G4 CI43348833732 source28810ef cancelled before Flutter full suite/build: targeted static review found two legacy UI fixtures creating a second independent DB next to first sandbox audio. New missing-DB/media guard correctly rejects that ambiguous layout; fixtures moved into separate diary/restored sandboxes. Production guard NOT weakened. Node legacy step had begun; no native/signing/build occurred. This avoids knowingly running a doomed full suite; replacement exact-source CI required.

G4 isolated fixture regression task4_ui+task5_ui:28PASS,59sec,1targeted run. Storage refusal policy preserved; only disposable fixture paths changed.
