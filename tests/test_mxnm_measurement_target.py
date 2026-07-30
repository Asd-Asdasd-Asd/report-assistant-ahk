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
            "ResolveMxNMRuntimeImageTargetFromToolAnchor",
            "BuildMxNMRuntimeOwnerFrameCandidates",
            "CaptureMxNMRuntimeOwnerFrame",
            "MxNMPointInsideRuntimeFrameClient",
            "ResolveMxNMMeasurementToolAnchor",
            "ResolveMxNMRootOwnerFromPoint",
            "ResolveMxNMActionWindowFromPoint",
            "ResolveMxNMActionWindowFromAnchor",
            "GetAncestor",
        ):
            self.assertIn(symbol, resolver)
        self.assertIn('"ShowModelSize"', resolver)
        self.assertIn('"LowWndSize"', resolver)
        self.assertIn("* 0.05", resolver)
        self.assertIn("* 0.01", resolver)
        runtime_resolver = resolver.split(
            "\nResolveMxNMRuntimeImageTarget(", 1
        )[1].split(
            "\nResolveMxNMRuntimeImageTargetFromToolAnchor(", 1
        )[0]
        self.assertNotIn("preferredFrameHwnd", runtime_resolver)
        self.assertIn("ResolveMxNMRootOwnerFromPoint", runtime_resolver)
        self.assertIn(
            "SelectMxNMRuntimeImageTargetByOwnerFamily",
            runtime_resolver,
        )
        self.assertIn("CountMxNMRuntimeOwnerFamily", resolver)
        self.assertIn("bestCount != 1", resolver)
        self.assertIn("bestScore < 2", resolver)
        self.assertIn("ResolveMxNMRootOwnerHwnd", resolver)
        self.assertIn("GetWindowThreadProcessId", resolver)
        self.assertIn("GetWindowRect", resolver)
        action_resolver = resolver.split(
            "ValidateMxNMActionWindow(", 2
        )[-1]
        self.assertIn("rootOwnerHwnd != runtimeFrameHwnd", action_resolver)
        self.assertIn("MxNMTargetScreenToClient", action_resolver)
        self.assertIn("clientPoint: clientPoint", action_resolver)
        self.assertIn("actionClientPoint", resolver)
        self.assertIn("WindowFromPoint", resolver)

    def test_runtime_target_reuses_validated_native_tool_group(self) -> None:
        resolver = source("src/mxnm_measurement_target_resolver.ahk")
        build_plan = resolver.split(
            "BuildMxNMMeasurementTargetPlan(", 1
        )[1].split("\n}\n\nMakeMxNMMeasurementTargetPlan", 1)[0]
        self.assertIn("BuildMxNMViewerToolCommandPlan(", build_plan)
        self.assertIn("plan.viewerToolPlan := viewerToolPlan", build_plan)

        resolve = resolver.split(
            "ResolveMxNMMeasurementTargetFromPlan(", 1
        )[1].split("\n}\n\nResolveMxNMMeasurementToolAnchor", 1)[0]
        self.assertIn("ResolveMxNMMeasurementToolAnchor(", resolve)
        self.assertIn("toolAnchor.frameHwnd", resolve)
        primary = "runtimeTarget := ResolveMxNMRuntimeImageTarget("
        fallback = "if !runtimeTarget.ok && toolAnchor.ok"
        self.assertLess(resolve.index(primary), resolve.index(fallback))
        self.assertIn("result.runtimeToolAnchorUsed := runtimeTarget.ok", resolve)
        self.assertIn("ResolveMxNMActionWindowFromPoint(", resolve)
        self.assertIn("ResolveMxNMActionWindowFromAnchor(", resolve)
        self.assertIn(
            "ResolveMxNMRuntimeImageTargetFromToolAnchor(",
            resolve,
        )

        anchor = resolver.split(
            "ResolveMxNMMeasurementToolAnchor(", 2
        )[-1].split("\n}\n\nResolveMxNMRuntimeImageTarget", 1)[0]
        self.assertIn("ResolveMxNMViewerToolControlSet(", anchor)
        self.assertIn("controlSet.frameHwnd", anchor)
        self.assertIn("controlSet.actionRootHwnd", anchor)

        fallback_target = resolver.split(
            "\nResolveMxNMRuntimeImageTargetFromToolAnchor(", 1
        )[1].split(
            "\n}\n\nBuildMxNMRuntimeOwnerFrameCandidates", 1
        )[0]
        self.assertIn("toolAnchor.actionRootHwnd", fallback_target)
        self.assertIn("actionFrame", fallback_target)
        self.assertIn(
            "MapMxNMLogicalImageRectToRuntime(\n"
            "        plan.mainGeometry,\n"
            "        actionFrame",
            fallback_target,
        )
        self.assertIn(
            "MxNMPointInsideRuntimeFrameClient",
            fallback_target,
        )
        for fallback_code in (
            "ANCHOR_INVALID",
            "ANCHOR_IDENTITY_INVALID",
            "ANCHOR_FRAME_INVALID",
            "ANCHOR_POINT_OUT_OF_BOUNDS",
            "READY_ACTION_CLIENT_RECT",
        ):
            self.assertIn(fallback_code, fallback_target)
        for field in (
            "actionFrame.clientX",
            "actionFrame.clientY",
            "actionFrame.clientWidth",
            "actionFrame.clientHeight",
        ):
            self.assertIn(field, fallback_target)

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
            "#Include ..\\..\\src\\mxnm_viewer_tool_commands.ahk",
            regression,
        )
        self.assertIn(
            "#Include ..\\..\\src\\mxnm_viewer_tool_commands.ahk",
            field,
        )
        self.assertIn(
            'Map("imageScreenPoint", target.screenPoint)',
            field,
        )


if __name__ == "__main__":
    unittest.main()
