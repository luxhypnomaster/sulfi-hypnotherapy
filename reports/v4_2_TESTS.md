# Приёмка v4.2

Статусы относятся к указанным автоматическим/рендер-проверкам. Они не заменяют телефон. Полная матрица исходного пакета — docs/v42/03_ACCEPTANCE_TESTS.md.

База до изменений: 120 тестов PASS. Финальная локальная проверка: 143 теста PASS, analyze --fatal-infos без замечаний, dart format и git diff --check. Flutter 3.47.9 / Dart 3.13.7. SQLite FFI — настоящие файлы БД/медиа fixtures, аудиотранспорт и захват внедрены.

| ID | Статус | Проверка/границы |
|---|---|---|
| R01 | NOT TESTED | R01: видимость действий проверена widget-рендером 412×915, физический Samsung отсутствует. |
| R02 | PASS | R02: категория/личное происхождение, фильтры A05 и сервис записи. |
| R03 | PASS | R03: категория не ограничивает addLoose; модели/редакторы. |
| R04 | PASS | R04: пустой/невалидный дубль отвергается, валидный interruption сохраняется (v4_models_recording_test). |
| R05 | NOT TESTED | R05: probe/preview проверены с fake; настоящий микрофон и слышимый звук требуют телефона. |
| P01 | PASS | P01: Добавить паузу → ApprovedPauseClock, без старого диалога. |
| P02 | PASS | P02: независимые вертикальные колёсики/haptic calls/применение, workspace + v42_interactions. |
| P03 | PASS | P03: нулевой интервал сохраняется как 0, engine пропускает без 60 сек. |
| P04 | PASS | P04: реальный long-press смешанного порядка модуля. |
| P05 | PASS | P05: SQLite v3→v4 и legacy intervals, v42_migration. |
| P06 | PASS | P06: порядок/estimatedMs/delay и фактическая timeline в session_engine_test. |
| E01 | PASS | E01: одна Добавить с меню |
| E02 | PASS | E02: drag смешанных children |
| E03 | PASS | E03: drag фаз и повторная загрузка |
| E04 | PASS | E04: 10 циклов +/− с одинаковой геометрией |
| E05 | PASS | E05: контекст отдельно от раскрытия |
| E06 | PASS | E06: 3 кнопки в закреплённом ряду |
| E07 | PASS | E07: библиотека/запись в меню элемента |
| E08 | PASS | E08: защита изменённого черновика при смене шаблона |
| E09 | PASS | E09: Применить сохраняет без запуска |
| A01 | PASS | A01: 10+ hit-testable строк при 412×915/1.0 |
| A02 | PASS | A02: тап добавляет, каталог открыт |
| A03 | PASS | A03: play не добавляет |
| A04 | PASS | A04: повтор даёт новый occurrence ID |
| A05 | PASS | A05: Мои и Установки одновременно |
| T01 | PASS | T01: 7+ видимых строк, real render templates. |
| T02 | PASS | T02: выбор строки + проверка baseTemplateId, без Run. |
| H01 | PASS | H01: двухстрочная длинная тема и компактный номер/дата, D10 widget. |
| H02 | PASS | H02: структура скроллится отдельно, шаблон/CTA фиксированы (v4_ui/workspace). |
| L01 | PASS | L01: просмотрены real Flutter renders player-* относительно единственного утверждённого PNG; адаптивная компоновка, не заявляется пиксельная идентичность. |
| L02 | PASS | L02: forecast 0/25/75/100%, изображения жидкости. |
| L03 | PASS | L03: current phase only и все имена фаз/модулей. |
| L04 | PASS | L04: scroll не перемещает watch/context/navigation. |
| L05 | PASS | L05: отдельный тест трёх кнопок на часах, один Run. |
| L06 | PASS | L06: tap 25% и drag 50% кругового ободка меняют transport position, сохраняют paused. |
| L07 | PASS | L07: #A6FF2E и точная подпись. |
| L08 | PASS | L08: Home → Run → stop → History/Interrupted, v42_completion. |
| L09 | PASS | L09: Home → Run → natural end → History/Completed, v42_completion. |
| L10 | PASS | L10: доступный/отсутствующий Exit и реальный конец, v41_player/session_engine. |
| L11 | PASS | L11: forecast + seek/skip/replay/interval, session_engine; native background отдельно NOT TESTED. |
| D01 | PASS | D01: переход с главной обычной сборки, без платной роли. |
| D02 | PASS | D02: публичная лента и private drafts раздельны. |
| D03 | PASS | D03: TextPainter pagination по высоте/scale, Unicode/body без потери. |
| D04 | PASS | D04: заголовок первой страницы, продолжение следующих. |
| D05 | PASS | D05: SQL reopen + настоящее автосохранение редактора. |
| D06 | PASS | D06: reader/preview один виджет, одинаковые страницы, real render. |
| D07 | PASS | D07: читатель не видит draft/editor, запись/публикация без прав запрещена. |
| D08 | PASS | D08: offline failure не уничтожает опубликованный кеш. |
| D09 | BLOCKED | D09: fake server publish/unpublish/auth/rejected draft/redirect PASS; живой сервер/credentials отсутствуют. |
| D10 | PASS | D10: home message → соответствующий entry ID, 4 nav сохранены. |
| G01 | PASS | G01: сравнение всех прежних SQL строк и байтов файла до/после v3→v4; v1/v2 tests сохранены. |
| G02 | PASS | G02: flutter analyze --fatal-infos — No issues found. |
| G03 | PASS | G03: flutter test — 143 passed, 0 failed (итоговый локальный запуск). |
| G04 | BLOCKED | G04: локальный flutter build apk --debug упёрся в No space left on device (Gradle transforms). Сборка GitHub Actions будет проверена перед выдачей APK. |
| G05 | PASS | G05: три отчёта v4_2_*.md, контракт и branch/PR. |

## Воспроизведение проверок

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter test --dart-define=SULFI_V42_SCREENSHOTS=/tmp/sulfi-v42 --dart-define=SULFI_V41_SCREENSHOTS=/tmp/sulfi-v42
flutter build apk --debug
```

Рендеры в docs/screenshots/v42 — настоящие интерактивные Flutter-экраны с тестовыми данными, не картинки референсов. Проверены размеры 412×915, 320×600/scale1.6 и 800×360 с системными отступами. Физическая тактильность и громкость отсюда не выводятся.

Локальная Android-сборка реально запускалась: Gradle assembleDebug завершился с exit 1 из-за заполнения диска. Удалены только generated Gradle transforms; после освобождения места проверки повторены. Первый параллельный рендер-прогон также получил No space left; повторный после очистки прошёл. Это не скрытые PASS.

## Осталось проверить

- NOT TESTED: реальный Samsung, микрофон/длительность/прослушивание нативного дубля, фон и интервалы при блокировке, media notification, звонки/гарнитура/Bluetooth, haptic feel, TalkBack, обновление совместимо подписанного APK без потери данных.
- BLOCKED: живой backend дневника, выдача/отзыв author credentials, проверка публикации на втором телефоне. API-контракт и fake server не означают развёрнутого сервера.
- Постоянная Android-подпись ещё не настроена. Не удалять старое приложение с личной библиотекой при INSTALL_FAILED_UPDATE_INCOMPATIBLE.
