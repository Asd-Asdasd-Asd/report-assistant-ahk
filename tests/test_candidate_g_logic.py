#!/usr/bin/env python3
"""Platform-independent Candidate G1 geometry and safety tests."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOGIC = ROOT / "src" / "medex_candidate_g_logic.ahk"
ADAPTER = ROOT / "src" / "adapters" / "medex_report_editor.ahk"
DEBUG = ROOT / "debug" / "medex_candidate_g_calibration.ahk"
G2_TEST = ROOT / "debug" / "medex_candidate_g2_test.ahk"
BUILD = ROOT / "scripts" / "build_release.py"
RELEASE = ROOT / "release" / "report_assistant.ahk"


def rect(left: int, top: int, right: int, bottom: int) -> dict[str, int]:
    return {"l": left, "t": top, "r": right, "b": bottom}


def anchor(name: str, bounds: dict[str, int]) -> dict[str, object]:
    return {"name": name, "rect": bounds}


def overlap_ratio(first: dict[str, int], second: dict[str, int]) -> float:
    overlap = max(0, min(first["b"], second["b"]) - max(first["t"], second["t"]))
    shorter = min(first["b"] - first["t"], second["b"] - second["t"])
    return overlap / shorter if shorter else 0


def geometry_valid(bounds: dict[str, int], client: dict[str, int]) -> bool:
    width = bounds["r"] - bounds["l"]
    height = bounds["b"] - bounds["t"]
    arrow = {"x": bounds["r"] + 320, "y": round((bounds["t"] + bounds["b"]) / 2)}
    return (
        client["l"] <= bounds["l"] < bounds["r"] <= client["r"]
        and client["t"] <= bounds["t"] < bounds["b"] <= client["b"]
        and 272 <= bounds["l"] <= 320
        and 40 <= width <= 80
        and 10 <= height <= 28
        and client["l"] <= arrow["x"] <= client["r"]
        and bounds["t"] - 6 <= arrow["y"] <= bounds["b"] + 6
    )


def corroboration(region: dict[str, int], anchors: list[dict[str, object]]) -> int:
    font = False
    optional = False
    for item in anchors:
        bounds = item["rect"]
        if bounds["l"] <= region["r"] or overlap_ratio(region, bounds) < 0.5:
            continue
        if re.fullmatch(r"\d+(?:\.\d+)?px", str(item["name"])) and bounds["l"] - region["r"] <= 240:
            font = True
        if item["name"] == "rAI":
            optional = True
    return int(font) + int(optional)


def resolve(anchors: list[dict[str, object]]) -> dict[str, object]:
    client = rect(0, 0, 1920, 1040)
    raw = [item for item in anchors if item["name"] == "检查所见"]
    valid = [item for item in raw if geometry_valid(item["rect"], client)]
    if not raw:
        return {"ok": False, "code": "not_found"}
    if not valid:
        return {"ok": False, "code": "invalid_geometry"}
    if len(valid) == 1:
        selected = valid[0]
    else:
        scored = [(corroboration(item["rect"], anchors), item) for item in valid]
        best = max(score for score, _ in scored)
        winners = [item for score, item in scored if score == best]
        if best < 1 or len(winners) != 1:
            return {"ok": False, "code": "ambiguous"}
        selected = winners[0]
    bounds = selected["rect"]
    arrow = {"x": bounds["r"] + 320, "y": round((bounds["t"] + bounds["b"]) / 2)}
    black = {"x": arrow["x"] + 6, "y": arrow["y"] + 83}
    return {"ok": True, "selected": selected, "arrow": arrow, "black": black}


def rgb_matches(actual: int, expected: int, tolerance: int) -> bool:
    return all(
        abs(((actual >> shift) & 0xFF) - ((expected >> shift) & 0xFF)) <= tolerance
        for shift in (16, 8, 0)
    )


def signature_matches(samples: dict[str, int]) -> bool:
    required = {
        "popupLight": (0xFFFFFF, 4),
        "blackSwatch": (0x000000, 8),
        "beigeSwatch": (0xEEEDE2, 12),
        "blueSwatch": (0x22447A, 12),
    }
    return all(
        name in samples and rgb_matches(samples[name], expected, tolerance)
        for name, (expected, tolerance) in required.items()
    )


class CandidateGLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.toolbar = anchor("检查所见", rect(296, 289, 352, 305))
        self.font = anchor("16px", rect(502, 290, 529, 304))
        self.rai = anchor("rAI", rect(1474, 291, 1490, 306))

    def test_unique_geometry_valid_region_is_selected(self) -> None:
        result = resolve([self.toolbar])
        self.assertTrue(result["ok"])
        self.assertEqual(result["arrow"], {"x": 672, "y": 297})
        self.assertEqual(result["black"], {"x": 678, "y": 380})

    def test_global_first_match_is_not_blindly_selected(self) -> None:
        content = anchor("检查所见", rect(700, 500, 756, 516))
        result = resolve([content, self.toolbar])
        self.assertTrue(result["ok"])
        self.assertIs(result["selected"], self.toolbar)

    def test_invalid_geometry_and_missing_region_fail_closed(self) -> None:
        self.assertFalse(resolve([])["ok"])
        content = anchor("检查所见", rect(700, 500, 756, 516))
        self.assertEqual(resolve([content])["code"], "invalid_geometry")

    def test_multiple_candidates_require_unique_corroboration(self) -> None:
        second = anchor("检查所见", rect(296, 600, 352, 616))
        aligned_font = anchor("14px", rect(502, 601, 529, 615))
        result = resolve([self.toolbar, second, aligned_font])
        self.assertTrue(result["ok"])
        self.assertIs(result["selected"], second)

    def test_unresolved_corroboration_tie_fails_closed(self) -> None:
        second = anchor("检查所见", rect(296, 600, 352, 616))
        first_font = anchor("16px", rect(502, 290, 529, 304))
        second_font = anchor("14px", rect(502, 601, 529, 615))
        self.assertEqual(
            resolve([self.toolbar, second, first_font, second_font])["code"],
            "ambiguous",
        )

    def test_toolbar_y_move_moves_points_by_same_delta(self) -> None:
        original = resolve([self.toolbar])
        moved = anchor("检查所见", rect(296, 489, 352, 505))
        result = resolve([moved])
        self.assertEqual(result["arrow"]["x"], original["arrow"]["x"])
        self.assertEqual(result["arrow"]["y"], original["arrow"]["y"] + 200)
        self.assertEqual(result["black"]["y"], original["black"]["y"] + 200)

    def test_profiles_and_runtime_calibration_are_centralized(self) -> None:
        source = LOGIC.read_text(encoding="utf-8")
        self.assertIn("class CandidateGCalibrationProfile", source)
        self.assertIn("class CandidateGRelativeMouseProfile", source)
        self.assertIn("static EstimatedArrowOffsetX := 320", source)
        self.assertIn("static EstimatedArrowOffsetY := 0", source)
        self.assertIn("static EstimatedBlackOffsetX := 6", source)
        self.assertIn("static EstimatedBlackOffsetY := 83", source)
        self.assertIn("static ArrowOffsetX := 320", source)
        self.assertIn("static ArrowOffsetY := 0", source)
        self.assertIn("static BlackOffsetX := 6", source)
        self.assertIn("static BlackOffsetY := 83", source)

    def test_field_signature_matches_open_popup_evidence(self) -> None:
        self.assertTrue(signature_matches({
            "popupLight": 0xFFFFFF,
            "blackSwatch": 0x000000,
            "beigeSwatch": 0xEEEDE2,
            "blueSwatch": 0x22447A,
        }))

    def test_closed_popup_signature_fails(self) -> None:
        self.assertFalse(signature_matches({
            "popupLight": 0xF6F8FB,
            "blackSwatch": 0xFFFFFF,
            "beigeSwatch": 0xFFFFFF,
            "blueSwatch": 0xFFFFFF,
        }))

    def test_signature_requires_every_pixel(self) -> None:
        self.assertFalse(signature_matches({
            "popupLight": 0xFFFFFF,
            "blackSwatch": 0x000000,
            "beigeSwatch": 0xEEEDE2,
        }))

    def test_debug_harness_never_clicks_black_or_uses_popup_uia(self) -> None:
        source = DEBUG.read_text(encoding="utf-8")
        executable = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith(";")
        )
        self.assertEqual(executable.count("Click arrowPoint"), 1)
        self.assertNotIn("Click black", executable)
        self.assertNotIn('"000000"', executable)
        self.assertNotIn("InvokePattern", executable)
        self.assertNotIn('Type: "Hyperlink"', executable)
        self.assertNotIn(":*?:;red::", executable)
        self.assertNotIn(":*?:;fzg::", executable)
        for forbidden in ("MsgBox", "ToolTip", "TrayTip"):
            self.assertNotIn(forbidden, executable)

    def test_strategy_default_is_candidate_g_without_fallback(self) -> None:
        adapter = ADAPTER.read_text(encoding="utf-8")
        self.assertIn(
            "static ColorResetStrategy := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED",
            adapter,
        )
        dispatcher = adapter.split("ResetMedExInsertionColor(options := 0)", 1)[1].split(
            "RunMedExUiaInvokeColorReset(options := 0)", 1
        )[0]
        self.assertIn("MedExColorResetStrategy.UIA_INVOKE", dispatcher)
        self.assertIn("RunMedExRelativeMousePixelValidatedColorReset(options)", dispatcher)
        self.assertEqual(dispatcher.count("RunMedExUiaInvokeColorReset(options)"), 1)
        relative_branch = dispatcher.split(
            "MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED", 1
        )[1]
        self.assertNotIn("RunMedExUiaInvokeColorReset(options)", relative_branch)

    def test_g2_logic_is_bundled_as_default(self) -> None:
        self.assertIn("medex_candidate_g_logic.ahk", BUILD.read_text(encoding="utf-8"))
        release = RELEASE.read_text(encoding="utf-8")
        self.assertIn("class CandidateGRelativeMouseProfile", release)
        self.assertIn(
            "static ColorResetStrategy := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED",
            release,
        )
        self.assertNotIn("RunCandidateGOpenPixelProbe", release)

    def test_g2_chain_is_bounded_and_has_no_popup_uia_or_fallback(self) -> None:
        adapter = ADAPTER.read_text(encoding="utf-8")
        body = adapter.split(
            "RunMedExRelativeMousePixelValidatedColorReset(options := 0)", 1
        )[1].split("\nRunMedExUiaInvokeColorReset(options := 0)", 1)[0]
        self.assertEqual(body.count('Click arrowPoint["x"], arrowPoint["y"]'), 1)
        self.assertEqual(body.count('Click blackPoint["x"], blackPoint["y"]'), 1)
        self.assertIn("SampleAndEvaluateCandidateGPopupSignature", body)
        self.assertIn("ColorResetCode.POPUP_SIGNATURE_MISMATCH", body)
        self.assertIn("ColorResetCode.BLACK_CLICK_FAILED", body)
        self.assertNotIn('"000000"', body)
        self.assertNotIn("InvokePattern", body)
        self.assertNotIn("RunMedExUiaInvokeColorReset", body)

    def test_g2_safety_guards_precede_clicks(self) -> None:
        adapter = ADAPTER.read_text(encoding="utf-8")
        body = adapter.split(
            "RunMedExRelativeMousePixelValidatedColorReset(options := 0)", 1
        )[1].split("\nRunMedExUiaInvokeColorReset(options := 0)", 1)[0]
        arrow_click = body.index('Click arrowPoint["x"], arrowPoint["y"]')
        black_click = body.index('Click blackPoint["x"], blackPoint["y"]')
        self.assertLess(body.index("ValidateCandidateGRuntimeProfile"), arrow_click)
        self.assertLess(body.index("RectContainsPoint(clientRectScreen, arrowPoint)"), arrow_click)
        self.assertLess(body.index("RectContainsPoint(clientRectScreen, blackPoint)"), arrow_click)
        self.assertLess(body.index('if !signature["matched"]'), black_click)
        self.assertGreaterEqual(body.count("MedExForegroundTargetMatches"), 3)
        self.assertIn("MouseMove originalMouseX, originalMouseY, 0", body)

    def test_g2_debug_uses_real_dispatcher_and_no_production_hotstrings(self) -> None:
        source = DEBUG.read_text(encoding="utf-8")
        self.assertIn("F12::RunCandidateG2ControlledReset()", source)
        self.assertIn("F7::RunCandidateG2ClosedSignatureGate()", source)
        self.assertIn('"candidateGSkipArrowClickForClosedSignatureTest", true', source)
        self.assertIn("ResetMedExInsertionColor(Map(", source)
        self.assertIn("MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED", source)
        self.assertNotIn(":*?:;red::", source)
        self.assertNotIn(":*?:;fzg::", source)

    def test_closed_signature_debug_gate_cannot_click_black_on_closed_popup(self) -> None:
        adapter = ADAPTER.read_text(encoding="utf-8")
        body = adapter.split(
            "RunMedExRelativeMousePixelValidatedColorReset(options := 0)", 1
        )[1].split("\nRunMedExUiaInvokeColorReset(options := 0)", 1)[0]
        self.assertIn("candidateGSkipArrowClickForClosedSignatureTest", body)
        self.assertIn("if !skipArrowClickForClosedSignatureTest", body)
        signature_gate = body.index('if !signature["matched"]')
        black_click = body.index('Click blackPoint["x"], blackPoint["y"]')
        self.assertLess(signature_gate, black_click)

    def test_g2_test_build_uses_shared_orchestration(self) -> None:
        source = G2_TEST.read_text(encoding="utf-8")
        self.assertIn("InsertRedFigureTextAndRestoreState", source)
        self.assertIn("RunFzgInsertion", source)
        self.assertIn("ResetMedExInsertionColor", source)
        self.assertIn("MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED", source)
        self.assertNotIn("PixelGetColor", source)
        self.assertNotIn('Click arrowPoint', source)
        self.assertNotIn('Click blackPoint', source)
        self.assertNotIn('"000000"', source)
        self.assertNotIn("InvokePattern", source)
        for forbidden in ("MsgBox", "ToolTip", "TrayTip"):
            self.assertNotIn(forbidden, source)

    def test_caret_ab_keeps_left_four_and_changes_only_reset_order(self) -> None:
        source = G2_TEST.read_text(encoding="utf-8")
        self.assertIn("^!F8::", source)
        self.assertIn("RunCandidateG2FzgWithColorResetDiagnostic()", source)
        self.assertIn("^!F9::RunCandidateG2FzgWithoutColorResetDiagnostic()", source)
        candidate = source.split(
            "\nRunCandidateG2FzgWithoutColorResetDiagnostic() {", 1
        )[1].split("\nWriteCandidateG2TestOperation", 1)[0]
        self.assertIn("PasteRedFigureTextDetailed", candidate)
        self.assertIn("ReportHotstringTimingDefaults.FzgCursorRestoreDelayMs", candidate)
        self.assertEqual(candidate.count('Send("{Left 4}")'), 1)
        self.assertNotIn("ResetMedExInsertionColor", candidate)
        self.assertNotIn("RunMedExRelativeMousePixelValidatedColorReset", candidate)
        self.assertNotIn("{Left 5}", source)


if __name__ == "__main__":
    unittest.main()
