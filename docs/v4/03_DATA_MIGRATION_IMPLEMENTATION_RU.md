# Сульфи v4.0 — ДАННЫЕ, МИГРАЦИЯ И КОНТРАКТ ИСПОЛНЕНИЯ

Этот документ конкретизирует `02_UNIFIED_SPEC_V4_RU.md`. Это **логическая схема**, не предписание конкретного ORM, SQLite, Hive, Isar или формата JSON до аудита существующего Flutter-кода.

## 1. Разделить определения, экземпляры и файлы

```text
PhaseType {
  id: string, canonicalOrder: int, title: string, description: string
}
ModuleDefinition {
  id: UUID|string, title, description, optionalTags[],
  recommendedPhaseTypeIds[], source: localUser|bundledFuture,
  version: int, recipeEntries: Ordered<RecipeEntry>,
  createdAt, updatedAt, archived?: bool
}
RecipeEntry {
  id: UUID, kind: audio|silence|freeWork,
  audioAssetId?: string, durationMs?: int,
  delayBeforeMs: int, enabledByDefault: bool, position: int
}
AudioAsset {
  id: UUID, title, description, librarySection, subcategory,
  tags[], source: imported|recorded|bundled,
  contentUriOrManagedPath?, bundledPath?, durationMs, format,
  createdAt, updatedAt, deleted?: bool
}
SessionTemplate {
  id, name, description, version, isDefault?,
  orderedPhases: PhaseInstance[], createdAt, updatedAt,
  contentPackId?: string
}
CurrentSessionDraft {
  id, sourceTemplateId?, sourceTemplateVersion?,
  modified: bool, topic, notes, orderedPhases: PhaseInstance[],
  updatedAt, draftSchemaVersion
}
PhaseInstance {
  instanceId: UUID, phaseTypeId, titleOverride?, enabled: bool,
  orderKey, children: Ordered<PhaseChild>
}
PhaseChild = ModuleInstance | TimelineItem
ModuleInstance {
  instanceId: UUID, moduleDefinitionId?: string, definitionVersion?,
  enabled: bool, modified: bool, orderKey,
  items: Ordered<TimelineItem>
}
TimelineItem {
  instanceId: UUID, kind: audio|silence|freeWork,
  enabled: bool, orderKey,
  audioAssetId?: string, displayTitleSnapshot?: string,
  audioDurationSnapshotMs?: int,
  delayBeforeMs: int,
  intervalDurationMs?: int,
  settings?: map
}
SessionRun {
  id, displayNumber, templateOriginId?,
  startedAtUtc, startedUtcOffsetMinutes, startedTimeZoneId?,
  startedLocalDate, endedAtUtc?, status,
  topicSnapshot, notesSnapshot, frozenPhases: DeepCopy<PhaseInstance>,
  frozenAudioMetadata: map<AssetId, {title,duration,format}>,
  events: Ordered<RunEvent>, recordings: RecordingLink[]
}
RunEvent {
  id, runId, atUtc, kind,
  phaseInstanceId?, moduleInstanceId?, timelineItemId?,
  elapsedMs?, playheadMs?, reason?, metadata?
}
VoiceRecording {
  id, audioAssetId?, createdAtUtc, recordingOrigin: library|draftNote|runWork,
  linkedDraftId?, linkedRunId?, lifecycleStatus
}
```

