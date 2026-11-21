# ISSUES №20

1. BLOCKED_OWNER: production GAS6 не содержит catalog.head/snapshot или versioned vitrine admin API. Router/Catalog/Diary не менялись. Допустимый fallback: isolated injected Node service + Flutter SQLite sync, explicit nullable transport, disabled live-save. Нужны согласованные wire/atomicity/ACL и отдельный узкий deploy approval.
2. BLOCKED_ENV: /dev/kvm отсутствует, emulator/OEM/2phones не запускались. Старый hosted CI43949403640 имеет0steps (billing/spending), повторов вслепую нет. Android Gradle в предыдущем №19 OOM; здесь root свободно~148MB, dangling old gradle cache. Не повторять ту же установку/сборку без новой гипотезы.
3. NOT_RUN: настоящие Google пользователи, live metadata/config E2E, физические геометрия/слух/фон/upgrade. Старые доказательства №18 сохранены и не объявляются новыми PASS.
4. Исправлено при разработке: старые аудио-read тесты требовали EOF; оставлены явные legacy fixtures, новый default проверяется отдельно. Дополнительно read notify не делает pause общего плеера.
5. Исправлено: expiry listener должен учитывать active(now), иначе одинаковый fingerprint скрывал истечение. Scope-specific entries дополнительно фильтруются в banner.
6. Test harness: первый widget slot не имел width, а fake future нового SessionController был создан вне runAsync — источник ожидания, не неисправность эмулятора. Ограниченный диагностический прогон + перенос создания внутрь runAsync; после исправления3widget PASS и2реальных Flutter PNG. Первые логи сохранены, не выдаются за PASS.
7. OPEN: полный editor static banner preview не подключён; существующий reader preview сохранён. Полная7-sectionadmin, quota и backup остаются будущим этапом. Технические ceiling ratio1..100/N1..1000 — proposal, не согласованный UX.
8. OPEN: production legacy catalog screen не переключён на неподдерживаемый протокол; current metadata adapter требует интеграции в headless factory после согласования. Ни CLIENT installation, ни реальные серверные публикации этим кодом не имитируются.

Обновление: реальный новыйCI44933039652:0steps, billing/spending annotation. Local fallback выполнен:514FlutterPASS/2SKIP,54+24Node,5JVM, обеAndroidtarget bundles exit0. APK20/Gradle/native runtime NOT_RUN. Дальнейшие повторные CI без устранения infrastructure blocker не запускаются.

Дополнительный harness incident: await завершённого fake-zone reader write из runAsync при подготовке следующего view; вынесено в отдельный controller/view и диагностически подтверждено, production код ради этого не ослаблялся. Проверка последней страницы использует rendered/scroll metrics; quiet refresh не повторяет показанные base items и не пропускает splash.
