#!/usr/bin/env python3
"""Ownership checks for the reduced legacy compatibility script."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class LegacyCompatTests(unittest.TestCase):
    def test_exe_owned_report_hotstrings_and_hjkl_are_absent(self) -> None:
        compat = source("legacy/medex_legacy_compat.ahk")
        for trigger in (";red", ";fzg", ";fwj", ";fjd", ";cmx"):
            self.assertNotIn(f":*?:{trigger}::", compat)
        for key in ("h", "j", "k", "l"):
            self.assertNotIn(f"RAlt & {key}::", compat)
        self.assertIn("GlobalHjklArrows=true", compat)

    def test_unmigrated_viewer_actions_remain_available(self) -> None:
        compat = source("legacy/medex_legacy_compat.ahk")
        retained_hotkeys = (
            "~XButton1::",
            "+!b::",
            "+!h::",
            "+!l::",
            "^#+c::",
        )
        for hotkey in retained_hotkeys:
            self.assertIn(hotkey, compat)

    def test_caption_advance_is_owned_by_production(self) -> None:
        compat = source("legacy/medex_legacy_compat.ahk")
        production = source("src/report_image_caption.ahk")
        self.assertNotIn("+!s::", compat)
        self.assertIn('static HotkeyChord := "+!s"', production)

    def test_retired_legacy_viewer_actions_are_absent(self) -> None:
        compat = source("legacy/medex_legacy_compat.ahk")
        for hotkey in ("^#+s::", "^#+m::", "^#+a::"):
            self.assertNotIn(hotkey, compat)
        self.assertNotIn("LastPressSUVTime", compat)
        self.assertNotIn("LastPressArrowTime", compat)
        for coordinate in (
            "1981, 1350",
            "2471, 826",
            "2470, 651",
        ):
            self.assertNotIn(coordinate, compat)

    def test_legacy_snapshot_writer_remains_excluded(self) -> None:
        compat = source("legacy/medex_legacy_compat.ahk")
        self.assertNotIn("+!r::", compat)
        self.assertNotIn("red_not.clip", compat.split("A_IconTip", 1)[1])


if __name__ == "__main__":
    unittest.main()
