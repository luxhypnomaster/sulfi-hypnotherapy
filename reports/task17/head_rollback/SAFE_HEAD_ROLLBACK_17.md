# №17 — deployment rollback и GAS HEAD: разные состояния

Production apply/rollback НЕ разрешены. Этот документ — план; main/live не менялись.

Текущий main-tool b88637a mode=rollback переключает deployment на6, но оставляет HEAD. Поэтому он НЕ считается полным восстановлением source-state и не должен запускаться как полный rollback без отдельного согласования процедуры ниже.

## Контракт восстановления

1. Перед любым разрешённым apply сохранить PRIVATE полный immutable6 content, manifest/types/SHA, deployment config и HEAD. Не класть InitialConfig/source secrets в отчёты. В отчёте только hashes; восстановление возможно также через неизменяемую version6 API.
2. После apply сохранить фактический versionNumber и полный manifest нового Diary-only bundle. Это позволяет отличить наш patch от постороннего HEAD. Не полагаться на один runtime sourceSha, он исторический.
3. Перед rollback снова GET deployment/active source/HEAD/version6. Active может быть только6 или ровно our Diary-only bundle. Иное — STOP. При уже6 никаких повторных writes deployment.
4. Если HEAD=base6, восстановление HEAD не нужно. Если HEAD=our-patch, подготовить diff HEAD→base6: ровно Diary condition. Если HEAD отличается хотя бы в одном source/type/name (даже чужой комментарий), автоматический push HEAD ЗАПРЕЩЁН. Сохранить чужое состояние приватно и оставить HEAD; отдельно согласовать ручное объединение или сохранить незавершённые правки владельцем. Не притворяться, что source rollback завершён.
5. Для полного rollback с HEAD=our-patch требуется отдельное разрешение и подтверждение владельцем окна исключительного доступа: закрыты редакторы Apps Script, остановлены сторонние clasp/CI writers. Наш GitHub concurrency покрывает только наши workflows, а не сторонний редактор. Apps Script content API не предоставляет атомарного CAS, поэтому одна предварительная hash-проверка не исключает гонку. Без такого окна HEAD НЕ ПИСАТЬ.
6. В этом окне сначала переключить existing deployment на immutable6 и проверить numeric version/executeAs/access/URL. Снова прочитать HEAD и сравнить полностью с our-patch непосредственно перед разрешённым push base6; при отличии STOP. Затем восстановить HEAD точными файлами version6 и GET content: all files/types/bytes/hash =base6. Никаких createScript/нового endpoint/bootstrap/ACL/данных.
7. Если push неопределён или final readback не совпал: STOP, сохранить факты, никаких автоматических повторов/«возврата» чужих файлов. Deployment6 и HEAD отмечать отдельно; полный rollback PASS только при обоих readback и фактически соблюдённом exclusive-writer окне.

## Реализованный предохранитель

Feature-only rollbackHeadPlan — чистая функция, никакого Google I/O и write. Различает BASE6/OUR_PATCH/FOREIGN; FOREIGN active STOP; FOREIGN HEAD всегда preserve, даже при exclusiveWriter=true. Даже eligible план не выполняет запись. Новые tests проверяют все ветви. Он не переносился в main и не меняет production-инструмент. Автоматическое восстановление HEAD не добавлено: без гарантированного окна записи оно было бы небезопасным.
