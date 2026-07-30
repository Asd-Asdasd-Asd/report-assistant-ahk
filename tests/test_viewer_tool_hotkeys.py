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
        self.assertNotIn('"User32\\WindowFromPoint"', commands)
        self.assertIn('"User32\\EnumChildWindows"', commands)
        self.assertIn('"User32\\GetDlgCtrlID"', commands)
        self.assertIn("candidatePid != runtimePid", commands)
        self.assertIn("MxNMViewerToolWindowRectScreen", commands)
        self.assertIn("IsWindowVisible", commands)
        self.assertIn("IsWindowEnabled", commands)
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
        self.assertIn("matches[1].column != 1", commands)
        self.assertIn("rowIndex := A_Index", commands)
        self.assertIn("row: rowIndex", commands)
        self.assertNotIn("row: A_Index", commands)
        self.assertIn(
            "MapMxNMViewerToolPadOriginToRuntimeFrame",
            commands,
        )
        invoke = commands.split(
            "static Invoke(commandName, viewerExe := \"\") {", 1
        )[1].split("MedExViewerToolForegroundActive(*) {", 1)[0]
        for legacy_constant in (
            "BuiltInRowCount",
            "ButtonCenterX",
            "ButtonCenterY",
            "ButtonPitch",
        ):
            self.assertNotIn(legacy_constant, invoke)
        self.assertIn("ResolveMxNMViewerToolControlSet", invoke)
        self.assertNotIn("ResolveMxNMRuntimeFrame", invoke)
        self.assertIn(
            "MxNMViewerToolRectCenter(target.rect)",
            invoke,
        )

    def test_runtime_control_set_is_unique_visible_and_ordered(self) -> None:
        commands = source("src/mxnm_viewer_tool_commands.ahk")
        resolver = commands.split(
            "\nResolveMxNMViewerToolControlSet(", 1
        )[1].split("\nResolveMxNMViewerToolProcess(", 1)[0]
        for required in (
            "commandKeyById",
            "EnumerateMxNMViewerToolControlCandidates",
            "candidate.parentHwnd",
            "MxNMViewerToolGetRootOwnerHwnd",
            "actionRootHwnd",
            "ValidateMxNMViewerToolControlLayout",
            "validGroups.Length != 1",
        ):
            self.assertIn(required, resolver)
        self.assertIn('"UInt", 3', commands)
        self.assertIn("leftCommand.row < rightCommand.row", commands)
        self.assertIn(
            "leftCommand.column < rightCommand.column",
            commands,
        )
        self.assertNotIn("WindowFromPoint", resolver)
        self.assertNotIn("MxNMViewerToolPanelMatchesPadOrigin", resolver)
        self.assertNotIn("ResolveMxNMViewerToolFrameGeometry", resolver)
        for required in (
            "EnumChildWindows",
            "IsWindowVisible",
            "IsWindowEnabled",
            "NativeClassName",
        ):
            self.assertIn(required, commands)

    def test_hotkeys_are_disabled_by_default_and_medex_scoped(self) -> None:
        model = source("src/feature_model.ahk")
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        features = source("src/features.ahk")
        self.assertIn('static ViewerToolEnabledDefault := "false"', model)
        for chord in ('"^!1"', '"^!2"', '"^!3"', '"^!4"', '"^!5"'):
            self.assertIn(chord, model)
        self.assertIn(
            "MedExViewerToolForegroundActive",
            source("src/mxnm_viewer_tool_commands.ahk"),
        )
        self.assertIn("MedExViewerToolForegroundActive", features)
        self.assertIn(
            "ViewerToolHotkeyDefinitions(settings, false)",
            features,
        )
        self.assertIn(
            "ViewerToolHotkeyDefinitions(settings, true)",
            features,
        )
        self.assertIn("MedExViewerForegroundActive", features)

    def test_single_modifier_and_viewer_only_bare_keys_are_supported(
        self,
    ) -> None:
        normalization = source("src/feature_normalization.ahk")
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        features = source("src/features.ahk")
        self.assertIn("ViewerHotkeyIsSafeBareChord", normalization)
        self.assertIn('"i)^[a-z0-9]$"', normalization)
        self.assertNotIn("modifierCount >= 2", normalization)
        self.assertIn("bareOnly := false", hotkeys)
        self.assertIn(
            "ViewerHotkeyChordIsBare(settings.ViewerArrowChord) = bareOnly",
            hotkeys,
        )
        self.assertIn(
            "ViewerToolHotkeyDefinitions(settings, true)",
            features,
        )
        self.assertIn(
            "MedExViewerForegroundActive",
            features,
        )

    def test_arrow_and_length_wait_for_release_to_prevent_bare_key_repeat(
        self,
    ) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        self.assertIn(
            'InvokeMxNMViewerToolHotkey.Bind(\n'
            '                "arrow",',
            hotkeys,
        )
        handler = hotkeys.split(
            "InvokeMxNMViewerToolHotkey(commandName, chord, *)", 1
        )[1]
        self.assertIn("static active := false", handler)
        self.assertIn(
            "while ViewerHotkeyChordHasPressedComponent(chord)",
            handler,
        )
        self.assertIn('if WinExist("A") != foregroundHwnd', handler)

    def test_settings_ui_exposes_all_viewer_hotkeys_and_win_modifier(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        for label in (
            "箭头",
            "长度测量",
            "3D SUV测量",
            "截图（发送 F12）",
            "清除全部标注",
        ):
            self.assertIn(label, ui)
        self.assertEqual(ui.count('"Hotkey"'), 5)
        self.assertEqual(ui.count('"CheckBox", "x276'), 5)
        self.assertEqual(ui.count('"CheckBox", "x648'), 5)
        self.assertEqual(ui.count('w90 h26", "启用"'), 5)
        self.assertEqual(ui.count('w70 h26", "使用"'), 5)
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

    def test_clear_hotkey_reuses_verified_context_menu_cleanup(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        self.assertIn('"viewer-clear-annotations"', hotkeys)
        self.assertIn("InvokeMxNMViewerClearHotkey.Bind(", hotkeys)
        handler = hotkeys.split(
            "InvokeMxNMViewerClearHotkey(chord, *)", 1
        )[1].split(
            "ViewerHotkeyChordHasPressedComponent(chord) {", 1
        )[0]
        self.assertIn("MxNMAnnotationCleaner.DeleteAll(", handler)
        self.assertIn(
            "MxNMAnnotationCleanupVerificationMode.COMMAND_ONLY",
            handler,
        )
        self.assertIn(
            "while ViewerHotkeyChordHasPressedComponent(chord)",
            handler,
        )
        self.assertIn("MxNMViewerClearFailureMessage(result)", handler)
        self.assertIn(
            "MxNMAnnotationCleanupCode.COMMAND_FAILED",
            hotkeys,
        )
        self.assertIn("result.failureReason", hotkeys)
        self.assertIn(
            "TARGET_CLIENT_POINT_INVALID",
            hotkeys,
        )
        self.assertNotIn("21081", hotkeys)

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