**Принципы:**
- `ModuleDefinition` = состав, который пользователь/автор настраивает **в каталоге**. `ModuleInstance` = конкретное применение, в которое **копируется** состав (deep copy `TimelineItem`, только ссылка на `AudioAsset` сохраняется). Изменение экземпляра не мутирует исходный каталог.
- Один тип модуля допустим 2, 3, 10 раз **в одной фазе**, если пользователь столько раз выбрал его через `Добавить модуль`. У всех `ModuleInstance.instanceId` уникален. Ссылка `moduleDefinitionId` общая. Запретов уникальности по `moduleDefinitionId + phaseInstanceId` нет.
- `PhaseType` — 10 стандартных записей. В интерфейсе пустого шаблона могут отображаться 10 `PhaseSlot`/virtual suggestions; не обязательно сериализовать 10 пустых `PhaseInstance`, но поведение и порядок стабильны. В реально исполняемом плане — только явно включённые фазы с исполняемыми элементами.
- `PhaseChild` решает проблему общего порядка: модуль A, свободный трек X, модуль B, тишина могут идти **вперемежку**. Проигрыватель flatten-ит их в том же порядке. Список UI и плейлист аудио должны совпадать.
- `delayBeforeMs` относится к конкретному `TimelineItem`, перемещается **вместе с ним**, не к соседней строке. При выключении элемента его задержка не проигрывается и не попадает в сумму.
- Необязательные рекомендации фазы (`ModuleDefinition.recommendedPhaseTypeIds`) **не влияют на совместимость**: любой модуль можно выбрать для любой фазы.
- Модуль может не иметь треков; его включение не создаёт фиктивных элементов и не увеличивает длительность. Созданный модуль с нулевым составом показывать «Пустой модуль», а не «доступен к воспроизведению».
- `AudioAsset` живёт отдельно от ссылок на него; название, категория или теги аудио не ограничивают использование. Удаление исходного файла не должно удалять историю или повторяющиеся экземпляры из снимков.

## 2. Изменения каталога и каскадная консистентность

При импорте MP3/записи `recorded` сначала создаётся/сохраняется `AudioAsset`, затем отдельной транзакцией, согласно выбору пользователя: (а) прикрепляется к существующему `ModuleDefinition`; (б) создаётся новый `ModuleDefinition` и добавляется туда; (в) остаётся без назначения. Если сохранение модуля сорвалось, трек должен остаться в библиотеке с понятным предупреждением; не терять файлы.

Правки `ModuleDefinition` НЕ переигрывают хранившиеся в текущем черновике `ModuleInstance`. При дальнейшем добавлении модуля создаётся новый экземпляр из актуальной версии каталога. Аналогично обновление bundled-модулей через APK не меняет сохранённые пользовательские шаблоны без их отдельного обновления.

Модуль, применённый несколько раз в одной фазе, не превращать в один при сериализации, десериализации, drag-and-drop, экспорте или миграции. Никаких `Set(moduleDefinitionId)` при flatten/restore.

Суммарное время, фазы/модули/треки и журналы вычислять из `effectivePlan = enabledPhases.flatMap(children in order).flatMap(enabledModules.items / loose item).filter(enabled)`. При этом `AudioAsset.durationMs` брать из кэша/метаданных, а при запуске сохранить снимок длительности. Временные элементы `silence` и `freeWork` складываются отдельно. Если время открыто — плановая сумма приблизительная. Любой preview/seek не меняет draft.

## 3. Безопасная миграция текущего приложения

1. До миграции: перечислить существующие models/entities, таблицы, сериализаторы, миграции, AudioAsset URIs, каталог записи, `SessionRun` и статусы. Создать тестовые JSON/DB фикстуры *реально существующего формата*, а не выдумать только новый формат.
2. Сохранить старые аудиобайты и стабильные ID. По возможности выполнить резервную копию перед преобразованием; миграция idempotent и версионируемая.
3. Старый «блок»/`SessionStep`, являющийся одиночной записью -> `TimelineItem(kind=audio)`; старый `freeWork`/«самостоятельная работа» -> `TimelineItem(kind=freeWork)`; «тишина» -> `kind=silence`. Старые `delayBefore` переводить **как задержки ДО** без сдвига на следующий элемент.
4. Если у старого шага нет фазы/модуля, не удалять его и не назначать случайную индукцию. Использовать техническую совместимую группу `Нераспределённые` в редакторе до ручного распределения. **Это не 11-й стандартный тип фазы и не новая категория библиотеки.** При переходе в редактор предложить корректное перемещение.
5. Старые сессии с history snapshots сохраняют запланированную структуру и все старые фактические события; если полная конфигурация старта ранее не была записана, помечать `legacyIncompletePlan=true` и честно показывать ограничения для `Повторить`/`Создать шаблон`, вместо выдуманного плана.
6. Даты истории: если есть UTC/offset — показывать день недели исходной даты. Если сохранилась только локальная строка без timezone, использовать её для исторического отображения и не конвертировать наугад; пометить ограничение миграции. Не менять номер, уникальные ID и исходные timestamps в истории.
7. Если у пользователя уже есть модульные структуры, сохранять их как отдельные экземпляры. Повторную миграцию не выполнять повторно; тестировать два перезапуска подряд.
8. Система должна начать работу со старыми живыми файлами без принудительного повторного импорта. При повреждении/отсутствии файла — показать путь/метаданные и возможность исправить ссылку, не считать всё успешным.
9. Определить старые тестовые fixtures: (A) 2 MP3 + 2 интервала; (B) пауза до первого; (C) два одноимённых трека; (D) изменённый черновик; (E) прерванная сессия; (F) старый шаблон с отсутствующим аудио.
10. Миграцию выполнять до запуска нового UI с использованием корректного schemaVersion и журналом ошибок; при невозможности — не стирать пользовательские данные.

