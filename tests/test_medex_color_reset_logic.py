#!/usr/bin/env python3
"""Platform-independent tests for the MedEx color-reset layout resolver.

These tests mirror src/medex_color_reset_logic.ahk. They do not execute
AutoHotkey, Windows UIA, mouse input, or MedEx.
"""

from __future__ import annotations

import math
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOGIC_SOURCE = ROOT / "src" / "medex_color_reset_logic.ahk"
ADAPTER_SOURCE = ROOT / "src" / "adapters" / "medex_report_editor.ahk"
DIAGNOSTICS_SOURCE = ROOT / "src" / "diagnostics.ahk"
FIELD_DEBUG_SOURCE = ROOT / "debug" / "medex_color_reset_field_debug.ahk"

OK = "COLOR_RESET_OK"
REGION_NOT_FOUND = "COLOR_RESET_REGION_ANCHOR_NOT_FOUND"
REGION_AMBIGUOUS = "COLOR_RESET_REGION_ANCHOR_AMBIGUOUS"
FONT_NOT_FOUND = "COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND"
FONT_AMBIGUOUS = "COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS"
INVALID_RECTANGLE = "COLOR_RESET_INVALID_RECTANGLE"
INVALID_GEOMETRY = "COLOR_RESET_INVALID_GEOMETRY"
INVALID_COORDINATE_SPACE = "COLOR_RESET_INVALID_COORDINATE_SPACE"


def rect(left: float, top: float, right: float, bottom: float) -> dict[str, float]:
    return {"l": left, "t": top, "r": right, "b": bottom}


def anchor(name: str, value: dict[str, float]) -> dict[str, object]:
    return {"name": name, "rect": value}


def valid_rect(value: dict[str, float]) -> bool:
    coordinates = [value.get(key) for key in ("l", "t", "r", "b")]
    return (
        all(isinstance(item, (int, float)) for item in coordinates)
        and all(math.isfinite(item) and abs(item) <= 10_000_000 for item in coordinates)
        and value["r"] > value["l"]
        and value["b"] > value["t"]
    )


def contains_rect(outer: dict[str, float], inner: dict[str, float]) -> bool:
    return (
        inner["l"] >= outer["l"]
        and inner["r"] <= outer["r"]
        and inner["t"] >= outer["t"]
        and inner["b"] <= outer["b"]
    )


def contains_point(bounds: dict[str, float], point: dict[str, float]) -> bool:
    return (
        bounds["l"] <= point["x"] <= bounds["r"]
        and bounds["t"] <= point["y"] <= bounds["b"]
    )


def center_y(value: dict[str, float]) -> float:
    return value["t"] + (value["b"] - value["t"]) / 2


def screen_to_client(point: dict[str, float], client: dict[str, float]) -> dict[str, float]:
    return {"x": point["x"] - client["l"], "y": point["y"] - client["t"]}


def overlap_ratio(first: dict[str, float], second: dict[str, float]) -> float:
    overlap = max(0, min(first["b"], second["b"]) - max(first["t"], second["t"]))
    shorter = min(first["b"] - first["t"], second["b"] - second["t"])
    return overlap / shorter if shorter > 0 else 0


