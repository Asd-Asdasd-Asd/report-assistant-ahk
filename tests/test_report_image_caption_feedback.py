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
        self.assertIn('card.BackColor := "EDF5FF"', body)
        self.assertIn('highlight.BackColor := "69A7FF"', body)
        self.assertIn('"User32\\SetWindowDisplayAffinity"', body)

    def test_motion_uses_easing_arc_scale_absorption_and_highlight(self) -> None:
        body = self.feedback.split(
            "static Advance(state)", 1
        )[1].split("\n    static RoundWindow", 1)[0]
        self.assertIn("progress * progress * (3 - 2 * progress)", body)
        self.assertIn("curveY", body)
        self.assertIn("inverse * inverse", body)
        self.assertIn("MinimumScale", body)
        self.assertIn("arrival * arrival", body)
        self.assertIn("highlightOpacity", body)
        self.assertIn("WinSetTransparent(", body)
        self.assertIn("SetTimer(", body)

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

    def test_caption_highlight_rect_is_derived_and_cached(self) -> None:
        self.assertIn("captionHighlightRect := {", self.caption)
        self.assertIn("l: Max(paneRect.l + 6, descriptionRect.r + 6)", self.caption)
        self.assertIn("r: saveRect.l - 6", self.caption)
        self.assertGreaterEqual(
            self.caption.count('HasOwnProp("captionHighlightRect")'),
            3,
        )
        self.assertIn(
            "captionHighlightRect: target.captionHighlightRect",
            self.caption,
        )


if __name__ == "__main__":
    unittest.main()
