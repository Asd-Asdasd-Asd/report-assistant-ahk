#!/usr/bin/env python3
"""Static integration checks for the production Color Reset V1 call chain."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def function_body(text: str, name: str, next_name: str) -> str:
    return text.split(f"{name}(", 1)[1].split(f"{next_name}(", 1)[0]


class ProductionColorResetIntegrationTests(unittest.TestCase):
    def test_hotstrings_use_report_editor_orchestration(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn("InsertRedFigureTextAndRestoreState()", hotstrings)
        self.assertNotIn("ResetMedExInsertionColor(", hotstrings)

    def test_orchestration_pastes_then_resets_and_preserves_partial_failure(self) -> None:
        report_editor = source("src/report_editor.ahk")
        body = function_body(
            report_editor,
            "InsertRedFigureTextAndRestoreState",
            "ResetReportFormattingPlaceholder",
        )
        paste = body.index("PasteRedFigureTextDetailed(text)")
        reset = body.index("ResetMedExInsertionColor(resetOptions)")
        self.assertLess(paste, reset)
        self.assertIn("RedTextOperationCode.PASTE_FAILED", body)
        self.assertIn("RedTextOperationCode.RESET_FAILED", body)
        self.assertIn("pasteDispatched: true", body)
        for forbidden in ("MsgBox", "ToolTip", "TrayTip", "Flash("):
            self.assertNotIn(forbidden, body)

    def test_generic_clipboard_module_has_no_medex_or_uia_dependency(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        self.assertNotIn("MedEx", clipboard)
        self.assertNotIn("UIA", clipboard)
        body = function_body(clipboard, "PasteHtmlFragmentDetailed", "BuildCfHtml")
        for forbidden in ("MsgBox", "ToolTip", "TrayTip", "Flash("):
            self.assertNotIn(forbidden, body)

    def test_provisional_process_allowlist_is_exact_and_enabled_for_baseline(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        self.assertIn('"medexworkstation.exe"', adapter)
        self.assertIn('"medexworkstations.exe"', adapter)
        self.assertIn("static AllowProvisionalProcess := true", adapter)
        self.assertIn('"processNameConfirmed", false', adapter)

    def test_foreground_change_has_stable_distinct_result_code(self) -> None:
        logic = source("src/medex_color_reset_logic.ahk")
        adapter = source("src/adapters/medex_report_editor.ahk")
        self.assertIn("COLOR_RESET_FOREGROUND_CHANGED", logic)
        self.assertGreaterEqual(adapter.count("ColorResetCode.FOREGROUND_CHANGED"), 4)
        self.assertIn("ColorResetCode.WRONG_PROCESS", adapter)

    def test_production_and_field_share_core_with_different_diagnostic_modes(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn('MedExAdapterOption(options, "diagnosticMode", "production")', adapter)
        self.assertIn('"diagnosticMode", "field"', field_debug)
        self.assertIn("ResetMedExInsertionColor(options)", field_debug)
        self.assertNotIn("ResolveMedExColorResetLayout(", field_debug)

    def test_production_logs_only_lightweight_failures_by_default(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        diagnostics = source("src/diagnostics.ahk")
        self.assertIn('diagnosticMode = "production" && !ok', adapter)
        self.assertIn("WriteMedExColorResetFailureDiagnostic", adapter)
        lightweight = function_body(
            diagnostics,
            "FormatMedExColorResetFailureLogLine",
            "FormatMedExColorResetLogLine",
        )
        self.assertIn('"appVersion="', lightweight)
        self.assertIn('"resultCode="', lightweight)
        for heavy_field in ("uiaRootRect", "regionAnchorRect", "fontSizeAnchorRect", "calculatedScreenPoint"):
            self.assertNotIn(heavy_field, lightweight)
        self.assertIn("FormatMedExFieldDebugResult", diagnostics)
        self.assertIn('"RegionAnchorRect="', diagnostics)

    def test_version_and_uia_dependency_are_production_owned(self) -> None:
        metadata = source("src/app_metadata.ahk")
        main = source("src/main.ahk")
        build = source("scripts/build_release.py")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn('static Version := "0.5.0-alpha.0"', metadata)
        self.assertIn("#Include app_metadata.ahk", main)
        self.assertIn("#Include <UIA>", main)
        self.assertTrue((SRC / "Lib" / "UIA.ahk").is_file())
        self.assertFalse((ROOT / "debug" / "Lib" / "UIA.ahk").exists())
        self.assertIn('"Lib/UIA.ahk"', build)
        self.assertIn("..\\src\\Lib\\UIA.ahk", field_debug)

    def test_production_sources_are_relocatable(self) -> None:
        app_sources = [
            path
            for path in SRC.rglob("*.ahk")
            if path.name != "UIA.ahk"
        ]
        combined = "\n".join(path.read_text(encoding="utf-8") for path in app_sources)
        for forbidden in (
            "/Users/",
            "debug/field-result-",
            "debug\\field-result-",
            "NAS",
        ):
            self.assertNotIn(forbidden, combined)
        self.assertIsNone(re.search(r'(?i)[A-Z]:\\(?:Users|AutoHotKey|Project)\\', combined))

    def test_generated_release_is_self_contained_after_build(self) -> None:
        release = source("release/report_assistant.ahk")
        self.assertIn("class AppMetadata", release)
        self.assertIn('static Version := "0.5.0-alpha.0"', release)
        self.assertIn('static Version => "1.1.3"', release)
        self.assertIn("class MedExColorResetLayoutProfile", release)
        self.assertIn("ResetMedExInsertionColor(options := 0)", release)
        self.assertNotIn("#Include", release)
        self.assertNotIn("if !A_IsCompiled && A_LineFile = A_ScriptFullPath", release)
        self.assertNotIn("UIA.Viewer()", release)


if __name__ == "__main__":
    unittest.main()
