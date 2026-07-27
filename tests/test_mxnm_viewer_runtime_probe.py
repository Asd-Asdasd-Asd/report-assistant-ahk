#!/usr/bin/env python3
"""Structural checks for the read-only adaptive Viewer checkpoint."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MxNMViewerRuntimeProbeTests(unittest.TestCase):
    def test_probe_is_read_only_and_bounded_to_vendor_root(self) -> None:
        probe = source("src/mxnm_viewer_runtime_probe.ahk")
        self.assertIn('static ProfileRootName := "MultNMSoftInfo"', probe)
        self.assertIn('static MainConfigPattern := "MxNMSoft*.ini"', probe)
        self.assertIn('Loop Files profileRoot "\\*"', probe)
        self.assertNotIn('"R"', probe)
        self.assertIn("MxNMConfigPathInsideRoot", probe)
        for forbidden in (
            "PostMessage",
            "SendMessage",
            "MouseMove",
            "Click(",
            "ControlClick",
            "A_Clipboard",
            "IniWrite",
            "FileAppend",
            "FileDelete",
            "FileMove",
        ):
            self.assertNotIn(forbidden, probe)

    def test_probe_collects_profile_and_resolution_evidence(self) -> None:
        probe = source("src/mxnm_viewer_runtime_probe.ahk")
        self.assertIn("AuditMxNMVendorProfiles", probe)
        self.assertIn("ReadMxNMVendorDisplayHints", probe)
        self.assertIn("MxNMVendorSafeDisplayHintValue", probe)
        self.assertIn("<numeric-tokens:", probe)
        for keyword in (
            "Resolution",
            "Screen",
            "Display",
            "Monitor",
            "Profile",
            "Dpi",
            "Scale",
        ):
            self.assertIn(keyword, probe)
        self.assertIn("mainConfigSha256", probe)
        self.assertIn("layoutConfigSha256", probe)
        self.assertIn("ParseMxNMSCBtnPadCommands", probe)

    def test_probe_collects_native_hierarchy_without_window_text(self) -> None:
        probe = source("src/mxnm_viewer_runtime_probe.ahk")
        self.assertIn('"User32\\WindowFromPoint"', probe)
        self.assertIn('"User32\\GetParent"', probe)
        self.assertIn('"User32\\GetAncestor"', probe)
        self.assertIn('"User32\\EnumChildWindows"', probe)
        self.assertIn('"User32\\GetDlgCtrlID"', probe)
        self.assertIn('"User32\\GetClassNameW"', probe)
        self.assertIn('"User32\\GetWindowRect"', probe)
        for forbidden in (
            "WinGetTitle",
            "ControlGetText",
            "UIA.",
        ):
            self.assertNotIn(forbidden, probe)

    def test_field_harness_requires_explicit_manual_point_capture(self) -> None:
        harness = source(
            "tests/windows/mxnm_viewer_adaptive_checkpoint1.ahk"
        )
        self.assertIn("^!F6::BeginMxNMAdaptiveCheckpoint1()", harness)
        self.assertIn("^!F7::CaptureMxNMAdaptiveManualPoint()", harness)
        self.assertIn(
            "#Include ..\\..\\src\\mxnm_config_path_cache.ahk",
            harness,
        )
        self.assertIn('["arrow", "length", "suv3d", "image"]', harness)
        self.assertIn("InteractionMode=READ_ONLY", harness)
        self.assertIn("CheckpointVersion=", harness)
        self.assertIn("AutomaticForegroundUnchanged=", harness)
        self.assertIn("AutomaticMouseUnchanged=", harness)
        self.assertIn("ManualCaptureComplete=true", harness)
        self.assertIn(
            r'A_Temp "\MedExAHK\mxnm_viewer_adaptive_checkpoint1.txt"',
            harness,
        )
        for forbidden in (
            ".Invoke(",
            "PrepareMxNMContextCommand(",
            "PostMessage",
            "SendMessage",
            "MouseMove",
            "Click(",
            "A_Clipboard",
        ):
            self.assertNotIn(forbidden, harness)

    def test_field_output_omits_absolute_vendor_paths_and_window_text(
        self,
    ) -> None:
        harness = source(
            "tests/windows/mxnm_viewer_adaptive_checkpoint1.ahk"
        )
        for forbidden in (
            "ViewerProcessPath=",
            "ViewerDirectory=",
            "MainConfigPath=",
            "LayoutConfigPath=",
            "WinGetTitle",
            "ControlGetText",
        ):
            self.assertNotIn(forbidden, harness)


if __name__ == "__main__":
    unittest.main()
