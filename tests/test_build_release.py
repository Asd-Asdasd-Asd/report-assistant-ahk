#!/usr/bin/env python3
"""Regression tests for self-contained release generation."""

from __future__ import annotations

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.build_release import (
    build_version_info_text,
    build_release_text,
    extract_app_version,
    require_stamped_source_revision,
    resolve_source_revision,
    short_source_revision,
    stamp_build_date,
    stamp_source_revision,
    strip_leading_component_bom,
    windows_file_version,
)


ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / "release" / "report_assistant.ahk"
VERSION_INFO = ROOT / "assets" / "publish" / "版本信息.md"


class BuildReleaseEncodingTests(unittest.TestCase):
    def test_component_boms_are_removed_when_merging(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_dir = Path(directory)
            (source_dir / "app_metadata.ahk").write_bytes(
                b'\xef\xbb\xbfclass AppMetadata {\n'
                b'    static Version := "1.2.3-test.1"\n'
                b'    static BuildDate := "UNSTAMPED"\n'
                b'    static SourceRevision := "UNSTAMPED"\n}\n'
            )
            (source_dir / "component.ahk").write_bytes(
                b"\xef\xbb\xbf; component\nExample() {\n    return true\n}\n"
            )

            merged = build_release_text(
                source_dir=source_dir,
                order=["app_metadata.ahk", "component.ahk"],
                timestamp="TEST",
                source_revision="abc123",
                build_date="2026-07-26",
            )

            self.assertEqual(merged.count("\ufeff"), 0)
            self.assertIn("; --- BEGIN component.ahk ---\n; component", merged)
            self.assertIn('static SourceRevision := "abc123"', merged)
            self.assertIn('static BuildDate := "2026-07-26"', merged)

    def test_windows_file_version_is_derived_from_canonical_version(self) -> None:
        self.assertEqual(windows_file_version("0.5.0-alpha.0"), "0.5.0.0")
        self.assertEqual(windows_file_version("2.7.11"), "2.7.11.0")

    def test_source_revision_stamp_requires_metadata_field(self) -> None:
        with self.assertRaisesRegex(ValueError, "SourceRevision"):
            stamp_source_revision(
                'class AppMetadata {\n    static Version := "1.2.3"\n}\n',
                "abc123",
            )

    def test_build_date_stamp_is_strict(self) -> None:
        metadata = 'class AppMetadata {\n    static BuildDate := "UNSTAMPED"\n}\n'
        self.assertIn(
            'static BuildDate := "2026-07-26"',
            stamp_build_date(metadata, "2026-07-26"),
        )
        with self.assertRaisesRegex(ValueError, "Build date"):
            stamp_build_date(metadata, "26/07/2026")

    def test_short_revision_and_dirty_version_info_are_readable(self) -> None:
        revision = "81ee8131234567890-dirty"
        self.assertEqual(short_source_revision(revision), "81ee813-dirty")
        version_info = build_version_info_text(
            "0.6.0",
            "2026-07-26",
            revision,
        )
        self.assertIn("# 麦旋风版本信息", version_info)
        self.assertIn("- 版本：0.6.0", version_info)
        self.assertIn("- 构建日期：2026-07-26", version_info)
        self.assertIn("- 源代码版本：81ee813-dirty", version_info)
        self.assertIn("包含未提交修改", version_info)

    def test_formal_generator_requires_git_revision(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "Install Git"):
            require_stamped_source_revision("UNSTAMPED")
        self.assertEqual(
            require_stamped_source_revision("81ee813"),
            "81ee813",
        )

    def test_generated_outputs_do_not_make_the_next_build_dirty(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "release").mkdir()
            (root / "assets" / "publish").mkdir(parents=True)
            (root / "src.txt").write_text("source\n", encoding="utf-8")
            (root / "release" / "report_assistant.ahk").write_text(
                "generated\n",
                encoding="utf-8",
            )
            (root / "assets" / "publish" / "版本信息.md").write_text(
                "generated\n",
                encoding="utf-8",
            )
            for command in (
                ["git", "init", "-q"],
                ["git", "config", "user.email", "test@example.invalid"],
                ["git", "config", "user.name", "Test"],
                ["git", "add", "."],
                ["git", "commit", "-qm", "fixture"],
            ):
                subprocess.run(command, cwd=root, check=True)

            clean_revision = resolve_source_revision(root)
            (root / "release" / "report_assistant.ahk").write_text(
                "regenerated\n",
                encoding="utf-8",
            )
            (root / "assets" / "publish" / "版本信息.md").write_text(
                "regenerated\n",
                encoding="utf-8",
            )
            self.assertEqual(resolve_source_revision(root), clean_revision)

            (root / "src.txt").write_text("changed\n", encoding="utf-8")
            self.assertEqual(
                resolve_source_revision(root),
                f"{clean_revision}-dirty",
            )

    def test_only_a_leading_component_bom_is_removed(self) -> None:
        value = "\ufefffirst\ufeffsecond"
        self.assertEqual(strip_leading_component_bom(value), "first\ufeffsecond")

    def test_generated_release_has_no_u_feff_characters(self) -> None:
        release_text = RELEASE.read_bytes().decode("utf-8")
        self.assertEqual(release_text.count("\ufeff"), 0)
        self.assertFalse(RELEASE.read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_release_directives_are_hoisted_once_before_components(self) -> None:
        release_text = RELEASE.read_text(encoding="utf-8")
        first_component = release_text.index("; --- BEGIN app_metadata.ahk ---")
        for directive in (
            "#Requires AutoHotkey v2.0",
            "#SingleInstance Off",
            "#Warn",
        ):
            self.assertEqual(release_text.count(directive), 1)
            self.assertLess(release_text.index(directive), first_component)

    def test_generated_release_contains_compiler_and_runtime_metadata(self) -> None:
        release_text = RELEASE.read_text(encoding="utf-8")
        metadata = (ROOT / "src" / "app_metadata.ahk").read_text(
            encoding="utf-8"
        )
        version = extract_app_version(metadata)
        self.assertIn(
            f";@Ahk2Exe-SetFileVersion {windows_file_version(version)}",
            release_text,
        )
        self.assertIn(f";@Ahk2Exe-SetProductVersion {version}", release_text)
        self.assertIn(";@Ahk2Exe-SetName MedEx Report Assistant", release_text)
        self.assertRegex(
            release_text,
            r'static BuildDate := "\d{4}-\d{2}-\d{2}"',
        )
        self.assertRegex(
            release_text,
            r'static SourceRevision := "(?:[0-9a-f]{40}(?:-dirty)?|UNSTAMPED)"',
        )

    def test_generated_publish_version_info_matches_release_metadata(self) -> None:
        release_text = RELEASE.read_text(encoding="utf-8")
        version_info = VERSION_INFO.read_text(encoding="utf-8")
        version = re.search(
            r'static Version := "([^"]+)"',
            release_text,
        ).group(1)
        build_date = re.search(
            r'static BuildDate := "([^"]+)"',
            release_text,
        ).group(1)
        source_revision = re.search(
            r'static SourceRevision := "([^"]+)"',
            release_text,
        ).group(1)
        self.assertEqual(
            version_info,
            build_version_info_text(version, build_date, source_revision),
        )


if __name__ == "__main__":
    unittest.main()
