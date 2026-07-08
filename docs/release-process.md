# Release Process

1. Edit source files in `src/`.
2. Run `python scripts/build_release.py`.
3. Review `release/report_assistant.ahk`.
4. Test on a Windows workstation using `tests/manual-test-checklist.md`.
5. Update `CHANGELOG.md`.
6. Tag the version.
7. Upload the generated `release/report_assistant.ahk` as the internal release asset.

Do not include patient data, hospital identifiers, credentials, screenshots, or sensitive logs in release artifacts.
