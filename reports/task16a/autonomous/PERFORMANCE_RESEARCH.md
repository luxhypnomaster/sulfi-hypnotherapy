# №16 — кандидат оптимизации Drive, без production deploy

Baseline: immutable server version6; файл test/fixtures/GasTransfer.version6.js — точная копия существующего GasTransfer.js из c895291. Измерение — local VM с реальным production adapter/stream SHA и подсчётом вызовов Google API через контролируемый test double. Это НЕ новая живая скорость Google Drive.

Для верификации1,048,617байт за5chunks baseline выполняет15metadata+15Permissions.list+5range=35RPC. Кандидат:10metadata+10Permissions.list+5range=25RPC, сокращение28.57%. SHA256 совпадает с native crypto, диапазоны/размеры/байты те же. Одна metadata+ACL проверка файла удалена как дублирующая: объединённый read проверяет parent+file ACL и expected MIME/size непосредственно перед Range. Между chunks ничего не кэшируется.

Отдельно проверены отзыв родительской папки, публикация самого файла при private parent, смена owner, MIME/size mismatch, ACL после полного прохода. До нового чтения выдаётся отказ. Остальные43теста исходного сервера остаются обязательны. Все45тестов и сборка GAS исходника проходят. Ни deployments, ни manifest OAuth scopes, ни Drive данные не менялись.

Другие источники задержек: immutable index shards создают verified snapshot и повторный readback при перемещении head; каждый private read проверяет Files.get+полный Permissions.list. Прежний mixed live51:42/193API/6.54MB, publish max67.910s — исторический baseline, не чистое копирование. По этим числам нельзя вычислить новую секундную скорость. После разрешения владельца нужен ограниченный живой контроль на том же проекте с безопасными sample-операциями, до него candidate latency=NOT_RUN.

Не применять: долгоживущий cache ACL, пропуск Permissions pagination, доверие только Files.shared, пропуск SHA/readback, публичные Drive URLs. Возможные последующие улучшения: сокращение числа immutable index commits/размера shard без изменения атомарности; fresh Drive checksum для пропуска второго byte-readback только при наличии проверяемого SHA256 и полного ACL. Эти идеи пока не реализованы и не выданы за ускорение.

Рекомендация: кодовая оптимизация имеет низкий объём, но production внедрение отложить до review+подтверждения и ограниченного реального измерения. Новая версия GAS не развёртывалась; server6 сохранён.
