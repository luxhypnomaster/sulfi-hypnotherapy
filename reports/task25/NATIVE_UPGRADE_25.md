# №25 — настоящие native-проверки, точные границы

Используются реальные исторические signed APK28 (источник de408f1cae08fce16069a701d147a0b1064053ba) и новые signed APK29 (737ea741636e9abe7c20353d9d5b8301cf44a5bb), одинаковые cert/packages, не helper APK. Только одноразовые GitHub-hosted Android эмуляторы, не телефон владельца.

|Прогон|Факт|Причина следующего шага|
|---|---|---|
|45104377872|CLIENT12PASS включая реальный install-r28→29; затем transient AX observation BLOCKED. MASTER10PASS до fail-fast cancel|Последующий XML/screenshot подтвердил живой player; ограниченный свежий read-only AX retry, без повторных действий|
|45106402826|Ошибка доступа KVM до запуска Android; native NOT_RUN|Проверка реального FD/API12/createVM, udev settle/chmod до загрузок; аппаратное ускорение обязательно|
|45107294363|Оба KVM PASS. CLIENT потерял ADB на старой28 при паузе; MASTER отменён|Добавить фактический monitor выхода QEMU, сохранить обе edition, уменьшить физический framebuffer без изменения logical frame/DB assertions|
|45157723278|CLIENT API34 все15PASS; MASTER5PASS, затем QEMU exit-11/SIGSEGV до29|Нужен faulting module; памяти/сигнала wrapper/OOM kill недостаточно для вывода о причине|
|45161085603|MASTER-only диагностика, статус в отдельном native_attempt5|Только exception/code module offsets, без дампа памяти; выдача APK запрещена в diagnostic mode|

## Полный CLIENT API34 PASS — run45157723278

Через UI APK28 созданы3разных синтетических WAV (включая одинаковые названия), модуль3трека, второй модуль с паузой, программа/template, current draft, history (interrupted), capsule через SAF. Supplemental queue/cache/settings созданы insert-only в настоящей Android SQLite отдельно от UI и НЕ являются реальным Google/сервером. Реальный PackageManager install-r28→29 и cold restart29 сохранили все проверяемые строки9таблиц и точные SHA старых медиа/капсулы; SQLite integrity ok/schema9; модули/аудио видны в UI, native preview observed, synthetic public diary читается офлайн. Независимый validator повторно проверил отчёт —15casesPASS.

MASTER run4 остановился на открытии редактора паузы old28. Monitor фактического qemu child3287: SIGSEGV,291.23sec, wrapper signals[], oom/oom_kill0 до/после, MemAvailable~14GB. Это доказывает прекращение работы host emulator, но не точный faulting module и не исправность миграции MASTER. При нехватке native evidence нельзя заменить gate FFI-тестом, создать состояние только SQL или пропустить паузу.

API36 обоих приложений NOT_RUN. Нужны все4 gates (MASTER/CLIENT × API34/36); независимый validator `verify_native_evidence.py` сейчас возвращает BLOCKED_NATIVE_DELIVERY. Старые результаты17/18 не переименовываются в25.

Реальные Google-аккаунты, физически услышанный звук, запись/разрешения на телефоне, actual owner installed version, полный29 background-transfer/live receipt и двухтелефонная приёмка — NOT_RUN. Старый случай24→25 UNKNOWN. Данные телефона не извлекались, uninstall/clear/downgrade не выполнялись. Сырые Crashpad/guest memory в отчёты не передаются.
