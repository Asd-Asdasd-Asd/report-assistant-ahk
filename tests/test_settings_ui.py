#!/usr/bin/env python3
"""Structural checks for the native report-template settings UI."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class SettingsUiTests(unittest.TestCase):
    def test_native_gui_has_tabs_list_and_user_facing_editor_fields(self) -> None:
        ui = source("src/settings_ui.ahk")
        self.assertIn('Gui(, ReportAssistantSettingsDefaults.WindowTitle)', ui)
        self.assertIn('"Tab3"', ui)
        self.assertIn('["报告模板", "快捷键", "其他"]', ui)
        self.assertIn('"ListView"', ui)
        for label in (
            "模板名称",
            "触发词",
            "模板文字",
            "插入模板元素",
            "光标位置",
            "当前日期",
            "红色“（见图）”",
        ):
            self.assertIn(label, ui)
        self.assertNotIn("SchemaVersion", ui)
        self.assertNotIn("Hotstring.builtin-", ui)
        self.assertNotIn("Hotstring.custom-", ui)

    def test_mode_is_not_exposed_or_saved(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        self.assertNotIn("ModeInput", ui)
        self.assertNotIn("ReportHotstringMode", ui + editor)
        self.assertNotIn('"Mode"', editor)

    def test_window_is_single_instance_and_save_uses_full_reload(self) -> None:
        ui = source("src/settings_ui.ahk")
        self.assertIn("static Current := 0", ui)
        self.assertIn("if IsObject(this.Current)", ui)
        self.assertIn("this.Current.Activate()", ui)
        self.assertIn("SaveEditableReportHotstringConfig(", ui)
        self.assertIn("try Reload()", ui)
        self.assertNotIn('Hotstring(":', ui)
        self.assertNotIn("Hotkey(definition", ui)

    def test_unsaved_close_can_prevent_the_window_from_closing(self) -> None:
        ui = source("src/settings_ui.ahk")
        close = ui.split("OnClose(*) {", 1)[1].split("\n    }", 1)[0]
        self.assertIn('if answer != "Yes"', close)
        self.assertIn("return true", close)
        self.assertIn("this.DestroyWindow()", close)

    def test_editor_validation_covers_required_fields_and_all_duplicates(self) -> None:
        editor = source("src/hotstring_config_editor.ahk")
        validation = editor.split(
            "ValidateEditableReportHotstringEntries(entries) {", 1
        )[1].split("\n}\n\nSaveEditableReportHotstringConfig", 1)[0]
        self.assertIn('name = ""', validation)
        self.assertIn('trigger = ""', validation)
        self.assertIn("seenTriggers.Has(triggerKey)", validation)
        self.assertIn("ValidateReportTemplate(entry.Text)", validation)
        self.assertIn('false, index, "Text"', validation)
        self.assertNotIn("entry.Enabled", validation.split("triggerKey :=", 1)[1])

    def test_multiline_editor_normalizes_windows_line_endings_before_encoding(self) -> None:
        config = source("src/hotstring_config.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        ui = source("src/settings_ui.ahk")
        self.assertIn('StrReplace(String(value), "`r`n", "`n")', config)
        self.assertIn('return StrReplace(value, "`r", "`n")', config)
        self.assertIn("ReportHotstringTextForMultilineEdit(entry.Text)", ui)
        self.assertIn(
            "ReportHotstringTextFromMultilineEdit(this.TextInput.Text)", ui
        )
        self.assertIn(
            "EncodeReportHotstringText(\n                    "
            "NormalizeEditableReportHotstringText(entry.Text)",
            editor,
        )

    def test_template_element_dropdown_replaces_selection_and_is_extensible(self) -> None:
        ui = source("src/settings_ui.ahk")
        self.assertIn("TemplateElementDefinitions()", ui)
        self.assertIn("ReportHotstringDefaults.CursorPlaceholder", ui)
        self.assertIn("ReportHotstringDefaults.DatePlaceholder", ui)
        self.assertIn(
            "ReportHotstringDefaults.RedFigureReferencePlaceholder", ui
        )
        self.assertIn("ReplaceReportTemplateEditSelection(", ui)
        self.assertIn('"UInt", 0x00C2', ui)
        self.assertIn("this.TemplateElementInput.Choose(0)", ui)
        self.assertIn("this.TextInput.Focus()", ui)
        self.assertIn("this.ModifiedSectionKeys", ui)

    def test_list_identity_is_section_based_and_product_sorting_remains_available(self) -> None:
        ui = source("src/settings_ui.ahk")
        self.assertIn('"ListView", "x28 y52 w844 h220 -Multi"', ui)
        self.assertNotIn("NoSort", ui)
        self.assertIn('["状态", "模板名称", "触发词", ""]', ui)
        self.assertIn("this.TemplateList.ModifyCol(4, 0)", ui)
        self.assertIn("this.SelectedSection", ui)
        self.assertIn("SectionForListRow(row)", ui)
        self.assertIn("FindEntryIndexBySection(section)", ui)
        self.assertIn("FindListRowBySection(section)", ui)
        self.assertNotIn("this.SelectedRow", ui)
        self.assertNotIn("this.Entries.RemoveAt(deletedRow)", ui)
        self.assertNotIn("this.TemplateList.Delete(deletedRow)", ui)

    def test_delete_refreshes_from_model_and_save_compares_by_section(self) -> None:
        ui = source("src/settings_ui.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        delete = ui.split("OnDeleteTemplate(*) {", 1)[1].split(
            "\n    }\n\n    OnSave", 1
        )[0]
        self.assertIn("entryIndex := this.FindEntryIndexBySection", delete)
        self.assertIn("this.Entries.RemoveAt(entryIndex)", delete)
        self.assertIn("this.RefreshTemplateList()", delete)
        self.assertIn("this.SelectSection(", delete)
        matcher = editor.split(
            "EditableReportHotstringEntriesMatch(expected, actual)", 1
        )[1]
        self.assertIn("EditableReportHotstringEntriesBySection(actual)", matcher)
        self.assertIn("ValidateEditableReportHotstringSaveResult(", editor)
        self.assertIn("originalLoad.Entries", editor)
        self.assertIn("this.ModifiedSectionKeys", ui)
        self.assertIn("&& !modifiedKeys.Has(sectionKey)", editor)

    def test_only_custom_sections_can_be_deleted(self) -> None:
        editor = source("src/hotstring_config_editor.ahk")
        ui = source("src/settings_ui.ahk")
        self.assertIn("if entry.IsBuiltin", ui)
        self.assertIn("内置模板不能删除", ui)
        self.assertIn("if !IsCustomReportHotstringSection(section)", editor)
        self.assertIn("IniDelete(tempPath, section)", editor)

    def test_save_is_copy_validate_promote_and_detects_external_changes(self) -> None:
        editor = source("src/hotstring_config_editor.ahk")
        save = editor.split(
            "SaveEditableReportHotstringConfig(\n    entries,", 1
        )[1].split("\n}\n\nEditableReportHotstringEntriesMatch", 1)[0]
        self.assertIn("if currentText != originalText", save)
        self.assertIn("CreateReportAssistantConfigBackup(configPath)", save)
        self.assertIn("FileCopy configPath, tempPath, true", save)
        self.assertIn("LoadEditableReportHotstringConfig(tempPath)", save)
        self.assertIn("FileMove tempPath, configPath, true", save)
        self.assertLess(save.index("FileCopy configPath"), save.index("IniWrite"))
        self.assertLess(
            save.index("LoadEditableReportHotstringConfig(tempPath)"),
            save.index("FileMove tempPath, configPath, true"),
        )

    def test_release_builder_includes_editor_and_ui_before_tray(self) -> None:
        main = source("src/main.ahk")
        builder = source("scripts/build_release.py")
        for text in (main, builder):
            self.assertLess(
                text.index("hotstring_config_editor.ahk"),
                text.index("settings_ui.ahk"),
            )
            self.assertLess(text.index("settings_ui.ahk"), text.index("tray_menu.ahk"))


if __name__ == "__main__":
    unittest.main()
