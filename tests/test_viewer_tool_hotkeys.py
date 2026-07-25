#!/usr/bin/env python3
"""Structural checks for config-validated MedEx viewer tool hotkeys."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ViewerToolHotkeyTests(unittest.TestCase):
    def test_commands_are_named_and_use_vendor_ids(self) -> None:
        commands = source("src/mxnm_viewer_tool_commands.ahk")
        self.assertIn("static Arrow := 21043", commands)
        self.assertIn("static Length := 21048", commands)
        self.assertIn("static Suv3D := 21193", commands)
        self.assertIn('"User32\\SendMessageTimeoutW"', commands)
        self.assertIn('"UInt", 0x0111', commands)
        self.assertIn('"User32\\GetParent"', commands)
        self.assertIn('"UPtr", target.controlId', commands)
        self.assertIn('"Ptr", target.hwnd', commands)
        self.assertNotIn('"UInt", 0x00F5', commands)
        self.assertIn('"User32\\WindowFromPoint"', commands)
        self.assertIn('"User32\\GetDlgCtrlID"', commands)
        self.assertIn("pointPid != runtimePid", commands)
        self.assertIn("MxNMViewerToolClientRectScreen", commands)
        self.assertIn("PrepareAtStartup", commands)
        for forbidden in ("UIA.", "MouseMove", "Click(", "Sleep "):
            self.assertNotIn(forbidden, commands)

    def test_command_schema_is_semantic_and_fails_closed(self) -> None:
        commands = source("src/mxnm_viewer_tool_commands.ahk")
        self.assertIn('"scbtnpadsetting"', commands)
        self.assertIn('StrSplit(value, "|")', commands)
        self.assertIn("rows.Count != rowCount", commands)
        self.assertIn("matches.Length != 1", commands)
        self.assertIn("SCBtnPadPos", commands)
        self.assertIn("ButtonPitch := 38", commands)
        self.assertIn("matches[1].column != 1", commands)
        self.assertIn("rowIndex := A_Index", commands)
        self.assertIn("row: rowIndex", commands)
        self.assertNotIn("row: A_Index", commands)
        mapping = commands.split(
            "MapMxNMViewerToolPointToRuntimeFrame(", 2
        )[-1]
        self.assertIn("logicalPadPoint.x", mapping)
        self.assertIn("runtimeFrame.windowWidth", mapping)
        self.assertIn(") + buttonOffset.x", mapping)

    def test_hotkeys_are_disabled_by_default_and_medex_scoped(self) -> None:
        model = source("src/feature_model.ahk")
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        features = source("src/features.ahk")
        self.assertIn('static ViewerToolEnabledDefault := "false"', model)
        for chord in ('"^!1"', '"^!2"', '"^!3"'):
            self.assertIn(chord, model)
        self.assertIn(
            "MedExViewerToolForegroundActive",
            source("src/mxnm_viewer_tool_commands.ahk"),
        )
        self.assertIn("MedExViewerToolForegroundActive", features)

    def test_settings_ui_exposes_all_three_hotkeys(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        for label in ("箭头", "长度测量", "3D SUV测量"):
            self.assertIn(label, ui)
        self.assertEqual(ui.count('"Hotkey"'), 3)
        self.assertEqual(ui.count('"CheckBox", "x276'), 3)
        self.assertEqual(ui.count('w90 h26", "启用"'), 3)
        self.assertEqual(ui.count("Limit15"), 3)
        self.assertIn("ValidateViewerToolHotkeySettings(", ui)
        self.assertIn(
            "ViewerToolHotkeyChordHasTwoModifiers",
            source("src/feature_normalization.ahk"),
        )
        self.assertIn("WriteViewerToolHotkeySettings(", editor)
        self.assertIn("ViewerToolHotkeySettingsMatch(", editor)

    def test_release_order_contains_command_and_hotkey_modules(self) -> None:
        main = source("src/main.ahk")
        build = source("scripts/build_release.py")
        for text in (main, build):
            self.assertIn("mxnm_viewer_tool_commands.ahk", text)
            self.assertIn("viewer_tool_hotkeys.ahk", text)
        self.assertLess(
            main.index("#Include mxnm_viewer_tool_commands.ahk"),
            main.index("#Include viewer_tool_hotkeys.ahk"),
        )


if __name__ == "__main__":
    unittest.main()
