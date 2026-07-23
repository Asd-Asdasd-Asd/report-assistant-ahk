#!/usr/bin/env python3
"""Structural regression tests for additive configuration reconciliation."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ConfigReconciliationTests(unittest.TestCase):
    def test_config_bootstrap_precedes_all_runtime_registration(self) -> None:
        main = source("src/main.ahk")
        expected = (
            "app_config.ahk",
            "feature_model.ahk",
            "hotstring_config.ahk",
            "config_reconciliation.ahk",
            "config_bootstrap.ahk",
            "hotstring_registration.ahk",
            "hotstrings.ahk",
            "features.ahk",
        )
        positions = [main.index(f"#Include {name}") for name in expected]
        self.assertEqual(positions, sorted(positions))

        release = source("release/report_assistant.ahk")
        prepare = release.index(
            "PrepareReportAssistantConfig(\n    ReportAssistantManagedConfigDefaults()"
        )
        hotstrings = release.index("RegisterReportHotstrings(", prepare)
        features = release.index("RegisterConfiguredFeatures(", hotstrings)
        self.assertLess(prepare, hotstrings)
        self.assertLess(hotstrings, features)

    def test_global_hjkl_arrows_declares_a_managed_default(self) -> None:
        model = source("src/feature_model.ahk")
        self.assertIn("static ManagedConfigDefaults()", model)
        self.assertIn("ManagedConfigEntry(", model)
        self.assertIn("this.GlobalHjklArrowsKey", model)
        self.assertIn("this.GlobalHjklArrowsDefault", model)

    def test_interim_schema2_builtin_defaults_upgrade_to_explicit_red_tokens(
        self,
    ) -> None:
        model = source("src/hotstring_model.ahk")
        reconciliation = source("src/config_reconciliation.ahk")
        bootstrap = source("src/config_bootstrap.ahk")
        for legacy_text in (
            '"Hotstring.builtin-red", "（见图）"',
            '"放射性摄取增高，SUVmax约为{{cursor}}（见图）"',
            '"Hotstring.builtin-fwj", "放射性摄取未见明显增高（见图）"',
            '"Hotstring.builtin-fjd", "放射性摄取降低（见图）"',
        ):
            self.assertIn(legacy_text, model)
        self.assertIn("LegacySchema2BuiltinTextUpgrades()", model)
        self.assertIn(
            "DecodeReportHotstringText(encodedText) != definition.FromText",
            reconciliation,
        )
        self.assertIn(
            "ApplySchema2BuiltinTemplateUpdates(configPath, updates)",
            reconciliation,
        )
        self.assertIn(
            "ReconcileSchema2BuiltinTemplateDefaults(configPath)", bootstrap
        )

    def test_builtin_upgrade_is_exact_transactional_and_preserves_custom_text(
        self,
    ) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        update = reconciliation.split(
            "ApplySchema2BuiltinTemplateUpdates(configPath, updates) {", 1
        )[1].split("\n}\n\nValidateSchema2BuiltinTemplateUpdates(", 1)[0]
        self.assertIn("CreateReportAssistantConfigBackup(configPath)", update)
        self.assertIn("FileCopy configPath, tempPath, true", update)
        self.assertIn("update.ExpectedEncodedText", update)
        self.assertIn("IniWrite(", update)
        self.assertIn("tempPath,", update)
        self.assertIn(
            "ValidateSchema2BuiltinTemplateUpdates(tempPath, updates)", update
        )
        self.assertIn("FileMove tempPath, configPath, true", update)
        self.assertIn("FileCopy backupPath, configPath, true", update)
        self.assertNotIn("Hotstring.custom-", reconciliation)

    def test_reconciliation_only_updates_missing_supported_defaults(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        find_missing = reconciliation.split(
            "FindMissingManagedConfigDefaults(configPath, managedDefaults) {", 1
        )[1].split("\n}\n\nApplyMissingManagedConfigDefaults(", 1)[0]
        self.assertIn("if value = MissingValue", find_missing)
        self.assertIn("missingDefaults.Push(definition)", find_missing)
        self.assertNotIn("IniWrite", find_missing)
        self.assertIn(
            "schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)",
            reconciliation,
        )

    def test_duplicate_managed_keys_abort_before_any_update(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        body = reconciliation.split(
            "ReconcileManagedConfigDefaults(configPath, managedDefaults) {", 1
        )[1].split("\n}\n\nHasUniqueManagedConfigDefaults(", 1)[0]
        self.assertIn("if !HasUniqueManagedConfigDefaults(managedDefaults)", body)
        self.assertIn("return false", body)
        uniqueness = reconciliation.split(
            "HasUniqueManagedConfigDefaults(managedDefaults) {", 1
        )[1].split("\n}\n\nManagedConfigEntryId(", 1)[0]
        self.assertIn("seenKeys.Has(keyId)", uniqueness)

    def test_backup_precedes_writes_and_update_targets_only_temp_copy(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        update = reconciliation.split(
            "ApplyMissingManagedConfigDefaults(configPath, missingDefaults) {", 1
        )[1].split("\n}\n\nCreateReportAssistantConfigBackup(", 1)[0]
        self.assertIn('tempPath := configPath ".update.tmp.ini"', update)
        self.assertLess(
            update.index("CreateReportAssistantConfigBackup(configPath)"),
            update.index("FileCopy configPath, tempPath, true"),
        )
        self.assertIn("IniWrite(", update)
        self.assertIn("tempPath,", update)
        self.assertNotIn("IniWrite(configPath", update)
        self.assertLess(
            update.index("ValidateManagedConfigUpdate(tempPath"),
            update.index("FileMove tempPath, configPath, true"),
        )

    def test_backup_is_unique_and_is_not_pruned(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        backup = reconciliation.split(
            "CreateReportAssistantConfigBackup(configPath) {", 1
        )[1].split("\n}\n\nValidateManagedConfigUpdate(", 1)[0]
        self.assertIn('backupDirectory := configDirectory "\\backups"', backup)
        self.assertIn('FormatTime(A_Now, "yyyyMMdd-HHmmss")', backup)
        self.assertIn("if FileExist(backupPath)\n            continue", backup)
        self.assertIn("FileCopy configPath, backupPath, false", backup)
        self.assertNotIn("FileDelete backupPath", reconciliation)

    def test_failures_leave_the_original_as_the_runtime_source(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        bootstrap = source("src/config_bootstrap.ahk")
        prepare = bootstrap.split(
            'PrepareReportAssistantConfig(managedDefaults, configPath := "") {', 1
        )[1].split("\n}\n\nglobal ReportAssistantConfigStartupResult", 1)[0]
        self.assertIn("MigrateReportAssistantConfigV1ToV2(configPath)", prepare)
        self.assertIn("ReconcileManagedConfigDefaults(configPath, managedDefaults)", prepare)
        self.assertIn('"CONFIG_RECONCILIATION_FAILED"', prepare)
        update = reconciliation.split(
            "ApplyMissingManagedConfigDefaults(configPath, missingDefaults) {", 1
        )[1].split("\n}\n\nCreateReportAssistantConfigBackup(", 1)[0]
        catch = update.split("} catch {", 1)[1]
        self.assertIn("try FileDelete tempPath", catch)
        self.assertIn("return false", catch)
        self.assertNotIn("FileDelete configPath", reconciliation)

    def test_validation_distinguishes_a_missing_key_from_an_empty_default(self) -> None:
        reconciliation = source("src/config_reconciliation.ahk")
        validation = reconciliation.split(
            "ValidateManagedConfigUpdate(configPath, updatedDefaults) {", 1
        )[1]
        self.assertIn("static MissingValue :=", validation)
        self.assertIn("definition.Key,\n            MissingValue", validation)
        self.assertIn("if value != definition.DefaultValue", validation)


if __name__ == "__main__":
    unittest.main()
