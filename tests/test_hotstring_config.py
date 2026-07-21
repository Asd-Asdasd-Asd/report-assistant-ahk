#!/usr/bin/env python3
"""Static checks for user-configurable MedEx report hotstrings."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class HotstringConfigTests(unittest.TestCase):
    def test_hotstring_pipeline_has_explicit_layer_boundaries(self) -> None:
        main = source("src/main.ahk")
        expected = (
            "hotstring_model.ahk",
            "hotstring_config.ahk",
            "hotstring_normalization.ahk",
            "hotstring_registration.ahk",
            "hotstrings.ahk",
        )
        positions = [main.index(f"#Include {name}") for name in expected]
        self.assertEqual(positions, sorted(positions))

        config = source("src/hotstring_config.ahk")
        normalization = source("src/hotstring_normalization.ahk")
        registration = source("src/hotstring_registration.ahk")
        self.assertNotIn("IniRead", normalization + registration)
        self.assertNotIn("Hotstring(", config + normalization)
        self.assertNotIn("RunRedResetInsertion", config + normalization + registration)

    def test_all_builtins_are_extracted_with_stable_sections_and_defaults(self) -> None:
        model = source("src/hotstring_model.ahk")
        expected = (
            ("red", ";red", "（见图）", "RED_RESET"),
            ("fzg", ";fzg", "放射性摄取增高，SUVmax约（见图）", "RED_LEFT4"),
            ("fwj", ";fwj", "放射性摄取未见明显增高（见图）", "RED_RESET"),
            ("fjd", ";fjd", "放射性摄取降低（见图）", "RED_RESET"),
            ("cmx", ";cmx", "cm×cm", "TEXT"),
        )
        for stable_id, trigger, text, mode in expected:
            self.assertIn(f'"Hotstring.builtin-{stable_id}"', model)
            self.assertIn(f'"{trigger}"', model)
            self.assertIn(f'"{text}"', model)
            self.assertIn(f"ReportHotstringMode.{mode}", model)

    def test_schema_path_first_launch_and_utf16_are_centralized(self) -> None:
        config = source("src/hotstring_config.ahk")
        model = source("src/hotstring_model.ahk")
        self.assertIn('static SchemaVersion := 1', model)
        self.assertIn('static DirectoryName := "MedExReportAssistant"', model)
        self.assertIn('static FileName := "config.ini"', model)
        self.assertIn('localAppData := EnvGet("LOCALAPPDATA")', config)
        self.assertIn('return localAppData "\\" ReportHotstringDefaults.DirectoryName', config)
        self.assertIn('throw Error("LOCALAPPDATA is unavailable")', config)
        self.assertNotIn("A_LocalAppData", config)
        self.assertIn('if !FileExist(configPath)', config)
        self.assertGreaterEqual(config.count('if FileExist(configPath)'), 2)
        self.assertIn('FileAppend BuildDefaultReportHotstringConfig(defaults), configPath, "UTF-16"', config)
        self.assertNotIn("IniWrite", config)

    def test_loader_only_parses_supported_fields(self) -> None:
        config = source("src/hotstring_config.ahk")
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn("ReadReportHotstringSection", config)
        self.assertNotIn("NormalizeReportHotstringEntry", config)
        self.assertEqual(hotstrings.count("LoadReportHotstringConfig()"), 1)
        self.assertNotIn("IniRead", hotstrings)
        fields = re.findall(r'IniRead\(configPath, section, "([A-Za-z]+)"', config)
        self.assertEqual(fields, ["Enabled", "Name", "Trigger", "Text", "Mode"])

    def test_validation_fallback_and_newline_decoding_are_explicit(self) -> None:
        config = source("src/hotstring_config.ahk")
        normalization = source("src/hotstring_normalization.ahk")
        self.assertIn('if trigger = ""', normalization)
        self.assertIn("IsSupportedReportHotstringMode(mode)", normalization)
        self.assertIn('return entries.Length > 0 ? entries : NormalizeReportHotstringEntries(', normalization)
        self.assertIn('if pair = "\\n"', config)
        self.assertIn('output .= "`n"', config)
        self.assertIn('else if pair = "\\\\"', config)

    def test_dynamic_registration_preserves_order_and_first_enabled_duplicate(self) -> None:
        registration = source("src/hotstring_registration.ahk")
        loop = registration.split("for entry in entries", 1)[1].split("} finally", 1)[0]
        self.assertIn("triggerKey := StrLower(entry.Trigger)", loop)
        self.assertIn("!entry.Enabled || seenTriggers.Has(triggerKey)", loop)
        self.assertLess(loop.index("Hotstring("), loop.index("seenTriggers[triggerKey] := true"))
        self.assertIn("executor.Bind(entry)", loop)

    def test_dispatcher_has_only_supported_non_executable_modes(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        dispatcher = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1]
        self.assertIn("SendConfiguredReportText(entry.PlainText)", dispatcher)
        self.assertIn("RunRedResetInsertion(entry.RedText)", dispatcher)
        self.assertIn("RunRedLeft4Insertion(entry.RedText)", dispatcher)
        self.assertNotIn("RunConfiguredRedResetInsertion", hotstrings)
        self.assertNotIn("RunConfiguredRedLeft4Insertion", hotstrings)
        for forbidden in ("Execute", "Eval", "Run(entry.Text", "Hotstring(entry.Text"):
            self.assertNotIn(forbidden, dispatcher)

    def test_all_red_modes_append_only_the_fixed_red_figure_marker(self) -> None:
        model = source("src/hotstring_model.ahk")
        normalization = source("src/hotstring_normalization.ahk")
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn('static RedFigureMarker := "（见图）"', model)
        self.assertIn("marker := ReportHotstringDefaults.RedFigureMarker", normalization)
        self.assertIn("plainText := TextEndsWith(text, marker)", normalization)
        self.assertIn("redText := marker", normalization)
        self.assertNotIn("IsLegacyMixedColorBuiltin", normalization + hotstrings)
        self.assertNotIn("LegacyRedSuffix", normalization + hotstrings)
        self.assertNotIn("SplitConfiguredRedText", hotstrings)

    def test_custom_and_builtin_red_entries_share_one_normalization_path(self) -> None:
        normalization = source("src/hotstring_normalization.ahk")
        red_plan = normalization.split("if IsRedReportHotstringMode(mode)", 1)[1].split(
            "postTextCaretLeftCount :=", 1
        )[0]
        self.assertNotIn("builtin-", red_plan)
        self.assertNotIn("custom-", red_plan)
        self.assertIn(": text", red_plan)
        self.assertIn("redText := marker", red_plan)

    def test_custom_red_left4_uses_shared_settle_and_caret_path(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        report_editor = source("src/report_editor.ahk")
        dispatcher = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1].split(
            "\n}\n\nSendConfiguredReportText", 1
        )[0]
        self.assertIn("RunRedLeft4Insertion(entry.RedText)", dispatcher)
        self.assertNotIn("entry.Section", dispatcher)
        self.assertIn("static RedLeft4AfterPasteSettleMs := 60", report_editor)
        self.assertIn(
            "Sleep ReportEditorTimingDefaults.RedLeft4AfterPasteSettleMs",
            report_editor,
        )

    def test_debug_compatibility_wrappers_remain_available(self) -> None:
        report_editor = source("src/report_editor.ahk")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        candidate_debug = source("debug/medex_candidate_g2_test.ahk")
        self.assertIn("RunRedInsertion(resetOptions", report_editor)
        self.assertIn("RunFzgInsertion(resetOptions", report_editor)
        self.assertIn("RunRedInsertion(", field_debug)
        self.assertIn("RunFzgInsertion(", candidate_debug)

    def test_text_ends_with_uses_v2_safe_positive_start_position(self) -> None:
        normalization = source("src/hotstring_normalization.ahk")
        helper = normalization.split("TextEndsWith(text, suffix)", 1)[1].split(
            "\n}\n\nParseReportHotstringEnabled", 1
        )[0]
        self.assertIn("suffixStart := StrLen(text) - StrLen(suffix) + 1", helper)
        self.assertIn("SubStr(text, suffixStart) = suffix", helper)
        self.assertNotIn("1 - StrLen(suffix)", helper)

    def test_fixed_caret_contracts_are_not_user_fields(self) -> None:
        config = source("src/hotstring_config.ahk")
        normalization = source("src/hotstring_normalization.ahk")
        hotstrings = source("src/hotstrings.ahk")
        report_editor = source("src/report_editor.ahk")
        self.assertIn('section = "Hotstring.builtin-cmx"', normalization)
        self.assertEqual(hotstrings.count('Send("{Left 2}")'), 1)
        self.assertEqual(report_editor.count('Send("{Left 4}")'), 1)
        self.assertNotIn('IniRead(configPath, section, "Left', config)
        self.assertNotIn("Order", config)

    def test_configured_red_newlines_render_as_html_breaks(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        self.assertIn('StrReplace(HtmlEscape(text), "`n", "<br>")', clipboard)


if __name__ == "__main__":
    unittest.main()
