# №19 — проверено и не проверено

| Уровень | Проверка | Фактический результат |
|---|---|---|
| SOURCE | ZIP SHA/CRC/manifest, 6 файлов | PASS; docs/task19/SOURCE.json |
| SOURCE | APK28 asset provenance, protected source and signing | PASS; APK28_READBACK_19.json / SOURCE_GUARDS_19.json |
| UNIT/WIDGET regression | Полный локальный Flutter | 493 PASS / 2 опциональных SKIP, FULL_DART_493_19.log |
| UNIT | Последние Dart bridge + legacy auth audit | 5 PASS, FINAL_TARGETED_5_19.log |
| UNIT/controlled transport | Kotlin coordinator/policy + REST adapter | 28 PASS (20+8), FINAL_JVM_28_19.log |
| UNIT/server | Existing Alchemist + legacy | 47+24 PASS, Node logs |
| STATIC | flutter analyze / format | PASS, FINAL_ANALYZE_19.log |
| ANDROID_COMPILE | Все 4 актуальных native source файла, SDK36 + Flutter embedding | PASS, FINAL_NATIVE_TYPE_COMPILE_19.log; отдельный bounded-heap compiler |
| CI | GitHub hosted run43949403640 | BLOCKED before runner, no code execution; CI_BLOCKER_19.json |
| APK_ASSEMBLY | Локальный полный Gradle build | FAIL/RESOURCE, daemon disappeared; OOM observed; LOCAL_APK_FAILURE_19.log |
| EMULATOR | Настоящий Android Keystore/cold-process test | NOT_RUN: no local KVM + hosted runner unavailable |
| LIVE_SUPABASE/GOOGLE | Настоящий tenant, consent, refresh, 2 accounts | NOT_RUN: конфигурация не подтверждена |
| OWNER_PHONE | 15/30/60мин, reboot, 2 phones, legacy E2E | NOT_RUN; owner statements из ТЗ не заменяют тест Codex |

JVM проверяет 32 concurrent restores/одну rotation,401→refresh,503/429/timeout без logout, revoked terminal state, сохранение нового refresh при follow-up outage, explicit logout, same-owner authority epoch, stale epoch denial после нового входа, account A/B isolation, nonce/replay/wrong callback, Google provider из managed identities вместо user_metadata, bounded responses и запрет redirect с bearer. REST connection controlled, не настоящая TLS/Google сеть.

Dart defaultOFF выполняет0platformcalls. onAuthStateChange.onError не очищает credentials. Restore не вызывает beginLogin; worker передаёт pinned owner; untrusted authorize URL отвергается. Legacy source reproduction доказывает временное rejected state и восстановление тем же ID token через новый whoami — не неизбежный picker на реальном телефоне.

Native harness рассчитан на обе .auth19 редакции: настоящий Keystore/AtomicFile и2native coordinator instances,32/24concurrent requests, новый PID между persist/restore phases, logout tombstone и разные Android UID. Его backend fake. **Даже будущий PASS этого harness не будет LIVE Google/OWNER_PHONE PASS.**

Локальная сборка: proxy не применялся Java автоматически; после явной настройки возник PKIX trust error. Использована изолированная копия Java truststore с уже установленными environment CAs. Gradle9.3.1 bootstrap PASS; hostname/TLS verification не отключалась, trust config в APK не менялся. Полный build затем потерял daemon в ограниченной8GiB cgroup среде; зафиксирован oom_kill1. Rebuild с теми же условиями не запускался. Освобождались только скачанные документация/src Gradle и завершённые generated test snapshots, не source/userdata/старые APK/remote artifacts.

После небольшого расширения worker API выполнены адресные тесты и анализ, не повторялись все неизменённые old493 tests. Старые №18 native/upgrade proofs сохранены как исторические, не подставлены вместо №19 integration. Точные SHA/размеры новых логов: TEST_EVIDENCE_19.json. Новых native upgrade/физических PASS нет.
