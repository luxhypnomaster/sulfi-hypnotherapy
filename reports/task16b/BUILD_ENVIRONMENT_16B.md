# №16-Б — наблюдение сборочного окружения

Первый attempt workflow43163688437 остановился до создания APK: Gradle plugin resolution не нашёл kotlin-stdlib/kotlin-gradle-plugins-bom2.2.21 в plugins.gradle.org, transitively required pinned Flutter Gradle plugin / Kotlin DSL. Исходник приложения012f7f, signing и package от этого не менялись; transient key удалён cleanup step. Ни APK24, ни текущий GAS не затронуты.

Проверка доступности тех же официальных POM через plugins.gradle.org и repo.maven.apache.org вернула200 и валидный XML project,2301bytes для stdlib. Это подтверждает наличие версии, но не устанавливает точную причину отказа GitHub runner. Причина пока CANDIDATE_REPOSITORY_RESOLUTION_TRANSIENT. Не понижались версии Kotlin/Flutter/Gradle и не подменялась подпись. Запрошен повтор failed job на том же проверенном SHA; окончательный результат указан в APK_INFO_16B.md.

Attempt2 того же43163688437 завершился SUCCESS без изменения исходника/репозиториев/версий зависимостей/signing. Обе APK созданы,проверены и скачаны обратно;первоначальный внешний resolution failure сохранён как отдельный факт,а не ошибочно приписан коду приложения.
