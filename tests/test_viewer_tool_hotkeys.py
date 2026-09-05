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
        self.assertNotIn("PrepareAtStartup", commands)
        for forbidden in ("UIA.", "MouseMove", "Click(", "Sleep "):
            self.assertNotIn(forbidden, commands)

    def test_native_plan_has_no_vendor_geometry_or_persistent_cache_gate(self) -> None:
        commands = source("src/mxnm_viewer_tool_commands.ahk")
        provider = commands.split("class MxNMViewerToolCommandProvider {", 1)[1].split(
            "MedExViewerToolForegroundActive(*) {", 1)[0]
        for forbidden in ("LoadStaticConfig", "ConfigPaths", "FileRead", "CachedPlan",
                          "frameSizeResolved", "SCBtnPadPos", "PrepareFromPathCache"):
            self.assertNotIn(forbidden, provider)
        self.assertIn("MxNMViewerToolCommand.Specs()", provider)
        self.assertIn("WinGetProcessPath", provider)
        self.assertIn("paths.Count != 1", provider)
        self.assertIn("ResolveMxNMViewerToolControlSet", provider)
        self.assertIn('"User32\\IsWindowEnabled", "Ptr", target.hwnd', provider)
        collector = commands.split("\nCollectMxNMViewerToolControlCandidate(\n", 1)[1].split(
            "\nMxNMViewerToolPanelMatchesPadOrigin", 1)[0]
        self.assertNotIn("IsWindowEnabled", collector)

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

    def test_tool_wrappers_share_bounded_release_transaction(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        self.assertIn('return RunMxNMViewerHotkey(commandName, chord)', hotkeys)
        self.assertIn('return RunMxNMViewerHotkey("suv3d", chord)', hotkeys)
        self.assertEqual(hotkeys.count("static active := false"), 1)
        runner = hotkeys.split("RunMxNMViewerHotkey(commandName, chord) {", 1)[1].split(
            "\nWaitMxNMViewerHotkeyRelease(", 1)[0]
        self.assertLess(runner.index("WaitMxNMViewerHotkeyRelease"),
                        runner.index("MxNMViewerToolCommandProvider.Invoke"))
        self.assertIn('operation.Complete("CANCELLED", "BUSY")', runner)
        self.assertIn("operation.Complete(outcome, resultCode)", runner)
        self.assertIn("timeoutMs := 3000", hotkeys)

    def test_settings_ui_exposes_all_viewer_hotkeys_and_win_modifier(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        for label in (
            "快速标图",
            "箭头",
            "长度测量",
            "3D SUV测量",
            "截图（发送 F12）",
            "清除全部标注",
        ):
            self.assertIn(label, ui)
        self.assertEqual(ui.count('"Hotkey"'), 9)
        self.assertEqual(ui.count('"CheckBox", "x276'), 7)
        self.assertEqual(ui.count('"CheckBox", "x648'), 9)
        self.assertEqual(ui.count('w90 h26", "启用"'), 6)
        self.assertEqual(ui.count('w70 h26", "使用"'), 9)
        self.assertNotIn("Limit15", ui)
        self.assertIn("ValidateFeatureHotkeySettings(", ui)
        self.assertIn(
            "ViewerToolHotkeyChordIsSafe",
            source("src/feature_normalization.ahk"),
        )
        self.assertIn("ViewerHotkeyNativeChord(", ui)
        self.assertIn("ViewerHotkeyUsesWin(", ui)
        self.assertIn("MergeViewerHotkeyChord(", ui)
        self.assertIn("WriteFeatureHotkeySettings(", editor)
        self.assertIn("FeatureHotkeySettingsMatch(", editor)
        self.assertIn("ReportImageCaptionEnabledInput", ui)
        self.assertIn("ReportImageCaptionChordInput", ui)
        self.assertIn("ReportImageCaptionWinInput", ui)

    def test_capture_dispatch_is_single_and_foreground_checked_after_pulse_discovery(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        runner = hotkeys.split("RunMxNMViewerHotkey(commandName, chord) {", 1)[1].split(
            "\nWaitMxNMViewerHotkeyRelease(", 1)[0]
        self.assertEqual(runner.count('Send "{F12}"'), 1)
        discover = runner.index("pulseHwnd := ResolveMxNMViewerCapturePulseHwnd")
        recheck = runner.index('if WinExist("A") != foregroundHwnd', discover)
        self.assertLess(discover, recheck)
        self.assertLess(recheck, runner.index('Send "{F12}"'))
        self.assertLess(runner.index('Send "{F12}"'), runner.index("ShowReportAssistantDispatchPulse"))
        self.assertIn('"UNOBSERVABLE"', runner)
        self.assertIn('"viewer.dispatchResult", "DISPATCHED"', runner)
        pulse = source("src/visual_feedback.ahk").split("class ReportAssistantDispatchPulse", 1)[1]
        for required in ('durationMs := 90', 'NoActivate', 'SetWindowDisplayAffinity'):
            self.assertIn(required, pulse)

    def test_clear_hotkey_reuses_context_menu_cleanup_once(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        self.assertIn('return RunMxNMViewerHotkey("clear", chord)', hotkeys)
        self.assertEqual(hotkeys.count("MxNMAnnotationCleaner.DeleteAll("), 1)
        self.assertIn("MxNMAnnotationCleanupVerificationMode.COMMAND_ONLY", hotkeys)
        self.assertNotIn("21081", hotkeys)

    def test_key_read_failure_is_not_treated_as_release(self) -> None:
        hotkeys = source("src/viewer_tool_hotkeys.ahk")
        reader = hotkeys.split("ViewerHotkeyChordHasPressedComponent(chord) {", 1)[1].split(
            "\nMxNMViewerClearFailureMessage", 1)[0]
        self.assertNotIn("catch", reader)
        self.assertIn("throw ValueError", reader)
        self.assertIn('GetKeyState("Control", "P")', reader)
        self.assertIn('GetKeyState("LWin", "P")', reader)

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
