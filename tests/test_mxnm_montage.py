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
        for value in ('"8.5"', '"8"', '"0.8"', '"4"', '"11"', '"1.2"', '"7.5"', '"23"', '"0.9"'):
            self.assertIn(value, module)
        self.assertIn('Preset: "lung"', module)
        self.assertEqual(module.count('Preset: "default"'), 2)

    def test_profiles_keep_legacy_chords_and_physical_transports(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn('"montage-body", "+!b"', module)
        self.assertIn('"montage-head", "+!h"', module)
        self.assertIn('"montage-lung", "+!l"', module)
        self.assertIn('MouseClick "left", x, y, 1, 0', module)
        self.assertIn('StrLower(pointClass) != "combolbox"', module)
        self.assertIn('Type: "ListItem", cs: 0', module)
        self.assertNotIn("SelectionItemPattern.Select", module)
        self.assertIn("MxNMMontageWaitForHotkeyRelease(profileId)", module)
        self.assertIn('KeyWait("Alt", "T2")', module)
        self.assertIn('KeyWait("Shift", "T2")', module)
        self.assertIn("static LayoutSettleMs := 350", module)
        self.assertIn("static EditConfirmTimeoutMs := 300", module)
        self.assertIn("static EditConfirmPollMs := 20", module)
        self.assertIn("static ButtonSettleMs := 60", module)
        self.assertIn("Sleep MxNMMontageTiming.LayoutSettleMs", module)
        self.assertIn("Sleep MxNMMontageTiming.EditConfirmPollMs", module)
        self.assertIn("Sleep MxNMMontageTiming.ButtonSettleMs", module)
        self.assertNotIn("index < steps.Length ? 250", module)
        self.assertIn('CoordMode "Mouse", "Screen"', module)

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

    def test_layout_is_configurable_but_only_validated_r4c4_executes(self) -> None:
        module = source("src/mxnm_montage.ahk")
        self.assertIn('static LayoutRowKey := "LayoutRow"', module)
        self.assertIn('static LayoutColumnKey := "LayoutColumn"', module)
        self.assertIn("settings.layoutRow != 4 || settings.layoutColumn != 4", module)
        self.assertIn('"LAYOUT_PROFILE_UNVALIDATED"', module)

    def test_module_is_integrated_into_bootstrap_and_release_build(self) -> None:
        self.assertIn("#Include mxnm_montage.ahk", source("src/main.ahk"))
        self.assertIn('"mxnm_montage.ahk"', source("scripts/build_release.py"))
        self.assertIn("MxNMMontageDefaults.ManagedConfigDefaults()", source("src/config_bootstrap.ahk"))
        self.assertIn('"[" MxNMMontageDefaults.Section "]"', source("src/hotstring_config.ahk"))
        self.assertIn("LoadMxNMMontageSettings()", source("src/features.ahk"))


if __name__ == "__main__":
    unittest.main()
