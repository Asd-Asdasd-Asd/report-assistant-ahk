#!/usr/bin/env python3
"""Static safety tests for the stepped Lung montage field test."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from scripts.build_mxnm_montage_lung_field_test import (
    DIRECTIVES,
    build_field_test_text,
)


ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tests" / "windows" / "mxnm_montage_lung_field_test.ahk"


class MxNMMontageLungFieldTestTests(unittest.TestCase):
    def test_generated_field_test_is_single_file(self) -> None:
        generated = build_field_test_text()
        self.assertNotIn("#Include", generated)
        self.assertIn("class UIA {", generated)
        self.assertIn("Test=MxNMMontageLungFieldTest", generated)
        self.assertIn("FieldTestVersion=0.5", generated)
        for directive in DIRECTIVES:
            self.assertEqual(generated.count(directive), 1)

    def test_test_is_operator_stepped_and_lung_only(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertIn("^!+F10::AdvanceMxNMMontageLungFieldTest()", harness)
        self.assertIn("^!+F7::AbortMxNMMontageLungFieldTest()", harness)
        self.assertIn(
            "InteractionMode=OPERATOR_STEPPED_ONE_ACTION_PER_HOTKEY",
            harness,
        )
        self.assertIn("Profile=LUNG_7.5_23_0.9_LAYOUT_R4_C4", harness)
        for expected_id in (
            'id: "layout-r4-c4"',
            'id: "tab-3"',
            'id: "caption-null"',
            'id: "tab-5"',
            'id: "window-lung"',
            'id: "thickness-value"',
            'id: "thickness-apply"',
            'id: "slice-value"',
            'id: "slice-jump"',
            'id: "tab-4"',
            'id: "zoom-value"',
            'id: "zoom-enter"',
        ):
            self.assertIn(expected_id, harness)

    def test_control_contract_matches_windows_evidence(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        for expected in (
            '21112,\n                "Static"',
            '21007,\n                "Static"',
            'RunMxNMMontageLungComboSelection.Bind(21155, "null")',
            'RunMxNMMontageLungComboSelection.Bind(21014, "lung")',
            'RunMxNMMontageLungEditValue.Bind(21012, "7.5")',
            "RunMxNMMontageLungButtonInvoke.Bind(21015)",
            'RunMxNMMontageLungEditValue.Bind(21201, "23")',
            "RunMxNMMontageLungButtonInvoke.Bind(21203)",
            'RunMxNMMontageLungEditValue.Bind(21032, "0.9")',
        ):
            self.assertIn(expected, harness)

    def test_static_clicks_are_bounded_physical_clicks_with_effect_checks(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertIn('"User32\\WindowFromPoint"', harness)
        self.assertIn("POINT_HWND_MISMATCH", harness)
        self.assertIn('MouseClick "left", screenX, screenY, 1, 0', harness)
        self.assertIn("MouseMove originalMouseX, originalMouseY, 0", harness)
        self.assertIn('"MouseMovementSent=" MxNMMontageLungBoolean(', harness)
        self.assertIn('"MouseButtonInputSent=" MxNMMontageLungBoolean(', harness)
        self.assertIn("STATIC_CLICK_NO_EFFECT", harness)
        self.assertIn("STATIC_CLICK_EFFECT_CONFIRMED", harness)
        self.assertIn("WaitForMxNMMontageLungControl(", harness)
        for expected_effect in (
            '0.5,\n                21155,\n                "ComboBox"',
            '0.5,\n                21014,\n                "ComboBox"',
            '0.5,\n                21032,\n                "Edit"',
        ):
            self.assertIn(expected_effect, harness)

    def test_standard_controls_use_uia_patterns(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        for expected in (
            "combo.ExpandCollapsePattern.Expand()",
            "option.SelectionItemPattern.Select()",
            "element.ValuePattern.SetValue(requestedValue)",
            "element.InvokePattern.Invoke()",
            "element.SetFocus()",
        ):
            self.assertIn(expected, harness)
        self.assertIn("desktop := UIA.GetRootElement()", harness)
        self.assertIn('Type: "ListItem",\n        cs: 0', harness)
        self.assertIn("UIA.RawViewWalker.TryGetParentElement(current)", harness)
        self.assertIn("UIA.CompareElementsEx(current, combo)", harness)
        self.assertIn('result["optionRawCandidateCount"]', harness)
        self.assertIn('result["optionDesktopQuerySucceeded"]', harness)

    def test_keyboard_input_is_enter_only(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        sends = re.findall(r'(?m)^\s*Send\s+"([^"]+)"', harness)
        self.assertEqual(sends, ["{Enter}"])
        self.assertNotRegex(harness, r"(?m)^\s*(SendText|SendInput)\b")
        self.assertIn("KeyboardInputSent=ENTER_ONLY", harness)
        self.assertIn("VIEWER_CHANGED_BEFORE_ENTER", harness)

    def test_control_resolution_is_unique_and_identity_checked(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertIn("EnumChildWindows", harness)
        self.assertIn("GetDlgCtrlID", harness)
        self.assertIn("UIA.ElementFromHandle(session[\"viewerRootOwner\"])", harness)
        self.assertIn("AutomationId: String(controlId)", harness)
        self.assertIn("element.NativeWindowHandle", harness)
        self.assertIn('result["win32CandidateCount"]', harness)
        self.assertIn('result["uiaCandidateCount"]', harness)
        self.assertIn("candidatesByHwnd := Map()", harness)
        self.assertIn("candidates.Length != 1", harness)
        self.assertIn('StrLower(processName) != "medexnmfusion.exe"', harness)
        self.assertIn(
            'MxNMMontageLungRootOwner(hwnd) != session["viewerRootOwner"]',
            harness,
        )

    def test_catch_assignments_use_blocks(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertNotRegex(
            harness,
            r"(?m)^[ \t]*catch[ \t]+\w+[ \t]*:=",
        )
        for forbidden_name in (
            "stageError",
            "elementError",
            "expandError",
            "selectionError",
            "valueError",
            "invokeError",
            "focusError",
        ):
            self.assertNotIn(f"catch as {forbidden_name}", harness)

    def test_control_ready_does_not_mark_action_success(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        merge = harness.split(
            "MergeMxNMMontageLungResult(result, source) {", 1
        )[1].split("\n}\n", 1)[0]
        self.assertIn('key = "ok"', merge)
        self.assertIn('result["ok"] := true', harness)

    def test_numeric_ids_and_counts_are_not_formatted_as_booleans(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        formatter = harness.split(
            "FormatMxNMMontageLungFieldStep(step) {", 1
        )[1].split("\n}\n", 1)[0]
        self.assertIn("booleanKeys := Map(", formatter)
        self.assertIn("if booleanKeys.Has(key)", formatter)
        self.assertNotIn("if value = true || value = false", formatter)


if __name__ == "__main__":
    unittest.main()
