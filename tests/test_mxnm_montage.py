#!/usr/bin/env python3
"""Structural checks for the field-validated Montage transport."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MxNMMontageTests(unittest.TestCase):
    def test_defaults_are_disabled_and_preserve_validated_profiles(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn('static Section := "MontageHotkeys"', module)
        self.assertIn('static EnabledDefault := "false"', module)
        self.assertIn('Thickness: "8.5", SliceKey: "BodySlice", Slice: "8", ZoomKey: "BodyZoom", Zoom: "0.7"', module)
        self.assertIn('Thickness: "4", SliceKey: "HeadSlice", Slice: "11", ZoomKey: "HeadZoom", Zoom: "1.2"', module)
        self.assertIn('Thickness: "8", SliceKey: "LungSlice", Slice: "23", ZoomKey: "LungZoom", Zoom: "0.85"', module)
        self.assertIn('Preset: "lung"', module)
        self.assertEqual(module.count('Preset: "default"'), 2)

    def test_profiles_keep_legacy_chords_and_physical_transports(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn('static BodyChordDefault := "+!b"', module)
        self.assertIn('static HeadChordDefault := "+!h"', module)
        self.assertIn('static LungChordDefault := "+!l"', module)
        self.assertIn('settings.chords["body"]', module)
        self.assertIn('settings.chords["head"]', module)
        self.assertIn('settings.chords["lung"]', module)
        self.assertIn('MouseClick "left", x, y, 1, 0', module)
        self.assertIn('StrLower(pointClass) != "combolbox"', module)
        self.assertIn('Type: "ListItem", cs: 0', module)
        self.assertNotIn("SelectionItemPattern.Select", module)
        self.assertIn("MxNMMontageWaitForHotkeyRelease(chord)", module)
        self.assertIn("ViewerHotkeyChordHasPressedComponent(chord)", module)
        self.assertIn("static LayoutSettleMs := 350", module)
        self.assertIn("static InitialControlReadyTimeoutMs := 1500", module)
        self.assertIn("static EditConfirmTimeoutMs := 300", module)
        self.assertIn("static EditConfirmPollMs := 20", module)
        self.assertIn("static ButtonSettleMs := 60", module)
        self.assertIn("Sleep MxNMMontageTiming.LayoutSettleMs", module)
        self.assertIn("Sleep MxNMMontageTiming.EditConfirmPollMs", module)
        self.assertIn("Sleep MxNMMontageTiming.ButtonSettleMs", module)
        self.assertNotIn("index < steps.Length ? 250", module)
        self.assertIn('CoordMode "Mouse", "Screen"', module)

    def test_only_required_initial_control_gets_bounded_readiness_retry(self) -> None:
        module = source("src/mxnm_montage.ahk")
        steps = module.split("steps := [", 1)[1].split("\n    ]", 1)[0]
        self.assertEqual(
            steps.count("MxNMMontageTiming.InitialControlReadyTimeoutMs"),
            1,
        )
        self.assertIn(
            'MxNMMontageStaticClick.Bind(21112, "Static", '
            "layoutPoint.xRatio, layoutPoint.yRatio, 0, \"\", "
            "MxNMMontageTiming.InitialControlReadyTimeoutMs)",
            steps,
        )
        static_click = module.split(
            "MxNMMontageStaticClick(controlId, className, xRatio, yRatio, "
            "effectId, effectClass, resolveTimeoutMs, session) {",
            1,
        )[1].split("\nMxNMMontageComboSelect", 1)[0]
        self.assertIn("MxNMMontageWaitForControl(", static_click)
        self.assertNotIn("WinGetTitle", static_click)
        self.assertNotIn("MonitorGet", static_click)

    def test_control_resolution_keeps_win32_and_uia_paths(self) -> None:
        module = source("src/mxnm_montage.ahk")
        resolver = module.split(
            "MxNMMontageResolveControl(session, controlId, className) {", 1
        )[1].split("MxNMMontageCollectUiaControls(session, controlId, className) {", 1)[0]
        self.assertIn('"User32\\EnumChildWindows"', resolver)
        self.assertIn("candidatesByHwnd", resolver)
        self.assertNotIn("uia :=", resolver)
        self.assertIn("MxNMMontageCollectUiaControls", module)
        self.assertIn("AutomationId: String(controlId)", module)

    def test_layout_is_configurable_and_r4c4_keeps_validated_point(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn('static LayoutRowKey := "LayoutRow"', module)
        self.assertIn('static LayoutColumnKey := "LayoutColumn"', module)
        self.assertIn("MxNMMontageLayoutPoint(", module)
        self.assertIn("0.131579 + (column - 1) * 0.25", module)
        self.assertIn("0.171014 + (row - 1) * 0.20", module)
        self.assertNotIn("settings.layoutRow != 4", module)

    def test_montage_settings_validate_hotkey_conflicts_and_match_saved_values(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn("ValidateMxNMMontageSettings(", module)
        self.assertIn("BuildHotkeyChordSet(ReservedApplicationHotkeyChords())", module)
        self.assertIn("ViewerToolHotkeyChordIsSafe(chord)", module)
        self.assertIn("MxNMMontageSettingsMatch(expected, actual)", module)

    def test_module_is_integrated_into_bootstrap_and_release_build(self) -> None:
        self.assertIn("#Include mxnm_montage.ahk", source("src/main.ahk"))
        self.assertIn('"mxnm_montage.ahk"', source("scripts/build_release.py"))
        self.assertIn("MxNMMontageDefaults.ManagedConfigDefaults()", source("src/config_bootstrap.ahk"))
        self.assertIn('"[" MxNMMontageDefaults.Section "]"', source("src/hotstring_config.ahk"))
        self.assertIn("LoadMxNMMontageSettings()", source("src/features.ahk"))

    def test_settings_writer_preserves_profile_numbers(self) -> None:
        editor = source("src/hotstring_config_editor.ahk")
        writer = editor.split(
            "WriteMxNMMontageSettings(configPath, settings) {", 1
        )[1].split("\n}\n\nEditableReportHotstringEntriesMatch", 1)[0]
        for key in (
            "EnabledKey",
            "LayoutRowKey",
            "LayoutColumnKey",
            "BodyChordKey",
            "HeadChordKey",
            "LungChordKey",
        ):
            self.assertIn(key, writer)
        self.assertNotIn("ThicknessKey", writer)
        self.assertNotIn("SliceKey", writer)
        self.assertNotIn("ZoomKey", writer)


if __name__ == "__main__":
    unittest.main()
