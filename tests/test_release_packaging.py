#!/usr/bin/env python3
"""Behavior and wiring checks for the release packaging workflow."""

from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

from scripts import package_release as packaging


ROOT = Path(__file__).resolve().parents[1]
CMD = ROOT / "Package Release.cmd"
POWERSHELL = ROOT / "scripts" / "package_release.ps1"


def write_publish_fixture(
    build_root: Path,
    *,
    version: str = "0.6.3",
    revision: str = "1234abc",
) -> Path:
    publish = build_root / "publish"
    publish.mkdir(parents=True)
    for file_name in packaging.REQUIRED_FILE_NAMES:
        content = (
            "# 麦旋风版本信息\n\n"
            f"- 版本：{version}\n"
            "- 构建日期：2026-07-30\n"
            f"- 源代码版本：{revision}\n"
            if file_name == "版本信息.md"
            else f"fixture: {file_name}\n"
        )
        (publish / file_name).write_text(content, encoding="utf-8")
    return publish


class ReleasePackagingWorkflowTests(unittest.TestCase):
    def test_cmd_runs_packager_and_propagates_exit_code(self) -> None:
        cmd = CMD.read_text(encoding="utf-8")
        self.assertIn('set "REPOSITORY_ROOT=%~dp0"', cmd)
        self.assertIn("powershell.exe -NoProfile -ExecutionPolicy Bypass", cmd)
        self.assertIn(
            '"%REPOSITORY_ROOT%scripts\\package_release.ps1"',
            cmd,
        )
        self.assertIn('set "PACKAGE_EXIT_CODE=%ERRORLEVEL%"', cmd)
        self.assertIn("exit /b %PACKAGE_EXIT_CODE%", cmd)

    def test_powershell_is_utf8_bom_and_only_launches_python(self) -> None:
        self.assertTrue(POWERSHELL.read_bytes().startswith(b"\xef\xbb\xbf"))
        script = POWERSHELL.read_text(encoding="utf-8-sig")
        self.assertIn("Join-Path $PSScriptRoot 'package_release.py'", script)
        for command in ("py.exe", "python.exe", "python3.exe"):
            self.assertIn(command, script)
        self.assertIn("exit $LASTEXITCODE", script)
        self.assertNotIn("Compress-Archive", script)
        self.assertNotIn("Remove-Item", script)

    def test_package_contains_only_versioned_five_file_allowlist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            build_root = Path(directory)
            publish = write_publish_fixture(build_root)
            (publish / "MxNM-Viewer-Context-Diagnostic.exe").write_bytes(
                b"diagnostic"
            )
            (publish / "unmanaged.log").write_text(
                "not for release",
                encoding="utf-8",
            )

            result = packaging.package_release(build_root)

            self.assertEqual(result.version, "0.6.3")
            self.assertEqual(result.zip_path.name, "麦旋风-v0.6.3.zip")
            self.assertEqual(
                result.hash_path.name,
                "麦旋风-v0.6.3.sha256.txt",
            )
            with zipfile.ZipFile(result.zip_path) as archive:
                self.assertEqual(
                    set(archive.namelist()),
                    set(
                        packaging.expected_archive_names(
                            "麦旋风-v0.6.3"
                        )
                    ),
                )
            self.assertEqual(
                hashlib.sha256(result.zip_path.read_bytes()).hexdigest(),
                result.sha256,
            )
            self.assertIn(
                result.sha256,
                result.hash_path.read_text(encoding="utf-8"),
            )
            self.assertFalse(
                any(build_root.glob("package-staging-*"))
            )

    def test_success_retires_only_old_managed_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            build_root = Path(directory)
            write_publish_fixture(build_root)
            dist = build_root / "dist"
            dist.mkdir()
            (dist / "麦旋风-v0.6.2.zip").write_bytes(b"old zip")
            (dist / "麦旋风-v0.6.2.sha256.txt").write_text(
                "old hash",
                encoding="utf-8",
            )
            unrelated = dist / "maintainer-note.txt"
            unrelated.write_text("keep", encoding="utf-8")

            packaging.package_release(build_root)

            self.assertFalse((dist / "麦旋风-v0.6.2.zip").exists())
            self.assertFalse(
                (dist / "麦旋风-v0.6.2.sha256.txt").exists()
            )
            self.assertEqual(
                unrelated.read_text(encoding="utf-8"),
                "keep",
            )
            self.assertFalse((dist / ".package-previous").exists())

    def test_failed_final_validation_restores_previous_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            build_root = Path(directory)
            write_publish_fixture(build_root)
            dist = build_root / "dist"
            dist.mkdir()
            old_zip = dist / "麦旋风-v0.6.2.zip"
            old_hash = dist / "麦旋风-v0.6.2.sha256.txt"
            old_zip.write_bytes(b"old zip")
            old_hash.write_text("old hash", encoding="utf-8")
            real_validate = packaging.validate_zip
            validation_count = 0

            def fail_second_validation(path: Path, root_name: str) -> None:
                nonlocal validation_count
                validation_count += 1
                if validation_count == 2:
                    raise ValueError("simulated final validation failure")
                real_validate(path, root_name)

            with mock.patch.object(
                packaging,
                "validate_zip",
                side_effect=fail_second_validation,
            ):
                with self.assertRaisesRegex(
                    ValueError,
                    "simulated final validation failure",
                ):
                    packaging.package_release(build_root)

            self.assertEqual(old_zip.read_bytes(), b"old zip")
            self.assertEqual(
                old_hash.read_text(encoding="utf-8"),
                "old hash",
            )
            self.assertFalse((dist / "麦旋风-v0.6.3.zip").exists())
            self.assertFalse((dist / ".package-previous").exists())

    def test_non_release_metadata_is_rejected_without_touching_dist(
        self,
    ) -> None:
        for revision in ("未标记", "UNSTAMPED", "1234abc-dirty"):
            with self.subTest(revision=revision):
                with tempfile.TemporaryDirectory() as directory:
                    build_root = Path(directory)
                    write_publish_fixture(
                        build_root,
                        revision=revision,
                    )
                    dist = build_root / "dist"
                    dist.mkdir()
                    old = dist / "麦旋风-v0.6.2.zip"
                    old.write_bytes(b"old")

                    with self.assertRaisesRegex(
                        ValueError,
                        "non-release build",
                    ):
                        packaging.package_release(build_root)

                    self.assertEqual(old.read_bytes(), b"old")
                    self.assertEqual(
                        list(dist.iterdir()),
                        [old],
                    )

    def test_missing_required_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            build_root = Path(directory)
            publish = write_publish_fixture(build_root)
            (publish / "配置指南.md").unlink()
            with self.assertRaisesRegex(
                FileNotFoundError,
                "required publish file",
            ):
                packaging.package_release(build_root)


if __name__ == "__main__":
    unittest.main()
