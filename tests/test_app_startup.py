#!/usr/bin/env python3
"""Static policy checks for portable startup and cross-version singleton logic."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class AppStartupPolicyTests(unittest.TestCase):
    def test_config_path_helper_is_side_effect_free(self) -> None:
        app_config = source("src/app_config.ahk")
        path_body = app_config.split("static Path() {", 1)[1].split("\n    }", 1)[0]
        self.assertIn('EnvGet("LOCALAPPDATA")', path_body)
        for forbidden in (
            "FileAppend",
            "FileCopy",
            "FileDelete",
            "FileMove",
            "IniRead",
            "IniWrite",
            "DirCreate",
        ):
            self.assertNotIn(forbidden, path_body)

    def test_singleton_runs_before_any_config_initialization(self) -> None:
        main = source("src/main.ahk")
        metadata = main.index("#Include app_metadata.ahk")
        path_helper = main.index("#Include app_config.ahk")
        startup = main.index("#Include app_startup.ahk")
        example = main.index("#Include config.example.ahk")
        bootstrap = main.index("#Include config_bootstrap.ahk")
        self.assertLess(metadata, path_helper)
        self.assertLess(path_helper, startup)
        self.assertLess(startup, example)
        self.assertLess(startup, bootstrap)

    def test_singleton_uses_stable_named_mutex_without_ownership(self) -> None:
        startup = source("src/app_startup.ahk")
        self.assertIn('static MutexName := "Local\\MedExReportAssistant.Singleton"', startup)
        self.assertIn('"CreateMutexW"', startup)
        self.assertIn('"Int", false', startup)
        self.assertIn("createError := A_LastError", startup)
        self.assertIn("ErrorAlreadyExists := 183", startup)
        self.assertNotIn("ReleaseMutex", startup)
        self.assertNotIn("WaitForSingleObject", startup)

    def test_mutex_decision_precedes_path_resolution_and_logging(self) -> None:
        startup = source("src/app_startup.ahk")
        runtime = startup.split("StartReportAssistantRuntime() {", 1)[1].split(
            "\n}\n\nCloseReportAssistantSingleton", 1
        )[0]
        self.assertLess(runtime.index('"CreateMutexW"'), runtime.index("A_LastError"))
        self.assertLess(
            runtime.index("A_LastError"),
            runtime.index("WriteReportAssistantStartupDiagnostic"),
        )
        self.assertNotIn("PrepareReportAssistantConfig", startup)
        self.assertNotIn("IniRead", startup)
        self.assertNotIn("IniWrite", startup)

    def test_mutex_handles_are_closed_on_conflict_and_normal_exit(self) -> None:
        startup = source("src/app_startup.ahk")
        self.assertIn('DllCall("CloseHandle", "Ptr", handle)', startup)
        self.assertIn("OnExit CloseReportAssistantSingleton", startup)
        self.assertIn(
            'DllCall("CloseHandle", "Ptr", REPORT_ASSISTANT_SINGLETON_HANDLE)',
            startup,
        )

    def test_conflict_message_and_required_startup_fields_are_present(self) -> None:
        startup = source("src/app_startup.ahk")
        self.assertIn("MedEx Report Assistant 已在运行。", startup)
        self.assertIn("请先通过系统托盘退出当前版本，再启动此版本。", startup)
        for field in (
            "AppVersion=",
            "SourceRevision=",
            "ExecutablePath=",
            "ConfigPath=",
        ):
            self.assertIn(field, startup)

    def test_portable_startup_has_no_install_or_exe_management_calls(self) -> None:
        startup = source("src/app_startup.ahk")
        for forbidden in (
            "RegWrite",
            "FileCopy",
            "FileMove",
            "FileDelete",
            "ProcessClose",
            "RunWait",
            "Shutdown",
        ):
            self.assertNotIn(forbidden, startup)


if __name__ == "__main__":
    unittest.main()
