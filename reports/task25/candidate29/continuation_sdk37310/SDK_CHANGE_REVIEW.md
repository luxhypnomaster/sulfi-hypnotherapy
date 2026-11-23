# №25: подтверждённая новая гипотеза SDK37.3.10

Официальные release notes Google от19.11.2026 содержат SIGSEGV fix #324995885. SDK stable channel0/build16970787, URL/size/SHA1 из repository2-3.xml;350068887bytes, SHA256a4405349d8a9c52136ab7861e5331dc40e85574bd91cb8889a298a2ff4c52e26, fullZIPCRC/source.propertiesverified locally. Это новая обоснованная гипотеза, не утверждение что данный vendor fix устраняет наш неизвестный fault.

Новый trustedQA helper устанавливает exact archive только в disposableCI доAVD, без signing bindings. Checks before SDKmutation, namespace/bounds/duplicates/symlink validation, headlessversion and rollback on failure; old frozen17prehook reused for resourcechecks and processmonitor with pin37.3.10 (its old37.2.12 install branch skipped). Strong readiness marker requires observed version +both hashes+size. Same appsource737, same APK29build45103325755, data assertions ASTidentical except existing MASTERobserver and added SDK/readiness metadata.

Если crash повторится: bounded hostkernel read-onlymetadata только monitoredQEMU PID, allowlistedmodule+relativeIP; no rawkernel/stack/memory published. Permissiondenial is honestUNAVAILABLE, not success.91controlledtoolsPASS/actionlint beforemanualfull35/36. Tests are not nativePASS. NativeGATE stillall4mandatory, ownerphysical/GoogleNOT_RUN.

Mainproposal scope: verifyworkflow+native25.py+newemulator_sdk25.py only. No app/server/DB/OAuth/ACL/key changes. OrdinaryprotectedmainPR only, expectedhead/base/hashreadback. No sign/builderrerun. Newnative source expectedSDK fingerprint required by independentvalidator; old receipts retain historicalscope and cannot masquerade ascurrentSDKPASS.
