# ИСТОЧНИКИ И ДОКАЗАТЕЛЬСТВА; НЕ ВЫДУМЫВАТЬ ЗА №14

## Живые документы проекта
- Старт новый чат / правила: https://docs.google.com/document/d/1FABRBXaL8wV0fiMtMaS1Exjz12d0kUyE72v0n_s8arw/edit
- Оперативное состояние: https://docs.google.com/document/d/1c7I4Ry8RZAk-5yWF1rgy9sdexSJEaCA47OxNRmooPvI/edit
- Реестр K и K-030: https://docs.google.com/document/d/14Lcqe6Rn4Q3hxEuHIuYx7nHfUCnCtgm7mNYoXWgj5M4/edit
- Реестр функций F: https://docs.google.com/document/d/1UEFVm4MkxxCfC8VAYkSMjrtXkAh_wQloPZEAHnjiKgE/edit
- Архитектура дневника и согласованные K-002…K-007/K-018/K-022/K-023: https://docs.google.com/document/d/1Zz53JQQT8PzX7wc0ndlFaWxTrl_HXmKz6KV4BOLYL-s/edit
- Глубокая концепция/дизайн: https://docs.google.com/document/d/1Af2SkvcwdhVkS1ZCxuKqUYjmMAOZwAJeU5fuW3mboBc/edit
- Единый навигатор папок: https://docs.google.com/document/d/1GfMU0dBMSvt12R9Aq7OBEtAPg0HhxYCgTLmI4z23bN4/edit

## Отчёты №14
- Папка: https://drive.google.com/drive/folders/1SAIk6swRXXHa07MDH10irzoiDKPYgkAT
- RESULT: https://drive.google.com/file/d/1W0x4Bd4pFa7-H_Yo9bNq4smcNg1Owkw-/view — 41 PASS / 5 PARTIAL, CI SUCCESS, 379 Flutter tests.
- TESTS: https://drive.google.com/file/d/1a4-DgwtNQU4O9BVX64sabR6Id9ZmZOP1/view — EXACT IDs EXP-08/VER-02/CAT-03/CAT-04/CAT-06 PARTIAL.
- ISSUES: https://drive.google.com/file/d/1SOQntAAbTWr6JNSQLVmQL9X09PuMQ7XK/view
- DATA CONTRACT: https://drive.google.com/file/d/1eqYQEBpL4vXfdRDvL9eM4LATU1Hv5MUb/view — source of truth current ContentKey/RevisionKey/identity, capsule, ContentLink.
- MIGRATIONS: https://drive.google.com/file/d/1v_wGaSLCFDJQl5lFUOXqIC8_xcihHejT/view
- Git HEAD №14: `9982df546aa032d014244df8f4483434294f350b`; PR https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/15 ; base №13 64639bd, PR14 not merged as of report. **Always verify fresh real Git**.
- CI #14: https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42633526373

## Владелец: реальные наблюдения после №14 на Android
- Кнопка «На главную страницу» в истории работает.
- Два экземпляра одного модуля уже в сессии, изменена сортировка только одного, оба выделились курсивом; третий свежедобавленный не выделился. Это **новый bug report**, не отменяется PASS DIF-01...DIF-03 из widget тестов.
- Метка состояния должна быть жёлтой «(Изменено)» и отдельно от авторского имени; имя фуксия+курсив. Тот же принцип у шаблона.
- Выборочный ZIP экспорта создаётся на Android, содержит `manifest.json` и `blobs/`; название «резервная копия» вводит в заблуждение, новое имя `Sulfi_exp_<transliteratedTitle>_DD.MM.YY.zip`.
- В библиотеке щит «Ваше пространство» автор/клиент есть; дублировать на главную сверху справа рядом с Сульфи, но **не удалять** библиотечную кнопку (K-030).
- Локальная запись в дневник работает, remote publish заблокирована из-за отсутствия server deployment. В существующем пользовательском UI импорт ZIP сложно найти.

## Скриншоты — НЕ генерированные, исходные
- `evidence/android_2814_zip_contents.jpg` — системный Android просмотр экспортного ZIP (`manifest.json`,`blobs`).
- `evidence/android_2819_library_shield_sheet.jpg` — библиотека и нижний лист «Ваше пространство», щит.
- `evidence/android_2817_library.jpg` — обычная библиотека; расположение shield, layout.
- Эти изображения являются наблюдениями, НЕ дизайном главного экрана и НЕ разрешением перерисовать Сульфи.
