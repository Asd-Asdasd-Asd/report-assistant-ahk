#!/usr/bin/env python3
"""Structural checks for the unified privacy-safe diagnostic workflow."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class AutomationDiagnosticsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.diagnostics = source("src/automation_diagnostics.ahk")
        self.caption = source("src/report_image_caption.ahk")

    def test_core_has_session_operation_and_monotonic_timing(self) -> None:
        for required in (
            "class AutomationDiagnosticSession",
            "class AutomationDiagnosticOperation",
            "static SessionId",
            "static NextOperationId",
            'FormatTime(, "yyyyMMdd-HHmmss")',
            "this.StartTick := A_TickCount",
            "tickOffsetMs: A_TickCount - this.StartTick",
            '"recordType=operation-summary"',
            '"recordType=stage-event"',
            '"firstSessionUse="',
            '"firstTargetProcessUse="',
            '"targetGeneration="',
        ):
            self.assertIn(required, self.diagnostics)

    def test_logging_policy_is_summary_first_and_detail_is_conditional(self) -> None:
        self.assertIn("lines := [summary]", self.diagnostics)
        self.assertIn("if detailed {", self.diagnostics)
        self.assertIn("this.FirstSessionUse", self.diagnostics)
        self.assertIn("this.FirstTargetProcessUse", self.diagnostics)
        self.assertIn('automationResult != "COMPLETED"', self.diagnostics)
        self.assertIn(
            "AutomationDiagnosticSession.DetailedModeActive()",
            self.diagnostics,
        )

    def test_log_rotation_keeps_three_bounded_files(self) -> None:
        for required in (
            'static LogFileName := "automation-events.log"',
            "static MaxFileBytes := 1048576",
            "static RotatedFileCount := 3",
            "RotateAutomationDiagnosticLog(logPath)",
            'FileMove logPath, logPath ".1", true',
        ):
            self.assertIn(required, self.diagnostics)

    def test_public_snapshot_and_diagnostic_window_are_restart_local(self) -> None:
        self.assertIn("static DiagnosticUntilTick := 0", self.diagnostics)
        self.assertIn("A_TickCount < this.DiagnosticUntilTick", self.diagnostics)
        self.assertIn("static DiagnosticWindowMs := 600000", self.diagnostics)
        self.assertNotIn("IniWrite", self.diagnostics)
        for required in (
            "CopyAutomationDiagnosticInformation",
            "BuildAutomationDiagnosticSnapshot",
            "RecentRelevantAction=",
            "RecommendedDiagnostic=",
            "REPORT_IMAGE_CAPTION",
            "PrivacyContract=NO_PATIENT_TEXT_NO_CLIPBOARD_CONTENT_NO_WINDOW_TITLES",
        ):
            self.assertIn(required, self.diagnostics)

    def test_common_and_caption_fields_are_allowlisted(self) -> None:
        self.assertIn("AutomationDiagnosticFieldAllowed", self.diagnostics)
        for required in (
            '"caption.saveDispatchResult"',
            '"caption.persistenceState"',
            '"caption.advanceDispatchResult"',
            '"caption.saveToAdvanceMs"',
        ):
            self.assertIn(required, self.diagnostics)
        for forbidden in (
            "patientName",
            "reportText",
            "captionText",
            "clipboardText",
            "WinGetTitle",
        ):
            self.assertNotIn(forbidden, self.diagnostics)

    def test_caption_marks_dispatch_without_claiming_persistence(self) -> None:
        for required in (
            'BeginAutomationDiagnosticOperation(\n            "ReportImageCaption"',
            '"caption.saveDispatchResult",\n                    "DISPATCHED"',
            '"caption.persistenceState",\n                    "UNOBSERVABLE"',
            'operation.Stage("SAVE_CLICK_DISPATCHED")',
            'operation.Stage("SAVE_SETTLE_COMPLETED")',
            'operation.Stage("ADVANCE_DISPATCHED")',
            'result.ok ? "COMPLETED" : "FAILED"',
        ):
            self.assertIn(required, self.caption)
        self.assertNotIn("SAVE_CONFIRMED", self.caption)
        self.assertNotIn("PERSISTED", self.caption)

    def test_modules_and_tray_support_workflow_are_production_owned(self) -> None:
        main = source("src/main.ahk")
        builder = source("scripts/build_release.py")
        tray = source("src/tray_menu.ahk")
        self.assertIn("#Include automation_diagnostics.ahk", main)
        self.assertLess(
            builder.index('"automation_diagnostics.ahk"'),
            builder.index('"app_startup.ahk"'),
        )
        self.assertIn('static CopyDiagnosticItemName := "复制诊断信息"', tray)
        self.assertIn(
            'static EnableDiagnosticItemName := "开启 10 分钟详细诊断"',
            tray,
        )
        self.assertIn("CopyAutomationDiagnosticInformation", tray)
        self.assertIn("EnableAutomationDiagnosticsForTenMinutes", tray)


if __name__ == "__main__":
    unittest.main()
