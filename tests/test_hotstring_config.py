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
    def test_all_builtins_are_extracted_with_stable_sections_and_defaults(self) -> None:
        config = source("src/hotstring_config.ahk")
        expected = (
            ("red", ";red", "（见图）", "RED_RESET"),
            ("fzg", ";fzg", "放射性摄取增高，SUVmax约（见图）", "RED_LEFT4"),
            ("fwj", ";fwj", "放射性摄取未见明显增高（见图）", "RED_RESET"),
            ("fjd", ";fjd", "放射性摄取降低（见图）", "RED_RESET"),
            ("cmx", ";cmx", "cm×cm", "TEXT"),
        )
        for stable_id, trigger, text, mode in expected:
            self.assertIn(f'"Hotstring.builtin-{stable_id}"', config)
            self.assertIn(f'"{trigger}"', config)
            self.assertIn(f'"{text}"', config)
            self.assertIn(f"ReportHotstringMode.{mode}", config)

    def test_schema_path_first_launch_and_utf16_are_centralized(self) -> None:
        config = source("src/hotstring_config.ahk")
        self.assertIn('static SchemaVersion := 1', config)
        self.assertIn('static DirectoryName := "MedExReportAssistant"', config)
        self.assertIn('static FileName := "config.ini"', config)
        self.assertIn('localAppData := EnvGet("LOCALAPPDATA")', config)
        self.assertIn('return localAppData "\\" this.DirectoryName', config)
        self.assertIn('throw Error("LOCALAPPDATA is unavailable")', config)
        self.assertNotIn("A_LocalAppData", config)
        self.assertIn('if !FileExist(configPath)', config)
        self.assertGreaterEqual(config.count('if FileExist(configPath)'), 2)
        self.assertIn('FileAppend BuildDefaultReportHotstringConfig(defaults), configPath, "UTF-16"', config)
        self.assertNotIn("IniWrite", config)

    def test_loader_normalizes_once_and_ignores_unknown_fields(self) -> None:
        config = source("src/hotstring_config.ahk")
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn("ReadReportHotstringSection", config)
        self.assertIn("NormalizeReportHotstringEntry", config)
        self.assertEqual(hotstrings.count("LoadReportHotstringConfig()"), 1)
        self.assertNotIn("IniRead", hotstrings)
        for field in ("Enabled", "Name", "Trigger", "Text", "Mode"):
            self.assertIn(f'"{field}", IniRead(', config)
        self.assertEqual(len(re.findall(r'"[A-Za-z]+", IniRead\(', config)), 5)

    def test_validation_fallback_and_newline_decoding_are_explicit(self) -> None:
        config = source("src/hotstring_config.ahk")
        self.assertIn('if trigger = ""', config)
        self.assertIn("IsSupportedReportHotstringMode(mode)", config)
        self.assertIn('return entries.Length > 0 ? entries : defaults', config)
        self.assertIn('if pair = "\\n"', config)
        self.assertIn('output .= "`n"', config)
        self.assertIn('else if pair = "\\\\"', config)

    def test_dynamic_registration_preserves_order_and_first_enabled_duplicate(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        loop = hotstrings.split("for entry in entries", 1)[1].split("} finally", 1)[0]
        self.assertIn("triggerKey := StrLower(entry.Trigger)", loop)
        self.assertIn("!entry.Enabled || seenTriggers.Has(triggerKey)", loop)
        self.assertLess(loop.index("Hotstring("), loop.index("seenTriggers[triggerKey] := true"))
        self.assertIn("RunConfiguredReportHotstring.Bind(entry)", loop)

    def test_dispatcher_has_only_supported_non_executable_modes(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        dispatcher = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1]
        self.assertIn("SendConfiguredReportText(entry.Text)", dispatcher)
        self.assertIn("RunConfiguredRedResetInsertion(entry)", dispatcher)
        self.assertIn("RunConfiguredRedLeft4Insertion(entry)", dispatcher)
        for forbidden in ("Execute", "Eval", "Run(entry.Text", "Hotstring(entry.Text"):
            self.assertNotIn(forbidden, dispatcher)

    def test_legacy_builtins_split_only_trailing_red_figure_marker(self) -> None:
        config = source("src/hotstring_config.ahk")
        hotstrings = source("src/hotstrings.ahk")
        for section in ("fzg", "fwj", "fjd"):
            self.assertIn(f'section = "Hotstring.builtin-{section}"', config)
        self.assertIn('TextEndsWith(decodedText, "（见图）")', config)
        self.assertIn('LegacyRedSuffix := String(legacyRedSuffix)', config)
        self.assertIn("suffix := entry.LegacyRedSuffix", hotstrings)
        self.assertIn("PlainPrefix: SubStr(entry.Text", hotstrings)
        self.assertIn("RedText: suffix", hotstrings)
        self.assertIn('return {PlainPrefix: "", RedText: entry.Text}', hotstrings)

    def test_text_ends_with_uses_v2_safe_positive_start_position(self) -> None:
        config = source("src/hotstring_config.ahk")
        helper = config.split("TextEndsWith(text, suffix)", 1)[1].split(
            "\n}\n\nParseReportHotstringEnabled", 1
        )[0]
        self.assertIn("suffixStart := StrLen(text) - StrLen(suffix) + 1", helper)
        self.assertIn("SubStr(text, suffixStart) = suffix", helper)
        self.assertNotIn("1 - StrLen(suffix)", helper)

    def test_fixed_caret_contracts_are_not_user_fields(self) -> None:
        config = source("src/hotstring_config.ahk")
        hotstrings = source("src/hotstrings.ahk")
        report_editor = source("src/report_editor.ahk")
        self.assertIn('section = "Hotstring.builtin-cmx"', config)
        self.assertEqual(hotstrings.count('Send("{Left 2}")'), 1)
        self.assertEqual(report_editor.count('Send("{Left 4}")'), 1)
        self.assertNotIn('IniRead(configPath, section, "Left', config)
        self.assertNotIn("Order", config)

    def test_configured_red_newlines_render_as_html_breaks(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        self.assertIn('StrReplace(HtmlEscape(text), "`n", "<br>")', clipboard)


if __name__ == "__main__":
    unittest.main()
