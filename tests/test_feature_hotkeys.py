#!/usr/bin/env python3
"""Structural regression tests for optional non-hotstring features."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class FeatureHotkeyTests(unittest.TestCase):
    def test_feature_pipeline_has_explicit_layer_boundaries(self) -> None:
        main = source("src/main.ahk")
        expected = (
            "feature_model.ahk",
            "feature_config.ahk",
            "feature_normalization.ahk",
            "hotkey_registration.ahk",
            "global_hjkl_arrows.ahk",
            "features.ahk",
        )
        positions = [main.index(f"#Include {name}") for name in expected]
        self.assertEqual(positions, sorted(positions))

        config = source("src/feature_config.ahk")
        normalization = source("src/feature_normalization.ahk")
        registration = source("src/hotkey_registration.ahk")
        execution = source("src/global_hjkl_arrows.ahk")
        self.assertNotIn("IniRead", normalization + registration + execution)
        self.assertNotIn("Hotkey(", config + normalization + execution)
        self.assertNotIn("SendInput", config + normalization + registration)

    def test_default_config_contains_disabled_global_hjkl_arrows(self) -> None:
        model = source("src/feature_model.ahk")
        config = source("src/hotstring_config.ahk")
        self.assertIn('static Section := "Features"', model)
        self.assertIn('static GlobalHjklArrowsKey := "GlobalHjklArrows"', model)
        self.assertIn('static GlobalHjklArrowsDefault := "false"', model)
        self.assertIn(
            'FeatureDefaults.GlobalHjklArrowsKey "=" FeatureDefaults.GlobalHjklArrowsDefault',
            config,
        )
        self.assertNotIn("IniWrite", source("src/feature_config.ahk"))

    def test_config_path_is_one_ahk_statement_in_source_and_release(self) -> None:
        expected = (
            'return localAppData "\\" ReportAssistantConfigDefaults.DirectoryName '
            '"\\" ReportAssistantConfigDefaults.FileName'
        )
        self.assertIn(expected, source("src/app_config.ahk"))
        self.assertIn(expected, source("release/report_assistant.ahk"))
        self.assertNotIn(
            'ReportAssistantConfigDefaults.DirectoryName\n',
            source("src/app_config.ahk"),
        )

    def test_missing_invalid_or_unsupported_feature_config_fails_closed(self) -> None:
        config = source("src/feature_config.ahk")
        normalization = source("src/feature_normalization.ahk")
        self.assertIn("if !FileExist(configPath)\n        return defaults", config)
        self.assertIn(
            "schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)",
            config,
        )
        self.assertIn("} catch {\n        return defaults", config)
        parser = normalization.split("ParseOptionalFeatureEnabled(value)", 1)[1]
        self.assertIn('return normalized = "true"', parser)
        self.assertNotIn('normalized = "false"', parser)

    def test_global_hjkl_arrows_register_only_when_enabled(self) -> None:
        bootstrap = source("src/features.ahk")
        self.assertEqual(bootstrap.count("LoadFeatureSettings()"), 1)
        self.assertIn("if settings.GlobalHjklArrows", bootstrap)
        self.assertLess(
            bootstrap.index("if settings.GlobalHjklArrows"),
            bootstrap.index("RegisterHotkeyDefinitions("),
        )

    def test_global_hjkl_arrows_preserve_legacy_global_mappings(self) -> None:
        navigation = source("src/global_hjkl_arrows.ahk")
        expected = {
            '"RAlt & h"': 'Bind("Left")',
            '"RAlt & j"': 'Bind("Down")',
            '"RAlt & k"': 'Bind("Up")',
            '"RAlt & l"': 'Bind("Right")',
        }
        for chord, handler in expected.items():
            self.assertEqual(navigation.count(chord), 1)
            self.assertIn(handler, navigation)
        self.assertIn('SendInput("{" direction "}")', navigation)
        self.assertNotIn("HotIf", navigation)
        self.assertNotIn("MedEx", navigation)
        self.assertNotIn('"~RAlt', navigation)
        self.assertNotIn('"*RAlt', navigation)

    def test_hotkey_registry_isolates_errors_and_reserves_emergency_controls(self) -> None:
        registration = source("src/hotkey_registration.ahk")
        loop = registration.split("for definition in definitions", 1)[1].split(
            "return registeredIds", 1
        )[0]
        self.assertIn("seenChords.Has(chordKey)", loop)
        self.assertIn("try {\n            Hotkey(", loop)
        self.assertLess(loop.index("Hotkey("), loop.index("seenChords[chordKey] := true"))
        self.assertIn('return ["^!Esc", "^!q"]', registration)

    def test_release_order_keeps_optional_hotkeys_before_suspend_exempt_controls(self) -> None:
        build = source("scripts/build_release.py")
        release = source("release/report_assistant.ahk")
        self.assertIn('"global_hjkl_arrows.ahk"', build)
        self.assertIn('"features.ahk"', build)
        feature_start = release.index("RegisterConfiguredFeatures(LoadFeatureSettings())")
        suspend_exempt = release.index("#SuspendExempt", feature_start)
        self.assertLess(feature_start, suspend_exempt)


if __name__ == "__main__":
    unittest.main()
