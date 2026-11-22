# Доставка №25 — проверена обратным скачиванием

Папка https://drive.google.com/drive/folders/1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn , parent For_Codex1iG5L28UybhIxLayHebggTAyH5cP5IPLJ. [Draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57), basePR56d0a6d9a, source737ea741636e9abe7c20353d9d5b8301cf44a5bb, отчётный checkpoint aed7305 (дальше только delivery/docs). Источник/lib/native/server не меняется отчётными commits.

Все28 файлов ниже фактически uploaded и заново downloaded raw через Drive, с независимым сравнением SHA-256, размера и parent. Не только успешный ответ upload. ZIP дополнительно прошёл CRC при readback. Download receipts и upload IDs сохранены в Git reports/task25/DRIVE_READBACK_25.json и DRIVE_DESTINATION_25.json. Сам индекс DELIVERY и его receipts исключены из evidence ZIP/собственного списка, чтобы избежать циклического hash; индекс проверяется отдельной квитанцией DELIVERY_INDEX_READBACK_25.json в Git после загрузки.

Наследуемый anyone:writer в For_Codex **не менялся**. Отчёты санитизированы, без private SQLite/media/credentials/keystore/APK. SHA подтверждает момент readback, не бессрочную неизменяемость папки. Публичный репозиторий не изменён в приватности. Старые файлы/отчёты не перезаписаны/не удалены.

