# Native run4 — actual result, no phone PASS

Run45157723278; trusted main cd8cf33789150d6c169c52906149a43f05a0b1cb; app737ea741636e9abe7c20353d9d5b8301cf44a5bb; same signed pair from45103325755, no rebuild/signing. Provider artifact digests and ZIP CRC independently verified.

CLIENT API34: all15 cases PASS. Independent row/media/integrity readback PASS including actual ordinary28→29 upgrade and cold29 restart. Native playback observed; sound heard by a person NOT_RUN. Google NOT_RUN.

MASTER API34:5 cases PASS then ui_module_pause BLOCKED on OLD28 before candidate29 is installed. Host child3287 qemu-system-x86 died with exit-11/SIGSEGV,291.23seconds, no wrapper signals. Cgroup oom/oom_kill counters stayed0; available host memory ~14GB. This proves emulator death, not an app migration cause; allocation/driver faults are not excluded by memory counters. Faulting module/instruction UNKNOWN.

API36 both NOT_RUN because unchanged API34 dependency gate failed. Delivery skipped. Independent four-gate validator BLOCKED; cannot recommend owner installation. All original P0 assertions remain mandatory.

New justified diagnostic: bounded Crashpad exception/code-module metadata, no memory/stack dump publication. Prior renderer experiments swangle43586282741 and lavapipe43586934519 failed on old26. Do not repeat renderer roulette. New diagnostic-only scope selects MASTER API34, blocks API36 and tester delivery, keeps current SDK/GPU/APKs/assertions. A synthetic parser test is not native PASS. If no dump is found report UNKNOWN, stop same-hypothesis retry.
