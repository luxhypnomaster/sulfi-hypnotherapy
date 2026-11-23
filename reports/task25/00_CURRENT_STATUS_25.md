# №25 — текущий результат кандидата29

**Пара собрана и независимо проверена. Полная выдача пока ожидает Android-гейтов.**

MASTER прошёл17 native проверок обновления28→29 на API34, CLIENT —15. SQLite/медиа/модули/программа/история/настройки сохранились; MASTER подтвердил локальный черновик после обновления. Разные Google API34 прогоны также выявили host QEMU SIGSEGV на старой28, до29; это не скрывается и не объявляется исправленным.

Сейчас идёт последний полный набор: обе редакции на официальных AOSP API35/API36, [run45166539406](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45166539406). Те же APK, тот же полный P0 dataset, без rebuild/resign. Доставка требует все4PASS. [Актуальная точка продолжения](candidate29/RESUME_CURRENT_25.md).

[Draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) · [Сборка45103325755](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45103325755) · [ОтчётыDrive](https://drive.google.com/drive/folders/1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn).

Код приложений737ea741636e9abe7c20353d9d5b8301cf44a5bb, без изменений после574Flutter/2SKIP/114Node;76QA-tool tests PASS. Сервер/GAS6/OAuth/ACL/ключ/данные не менялись. App PR51–57 unmerged, main только узкие operational PR. Реальные Google/телефоны NOT_RUN, установленная версия владельцаUNKNOWN. Пока не устанавливать/не удалять приложение. Итоговая партия Drive ещё готовится; промежуточные отчёты не равны native/physicalPASS.
