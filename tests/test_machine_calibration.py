#!/usr/bin/env python3
"""Structural regression tests for lightweight MedEx machine calibration."""

from __future__ import annotations

import unittest
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MachineCalibrationTests(unittest.TestCase):
    def test_machine_profile_is_separate_from_user_config(self) -> None:
        profile = source("src/machine_profile.ahk")
        self.assertIn('static FileName := "machine-profile.ini"', profile)
        self.assertIn('static SchemaVersion := 1', profile)
        self.assertIn('static Status := "validated"', profile)
        self.assertIn('configDirectory "\\" MedExMachineProfileDefaults.FileName', profile)
        self.assertNotIn('ReportAssistantConfigDefaults.FileName :=', profile)

    def test_profile_write_is_temp_validated_and_backup_safe(self) -> None:
        profile = source("src/machine_profile.ahk")
        save = profile.split("SaveValidatedMedExMachineProfile(", 1)[1].split(
            "\n\nBackupMedExMachineProfile", 1
        )[0]
        self.assertIn('tempPath := profilePath ".write.tmp.ini"', save)
        self.assertIn("LoadValidatedMedExMachineProfile(tempPath)", save)
        self.assertIn("BackupMedExMachineProfile(profilePath)", save)
        self.assertIn("FileMove tempPath, profilePath, true", save)

    def test_normal_path_is_two_press_with_uia_black_fallback(self) -> None:
        calibration = source("src/medex_calibration.ahk")
        self.assertIn('static WAIT_ARROW := "WaitArrow"', calibration)
        self.assertIn('static WAIT_BLACK := "WaitBlack"', calibration)
        capture = calibration.split("CaptureMedExCalibrationArrow()", 1)[1].split(
            "\n\nCaptureMedExCalibrationBlack()", 1
        )[0]
        self.assertIn("WaitForMedExColorMenu(", capture)
        self.assertIn("blackItem.BoundingRectangle", capture)
        self.assertIn('TryCompleteMedExCalibration(blackPoint, "uia")', capture)
        self.assertIn("MedExCalibrationStage.WAIT_BLACK", capture)

    def test_multiline_calibration_messages_use_explicit_concatenation(self) -> None:
        calibration = source("src/medex_calibration.ahk")
        self.assertIn('completionMessage := "校准完成`n此电脑已启用红字恢复。', calibration)
        self.assertIn('Chr(59) "red 进行测试。', calibration)
        self.assertNotIn(';red', calibration)

    def test_catch_assignments_use_ahk_v2_blocks(self) -> None:
        calibration = source("src/medex_calibration.ahk")
        self.assertIsNone(re.search(r"(?m)^\s*catch\s+\w+\s*:=", calibration))
        self.assertIn("catch {\n            blackRect := 0\n        }", calibration)

    def test_calibration_validates_production_signature_and_click(self) -> None:
        calibration = source("src/medex_calibration.ahk")
        completion = calibration.split("TryCompleteMedExCalibration(blackPoint, source)", 1)[1].split(
            "\n\nCancelMedExCalibration", 1
        )[0]
        signature = completion.index("SampleAndEvaluateCandidateGPopupSignature")
        black_click = completion.index('Click blackPoint["x"], blackPoint["y"]')
        save = completion.index("SaveValidatedMedExMachineProfile(profile)")
        self.assertLess(signature, black_click)
        self.assertLess(black_click, save)
        self.assertIn('if closedSignature["matched"]', completion)

    def test_red_reset_preflight_runs_before_any_text(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        body = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1].split(
            "\n}\n\nSendConfiguredReportText", 1
        )[0]
        self.assertLess(body.index("PrepareMedExRedReset()"), body.index("SendConfiguredReportText"))
        self.assertIn("if !resetReadiness.ok\n            return false", body)
        self.assertIn("RunRedResetInsertion(entry.RedText, resetReadiness.options)", body)

    def test_calibration_hotkeys_are_suspendable_and_escape_is_scoped(self) -> None:
        main = source("src/main.ahk")
        suspendable = main.split("#SuspendExempt False", 1)[1]
        self.assertIn("^!F8::AdvanceMedExCalibration()", suspendable)
        self.assertIn("#HotIf MedExCalibrationActive()", suspendable)
        self.assertIn("Esc::CancelMedExCalibration()", suspendable)
        self.assertIn("#HotIf\n", suspendable)

    def test_machine_profile_relaxes_resolution_only(self) -> None:
        logic = source("src/medex_candidate_g_logic.ahk")
        runtime = logic.split("ValidateCandidateGRuntimeProfile(environment, options := 0)", 1)[1].split(
            "\n\nCandidateGPopupSignatureSample", 1
        )[0]
        self.assertIn('expected.Delete("screenWidth")', runtime)
        self.assertIn('expected.Delete("screenHeight")', runtime)
        self.assertNotIn('expected.Delete("dpi")', runtime)
        self.assertNotIn('expected.Delete("displayScaling")', runtime)

    def test_release_builder_keeps_dependency_order(self) -> None:
        build = source("scripts/build_release.py")
        order = [
            build.index('"medex_candidate_g_logic.ahk"'),
            build.index('"machine_profile.ahk"'),
            build.index('"adapters/medex_report_editor.ahk"'),
            build.index('"medex_calibration.ahk"'),
            build.index('"hotstrings.ahk"'),
            build.index('"main.ahk"'),
        ]
        self.assertEqual(order, sorted(order))


if __name__ == "__main__":
    unittest.main()