## 4. Статусы и переходы сеанса

```text
Draft --press CTA, valid plan--> Running
Running --pause user/focus--> Paused
Paused --resume--> Running
Running/Paused --freeWork extend--> same run (duration adjusted), event logged
Running --finish freeWork early--> Running at next scheduled item
Running/Paused --go to exit--> ExitingEarly
ExitingEarly --exit playback complete--> CompletedEarlyWithExit
Running --last planned item complete--> Completed
Running/Paused/ExitingEarly --user confirms interrupt--> Interrupted
Running/Paused/ExitingEarly --system/unrecoverable failure--> ErrorOrInterrupted
```

`Completed` не равно `CompletedEarlyWithExit`, и тем более не `Interrupted`. Исторический `frozenPlan` неизменяемый, даже если во время FreeWork продлили интервал: дополнение хранится **в RunEvent** и вычисляется для фактической длительности. Если несколько фаз «Выход», выбрать **первую доступную последующую** при досрочном выходе; если ни одной далее по плану нет — уточнить у пользователя доступные выходные треки/показать возможность остановить без звуковых имитаций. Не переносить исполнение к самому началу очереди.

Когда пользователь нажимает `Пауза`, остановить и воспроизведение и отсчёт интервалов; при `Продолжить` восстановить точное место. `Stop` и `Go to exit` — различные команды с подтверждением. При аудиофокусе `Duck` или `Pause` выбрать политику исходя из безопасного поведения; отключение наушников — пауза, без неожиданного перехода на динамик. `Force stop`/kill ОС не объявлять успехом.

## 5. Хранение и приватность записи

- Диктофон пишет во временный каталог (`temp/recordings`) или эквивалент, до `Завершить` файл не считается законченным. После `Завершить` доступен предпросмотр; после `Сохранить трек` — атомарное перемещение/копирование в managed local media и запись транзакции `AudioAsset`.
- При `Отмена`/`Удалить` уничтожать только временный несохранённый дубль после подтверждения. Существующий сохранённый `AudioAsset` и записи, прикреплённые к другим сценариям, не удалять.
- Не требовать сетевого подключения. Разрешение микрофона — только при начале записи. При сохранении не пропускать нулевой/нечитаемый файл.
- Связь записи с `ModuleDefinition` не равнозначна связи с конкретным `ModuleInstance` или текущим `SessionRun`: пользовательский выбор явно определяет, что изменяется.

## 6. Проверка целостности и поставка

- unit tests: flatten точно по UI, пауза ДО, стабильный порядок, повтор модуля в одной фазе, независимость модулей/экземпляров, нулевая длительность пустых групп, подсчёт total; сохранение черновика без перезаписи шаблона.
- migration tests: fixtures на старые данные, двойной миграционный проход, отсутствующий файл, старый стартовый timestamp.
- recording tests: разрешения, save atomic, отмена с подтверждением, модуль новый/существующий/без связки, отсутствие дублей при двойном сохранении.
- background tests: device scenarios отдельно; нельзя заменить их unit-тестами.
- При отсутствии SDK/устройства в финальном отчёте явно разделить `automated passed` и `physical-device NOT TESTED`.
