#!/usr/bin/env python3
"""Safety checks for the report image caption migration diagnostic."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HARNESS = (
    ROOT
    / "tests"
    / "windows"
    / "report_image_caption_migration_diagnostic.ahk"
)


class ReportImageCaptionMigrationDiagnosticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = HARNESS.read_text(encoding="utf-8")

    def test_three_stage_capture_covers_source_caption_and_image(self) -> None:
        for required in (
            "StartReportCaptionDiagnostic()",
            "CaptureReportCaptionInputPoint()",
            "CaptureReportCaptionImagePoint()",
            '"CAPTION_INPUT"',
            '"IMAGE_WHEEL"',
            "SnapshotReportCaptionWindow(",
            "SnapshotReportCaptionMonitors(",
            "CollectReportCaptionNativePointChain(",
            "CollectReportCaptionUiaParentChain(",
        ):
            self.assertIn(required, self.source)

    def test_selection_probe_discards_payload_and_restores_clipboard(self) -> None:
        self.assertIn('SendInput("^c")', self.source)
        self.assertIn("savedClipboard := ClipboardAll()", self.source)
        self.assertIn("A_Clipboard := savedClipboard", self.source)
        self.assertIn('copiedText := ""', self.source)
        self.assertIn("SelectionPayloadPersisted=false", self.source)
        for forbidden in (
            '"CopiedText="',
            '"SelectionText="',
            "FileAppend(",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_diagnostic_does_not_click_paste_or_scroll(self) -> None:
        for forbidden in (
            "MouseClick(",
            'MouseClick "',
            'SendInput("^v")',
            'SendInput("{WheelDown}")',
            "WinActivate",
        ):
            self.assertNotIn(forbidden, self.source)
        for declaration in (
            "MouseClickSent=false",
            "WheelSent=false",
            "PasteSent=false",
        ):
            self.assertIn(declaration, self.source)

    def test_diagnostic_never_outputs_raw_accessible_content(self) -> None:
        self.assertIn(
            "Privacy=NO_RAW_NAME_VALUE_TEXT_TITLE_OR_URL_OUTPUT",
            self.source,
        )
        for forbidden in (
            ".Name",
            ".Value",
            "ValuePattern.Value",
            "GetText(",
            "ControlGetText",
            "WinGetText",
            "LegacyIAccessiblePattern.",
            '"Title="',
            '"URL="',
        ):
            self.assertNotIn(forbidden, self.source)

    def test_known_name_queries_are_fixed_static_anchors_only(self) -> None:
        self.assertIn('condition: {Name: "图像描述"}', self.source)
        self.assertIn('condition: {Name: "保存"}', self.source)
        self.assertNotIn("snapshot[\"name\"]", self.source)


if __name__ == "__main__":
    unittest.main()
