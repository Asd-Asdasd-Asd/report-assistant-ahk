#!/usr/bin/env python3
"""Static checks for the schema 2 report-template engine."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class HotstringConfigTests(unittest.TestCase):
    def test_pipeline_has_template_and_migration_layers(self) -> None:
        main = source("src/main.ahk")
        expected = (
            "hotstring_model.ahk",
            "hotstring_config.ahk",
            "template_renderer.ahk",
            "hotstring_normalization.ahk",
            "config_reconciliation.ahk",
            "hotstring_config_migration.ahk",
            "hotstring_config_editor.ahk",
            "config_bootstrap.ahk",
            "hotstring_registration.ahk",
            "hotstrings.ahk",
        )
        positions = [main.index(f"#Include {name}") for name in expected]
        self.assertEqual(positions, sorted(positions))

    def test_schema2_builtins_are_template_driven(self) -> None:
        model = source("src/hotstring_model.ahk")
        expected = (
            ("red", ";red", "{{red:（见图）}}"),
            (
                "fzg",
                ";fzg",
                "放射性摄取增高，SUVmax约为{{cursor}}{{red:（见图）}}",
            ),
            ("fwj", ";fwj", "放射性摄取未见明显增高{{red:（见图）}}"),
            ("fjd", ";fjd", "放射性摄取降低{{red:（见图）}}"),
            ("cmx", ";cmx", "cm×{{cursor}}cm"),
        )
        for stable_id, trigger, text in expected:
            self.assertIn(f'"Hotstring.builtin-{stable_id}"', model)
            self.assertIn(f'"{trigger}"', model)
            self.assertIn(f'"{text}"', model)
        self.assertNotIn("ReportHotstringMode", model)
        self.assertNotIn("Mode", model)

    def test_schema_path_and_new_config_have_no_mode(self) -> None:
        config = source("src/hotstring_config.ahk")
        app_config = source("src/app_config.ahk")
        self.assertIn("static SchemaVersion := 2", app_config)
        self.assertIn('static DirectoryName := "MedExReportAssistant"', app_config)
        self.assertIn('static FileName := "config.ini"', app_config)
        self.assertIn('localAppData := EnvGet("LOCALAPPDATA")', app_config)
        self.assertIn(
            'FileAppend BuildDefaultReportHotstringConfig(defaults), configPath, "UTF-16"',
            config,
        )
        builder = config.split(
            "BuildDefaultReportHotstringConfig(defaults := 0)", 1
        )[1].split("\n}\n\nJoinConfigLines", 1)[0]
        for line in (
            "[Hotstring.custom-example]",
            "Enabled=false",
            "Name=新的快捷语",
            "Trigger=;example",
            "Text=请输入内容",
        ):
            self.assertIn(f'lines.Push("{line}")', builder)
        self.assertNotIn("Mode=", builder)

    def test_schema2_loader_reads_only_four_template_fields(self) -> None:
        config = source("src/hotstring_config.ahk")
        fields = re.findall(
            r'IniRead\(configPath, section, "([A-Za-z]+)"', config
        )
        self.assertEqual(fields, ["Enabled", "Name", "Trigger", "Text"])
        self.assertNotIn('"Mode"', config)

    def test_invalid_config_is_fail_closed_without_builtin_fallback(self) -> None:
        config = source("src/hotstring_config.ahk")
        normalization = source("src/hotstring_normalization.ahk")
        self.assertIn("return []", config)
        self.assertNotIn("return defaults", config)
        self.assertNotIn("ReportHotstringDefaults.BuiltinDefinitions()", normalization)
        self.assertIn("ValidateReportTemplate(raw.Text)", normalization)
        self.assertIn("return []", normalization)
        self.assertIn("DUPLICATE_TRIGGER", normalization)

    def test_double_brace_parser_is_strict_but_single_braces_are_not_reserved(self) -> None:
        renderer = source("src/template_renderer.ahk")
        self.assertIn('InStr(sourceText, "{{"', renderer)
        self.assertIn('InStr(sourceText, "}}"', renderer)
        self.assertIn('token = "cursor"', renderer)
        self.assertIn('token = "date"', renderer)
        self.assertIn('token = "red:（见图）"', renderer)
        self.assertIn("RedFigureStartIndex", renderer)
        self.assertIn("必须是模板最后一个元素", renderer)
        self.assertIn("cursorCount > 1", renderer)
        self.assertIn("占位符不能嵌套", renderer)
        self.assertNotIn('InStr(sourceText, "{")', renderer)

    def test_date_is_evaluated_at_render_time_before_caret_distance(self) -> None:
        renderer = source("src/template_renderer.ahk")
        self.assertIn('FormatTime(, "yyyy-MM-dd")', renderer)
        self.assertLess(
            renderer.index('FormatTime(, "yyyy-MM-dd")'),
            renderer.index(
                "caretLeftCount := StrLen(renderedText) - rendered.CaretIndex"
            ),
        )

    def test_dispatcher_derives_caret_and_color_from_plan(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        body = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1]
        self.assertIn("plan := BuildReportTemplatePlan(entry.Text)", body)
        self.assertIn("if plan.RequiresColorReset", body)
        self.assertIn("SendConfiguredReportText(plan.PlainText)", body)
        self.assertIn("RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)", body)
        self.assertIn("RunRedResetInsertion(plan.RedText, resetReadiness.options)", body)
        self.assertNotIn("entry.Mode", body)
        self.assertNotIn("ReportHotstringMode", body)

    def test_black_templates_keep_existing_sendtext_backend(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn("SendConfiguredReportText(plan.PlainText)", hotstrings)
        self.assertIn("SendText(line)", hotstrings)
        self.assertIn('Send("{Enter}")', hotstrings)
        self.assertNotIn("PastePlainText(plan.PlainText)", hotstrings)

    def test_red_suffix_and_caret_share_generic_safe_path(self) -> None:
        renderer = source("src/template_renderer.ahk")
        report_editor = source("src/report_editor.ahk")
        plan = renderer.split("BuildReportTemplatePlan(templateText)", 1)[1]
        self.assertIn("rendered.RedFigureCount = 1", plan)
        self.assertIn("rendered.RedFigureStartIndex", plan)
        self.assertNotIn("TextEndsWith(", plan)
        self.assertIn("caretLeftCount = 0 && redText != \"\"", renderer)
        self.assertIn("RunRedCaretInsertion(text, caretLeftCount", report_editor)
        self.assertIn("cursorRestoreRequestedCount\", caretLeftCount", report_editor)
        self.assertIn("Send(\"{Left \" caretLeftCount \"}\")", report_editor)
        self.assertIn("static RedCaretAfterPasteSettleMs := 60", report_editor)

    def test_text_codec_is_symmetric_and_normalizes_windows_line_endings(self) -> None:
        config = source("src/hotstring_config.ahk")
        encoder = config.split("EncodeReportHotstringText(value)", 1)[1].split(
            "\n}\n\nDecodeReportHotstringText", 1
        )[0]
        self.assertIn("NormalizeReportHotstringTextNewlines(value)", encoder)
        self.assertIn('if A_LoopField = "\\"', encoder)
        self.assertIn('output .= "\\\\"', encoder)
        self.assertIn('else if A_LoopField = "`n"', encoder)
        self.assertIn('output .= "\\n"', encoder)
        self.assertIn("ReportHotstringTextForMultilineEdit(value)", config)
        self.assertIn("ReportHotstringTextFromMultilineEdit(value)", config)

    def test_registration_remains_data_only_and_ordered(self) -> None:
        registration = source("src/hotstring_registration.ahk")
        loop = registration.split("for entry in entries", 1)[1].split(
            "} finally", 1
        )[0]
        self.assertIn("triggerKey := StrLower(entry.Trigger)", loop)
        self.assertIn("!entry.Enabled || seenTriggers.Has(triggerKey)", loop)
        self.assertIn("executor.Bind(entry)", loop)

    def test_migration_is_the_only_legacy_mode_owner(self) -> None:
        migration = source("src/hotstring_config_migration.ahk")
        combined = "\n".join(
            source(path)
            for path in (
                "src/hotstring_model.ahk",
                "src/hotstring_config.ahk",
                "src/template_renderer.ahk",
                "src/hotstring_normalization.ahk",
                "src/hotstrings.ahk",
                "src/settings_ui.ahk",
            )
        )
        for mode in ('"text"', '"red-reset"', '"red-left4"'):
            self.assertIn(mode, migration)
            self.assertNotIn(mode, combined)
        self.assertIn('IniRead(configPath, section, "Mode", "")', migration)

    def test_migration_is_audited_backed_up_validated_and_restorable(self) -> None:
        migration = source("src/hotstring_config_migration.ahk")
        self.assertIn("AuditReportAssistantConfigV1(configPath)", migration)
        self.assertIn("CreateReportAssistantConfigBackup(configPath)", migration)
        self.assertIn("FileCopy configPath, tempPath, true", migration)
        self.assertIn("ValidateMigratedReportAssistantConfig(tempPath", migration)
        self.assertIn("FileMove tempPath, configPath, true", migration)
        self.assertIn("FileCopy backupPath, configPath, true", migration)
        self.assertIn("try FileDelete tempPath", migration)
        self.assertNotIn("FileDelete configPath", migration)

    def test_migration_covers_known_semantics_and_unsafe_cases(self) -> None:
        migration = source("src/hotstring_config_migration.ahk")
        self.assertIn("RedFigureReferencePlaceholder", migration)
        self.assertIn("ExpectedRedText", migration)
        self.assertIn("cm×", source("src/hotstring_model.ahk"))
        self.assertNotIn("BLACK_RED_SUFFIX_AMBIGUOUS", migration)
        self.assertIn("UNKNOWN_LEGACY_MODE", migration)
        self.assertIn("LEGACY_PLACEHOLDER_AMBIGUOUS", migration)
        self.assertIn("DUPLICATE_TRIGGER", migration)
        self.assertIn("MIGRATION_SEMANTICS_MISMATCH", migration)

    def test_windows_harnesses_cover_audit_and_cmx_trigger(self) -> None:
        audit = source("tests/windows/config_v2_migration_audit.ahk")
        cmx = source("tests/windows/cmx_template_regression.ahk")
        regression = source("tests/windows/template_engine_regression.ahk")
        settings = source("tests/windows/settings_ui_regression.ahk")
        self.assertIn("WriteReportAssistantConfigV2Audit", audit)
        self.assertIn("config-v2-migration-audit.txt", audit)
        self.assertIn('Hotstring(":*?:;cmx"', cmx)
        self.assertIn('SendText "3.5;cmx"', cmx)
        self.assertIn('"3.5cm×cm"', cmx)
        self.assertIn("selectionStart", cmx)
        self.assertIn("MigrateReportAssistantConfigV1ToV2", regression)
        self.assertIn("before = after", regression)
        self.assertIn("CaretLeftCount = 4", regression)
        for harness in (audit, regression, settings):
            dependency_order = (
                "feature_model.ahk",
                "hotstring_model.ahk",
                "hotstring_config.ahk",
                "template_renderer.ahk",
                "hotstring_normalization.ahk",
                "config_reconciliation.ahk",
                "hotstring_config_migration.ahk",
            )
            positions = [
                harness.index(f"#Include ..\\..\\src\\{name}")
                for name in dependency_order
            ]
            self.assertEqual(positions, sorted(positions))

    def test_configured_red_newlines_render_as_html_breaks(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        self.assertIn('StrReplace(HtmlEscape(text), "`n", "<br>")', clipboard)


if __name__ == "__main__":
    unittest.main()
