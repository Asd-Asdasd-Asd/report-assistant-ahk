#!/usr/bin/env python3
"""Structural coverage for quick-caption transfer feedback."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ReportImageCaptionFeedbackTests(unittest.TestCase):
    def setUp(self) -> None:
        self.feedback = source("src/visual_feedback.ahk")
        self.caption = source("src/report_image_caption.ahk")

    def test_transfer_is_nonactivating_click_through_and_text_like(self) -> None:
        body = self.feedback.split(
            "class ReportImageCaptionTransferFeedback", 1
        )[1]
        self.assertIn("+AlwaysOnTop -Caption +ToolWindow -DPIScale", body)
        self.assertIn("+E0x20 +E0x08000000", body)
        self.assertIn('card.Show("NoActivate")', body)
        self.assertIn('"≡"', body)
        self.assertIn('card.BackColor := "3F4650"', body)
        self.assertIn('card.SetFont("s13 Bold cF4F5F7"', body)
        self.assertIn("static CardWidth := 42", body)
        self.assertIn("static CardHeight := 28", body)
        self.assertNotIn("HighlightWindow", body)
        self.assertNotIn("highlight.BackColor", body)
        self.assertIn('"User32\\SetWindowDisplayAffinity"', body)

    def test_motion_uses_easing_arc_scale_and_absorption(self) -> None:
        body = self.feedback.split(
            "static AdvanceCurrent()", 1
        )[1].split("\n    static RoundWindow", 1)[0]
        self.assertIn("progress * progress * (3 - 2 * progress)", body)
        self.assertIn("curveY", body)
        self.assertIn("inverse * inverse", body)
        self.assertIn("MinimumScale", body)
        self.assertIn("arrival * arrival", body)
        self.assertIn("WinSetTransparent(", body)
        self.assertIn("SetTimer(", body)
        self.assertIn("ReportImageCaptionTransferFeedbackTimer", body)
        self.assertNotIn("Advance.Bind(state)", body)
        self.assertIn(
            "ReportImageCaptionTransferFeedbackCleanupTimer", self.feedback
        )

    def test_save_dispatch_starts_feedback_inside_existing_wait(self) -> None:
        action = self.caption.split(
            "ExecuteReportImageCaptionAction(cache, target, expectedForegroundHwnd)",
            1,
        )[1].split("\nSetReportImageCaptionClipboard(payload)", 1)[0]
        show = "ShowReportImageCaptionTransferFeedback("
        self.assertIn(show, action)
        self.assertIn("ReportImageCaptionFeedbackOrigin(", action)
        self.assertLess(
            action.index("target.savePoint.x"),
            action.index(show),
        )
        self.assertLess(
            action.index(show),
            action.index("ExplicitSaveSettleMs"),
        )
        self.assertLess(
            action.index(show),
            action.index('SendInput "{WheelDown}"'),
        )

    def test_no_unreliable_caption_highlight_geometry_is_retained(self) -> None:
        self.assertNotIn("captionHighlightRect", self.caption)
        self.assertNotIn("highlightRect", self.feedback)


if __name__ == "__main__":
    unittest.main()
