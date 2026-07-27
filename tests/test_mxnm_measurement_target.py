#!/usr/bin/env python3
"""Checks for the field-only automatic MxNM measurement target resolver."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def maximin_center(
    models: list[list[tuple[int, int, int, int]]],
    width: int,
    height: int,
) -> tuple[int, int, int] | None:
    candidates = {
        (round((left + right) / 2), round((top + bottom) / 2))
        for panes in models
        for left, top, right, bottom in panes
    }
    best: tuple[int, int, int] | None = None
    for x, y in candidates:
        clearances: list[int] = []
        for panes in models:
            pane_clearances = [
                min(x - left, right - x, y - top, bottom - y)
                for left, top, right, bottom in panes
                if left < x < right and top < y < bottom
            ]
            if not pane_clearances:
                break
            clearances.append(max(pane_clearances))
        else:
            clearance = min(clearances)
            candidate = (clearance, -y, -x)
            if best is None or candidate > (best[2], -best[1], -best[0]):
                best = (x, y, clearance)
    if best is None or best[2] < min(width, height) * 0.05:
        return None
    return best


class MxNMMeasurementTargetTests(unittest.TestCase):
    def test_maximin_point_is_deterministic_and_cleared(self) -> None:
        models = [
            [(0, 0, 100, 100)],
            [
                (0, 0, 50, 50),
                (50, 0, 100, 50),
                (0, 50, 50, 100),
                (50, 50, 100, 100),
            ],
        ]
        self.assertEqual(maximin_center(models, 100, 100), (25, 25, 25))

    def test_no_shared_or_low_clearance_point_fails_closed(self) -> None:
        self.assertIsNone(
            maximin_center(
                [[(0, 0, 40, 100)], [(60, 0, 100, 100)]],
                100,
                100,
            )
        )
        self.assertIsNone(
            maximin_center(
                [
                    [(0, 0, 8, 100), (8, 0, 100, 100)],
                    [(0, 0, 8, 100)],
                ],
                100,
                100,
            )
        )

    def test_resolver_has_declared_model_and_safety_gates(self) -> None:
        resolver = source("src/mxnm_measurement_target_resolver.ahk")
        for symbol in (
            "ParseMxNMDeclaredLayoutModels",
            "FindMxNMCrossLayoutSafePoint",
            "MxNMPointClearanceAcrossLayouts",
            "minimumRequiredClearance",
            "ResolveMxNMRuntimeImageTarget",
            "ResolveMxNMRootOwnerFromPoint",
            "ResolveMxNMActionWindowFromPoint",
            "WindowFromPoint",
            "GetAncestor",
        ):
            self.assertIn(symbol, resolver)
        self.assertIn('"ShowModelSize"', resolver)
        self.assertIn('"LowWndSize"', resolver)
        self.assertIn("* 0.05", resolver)
        self.assertIn("* 0.01", resolver)
        runtime_resolver = resolver.split(
            "ResolveMxNMRuntimeImageTarget(", 1
        )[1].split("IsReusableMxNMMeasurementTargetPlan", 1)[0]
        self.assertIn("rootOwnerHwnd != candidateFrame.hwnd", runtime_resolver)
        self.assertIn("candidates.Length != 1", runtime_resolver)
        action_resolver = resolver.split(
            "ResolveMxNMActionWindowFromPoint(", 2
        )[-1]
        self.assertIn("rootOwnerHwnd != runtimeFrameHwnd", action_resolver)
        self.assertIn("MxNMTargetScreenToClient", action_resolver)
        self.assertIn("clientPoint: clientPoint", action_resolver)
        self.assertIn("actionClientPoint", resolver)

    def test_resolver_and_field_harness_are_privacy_safe(self) -> None:
        resolver = source("src/mxnm_measurement_target_resolver.ahk")
        harness = source("tests/windows/mxnm_measurement_target_field.ahk")
        for forbidden in (
            ".Name",
            "CachedName",
            'context["rawText"]',
            "rawValue",
            "formattedValue",
            "SoundBeep",
            "WinActivate",
            "MouseMove",
            "Click(",
        ):
            self.assertNotIn(forbidden, resolver + harness)
        self.assertIn("ForegroundUnchanged=", harness)
        self.assertIn("MouseUnchanged=", harness)
        self.assertIn("TargetActionMatchesProviderViewer=", harness)

    def test_validated_checkpoint_is_connected_to_production_wiring(self) -> None:
        resolver_name = "mxnm_measurement_target_resolver.ahk"
        self.assertIn(resolver_name, source("src/main.ahk"))
        self.assertIn(resolver_name, source("scripts/build_release.py"))
        self.assertNotIn(
            "MxNMMeasurementTargetResolver",
            source("src/context_measurement_provider.ahk"),
        )
        self.assertIn(
            "MxNMMeasurementProvider.ReadSuvMax()",
            source("src/hotstrings.ahk"),
        )

    def test_windows_harnesses_cover_logic_and_field_paths(self) -> None:
        regression = source(
            "tests/windows/mxnm_measurement_target_regression.ahk"
        )
        field = source("tests/windows/mxnm_measurement_target_field.ahk")
        for phrase in (
            "valid layout schema",
            "one-percent clipping",
            "missing pane field",
            "duplicate pane field",
            "no shared safe point",
            "five-percent clearance gate",
        ):
            self.assertIn(phrase, regression)
        self.assertIn("^!F10::PreviewMxNMMeasurementTarget()", field)
        self.assertIn("^!F11::RunMxNMAutomaticTargetSuvMax()", field)
        self.assertIn(
            'Map("imageScreenPoint", target.screenPoint)',
            field,
        )


if __name__ == "__main__":
    unittest.main()
