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

    def test_profile_and_estimates_are_centralized(self) -> None:
        source = LOGIC.read_text(encoding="utf-8")
        self.assertIn("class CandidateGCalibrationProfile", source)
        self.assertIn("static EstimatedArrowOffsetX := 320", source)
        self.assertIn("static EstimatedArrowOffsetY := 0", source)
        self.assertIn("static EstimatedBlackOffsetX := 6", source)
        self.assertIn("static EstimatedBlackOffsetY := 83", source)

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

    def test_strategy_default_remains_uia_without_fallback(self) -> None:
        adapter = ADAPTER.read_text(encoding="utf-8")
        dispatcher = adapter.split("ResetMedExInsertionColor(options := 0)", 1)[1].split(
            "RunMedExUiaInvokeColorReset(options := 0)", 1
        )[0]
        self.assertIn("MedExColorResetStrategy.UIA_INVOKE", dispatcher)
        self.assertIn("ColorResetCode.STRATEGY_NOT_IMPLEMENTED", dispatcher)
        self.assertEqual(dispatcher.count("RunMedExUiaInvokeColorReset(options)"), 1)

    def test_g1_calibration_logic_is_not_in_production_release(self) -> None:
        self.assertNotIn("medex_candidate_g_logic.ahk", BUILD.read_text(encoding="utf-8"))
        release = RELEASE.read_text(encoding="utf-8")
        self.assertNotIn("class CandidateGCalibrationProfile", release)
        self.assertNotIn("RunCandidateGOpenPixelProbe", release)


if __name__ == "__main__":
    unittest.main()
