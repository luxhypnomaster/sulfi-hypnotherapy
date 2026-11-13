# №17 — проверки (checkpoint до завершения CI)

## CODE / CONTROLLED

- G0: два production-path RED до исправлений; дополнительный frozen-public-credential RED. Точные тесты и логи сохранены.
- G1:13 targeted PASS (пересекающиеся серии не суммируются как новые тесты).
- G2/G3:19 auth/queue/root/diary/shared-session/SDK/production-domain-loopback PASS. Потеря ответа после commit проверяется с прежним requestId и промежуточным GET.
- G4:5 новых unit/widget PASS; отдельный существующий catalog UI200% font PASS. Проверены focus/selection/composing, профиль автора, категории, все страницы preview и отсутствие read-state writes,5 нажатий→1 review, ошибка enqueue сохраняет editor и точный draft.
- Node candidate46 PASS; analyze без замечаний;185 lib/test files format без изменений. Эти числа относятся к перечисленным прогонам, не к ещё работающему full CI.
- Точный старый Diary.js GAS6: новый short-only regression RED. Candidate server diff GREEN. Этот RED означает воспроизведение ограничения старого сервера, не успешную live публикацию.

## Полный CI / Android

[https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43513716062](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43513716062), source `5cfb8a10dfa11be8718a8692126c39b7179212bc`: PENDING. Он запускает locked dependencies, схемы/контракты, оба JS backend suites, формат/analyze, весь Flutter набор, CLIENT compile-time тесты. Затем отдельный job собирает signed MASTER/CLIENT27, сверяет cert/packages/config/storage guard. Три fresh Android35 jobs проверяют UI-created MASTER25→27, MASTER26→27 и CLIENT25→27. Их фактические результаты будут дописаны; запуск job не равен PASS.

Локальный /dev/kvm отсутствует. Бесполезная установка эмулятора не выполнялась. Исходная SQLite и медиа создаются через Android UI в disposable CI; SQL используется только для чтения копий SQLite/WAL/SHM и сравнений после обновления. Физические устройства владельца не затрагиваются.

## LIVE / OWNER

Read-only health HTTP200 с исходником существующего сервера. Настоящий Google Android login обоих аккаунтов,15/30/60мин, сетевые переключения и человеческая слышимость трёх установленных треков — NOT_RUN. Controlled identities в loopback/SDK tests не являются настоящими Google-пользователями.
