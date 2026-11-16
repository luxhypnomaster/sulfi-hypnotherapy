# №19 — ресурсы и checkpoints

Остаток5часового/недельного Codex лимита владельцем не предоставлен; проценты/расход не выдумываются. Вопрос из пакета был задан как необязательный, работа не останавливалась.

G0 до кода: cf5fadb. Initial prototype5d61c63. Единственная попытка hosted CI43949403640 остановлена до runner. Причина billing/spending annotation; автоматические push-триггеры отключены, повторCI не выполнялся. Нет расходов/нулевого биллинга, заявленных без доступа к метрикам.

Проверки по изменениям: targeted25→JVM17→REST24→headless/epoch/provider final28; fullFlutter493 один раз + адресные5после изменения optionalworkerAPI, Node47+24. Полные suites не повторялись ради отчётности. SDK compiler в cmdline-tools оказался stripped: использован полный pinned Kotlin compiler2.1.0 для локальных source tests. Последний compile запускался с ограниченным heap и минимальным classpath.

Local APK: initial Java direct network refused; proxy configuration gave PKIX, затем copied environment truststore resolved Gradle bootstrap. Это разные подтверждённые гипотезы, не слепые одинаковые rebuilds. Полный build однажды дошёл доdaemon loss/OOM observed; повтор при тех же ресурсах не сделан. Обособленные RAM SDK/cache, original SDK и signing/data не трогались. Только свой orphan build workers завершены после build failure.

Stage19 не повторял тяжёлые №18 UI/native/upgrade tests и большой live E2E. Никаких платных действий, server deploy/ACL/main/account migration. APK19 выпуск не объявлен.
