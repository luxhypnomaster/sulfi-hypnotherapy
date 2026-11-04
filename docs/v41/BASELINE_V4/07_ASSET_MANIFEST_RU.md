# Сульфи v4.0 — ГРАФИЧЕСКИЕ РЕСУРСЫ И СТАТУС УТВЕРЖДЕНИЯ

Это реальные файлы в данном ZIP, а не ссылки на отсутствующие картинки. **Не вшивать скриншот как единственный Flutter-экран**: использовать как референс художественного характера.

## Утверждённые макеты экранов

| Файл | Размер | Назначение |
|---|---:|---|
| `assets/screens/01_MAIN_APPROVED.png` | 1024×1536 | Последний утверждённый художественный макет главной, включая «НАЧАТЬ ТРАНСФОРМАЦИЮ», спираль и «Записаться к мастеру». Функционально требуется дополнительно сохранить компактную карточку активного шаблона. |
| `assets/screens/02_RECORDER_APPROVED.png` | 941×1672 | Последний утверждённый диктофон: параметры над записью; спираль; четыре кнопки; Отмена слева, Сохранить справа. |
| `assets/screens/03_PAUSE_CLOCK_REFERENCE.png` | 1122×1402 | Историческая иллюстрация золотого редактора времени: часы должны быть реально интерактивны, не статичная картинка. |

## Реальные ассеты спирали и Android-иконки

Из прежнего графического пакета перенесены ассеты `assets/spiral/android/`, `assets/spiral/brand/`, `assets/spiral/ui/`. Они могут быть более **геометричными**, чем современная художественная спираль большого мокапа. Это известное различие, **не повод переизобретать дизайн главной страницы**.

Для launcher использовать реальные foreground/background/monochrome/legacy согласно Android adaptive icon; для навигации — прозрачную/мелкую UI-спираль. Графика без текста внутри launcher; launcher label — «Сульфи».

| Файл | Размер/тип |
|---|---|
| `assets/spiral/README_FOR_CODEX_RU.md` | MD |
| `assets/spiral/android/ic_launcher_background_432.png` | 432×432 |
| `assets/spiral/android/ic_launcher_foreground_432.png` | 432×432 |
| `assets/spiral/android/ic_launcher_legacy_512.png` | 512×512 |
| `assets/spiral/android/ic_launcher_monochrome_432.png` | 432×432 |
| `assets/spiral/android/ic_launcher_preview_1024.png` | 1024×1024 |
| `assets/spiral/brand/sulfi_spiral_flat.svg` | SVG |
| `assets/spiral/brand/sulfi_spiral_neon.svg` | SVG |
| `assets/spiral/brand/sulfi_spiral_transparent_1024.png` | 1024×1024 |
| `assets/spiral/brand/sulfi_spiral_transparent_128.png` | 128×128 |
| `assets/spiral/brand/sulfi_spiral_transparent_256.png` | 256×256 |
| `assets/spiral/brand/sulfi_spiral_transparent_512.png` | 512×512 |
| `assets/spiral/reference/SULFI_brand_preview.png` | 1450×1170 |
| `assets/spiral/reference/visual_idea_sheet.png` | 1254×1254 |
| `assets/spiral/ui/booking_spiral_nav_192.png` | 192×192 |
| `assets/spiral/ui/booking_spiral_nav_96.png` | 96×96 |

## Скриншоты текущих проблем (не целевой дизайн)

| Файл | Зачем сохранён |
|---|---|
| `assets/current/MAIN_OLD_2_COLUMNS.jpg` | Показана ошибка двухколоночной структуры и обрезания названий |
| `assets/current/HISTORY_OLD_EXPANDED.jpg` | Показана огромная карточка истории |
| `assets/current/STRUCTURE_OLD.jpg` | Показано старое «Без раздела», «Добавить блок» и меню |
| `assets/current/IMPORT_OLD_TAGS.jpg` | Показано старое поле «Метки через запятую» |

## Правила применения

1. Текст v4.0 главнее случайных цифр и названий внутри художественных макетов. Любые счётчики, темы и примеры MP3 **демонстрационные**, не наполнение APK.
2. Основные UI-элементы надо реализовать Flutter-компонентами с настоящими onPressed, состояниями и accessibility; фон/обводки/наслоения могут быть графическими.
3. Спираль в диктофоне функциональная: центральное касание начинает или продолжает запись; верхняя малая спираль — фирменная иконка.
4. Готовая историческая иконка Android не гарантирует попиксельного совпадения с новой художественной спиралью; не скрывать этот факт в отчёте.
5. Не использовать шрифты, изображения, реальные тексты/темы из пользовательских скриншотов как тестовые данные приложения.

## Контроль целостности крупных файлов

| Файл | SHA-256 (первые 16 символов) |
|---|---|
| `assets/screens/01_MAIN_APPROVED.png` | `297ae50129b57bbb` |
| `assets/screens/02_RECORDER_APPROVED.png` | `ffb8a23c6aad5374` |
| `assets/screens/03_PAUSE_CLOCK_REFERENCE.png` | `b4196f1a3775650d` |
**Аудит v4:** старые растровые кнопки с надписью «Записаться на приём» и старый preview нижней навигации намеренно исключены. Их использование противоречило бы финальному названию `Записаться к мастеру`.
