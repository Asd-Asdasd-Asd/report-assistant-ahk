#!/usr/bin/env python3
"""Platform-independent reference tests for MedEx color-reset pure logic.

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
DIAGNOSTICS_SOURCE = ROOT / "src" / "diagnostics.ahk"
FIELD_DEBUG_SOURCE = ROOT / "debug" / "medex_color_reset_field_debug.ahk"

OK = "COLOR_RESET_OK"
INVALID_RECTANGLE = "COLOR_RESET_INVALID_RECTANGLE"
INVALID_GEOMETRY = "COLOR_RESET_INVALID_GEOMETRY"
INVALID_COORDINATE_SPACE = "COLOR_RESET_INVALID_COORDINATE_SPACE"
TOOLBAR_CANDIDATE_NOT_FOUND = "COLOR_RESET_TOOLBAR_CANDIDATE_NOT_FOUND"
TOOLBAR_PAIRING_AMBIGUOUS = "COLOR_RESET_TOOLBAR_PAIRING_AMBIGUOUS"
TOOLBAR_SORT_AMBIGUOUS = "COLOR_RESET_TOOLBAR_SORT_AMBIGUOUS"


def rect(left: float, top: float, right: float, bottom: float) -> dict[str, float]:
    return {"l": left, "t": top, "r": right, "b": bottom}


def valid_rect(value: dict[str, float]) -> bool:
    coordinates = [value.get(key) for key in ("l", "t", "r", "b")]
    return (
        all(isinstance(item, (int, float)) for item in coordinates)
        and all(math.isfinite(item) and abs(item) <= 10_000_000 for item in coordinates)
        and value["r"] > value["l"]
        and value["b"] > value["t"]
    )


def contains_point(bounds: dict[str, float], point: dict[str, float], tolerance: float = 0) -> bool:
    return (
        point["x"] >= bounds["l"] - tolerance
        and point["x"] <= bounds["r"] + tolerance
        and point["y"] >= bounds["t"] - tolerance
        and point["y"] <= bounds["b"] + tolerance
    )


def contains_rect(outer: dict[str, float], inner: dict[str, float], tolerance: float = 0) -> bool:
    return (
        inner["l"] >= outer["l"] - tolerance
        and inner["r"] <= outer["r"] + tolerance
        and inner["t"] >= outer["t"] - tolerance
        and inner["b"] <= outer["b"] + tolerance
    )


def calculate_point(font: dict[str, float], number: dict[str, float], ratio: float = 0.337) -> dict[str, float]:
    raw_x = font["r"] + ratio * (number["l"] - font["r"])
    raw_y = font["t"] + 1
    return {"x": round(raw_x), "y": round(raw_y), "rawX": raw_x, "rawY": raw_y, "ratio": ratio}


def screen_to_client(point: dict[str, float], client: dict[str, float]) -> dict[str, float]:
    return {"x": point["x"] - client["l"], "y": point["y"] - client["t"]}


def pair_is_plausible(
    font: dict[str, float],
    number: dict[str, float],
    *,
    min_gap: float = 100,
    max_gap: float = 1200,
    max_vertical_delta: float = 24,
) -> bool:
    if not valid_rect(font) or not valid_rect(number):
        return False
    gap = number["l"] - font["r"]
    font_y = font["t"] + (font["b"] - font["t"]) / 2
    number_y = number["t"] + (number["b"] - number["t"]) / 2
    return min_gap <= gap <= max_gap and abs(font_y - number_y) <= max_vertical_delta


def build_candidates(
    fonts: list[dict[str, float]],
    numbers: list[dict[str, float]],
    *,
    min_gap: float = 100,
    max_gap: float = 1200,
    max_vertical_delta: float = 24,
    min_y_separation: float = 2,
) -> dict[str, object]:
    context: dict[str, object] = {
        "toolbarCandidateCount": 0,
        "toolbarCandidateSelected": False,
        "selectedToolbarIndex": 0,
        "retryCount": 0,
    }
    if not all(valid_rect(value) for value in [*fonts, *numbers]):
        return {"ok": False, "code": INVALID_RECTANGLE, "context": context}

    font_matches: list[list[int]] = [[] for _ in fonts]
    number_matches: list[list[int]] = [[] for _ in numbers]
    for font_index, font in enumerate(fonts):
        for number_index, number in enumerate(numbers):
            if pair_is_plausible(
                font,
                number,
                min_gap=min_gap,
                max_gap=max_gap,
                max_vertical_delta=max_vertical_delta,
            ):
                font_matches[font_index].append(number_index)
                number_matches[number_index].append(font_index)

    if any(len(matches) > 1 for matches in [*font_matches, *number_matches]):
        return {"ok": False, "code": TOOLBAR_PAIRING_AMBIGUOUS, "context": context}

    candidates: list[dict[str, object]] = []
    for font_index, matches in enumerate(font_matches):
        if len(matches) != 1:
            continue
        number_index = matches[0]
        if len(number_matches[number_index]) != 1:
            continue
        font = fonts[font_index]
        number = numbers[number_index]
        toolbar_y = (
            font["t"] + (font["b"] - font["t"]) / 2
            + number["t"] + (number["b"] - number["t"]) / 2
        ) / 2
        candidates.append({"font": font, "number": number, "toolbarY": toolbar_y})

    candidates.sort(key=lambda candidate: candidate["toolbarY"])
    context["toolbarCandidateCount"] = len(candidates)
    if any(
        abs(candidates[index + 1]["toolbarY"] - candidates[index]["toolbarY"])
        < min_y_separation
        for index in range(len(candidates) - 1)
    ):
        return {"ok": False, "code": TOOLBAR_SORT_AMBIGUOUS, "context": context}
    if len(candidates) < 2:
        return {"ok": False, "code": TOOLBAR_CANDIDATE_NOT_FOUND, "context": context}

    selected = candidates[1]
    context.update(
        {
            "toolbarCandidateSelected": True,
            "selectedToolbarIndex": 2,
            "selectedFontSizeRect": selected["font"],
            "selectedNumberButtonRect": selected["number"],
        }
    )
    return {"ok": True, "code": OK, "context": context}


def validate_geometry(
    document: dict[str, float],
    font: dict[str, float],
    number: dict[str, float],
    window: dict[str, float],
    client: dict[str, float],
    *,
    ratio: float = 0.337,
    min_gap: float = 100,
    max_gap: float = 1200,
    max_vertical_delta: float = 24,
    tolerance: float = 4,
    toolbar_padding: float = 12,
) -> dict[str, object]:
    values = {
        "documentRect": document,
        "fontSizeRect": font,
        "numberButtonRect": number,
        "windowRect": window,
        "clientRectScreen": client,
    }
    for name, value in values.items():
        if not valid_rect(value):
            return {"ok": False, "code": INVALID_RECTANGLE, "context": {"invalidRectangle": name}}

    if not all(
        (
            contains_rect(window, document, tolerance),
            contains_rect(window, font, tolerance),
            contains_rect(window, number, tolerance),
            contains_rect(client, document, tolerance),
            contains_rect(client, font, tolerance),
            contains_rect(client, number, tolerance),
            contains_rect(document, font, tolerance),
            contains_rect(document, number, tolerance),
        )
    ):
        return {"ok": False, "code": INVALID_COORDINATE_SPACE, "context": {}}

    gap = number["l"] - font["r"]
    if gap <= 0 or gap < min_gap or gap > max_gap:
        return {"ok": False, "code": INVALID_GEOMETRY, "context": {"horizontalGap": gap}}

    font_center = font["t"] + (font["b"] - font["t"]) / 2
    number_center = number["t"] + (number["b"] - number["t"]) / 2
    if abs(font_center - number_center) > max_vertical_delta:
        return {"ok": False, "code": INVALID_GEOMETRY, "context": {}}

    point = calculate_point(font, number, ratio)
    client_point = screen_to_client(point, client)
    toolbar = rect(
        font["r"],
        min(font["t"], number["t"]) - toolbar_padding,
        number["l"],
        max(font["b"], number["b"]) + toolbar_padding,
    )
    if not all(
        (
            contains_point(window, point),
            contains_point(client, point),
            contains_point(document, point),
        )
    ):
        return {"ok": False, "code": INVALID_COORDINATE_SPACE, "context": {"point": point}}
    client_bounds = rect(0, 0, client["r"] - client["l"], client["b"] - client["t"])
    if not contains_point(client_bounds, client_point):
        return {"ok": False, "code": INVALID_COORDINATE_SPACE, "context": {"point": point}}
    if not contains_point(toolbar, point):
        return {"ok": False, "code": INVALID_GEOMETRY, "context": {"point": point}}

    return {
        "ok": True,
        "code": OK,
        "context": {"calculatedScreenPoint": point, "calculatedClientPoint": client_point},
    }


def make_result(ok: bool, code: str, context: dict[str, object] | None = None) -> dict[str, object]:
    return {"ok": bool(ok), "code": str(code), "context": context or {}}


class MedExColorResetLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.document = rect(296, 270, 990, 700)
        self.font = rect(502, 290, 529, 310)
        self.number = rect(953, 290, 967, 310)
        self.window = rect(250, 200, 1100, 900)
        self.client = rect(260, 230, 1090, 890)

    def validate(self, **kwargs: object) -> dict[str, object]:
        return validate_geometry(
            self.document,
            self.font,
            self.number,
            self.window,
            self.client,
            **kwargs,
        )

    def test_ratio_calculation_matches_investigation(self) -> None:
        point = calculate_point(self.font, self.number)
        self.assertEqual(point["x"], 672)
        self.assertEqual(point["y"], 291)
        self.assertAlmostEqual(point["ratio"], 0.337)

    def test_ahk_source_uses_named_provisional_ratio(self) -> None:
        adapter = (ROOT / "src" / "adapters" / "medex_report_editor.ahk").read_text(encoding="utf-8")
        match = re.search(r"ProvisionalArrowHorizontalRatio\s*:=\s*([0-9.]+)", adapter)
        self.assertIsNotNone(match)
        self.assertEqual(float(match.group(1)), 0.337)

    def test_adapter_enumerates_anchors_from_window_root(self) -> None:
        adapter = (ROOT / "src" / "adapters" / "medex_report_editor.ahk").read_text(
            encoding="utf-8"
        )
        self.assertIn('windowElement.FindElements({Name: "16px"})', adapter)
        self.assertIn('windowElement.FindElements({Name: "①"})', adapter)
        self.assertNotIn('documentElement.ElementExist({Name: "16px"})', adapter)

    def test_valid_geometry(self) -> None:
        result = self.validate()
        self.assertTrue(result["ok"])
        self.assertEqual(result["code"], OK)
        self.assertEqual(result["context"]["calculatedScreenPoint"]["x"], 672)

    def test_reversed_anchors_are_rejected(self) -> None:
        self.number = rect(450, 290, 470, 310)
        result = self.validate()
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], INVALID_GEOMETRY)

    def test_zero_width_rectangle_is_rejected(self) -> None:
        self.font = rect(502, 290, 502, 310)
        result = self.validate()
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], INVALID_RECTANGLE)

    def test_invalid_coordinate_range_is_rejected(self) -> None:
        self.font = rect(502, 290, math.inf, 310)
        result = self.validate()
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], INVALID_RECTANGLE)

    def test_point_outside_target_window_is_rejected(self) -> None:
        result = self.validate(ratio=10)
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], INVALID_COORDINATE_SPACE)

    def test_screen_to_client_conversion(self) -> None:
        point = screen_to_client({"x": 672, "y": 291}, self.client)
        self.assertEqual(point, {"x": 412, "y": 61})

    def test_structured_result_construction(self) -> None:
        result = make_result(False, INVALID_GEOMETRY, {"reason": "test"})
        self.assertEqual(
            result,
            {"ok": False, "code": INVALID_GEOMETRY, "context": {"reason": "test"}},
        )

    def test_required_result_codes_are_centralized(self) -> None:
        source = LOGIC_SOURCE.read_text(encoding="utf-8")
        required = {
            "COLOR_RESET_OK",
            "COLOR_RESET_WRONG_PROCESS",
            "COLOR_RESET_PROCESS_NAME_UNCONFIRMED",
            "COLOR_RESET_UIA_UNAVAILABLE",
            "COLOR_RESET_DOCUMENT_NOT_FOUND",
            "COLOR_RESET_ANCHOR_FONT_SIZE_NOT_FOUND",
            "COLOR_RESET_ANCHOR_NUMBER_BUTTON_NOT_FOUND",
            "COLOR_RESET_TOOLBAR_CANDIDATE_NOT_FOUND",
            "COLOR_RESET_TOOLBAR_PAIRING_AMBIGUOUS",
            "COLOR_RESET_TOOLBAR_SORT_AMBIGUOUS",
            "COLOR_RESET_INVALID_RECTANGLE",
            "COLOR_RESET_INVALID_GEOMETRY",
            "COLOR_RESET_INVALID_COORDINATE_SPACE",
            "COLOR_RESET_TRIGGER_CLICK_FAILED",
            "COLOR_RESET_MENU_NOT_OPENED",
            "COLOR_RESET_BLACK_ITEM_NOT_FOUND",
            "COLOR_RESET_INVOKE_UNAVAILABLE",
            "COLOR_RESET_INVOKE_FAILED",
            "COLOR_RESET_UNEXPECTED_ERROR",
        }
        for code in required:
            with self.subTest(code=code):
                self.assertIn(code, source)

    def test_three_toolbars_select_second_candidate(self) -> None:
        fonts = [rect(502, y, 529, y + 14) for y in (112, 290, 735)]
        numbers = [rect(953, y - 1, 967, y + 15) for y in (112, 290, 735)]
        result = build_candidates(fonts, numbers)
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["toolbarCandidateCount"], 3)
        self.assertEqual(result["context"]["selectedToolbarIndex"], 2)
        self.assertEqual(result["context"]["selectedFontSizeRect"], fonts[1])

    def test_more_than_three_candidates_still_selects_second(self) -> None:
        ys = (80, 160, 240, 320)
        result = build_candidates(
            [rect(502, y, 529, y + 14) for y in ys],
            [rect(953, y, 967, y + 14) for y in ys],
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["toolbarCandidateCount"], 4)
        self.assertEqual(result["context"]["selectedFontSizeRect"]["t"], 160)

    def test_only_one_candidate_fails_closed(self) -> None:
        result = build_candidates([self.font], [self.number])
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], TOOLBAR_CANDIDATE_NOT_FOUND)

    def test_vertically_misaligned_anchors_do_not_pair(self) -> None:
        result = build_candidates([self.font], [rect(953, 400, 967, 420)])
        self.assertEqual(result["code"], TOOLBAR_CANDIDATE_NOT_FOUND)

    def test_reversed_horizontal_order_does_not_pair(self) -> None:
        result = build_candidates([self.font], [rect(450, 290, 470, 310)])
        self.assertEqual(result["code"], TOOLBAR_CANDIDATE_NOT_FOUND)

    def test_duplicate_pairing_possibility_is_rejected(self) -> None:
        fonts = [rect(502, 100, 529, 114), rect(502, 112, 529, 126)]
        numbers = [rect(953, 106, 967, 120)]
        result = build_candidates(fonts, numbers)
        self.assertEqual(result["code"], TOOLBAR_PAIRING_AMBIGUOUS)

    def test_one_font_matching_multiple_numbers_is_rejected(self) -> None:
        fonts = [rect(502, 100, 529, 114)]
        numbers = [rect(953, 95, 967, 109), rect(953, 105, 967, 119)]
        result = build_candidates(fonts, numbers)
        self.assertEqual(result["code"], TOOLBAR_PAIRING_AMBIGUOUS)

    def test_overlapping_or_zero_size_rectangles_are_rejected(self) -> None:
        zero_width = rect(502, 100, 502, 114)
        result = build_candidates([zero_width], [rect(953, 100, 967, 114)])
        self.assertEqual(result["code"], INVALID_RECTANGLE)

    def test_ambiguous_y_ordering_is_rejected(self) -> None:
        fonts = [rect(502, 100, 529, 114), rect(502, 101, 529, 115)]
        numbers = [rect(953, 100, 967, 114), rect(953, 101, 967, 115)]
        result = build_candidates(fonts, numbers, max_vertical_delta=0.1)
        self.assertEqual(result["code"], TOOLBAR_SORT_AMBIGUOUS)

    def test_sorting_is_independent_of_enumeration_order(self) -> None:
        fonts = [rect(502, y, 529, y + 14) for y in (735, 112, 290)]
        numbers = [rect(953, y, 967, y + 14) for y in (290, 735, 112)]
        result = build_candidates(fonts, numbers)
        self.assertTrue(result["ok"])
        self.assertEqual(result["context"]["selectedFontSizeRect"]["t"], 290)

    def test_result_fields_and_retry_count_type(self) -> None:
        fonts = [rect(502, y, 529, y + 14) for y in (112, 290)]
        numbers = [rect(953, y, 967, y + 14) for y in (112, 290)]
        context = build_candidates(fonts, numbers)["context"]
        self.assertIs(context["toolbarCandidateSelected"], True)
        self.assertEqual(context["selectedToolbarIndex"], 2)
        self.assertIsInstance(context["retryCount"], int)
        self.assertNotIsInstance(context["retryCount"], bool)

    def test_diagnostic_schema_separates_automation_and_visual_validation(self) -> None:
        source = DIAGNOSTICS_SOURCE.read_text(encoding="utf-8")
        for field in (
            "ToolbarCandidateCount",
            "FontSizeAnchorRects",
            "NumberButtonAnchorRects",
            "ToolbarCandidateSelected",
            "SelectedToolbarIndex",
            "SelectedFontSizeRect",
            "SelectedNumberButtonRect",
            "CalculatedScreenPoint",
            "ColorMenuClickSent",
            "BlackItemFound",
            "BlackItemInvokeSucceeded",
            "AutomationChainResult",
            "FinalInsertionColorVisuallyValidated",
        ):
            with self.subTest(field=field):
                self.assertIn(field, source)
        self.assertIn("FINAL_COLOR_PENDING_VISUAL_VALIDATION", source)

    def test_field_debug_has_no_focus_changing_completion_ui(self) -> None:
        source = FIELD_DEBUG_SOURCE.read_text(encoding="utf-8")
        executable_lines = [
            line
            for line in source.splitlines()
            if not line.lstrip().startswith(";")
        ]
        executable_source = "\n".join(executable_lines)
        for forbidden in ("MsgBox", "ToolTip", "TrayTip"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, executable_source)


if __name__ == "__main__":
    unittest.main()
