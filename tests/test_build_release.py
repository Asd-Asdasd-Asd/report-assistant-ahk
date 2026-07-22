#!/usr/bin/env python3
"""Regression tests for self-contained release generation."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.build_release import (
    build_release_text,
    stamp_source_revision,
    strip_leading_component_bom,
    windows_file_version,
)


ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / "release" / "report_assistant.ahk"


class BuildReleaseEncodingTests(unittest.TestCase):
    def test_component_boms_are_removed_when_merging(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_dir = Path(directory)
            (source_dir / "app_metadata.ahk").write_bytes(
                b'\xef\xbb\xbfclass AppMetadata {\n'
                b'    static Version := "1.2.3-test.1"\n'
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
            )

            self.assertEqual(merged.count("\ufeff"), 0)
            self.assertIn("; --- BEGIN component.ahk ---\n; component", merged)
            self.assertIn('static SourceRevision := "abc123"', merged)

    def test_windows_file_version_is_derived_from_canonical_version(self) -> None:
        self.assertEqual(windows_file_version("0.5.0-alpha.0"), "0.5.0.0")
        self.assertEqual(windows_file_version("2.7.11"), "2.7.11.0")

    def test_source_revision_stamp_requires_metadata_field(self) -> None:
        with self.assertRaisesRegex(ValueError, "SourceRevision"):
            stamp_source_revision(
                'class AppMetadata {\n    static Version := "1.2.3"\n}\n',
                "abc123",
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
        self.assertIn(";@Ahk2Exe-SetFileVersion 0.5.0.0", release_text)
        self.assertIn(";@Ahk2Exe-SetProductVersion 0.5.0-alpha.0", release_text)
        self.assertIn(";@Ahk2Exe-SetName MedEx Report Assistant", release_text)
        self.assertRegex(
            release_text,
            r'static SourceRevision := "(?:[0-9a-f]{40}(?:-dirty)?|UNSTAMPED)"',
        )


if __name__ == "__main__":
    unittest.main()
