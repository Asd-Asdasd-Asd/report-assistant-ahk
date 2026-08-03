#!/usr/bin/env python3
"""Static safety checks for the MxNM montage control diagnostic."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from scripts.build_mxnm_montage_control_diagnostic import (
    DIRECTIVES,
    build_diagnostic_text,
)


ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tests" / "windows" / "mxnm_montage_control_diagnostic.ahk"


class MxNMMontageControlDiagnosticTests(unittest.TestCase):
    def test_generated_diagnostic_is_single_file(self) -> None:
        generated = build_diagnostic_text()
        self.assertNotIn("#Include", generated)
        self.assertIn("class UIA {", generated)
        self.assertIn("Test=MxNMMontageControlDiagnostic", generated)
        self.assertIn("DiagnosticVersion=0.1", generated)
        for directive in DIRECTIVES:
            self.assertEqual(generated.count(directive), 1)

    def test_layout_and_workflow_targets_are_guided(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        for required in (
            '"GRID_R1_C1"',
            '"GRID_R1_C4"',
            '"GRID_R5_C1_VISIBLE"',
            '"GRID_R5_C4_VISIBLE"',
            '"GRID_R4_C4_TARGET"',
            '"CAPTION_NULL_OPTION"',
            '"WINDOW_DEFAULT_OPTION"',
            '"WINDOW_LUNG_OPTION"',
            '"THICKNESS_EDIT"',
            '"CURRENT_SLICE_EDIT"',
            '"ZOOM_EDIT"',
            '"ExpectedLayoutRows=5',
            '"ExpectedLayoutColumns=4',
        ):
            self.assertIn(required, harness)

    def test_probe_is_hover_only_and_privacy_bounded(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        for required in (
            "InteractionMode=HOVER_ONLY_NO_AUTOMATION_CLICK",
            "Privacy=NO_RAW_NAME_VALUE_OR_WINDOW_TITLE_OUTPUT",
            "RawNamePersisted=false",
            "RawValuePersisted=false",
            "ScreenshotCaptured=false",
            "MouseClickSent=false",
            "TextInputSent=false",
            "SafeMxNMMontageNameToken(rawName)",
            "SetTimer CaptureArmedMxNMMontageDiagnostic, -4000",
            "SetTimer CaptureArmedMxNMMontageDiagnostic, 0",
        ):
            self.assertIn(required, harness)
        for forbidden in (
            r"(?m)^\s*MouseClick\b",
            r"(?m)^\s*Click\b",
            r"(?m)^\s*ControlClick\b",
            r"(?m)^\s*SendText\b",
            r"(?m)^\s*SendInput\b",
        ):
            self.assertIsNone(re.search(forbidden, harness))

    def test_probe_records_uia_native_geometry_and_patterns(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        for required in (
            "UIA.SmallestElementFromPoint",
            "UIA.RawViewWalker.TryGetParentElement",
            '"user32.dll\\WindowFromPoint"',
            '"user32.dll\\GetDlgCtrlID"',
            '"user32.dll\\GetAncestor"',
            "IsInvokePatternAvailable",
            "IsExpandCollapsePatternAvailable",
            "IsValuePatternAvailable",
            "IsSelectionItemPatternAvailable",
            "RectContainsPoint=",
            "EstimatedColumnStep=",
            "EstimatedRowStep=",
        ):
            self.assertIn(required, harness)

    def test_catch_assignment_uses_a_block(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertIn('catch {\n        processName := ""\n    }', harness)
        self.assertNotRegex(harness, r"(?m)^\s*catch\s+\w+\s*:=")


if __name__ == "__main__":
    unittest.main()