def resolve_layout(
    text_anchors: list[dict[str, object]],
    client: dict[str, float],
    *,
    region_name: str = "检查所见",
    font_pattern: str = r"^\d+(?:\.\d+)?px$",
    optional_name: str = "rAI",
    offset_x: float = 143,
    offset_y: float = 0,
    min_overlap: float = 0.5,
) -> dict[str, object]:
    context: dict[str, object] = {
        "layoutProfileName": "medex-0.0.1-baseline",
        "regionAnchorName": region_name,
        "fontSizeAnchorPattern": font_pattern,
        "optionalRightAnchorName": optional_name,
        "colorArrowOffsetX": offset_x,
        "colorArrowOffsetY": offset_y,
        "regionAnchorFound": False,
        "fontSizeAnchorFound": False,
        "optionalRightAnchorFound": False,
    }
    if not valid_rect(client):
        return {"ok": False, "code": INVALID_RECTANGLE, "context": context}

    usable = [
        item
        for item in text_anchors
        if isinstance(item.get("name"), str)
        and isinstance(item.get("rect"), dict)
        and valid_rect(item["rect"])
    ]
    regions = [
        item
        for item in usable
        if item["name"] == region_name and contains_rect(client, item["rect"])
    ]
    if not regions:
        return {"ok": False, "code": REGION_NOT_FOUND, "context": context}
    if len(regions) > 1:
        return {"ok": False, "code": REGION_AMBIGUOUS, "context": context}

    region = regions[0]["rect"]
    context.update({"regionAnchorFound": True, "regionAnchorRect": region})
    fonts = [
        item
        for item in usable
        if re.fullmatch(font_pattern, item["name"])
        and contains_rect(client, item["rect"])
        and item["rect"]["l"] > region["r"]
        and overlap_ratio(region, item["rect"]) >= min_overlap
    ]
    context["fontSizeCandidateCount"] = len(fonts)
    if not fonts:
        return {"ok": False, "code": FONT_NOT_FOUND, "context": context}
    if len(fonts) > 1:
        return {"ok": False, "code": FONT_AMBIGUOUS, "context": context}

    font = fonts[0]["rect"]
    context.update(
        {
            "fontSizeAnchorFound": True,
            "fontSizeAnchorMatchedName": fonts[0]["name"],
            "fontSizeAnchorRect": font,
            "verticalOverlapRatio": overlap_ratio(region, font),
        }
    )
    if not all(isinstance(value, (int, float)) and math.isfinite(value) for value in (offset_x, offset_y)) or offset_x <= 0:
        return {"ok": False, "code": INVALID_GEOMETRY, "context": context}

    point = {"x": round(font["r"] + offset_x), "y": round(center_y(font) + offset_y)}
    context["calculatedScreenPoint"] = point
    if point["x"] <= font["r"]:
        return {"ok": False, "code": INVALID_GEOMETRY, "context": context}
    toolbar_top = min(region["t"], font["t"]) - 4
    toolbar_bottom = max(region["b"], font["b"]) + 4
    if not toolbar_top <= point["y"] <= toolbar_bottom:
        return {"ok": False, "code": INVALID_GEOMETRY, "context": context}
    if not contains_point(client, point):
        return {"ok": False, "code": INVALID_COORDINATE_SPACE, "context": context}

    optional = [
        item
        for item in usable
        if item["name"] == optional_name
        and contains_rect(client, item["rect"])
        and item["rect"]["l"] > font["r"]
        and overlap_ratio(region, item["rect"]) >= min_overlap
    ]
    if len(optional) == 1:
        context.update(
            {
                "optionalRightAnchorFound": True,
                "optionalRightAnchorRect": optional[0]["rect"],
            }
        )
    return {"ok": True, "code": OK, "context": context}


class MedExColorResetLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = rect(0, 0, 1920, 1040)
        self.region = anchor("检查所见", rect(296, 289, 352, 305))
        self.font = anchor("16px", rect(502, 290, 529, 304))
        self.optional = anchor("rAI", rect(1474, 291, 1490, 306))

    def resolve(self, extra: list[dict[str, object]] | None = None, **kwargs: object) -> dict[str, object]:
        return resolve_layout([self.region, self.font, *(extra or [])], self.client, **kwargs)

    def test_16px_font_size_value_works(self) -> None:
        self.assertTrue(self.resolve()["ok"])

    def test_14px_font_size_value_works(self) -> None:
        self.font["name"] = "14px"
        result = self.resolve()
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["fontSizeAnchorMatchedName"], "14px")

    def test_other_valid_integer_and_decimal_px_values_work(self) -> None:
        for name in ("9px", "12.5px", "120px"):
            with self.subTest(name=name):
                self.font["name"] = name
                self.assertTrue(self.resolve()["ok"])

    def test_exact_16px_is_not_used_by_production_resolver(self) -> None:
        adapter = ADAPTER_SOURCE.read_text(encoding="utf-8")
        self.assertNotIn('FindElements({Name: "16px"})', adapter)
        self.assertNotIn('FindElements({Name: "①"})', adapter)

    def test_profile_centralizes_calibration_and_removes_old_ratio(self) -> None:
        logic = LOGIC_SOURCE.read_text(encoding="utf-8")
        adapter = ADAPTER_SOURCE.read_text(encoding="utf-8")
        self.assertIn("class MedExColorResetLayoutProfile", logic)
        self.assertIn("static ColorArrowOffsetX := 143", logic)
        self.assertIn("static ColorArrowOffsetY := 0", logic)
        self.assertNotIn("ProvisionalArrowHorizontalRatio", logic + adapter)
        self.assertNotIn("0.337", logic + adapter)

    def test_shortcut_absent_renamed_or_multiple_does_not_affect_selection(self) -> None:
        shortcut_variants = (
            [],
            [anchor("②", rect(953, 289, 967, 305))],
            [anchor("①", rect(953, 289, 967, 305)), anchor("custom", rect(980, 289, 1010, 305))],
        )
        for shortcuts in shortcut_variants:
            with self.subTest(shortcuts=shortcuts):
                self.assertTrue(self.resolve(shortcuts)["ok"])

    def test_region_anchor_selects_target_when_toolbar_inserted_above(self) -> None:
        above = [
            anchor("新增区域", rect(296, 200, 352, 216)),
            anchor("12px", rect(502, 201, 529, 215)),
        ]
        result = self.resolve(above)
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["fontSizeAnchorRect"], self.font["rect"])

    def test_global_font_candidates_reduce_to_one_aligned_target(self) -> None:
        other_rows = [
            anchor("14px", rect(502, 112, 529, 126)),
            anchor("18px", rect(502, 735, 529, 749)),
        ]
        result = self.resolve(other_rows)
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["fontSizeCandidateCount"], 1)

    def test_multiple_font_candidates_on_target_row_fail_closed(self) -> None:
        duplicate = anchor("14px", rect(550, 290, 577, 304))
        result = self.resolve([duplicate])
        self.assertEqual(result["code"], FONT_AMBIGUOUS)

    def test_missing_or_duplicate_region_fails_closed(self) -> None:
        self.assertEqual(resolve_layout([self.font], self.client)["code"], REGION_NOT_FOUND)
        duplicate = anchor("检查所见", rect(296, 400, 352, 416))
        self.assertEqual(self.resolve([duplicate])["code"], REGION_AMBIGUOUS)

    def test_insufficient_vertical_overlap_does_not_select_font(self) -> None:
        self.font["rect"] = rect(502, 300, 529, 314)
        self.assertEqual(self.resolve()["code"], FONT_NOT_FOUND)

    def test_toolbar_vertical_move_moves_point_by_same_delta(self) -> None:
        original = self.resolve()["context"]["calculatedScreenPoint"]
        delta = 125
        for item in (self.region, self.font):
            value = item["rect"]
            item["rect"] = rect(value["l"], value["t"] + delta, value["r"], value["b"] + delta)
        moved = self.resolve()["context"]["calculatedScreenPoint"]
        self.assertEqual(moved["x"], original["x"])
        self.assertEqual(moved["y"], original["y"] + delta)

    def test_font_name_change_with_stable_rect_keeps_point(self) -> None:
        first = self.resolve()["context"]["calculatedScreenPoint"]
        self.font["name"] = "14px"
        second = self.resolve()["context"]["calculatedScreenPoint"]
        self.assertEqual(first, second)

    def test_central_offsets_change_point_without_resolver_change(self) -> None:
        result = self.resolve(offset_x=150, offset_y=3)
        self.assertEqual(result["context"]["calculatedScreenPoint"], {"x": 679, "y": 300})

    def test_default_calibrated_point_is_672_297(self) -> None:
        self.assertEqual(self.resolve()["context"]["calculatedScreenPoint"], {"x": 672, "y": 297})

    def test_optional_right_anchor_populates_diagnostics(self) -> None:
        result = self.resolve([self.optional])
        self.assertTrue(result["ok"])
        self.assertTrue(result["context"]["optionalRightAnchorFound"])
        self.assertEqual(result["context"]["optionalRightAnchorRect"], self.optional["rect"])

    def test_optional_anchor_absent_renamed_or_ambiguous_never_blocks(self) -> None:
        variants = (
            [],
            [anchor("AI", self.optional["rect"])],
            [self.optional, anchor("rAI", rect(1500, 291, 1516, 306))],
        )
        for optional in variants:
            with self.subTest(optional=optional):
                self.assertTrue(self.resolve(optional)["ok"])

    def test_point_outside_client_fails_closed(self) -> None:
        self.assertEqual(self.resolve(offset_x=2000)["code"], INVALID_COORDINATE_SPACE)

    def test_invalid_or_nonpositive_offsets_fail_closed(self) -> None:
        for value in (0, -1, math.inf):
            with self.subTest(value=value):
                self.assertEqual(self.resolve(offset_x=value)["code"], INVALID_GEOMETRY)

    def test_zero_width_rectangles_fail_closed(self) -> None:
        self.font["rect"] = rect(502, 290, 502, 304)
        self.assertEqual(self.resolve()["code"], FONT_NOT_FOUND)
        invalid_client = rect(0, 0, 0, 1040)
        self.assertEqual(resolve_layout([self.region, self.font], invalid_client)["code"], INVALID_RECTANGLE)

    def test_screen_to_client_conversion_is_explicit(self) -> None:
        self.assertEqual(
            screen_to_client({"x": 672, "y": 297}, rect(8, 31, 1920, 1040)),
            {"x": 664, "y": 266},
        )

    def test_structured_result_constructor_contract_is_present(self) -> None:
        source = LOGIC_SOURCE.read_text(encoding="utf-8")
        self.assertIn("MakeColorResetResult(ok, code, context := 0)", source)
        self.assertIn("return {ok: ok = true, code: String(code), context: context}", source)

    def test_required_result_codes_are_centralized(self) -> None:
        source = LOGIC_SOURCE.read_text(encoding="utf-8")
        for code in (
            REGION_NOT_FOUND,
            REGION_AMBIGUOUS,
            FONT_NOT_FOUND,
            FONT_AMBIGUOUS,
            INVALID_RECTANGLE,
            INVALID_GEOMETRY,
            INVALID_COORDINATE_SPACE,
            "AUTOMATION_CHAIN_OK",
        ):
            with self.subTest(code=code):
                self.assertIn(code, source)

    def test_foreground_guards_black_match_and_retry_remain(self) -> None:
        source = ADAPTER_SOURCE.read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("MedExForegroundTargetMatches("), 3)
        self.assertIn('{Type: "Hyperlink", Name: "000000"}', source)
        self.assertIn("Min(2, Integer(maxAttempts))", source)

    def test_diagnostic_schema_contains_profile_and_anchor_fields(self) -> None:
        source = DIAGNOSTICS_SOURCE.read_text(encoding="utf-8")
        for field in (
            "LayoutProfileName",
            "RegionAnchorName",
            "RegionAnchorFound",
            "RegionAnchorRect",
            "DocumentFound",
            "DocumentRect",
            "FontSizeAnchorPattern",
            "FontSizeAnchorMatchedName",
            "FontSizeCandidateCount",
            "OptionalRightAnchorFound",
            "ColorArrowOffsetX",
            "ColorArrowOffsetY",
            "AnchorSelectionReason",
            "CoordinateSpaceReason",
            "ForegroundGuardReason",
        ):
            with self.subTest(field=field):
                self.assertIn(field, source)

    def test_field_debug_has_no_focus_changing_ui(self) -> None:
        source = FIELD_DEBUG_SOURCE.read_text(encoding="utf-8")
        executable = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith(";")
        )
        for forbidden in ("MsgBox", "ToolTip", "TrayTip"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, executable)


if __name__ == "__main__":
    unittest.main()
