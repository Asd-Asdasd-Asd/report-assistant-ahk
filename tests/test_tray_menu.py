#!/usr/bin/env python3
"""Static checks for the minimal tray-menu reload behavior."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class TrayMenuTests(unittest.TestCase):
    def test_reload_item_is_inserted_before_standard_exit(self) -> None:
        tray = source("src/tray_menu.ahk")
        self.assertIn('static ReloadItemName := "重新加载配置"', tray)
        self.assertIn('static ExitItemName := "E&xit"', tray)
        self.assertIn("A_TrayMenu.Insert(", tray)
        self.assertIn("ReloadReportAssistantFromTray", tray)
        self.assertNotIn('A_TrayMenu.Add("Exit', tray)
        self.assertNotIn('A_TrayMenu.Add("退出', tray)

    def test_double_click_remains_unassigned(self) -> None:
        tray = source("src/tray_menu.ahk")
        self.assertIn('A_TrayMenu.Default := ""', tray)
        self.assertNotIn("A_TrayMenu.ClickCount", tray)

    def test_reload_uses_builtin_restart_without_singleton_bypass(self) -> None:
        tray = source("src/tray_menu.ahk")
        callback = tray.split("ReloadReportAssistantFromTray(*)", 1)[1]
        self.assertIn("try Reload()", callback)
        for forbidden in (
            "ExitApp",
            "Run(",
            "CreateMutex",
            "CloseHandle",
            "REPORT_ASSISTANT_SINGLETON_HANDLE",
        ):
            self.assertNotIn(forbidden, callback)
        self.assertIn("无法重新加载配置", callback)
        self.assertIn("当前版本将继续运行", callback)

    def test_tray_setup_runs_after_runtime_modules_are_included(self) -> None:
        main = source("src/main.ahk")
        self.assertIn("#Include tray_menu.ahk", main)
        setup = main.index("ConfigureReportAssistantTrayMenu()")
        self.assertLess(main.index("#Include hotstrings.ahk"), setup)
        self.assertLess(main.index("#Include features.ahk"), setup)
        self.assertLess(main.index("#Include tray_menu.ahk"), setup)

    def test_release_builder_places_tray_module_before_main(self) -> None:
        builder = source("scripts/build_release.py")
        self.assertLess(builder.index('"tray_menu.ahk"'), builder.index('"main.ahk"'))

    def test_generated_release_contains_the_same_tray_policy(self) -> None:
        release = source("release/report_assistant.ahk")
        self.assertIn('static ReloadItemName := "重新加载配置"', release)
        self.assertIn('A_TrayMenu.Default := ""', release)
        self.assertIn("try Reload()", release)
        tray_end = release.index("; --- END tray_menu.ahk ---")
        setup_call = release.index("ConfigureReportAssistantTrayMenu()", tray_end)
        self.assertLess(tray_end, setup_call)


if __name__ == "__main__":
    unittest.main()