|Файл|Байты|SHA-256 (local=download)|Drive|
|---|---:|---|---|
|ARCHIVE_25.json|277|`830140d725b8fafafcd4541966cd0b0266f145b1ed3600f9a0dc32714be45160`|[Открыть](https://drive.google.com/file/d/1BLOwgQEtesItorj0QmgL0MliEXg4mXKg/view)|
|GITHUB_BASELINE_25.json|1665|`34f05fc3622682e85a29269a90b24dff342da322e9d91fb89224318904cfda9a`|[Открыть](https://drive.google.com/file/d/1TZgz817TArySB-leSDjjVc5PzpRRooHB/view)|
|SOURCE_GATE_25.json|603|`f0555713147a9ea028262adc25701805ff93c1654212fd6046b436c3c8404ab9`|[Открыть](https://drive.google.com/file/d/1RbQBw3qEz3BaGs_h1nLA6qLhhaAGcz76/view)|
|DEPENDENCY_GRAPH_25.md|3478|`54bf6df8e18b9f72853f0693ef4b7924ab723ab5b149e16e0beeaffe1090702f`|[Открыть](https://drive.google.com/file/d/1yY4QliblUZXkLYHIXVbtV_jYqZWP6AE2/view)|
|APK_BLOCKER_25.md|2630|`d77dc68303574453030dc7f703079f9b083ff39df0664c9937b17bfcfc81ded1`|[Открыть](https://drive.google.com/file/d/1FZ_CBeD2UY9veztMswhTlvjlnLndM6rG/view)|
|NATIVE_UPGRADE_25.md|2610|`f95b77ae87da979a7c8e73bf6cb304b5347a8624b8bb503654df31ab951048e8`|[Открыть](https://drive.google.com/file/d/1UjqLnzwTuNL941OJ4feD4QTwvIKqHGya/view)|
|CI_SECURITY_25.md|2288|`c502e426f61d6e46d35df36ce2d0e0a6abdb4545734ad370105af41651ef4411`|[Открыть](https://drive.google.com/file/d/1nFeIGWcWeplJMWVeC7nGKAJFoc47At0r/view)|
|SAFE_NATIVE_PLAN_25.md|5547|`b9425f8d253600127965537a044602768569969850a5f659d480d83462132dcd`|[Открыть](https://drive.google.com/file/d/1YmnXvCDZ7ZqeKUnfKtp5s7zXphOJ5hEB/view)|
|ANDROID_AUDIT_25.md|2961|`5207bbbafdb0390746a1a32b176dc8dab1953a3840178098920bc74870550013`|[Открыть](https://drive.google.com/file/d/1pQUqpFBSusAnrYEtFS3Kv_GaB1YIfMwf/view)|
|SDK_REVIEW_25.json|1414|`7352623dc88d4db2fe611220dd11a446a117ae325c7922a7f641c6ad00ed82ea`|[Открыть](https://drive.google.com/file/d/1fZkcMlh9PnxB_Ob2IXzayQ38EulVmdMZ/view)|
|OWNER_QA_25.md|2685|`116f244d7b02db4ef11e9de883e6b2a94b88837caa91adafafb08828f267b614`|[Открыть](https://drive.google.com/file/d/1tR0KD1RriuFVkXJE64aHJYPsIc3xODg4/view)|
|SOURCE_TREES_25.json|3661|`f3c292451976961712e071bc76c23de7b6497ccb7e7b6c3538b2cd6837826879`|[Открыть](https://drive.google.com/file/d/163JkOgRoI-jLaeV1wdjCbQM4JBeUf2ra/view)|
|CI_PROBE_25.json|895|`e83e5b33fc48bb1654381ed3c45466aa5b52c1187186288ce46504ea05a1e12c`|[Открыть](https://drive.google.com/file/d/1v3Zk0sLXGkwjhMaPdOERU32_8kzcUth5/view)|
|RESULT_25.md|4617|`622767238acafda8cddd80ad0932e84099692fb15d397b7692f54df12d03f78b`|[Открыть](https://drive.google.com/file/d/1usnN7ZGBzYrdhWdAg7oz23nQl3fE4QcW/view)|
|CHANGES_25.md|3116|`a18c986334db7365ea4c99214b0163882f76a52746755355eaa5b6e334f1cd70`|[Открыть](https://drive.google.com/file/d/1RFqaIAARWHtKSiDMOXzAfL-jTM71s6r_/view)|
|TESTS_25.md|5449|`bd84e71987d18a28393477268d01f7dc8c0af57a3acb4fa3336fdbeb570f2fc2`|[Открыть](https://drive.google.com/file/d/1YExy5cJJb8OB-MRpSEvCThwXHv8QQjSW/view)|
|ISSUES_25.md|4535|`40e579defc924b87821526730642fd47f6cb912c1902b3c63a76b8af3d5acac5`|[Открыть](https://drive.google.com/file/d/1RKBUjOLdR0Qn8YMncXAK1nvW6kwupCEL/view)|
|ACCEPTANCE_25.csv|9984|`e3aefbd8fa9a9f3a25d83f6b7cf6098a42451af510842660bf94a9f18a5f96a5`|[Открыть](https://drive.google.com/file/d/10r_evXG0qXDR9PZLu9KaZbYoG31aNU1W/view)|
|EVIDENCE_25.zip|145433|`3987baa0cc1a0d3992bc853d48715a6ab15b299812c9433327fa600eef218295`|[Открыть](https://drive.google.com/file/d/12J01qDlvf_bs0KOVvlQrtWrCDzTDJyxU/view)|
|EVIDENCE_MANIFEST_25.json|8925|`52d888fdeb2bcc664bf031034843fc4eb3e58370484f43182e7db5a3172acd0a`|[Открыть](https://drive.google.com/file/d/10eWfV1eMknpJtQvQVuASLM131tTYOaOx/view)|
|EVIDENCE_ZIP_25.json|241|`f64335e314bc04792e6b1da9a51f97ec5a7d62a2d391d0f3b66c2a9a664d0751`|[Открыть](https://drive.google.com/file/d/1QyQaqyABOzlvMcFXddYQQuzLcBql2-8T/view)|
|TEST_COUNTS_25.json|783|`3620d6ae8e3f47ece5e449358cff00bf9623b3846815cd4668470a834384bb08`|[Открыть](https://drive.google.com/file/d/12scbYqZDRi7XtNa-R1urGq768z-Hkv2o/view)|
|SECURITY_SCAN_25.json|515|`4612e2d9c37af9ed21e6dc6098e4f49f2c29b1685cd41e340500b41930722943`|[Открыть](https://drive.google.com/file/d/12daUyNYTCtQDLnOuKi-se21QJxq7Etst/view)|
|GITHUB_FINAL_25.json|1784|`c1457d3485578dbf28a93b98b612d5c7193f3b6a7cfe8ce6449f0f8665defc81`|[Открыть](https://drive.google.com/file/d/1UZISJK9636T99Z7u9f8OHQGe2ZKAlpRa/view)|
|TEST_SOURCE_25.json|819|`99ddac4f3a5ee35acfa71bf82b9edb64ddfe5d96e4d5389edffe1e42d7e30c36`|[Открыть](https://drive.google.com/file/d/1KmQGgm3TxSayNxA8qdZZDszfmhIW2XpL/view)|
|CI_SOURCE_PINS_25.json|736|`dd7212caf2e318512aea12385ff49e6f765e31feb50b2611cbd2a11cdd94311d`|[Открыть](https://drive.google.com/file/d/1NVGg4_D3brFzyvj-nxr3qpqy0d_V4d5f/view)|
|ENVIRONMENT_PREFLIGHT_25.json|380|`70b945cf079d639f2a5e87fe723c499dbb663dd41a500d2ff0cfebb35650345c`|[Открыть](https://drive.google.com/file/d/1314NR8ukTSBpGAloTE-LNeOnsxMMb551/view)|
|PROGRESS.md|1539|`d39bac695a0521026b6d5d248b0570af6c9aa536c04f2593041d47c1794c8067`|[Открыть](https://drive.google.com/file/d/1eLcdFKZfVufYRAeqlA9ELELY8X7ubv40/view)|

Проверки:574Flutter PASS/2SKIP; Node114; Python53; analyzer/format/source/nativeJava typecompilePASS. Все55критериев заполнены с уровнями. Архив EVIDENCE содержит57manifest entries плюс сам manifest, CRC PASS; APK/подписанных byte-артефактов внутри нет.

CI [45048084597](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45048084597) SUCCESS — только runner probe на main, не текущий Fluttersource. Подписанные MASTER/CLIENT и native normal-upgrade BLOCKED_ENV/BLOCKED_OWNER; Google/два телефона/production22 NOT_RUN. Рабочих новых APK download links нет. Исторические APK28 не переименованы в№25.

Следующий шаг: снять конкретные signing/native blockers по APK_BLOCKER/SAFE_NATIVE_PLAN. Ни main merge, ни publicrelease, ни production deployment в этом этапе не выполнены.
