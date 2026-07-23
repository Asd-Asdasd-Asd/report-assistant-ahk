#!/usr/bin/env python3
"""Static checks for the maintainer-only Windows EXE build workflow."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CMD = ROOT / "Build EXE.cmd"
POWERSHELL = ROOT / "scripts" / "build_exe.ps1"


def text(path: Path, encoding: str = "utf-8") -> str:
    return path.read_text(encoding=encoding)


class WindowsBuildWorkflowTests(unittest.TestCase):
    def test_cmd_resolves_root_and_propagates_exit_code(self) -> None:
        cmd = text(CMD)
        self.assertIn('set "REPOSITORY_ROOT=%~dp0"', cmd)
        self.assertIn("powershell.exe -NoProfile -ExecutionPolicy Bypass", cmd)
        self.assertIn('"%REPOSITORY_ROOT%scripts\\build_exe.ps1"', cmd)
        self.assertIn('set "BUILD_EXIT_CODE=%ERRORLEVEL%"', cmd)
        self.assertIn("pause", cmd)
        self.assertIn("exit /b %BUILD_EXIT_CODE%", cmd)

    def test_powershell_is_utf8_bom_for_windows_powershell_51(self) -> None:
        self.assertTrue(POWERSHELL.read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_tool_defaults_and_root_relative_paths_are_explicit(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        self.assertIn(
            "C:\\Program Files\\AutoHotkey\\Compiler\\Ahk2Exe.exe", script
        )
        self.assertIn(
            "C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe", script
        )
        self.assertIn("Split-Path -Parent $PSScriptRoot", script)
        self.assertIn("Join-Path $PSScriptRoot 'build_release.py'", script)
        self.assertIn("Join-Path $repositoryRoot 'release\\report_assistant.ahk'", script)
        self.assertIn(
            "Join-Path $repositoryRoot 'assets\\icon\\generated\\medex-icon.ico'",
            script,
        )
        self.assertIn("Join-Path $repositoryRoot 'assets\\publish'", script)
        self.assertIn("Join-Path $repositoryRoot 'publish'", script)

    def test_python_and_required_inputs_are_validated(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        for command in ("py.exe", "python.exe", "python3.exe"):
            self.assertIn(command, script)
        self.assertIn("--version", script)
        self.assertIn("Release generator was not found", script)
        self.assertIn("Ahk2Exe compiler was not found", script)
        self.assertIn("AutoHotkey v2 64-bit base executable was not found", script)
        self.assertIn("Application icon was not found", script)
        self.assertIn("Application icon is empty", script)
        self.assertIn("Generated release script", script)

    def test_ahk2exe_arguments_and_temporary_validation_are_present(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        for argument in (
            "'/in'",
            "'/out'",
            "'/base'",
            "'/icon'",
            "'/silent'",
            "'verbose'",
        ):
            self.assertIn(argument, script)
        self.assertIn("('\"{0}\"' -f $iconPath)", script)
        self.assertIn("Start-Process", script)
        self.assertIn("-Wait", script)
        self.assertIn("-PassThru", script)
        self.assertIn("-RedirectStandardOutput", script)
        self.assertIn("-RedirectStandardError", script)
        self.assertIn("$compilerExitCode = $compilerProcess.ExitCode", script)
        self.assertNotIn("& $CompilerPath @compilerArguments", script)
        self.assertIn("$item.Length -le 0", script)
        self.assertIn("$item.LastWriteTimeUtc", script)
        self.assertIn("麦旋风.building.exe", script)

    def test_temporary_cleanup_retries_and_reports_file_ownership(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        self.assertIn("[int]$Attempts = 5", script)
        self.assertIn("Start-Sleep -Milliseconds $RetryDelayMs", script)
        self.assertIn("Exit any running Ahk2Exe or MedEx Report Assistant", script)

    def test_assets_sync_after_validation_and_before_promotion(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        validate = script.index("$stage = 'validate temporary executable'")
        assets = script.index("$stage = 'synchronize static publish assets'")
        promotion = script.index("$stage = 'promote final executable'")
        self.assertLess(validate, assets)
        self.assertLess(assets, promotion)
        self.assertIn("Get-ChildItem -LiteralPath $SourceDirectory -Force -Recurse -File", script)
        self.assertIn("Copy-Item -LiteralPath $item.FullName", script)
        self.assertIn("Static asset source:", script)
        self.assertIn("Static asset destination:", script)
        self.assertIn("Static publish asset validation failed", script)
        self.assertIn("Synchronized $assetCount static publish asset(s).", script)
        self.assertNotIn("Get-ChildItem -LiteralPath $publishDirectory", script)

    def test_transaction_preserves_and_restores_last_known_good(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        self.assertIn("麦旋风.previous.exe", script)
        self.assertIn("Restore-InterruptedPromotion", script)
        self.assertIn("Restore-LastKnownGoodFinal", script)
        self.assertIn(
            "[System.IO.File]::Replace($buildingExe, $finalExe, $previousExe, $false)",
            script,
        )
        self.assertLess(
            script.index("[System.IO.File]::Replace"),
            script.index("$stage = 'validate final executable'"),
        )
        prerequisite_stage = script.index("$stage = 'validate build prerequisites'")
        promotion_stage = script.index("$stage = 'promote final executable'")
        self.assertNotIn(
            "Remove-ManagedFile -Path $finalExe",
            script[prerequisite_stage:promotion_stage],
        )

    def test_success_output_identifies_exact_artifact(self) -> None:
        script = text(POWERSHELL, "utf-8-sig")
        self.assertIn("$displayArtifactPath = 'publish\\麦旋风.exe'", script)
        self.assertIn("Write-Host 'Artifact:'", script)
        self.assertGreaterEqual(script.count("Write-Host '================================'"), 2)

    def test_build_scripts_do_not_duplicate_metadata_or_deploy(self) -> None:
        combined = text(CMD) + text(POWERSHELL, "utf-8-sig")
        for forbidden in (
            "AppVersion",
            "ProductVersion",
            "FileVersion",
            "SourceRevision",
            "CompanyName",
            "FileDescription",
            "LOCALAPPDATA",
            "RegWrite",
            "New-ItemProperty",
            "Stop-Process",
            "taskkill",
            "Compress-Archive",
            "git commit",
            "git tag",
        ):
            self.assertNotIn(forbidden, combined)

    def test_publish_is_ignored_and_assets_are_tracked_sources(self) -> None:
        gitignore = text(ROOT / ".gitignore")
        self.assertIn("/publish/", gitignore)
        self.assertTrue((ROOT / "assets" / "publish" / "首次使用.md").is_file())
        self.assertTrue((ROOT / "assets" / "publish" / "配置指南.md").is_file())
        self.assertTrue(
            (ROOT / "assets" / "icon" / "source" / "medex-icon.svg").is_file()
        )
        self.assertTrue(
            (
                ROOT
                / "assets"
                / "icon"
                / "generated"
                / "medex-icon.ico"
            ).is_file()
        )


if __name__ == "__main__":
    unittest.main()
