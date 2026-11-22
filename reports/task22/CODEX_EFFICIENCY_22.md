# Экономия и контроль №22

Источник a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde. Не вычислялись проценты пользовательской квоты.

- Использованы существующие G0/№20/21 audit, PR51/52 readback; новая ветка, без переписывания работающих компонентов.
- Адресные Node/Flutter проверки при изменении соответствующего кода; full Flutter после code freeze; после найденного replay/revoke edge повторён full. После него только форматирование metadata_runtime и Node-only overview cache; последняя адресная проверка охватывает итоговый source. Node full повторялся только после новых Node изменений. Addressed counts не прибавляются к full.
- При замене окружения потерян только незафиксированный временный SHM-код; повтор понадобился для восстановленного источника, а не ради отчётности. Git checkpoints ce8f4a9/772cc39/402346c/0adcb4d/54c1932 сохранены. Потерянные logs не доказывают current source.
- Recovery первый target выявил init-order policyHash и test error-code expectation; исправлено. Model constructor и lint recovery исправлены адресно. Недоказанные промежуточные результаты не PASS.
- Hosted CI не повторялся вслепую после billing0steps run44959026009. Коммиты [skip ci]; ни main/workflows/billing/права не менялись. PR может показывать skipped/check-required; это не CI PASS.
- Никаких APK/native/эмуляторных установок/OOM retries. User v1.7 приоритетнее старого AGENTS Android build пункта.
- Live blocker не остановил jobs/backup/ratings/IAM/courses/admin/batch. Production gates и отсутствующие функции названы прямо, без подмены отчётом.

Фактические full Flutter runs:54c1932(539/2),9113800(539/2) после receipt/revoke fix,a5a4c77(539/2) после подтверждённого wire-order UI дефекта и полного freeze. Третий прогон закрепляет однозначный final source; новых изменений после него нет. Node full76→78→79 соответствуют дополнительным receipt/backup-history/derived-cache изменениям,8–9s каждый. Hosted CI/native не повторялись. Недельная квота не оценивалась.
