#!/usr/bin/env python3
"""Non-destructive audit of delivered Sulfi Codex specification package.
Checks packaging and key final decisions; does NOT test Flutter code or Android behavior.
"""
from pathlib import Path
from PIL import Image
import re, sys, hashlib
ROOT = Path(__file__).resolve().parents[1]
checks=[]

def check(name, ok, detail=''):
    checks.append((name, bool(ok),detail))

names=['00_README_RU.md','01_CODEX_EXECUTION_TASK_RU.md','02_UNIFIED_SPEC_V4_RU.md','03_DATA_MIGRATION_IMPLEMENTATION_RU.md','04_RECORDER_STATE_MACHINE_RU.md','05_ACCEPTANCE_TESTS_RU.md','06_FINAL_AUDIT_AND_DECISIONS_RU.md','07_ASSET_MANIFEST_RU.md']
for n in names: check('file:'+n,(ROOT/n).is_file())
texts={n:(ROOT/n).read_text(encoding='utf8') for n in names if (ROOT/n).is_file()}
S=texts.get('02_UNIFIED_SPEC_V4_RU.md','')
R=texts.get('04_RECORDER_STATE_MACHINE_RU.md','')
T=texts.get('05_ACCEPTANCE_TESTS_RU.md','')
P=texts.get('01_CODEX_EXECUTION_TASK_RU.md','')
G=(ROOT/'assets/spiral/README_FOR_CODEX_RU.md').read_text(encoding='utf8')
terms=['Фаза → Модуль → Трек','Записаться к мастеру','НАЧАТЬ ТРАНСФОРМАЦИЮ','Добавить модуль','Создать новый модуль','Теги','Возвращение в безопасное место','Серая комната','Тишина','Самостоятельная работа','Повторить сессию','Создать шаблон из сессии','Воспроизвести','Завершить','Сохранить трек','Фонов','день недели','Telegram','Электронная почта']
for term in terms: check('main:'+term,term.lower() in S.lower())
check('repeat module same phase', 'несколько раз внутри одной фазы' in S and 'не делать' in S.lower())
check('no preset Razvedka', 'НЕ собирать' in S and '«Разведка»' in S)
check('module via import', '«Добавить в существующий модуль»' in S and '«Создать новый модуль»' in S)
check('recorder bottom buttons', 'Отмена слева' in R and 'Сохранить трек справа' in R)
check('recorder start spiral', 'центральная спираль' in R and 'Начать запись' in R)
check('old asset instructions not active', 'К мастеру` обсуждалось, но не утверждено' not in G and 'Рабочая короткая подпись** «Записаться»' not in G)
check('remove outdated label PNG', not (ROOT/'assets/spiral/ui/booking_handwritten_transparent_900x220.png').exists())
check('remove outdated bottom preview', not (ROOT/'assets/spiral/ui/bottom_navigation_preview.png').exists())
check('current task includes 4 nav', 'Записаться к мастеру' in P and 'НАЧАТЬ ТРАНСФОРМАЦИЮ' in P)
check('tests >=84',T.count('- [ ]')>=84,f"tests={T.count('- [ ]')}")
files=['assets/screens/01_MAIN_APPROVED.png','assets/screens/02_RECORDER_APPROVED.png','assets/screens/03_PAUSE_CLOCK_REFERENCE.png','assets/spiral/brand/sulfi_spiral_neon.svg','assets/spiral/android/ic_launcher_foreground_432.png','assets/spiral/android/ic_launcher_background_432.png','assets/spiral/android/ic_launcher_monochrome_432.png','assets/spiral/ui/booking_spiral_nav_96.png','assets/current/MAIN_OLD_2_COLUMNS.jpg']
for f in files:
    p=ROOT/f;check('asset:'+f,p.is_file(),str(p.stat().st_size)+' bytes' if p.exists() else '')
for f in ('assets/screens/01_MAIN_APPROVED.png','assets/screens/02_RECORDER_APPROVED.png'):
    im=Image.open(ROOT/f);check('portrait:'+f,im.height>im.width)
# Verify local markdown references to top-level docs and selected asset paths.
for n in names:
    check('README lists '+n,n in texts.get('00_README_RU.md','') or n=='00_README_RU.md')
# Old version files should not coexist as peers in new package.
check('no old v3 spec peers', not any(p.name.startswith('02_UNIFIED_SPEC_V3') for p in ROOT.glob('*.md')))
passed=sum(ok for _,ok,_ in checks)
report=['СУЛЬФИ v4.0 — АВТОМАТИЧЕСКИЙ АУДИТ ПАКЕТА',
        'Предмет: текстовый пакет, названия, файлы и основные решения. НЕ проверяет Flutter, APK, реальный Android, звукозапись или фон.',
        f'Проверок: {len(checks)}. Успешно: {passed}. Ошибок: {len(checks)-passed}.', '']
for name,ok,detail in checks:
    report.append(('[PASS] ' if ok else '[FAIL] ')+name+((' — '+detail) if detail else ''))
(ROOT/'08_AUDIT_RESULTS.txt').write_text('\n'.join(report)+'\n',encoding='utf8')
print('\n'.join(report[:4]));print('Failures:')
for name,ok,detail in checks:
    if not ok: print(name,detail)
if passed != len(checks): sys.exit(1)
