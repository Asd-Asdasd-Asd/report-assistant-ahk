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
        for chord in ('"^!1"', '"^!2"', '"^!3"', '"^!4"'):
            self.assertIn(chord, model)
        self.assertIn(
            "MedExViewerToolForegroundActive",
            source("src/mxnm_viewer_tool_commands.ahk"),
        )
        self.assertIn("MedExViewerToolForegroundActive", features)

    def test_settings_ui_exposes_all_viewer_hotkeys_and_win_modifier(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        for label in ("箭头", "长度测量", "3D SUV测量", "截图（发送 F12）"):
            self.assertIn(label, ui)
        self.assertEqual(ui.count('"Hotkey"'), 4)
        self.assertEqual(ui.count('"CheckBox", "x276'), 4)
        self.assertEqual(ui.count('"CheckBox", "x648'), 4)
        self.assertEqual(ui.count('w90 h26", "启用"'), 4)
        self.assertEqual(ui.count('w70 h26", "使用"'), 4)
        self.assertNotIn("Limit15", ui)
        self.assertIn("ValidateViewerToolHotkeySettings(", ui)
        self.assertIn(
            "ViewerToolHotkeyChordIsSafe",
            source("src/feature_normalization.ahk"),
        )
        self.assertIn("ViewerHotkeyNativeChord(", ui)
        self.assertIn("ViewerHotkeyUsesWin(", ui)
        self.assertIn("MergeViewerHotkeyChord(", ui)
        self.assertIn("WriteViewerToolHotkeySettings(", editor)
        self.assertIn("ViewerToolHotkeySettingsMatch(", editor)

    def test_capture_mapping_is_viewer_only_and_feedback_is_non_textual(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        features = source("src/features.ahk")
        feedback = source("src/visual_feedback.ahk")
        self.assertIn("ViewerCaptureHotkeyDefinitions(settings)", hotkeys)
        self.assertIn("InvokeMxNMViewerCaptureHotkey.Bind(", hotkeys)
        self.assertIn(
            "ViewerHotkeyChordHasPressedComponent(chord)",
            hotkeys,
        )
        self.assertIn('if WinExist("A") != viewerHwnd', hotkeys)
        self.assertIn('Send "{F12}"', hotkeys)
        self.assertIn("ShowReportAssistantDispatchPulse(viewerHwnd)", hotkeys)
        self.assertIn("MedExViewerForegroundActive", features)
        self.assertIn("ReportAssistantDispatchPulse", feedback)
        pulse = feedback.split(
            "class ReportAssistantDispatchPulse", 1
        )[1]
        self.assertIn("durationMs := 90", pulse)
        self.assertIn('window.BackColor := "FFFFFF"', pulse)
        self.assertIn("WinSetTransparent(", pulse)
        self.assertIn('"User32\\SetWindowDisplayAffinity"', pulse)
        self.assertNotIn('window.Add("Text"', pulse)
        self.assertIn("NoActivate", pulse)

    def test_suv3d_dispatches_once_after_the_chord_is_released(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        commands = source("src/mxnm_viewer_tool_commands.ahk")
        self.assertIn("InvokeMxNMViewerSuv3DHotkey.Bind(", hotkeys)
        self.assertIn('Invoke("suv3d")', hotkeys)
        handler = hotkeys.split(
            "InvokeMxNMViewerSuv3DHotkey(chord, *)", 1
        )[1].split(
            "ViewerHotkeyChordHasPressedComponent(chord) {", 1
        )[0]
        release_wait = (
            "while ViewerHotkeyChordHasPressedComponent(chord)"
        )
        self.assertIn(release_wait, handler)
        self.assertLess(
            handler.index(release_wait),
            handler.index('Invoke("suv3d")'),
        )
        self.assertIn('if WinExist("A") != foregroundHwnd', handler)
        self.assertNotIn("RepeatValidatedMxNMViewerToolButton", commands)
        self.assertNotIn("Sleep 35", hotkeys)
        self.assertIn('GetKeyState("Control", "P")', hotkeys)
        self.assertIn('GetKeyState("LWin", "P")', hotkeys)

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
