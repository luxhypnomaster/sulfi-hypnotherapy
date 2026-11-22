# Working policy
1. Source audit F-038/K-025/029/026/027/030/037: each can be already fixed by tasks 13,15,17,18,20. Do NOT create duplicate routes/widgets or claim a feature added just because it existed.
2. First write/regress tests reproducing named real symptom. Only then minimal bug fixes. Preserve current Home/RunScreen geometry and approved colors. If already tested PASS, report as verified rather than modifying it.
3. Task21 likely modifies diary reader and carousel; do not overwrite its work. Use isolated branch and rebase only after future branch inspected. Task22 writes catalog/admin; do not modify their files.
4. No production, personal data, live auth, APK signing, main merge. Avoid blocking on GitHub Actions billing/physical phone. Run local analyze, tests and visible widget 9:16 evidence when environment allows.
5. If a subtask conflicts with #21/#22, emit exact minimal patch/tests and continue other screens.
