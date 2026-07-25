#!/usr/bin/env python3
"""Static and fixture checks for the config-first MxNM geometry audit."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def audit_entries(config_text: str, source_name: str) -> list[tuple[str, str, str]]:
    entries: list[tuple[str, str, str]] = []
    section = ""
    numeric = re.compile(
        r"^-?\d+(?:\.\d+)?(?:\s*,\s*-?\d+(?:\.\d+)?)*$"
    )
    for raw_line in config_text.splitlines():
        line = raw_line.strip()
        section_match = re.fullmatch(r"\[([^\]]+)\]", line)
        if section_match:
            section = section_match.group(1)
            continue
        if not line or line[0] in ";#" or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if source_name == "MxNMSoft":
            allowed = section.lower() == "showsetting" and re.fullmatch(
                r"(?:FramePos[XY]|Frame(?:Width|Height)|"
                r"ShowImagePos[XY]|ShowImage(?:Width|Height))",
                key,
                re.IGNORECASE,
            )
        else:
            allowed = re.fullmatch(
                r"(?:ShowModel|LowWnd)[A-Za-z0-9_]*",
                key,
                re.IGNORECASE,
            )
        if allowed and numeric.fullmatch(value):
            entries.append((section, key, re.sub(r"\s+", "", value)))
    return entries


class MxNMConfigGeometryTests(unittest.TestCase):
    def test_runtime_paths_are_relative_to_the_viewer_executable(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        self.assertIn('static RelativeConfigDirectory := "MultNMSoftInfo\\1"', provider)
        self.assertIn('static MainConfigFileName := "MxNMSoft.ini"', provider)
        self.assertIn('static LayoutConfigFileName := "MxPetCtTemp.ini"', provider)
        self.assertIn("WinGetProcessPath", provider)
        self.assertIn("NormalizeMxNMConfigPath", provider)
        self.assertIn("MxNMConfigPathInsideRoot", provider)
        self.assertNotIn(r"C:\MedEx", provider)
        self.assertNotIn("Loop Files", provider)

    def test_provider_is_read_only_and_does_not_use_uia(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        for forbidden in (
            "IniWrite",
            "FileAppend",
            "FileDelete",
            "FileMove",
            "FileCopy",
            "UIA.",
            "MouseMove",
            "Click(",
            "A_Clipboard",
        ):
            self.assertNotIn(forbidden, provider)
        self.assertIn("ComputeMxNMConfigSha256", provider)
        self.assertIn('"Bcrypt\\BCryptHashData"', provider)

    def test_geometry_audit_filters_main_config_to_numeric_whitelist(self) -> None:
        fixture = """
        [ShowSetting]
        FramePosX=10
        FramePosY=20
        FrameWidth=1100
        FrameHeight=1000
        ShowImagePosX=340
        ShowImagePosY=56
        ShowImageWidth=750
        ShowImageHeight=940
        StudyListPos=1,2,3,4
        PatientName=123
        ShowImagePosText=not-numeric
        [Other]
        FramePosLeft=99
        """
        self.assertEqual(
            audit_entries(fixture, "MxNMSoft"),
            [
                ("ShowSetting", "FramePosX", "10"),
                ("ShowSetting", "FramePosY", "20"),
                ("ShowSetting", "FrameWidth", "1100"),
                ("ShowSetting", "FrameHeight", "1000"),
                ("ShowSetting", "ShowImagePosX", "340"),
                ("ShowSetting", "ShowImagePosY", "56"),
                ("ShowSetting", "ShowImageWidth", "750"),
                ("ShowSetting", "ShowImageHeight", "940"),
            ],
        )

    def test_geometry_audit_filters_layout_config_to_numeric_whitelist(self) -> None:
        fixture = """
        [ShowModel3]
        LowWndLeft_0=10
        LowWndTop_0=20
        LowWndImageType_0=5
        Description=123
        [Runtime]
        ShowModelCurrent=3
        Secret=456
        """
        self.assertEqual(
            audit_entries(fixture, "MxPetCtTemp"),
            [
                ("ShowModel3", "LowWndLeft_0", "10"),
                ("ShowModel3", "LowWndTop_0", "20"),
                ("ShowModel3", "LowWndImageType_0", "5"),
                ("Runtime", "ShowModelCurrent", "3"),
            ],
        )

    def test_field_audit_output_omits_absolute_paths_and_raw_config(self) -> None:
        harness = source("tests/windows/mxnm_config_geometry_audit.ahk")
        self.assertIn(
            r'A_Temp "\MedExAHK\mxnm_config_geometry_audit.txt"',
            harness,
        )
        self.assertIn("MxNMSoftSha256=", harness)
        self.assertIn("MxPetCtTempSha256=", harness)
        self.assertIn("GeometryEntry=", harness)
        self.assertIn("ViewerWindow=", harness)
        self.assertIn("ShowImageSizeResolved=", harness)
        for forbidden in (
            '"ViewerProcessPath="',
            '"ViewerDirectory="',
            '"MainConfigPath="',
            '"LayoutConfigPath="',
            "FileRead",
            "A_Clipboard",
            "SoundBeep",
            "UIA.",
            "CoordinateCandidate=",
            "ShowMxNMCoordinateCandidateMarkers",
        ):
            self.assertNotIn(forbidden, harness)

    def test_runtime_geometry_records_window_and_client_rectangles(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        self.assertIn("GetClientRect", provider)
        self.assertIn("ClientToScreen", provider)
        self.assertIn("ResolveMxNMRuntimeFrame", provider)
        self.assertNotIn("MouseMove", provider)
        self.assertNotIn("Click(", provider)

    def test_main_geometry_parses_complete_show_image_rectangle(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        for key in (
            "ShowImagePosX",
            "ShowImagePosY",
            "ShowImageWidth",
            "ShowImageHeight",
        ):
            self.assertIn(f'"{key}"', provider)
        self.assertIn("imageSizeResolved", provider)
        self.assertIn("frameSizeResolved", provider)

    def test_runtime_mapping_uses_unique_containing_frame_and_axis_scaling(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        self.assertIn("ResolveMxNMRuntimeFrame", provider)
        self.assertIn("MxNMRuntimeWindowContains", provider)
        self.assertIn("MapMxNMLogicalImageRectToRuntime", provider)
        self.assertIn("/ mainGeometry.frameWidth", provider)
        self.assertIn("/ mainGeometry.frameHeight", provider)
        self.assertNotIn("CountMxNMFrameMatchedWindows", provider)
        self.assertNotIn("frameMatchedWindowCount", provider)

    def test_measurement_target_resolution_is_config_only(self) -> None:
        resolver = source("src/mxnm_measurement_target_resolver.ahk")
        self.assertIn("BuildMxNMMeasurementTargetPlan", resolver)
        self.assertIn("MapMxNMLogicalPointToRuntimeRect", resolver)
        self.assertIn("CaptureMxNMViewerWindowGeometry", resolver)
        self.assertIn("ResolveMxNMRuntimeFrame", resolver)
        self.assertIn("ResolveMxNMActionWindowFromPoint", resolver)
        for forbidden in (
            "UIA.",
            "FindElements",
            "BoundingRectangle",
            "ResolveMxNMUiaImageRegion",
            "UIA_IMAGE_REGION",
            ".Name",
            "CachedName",
            "A_Clipboard",
            "MouseMove",
            "Click(",
            "SoundBeep",
            "WinActivate",
        ):
            self.assertNotIn(forbidden, resolver)

    def test_static_plan_loading_does_not_enumerate_runtime_windows(self) -> None:
        provider = source("src/mxnm_config_geometry_provider.ahk")
        static_loader = provider.split(
            "LoadMxNMStaticConfigGeometry(viewerExe, configPaths) {", 1
        )[1].split("\n\nMakeMxNMConfigGeometryResult", 1)[0]
        self.assertIn("ComputeMxNMConfigSha256", static_loader)
        self.assertIn("ReadMxNMGeometryAuditEntries", static_loader)
        for forbidden in (
            "WinGetList",
            "WinGetProcessPath",
            "CaptureMxNMViewerWindowGeometry",
            "ResolveMxNMRuntimeFrame",
        ):
            self.assertNotIn(forbidden, static_loader)

    def test_path_cache_persists_only_validated_viewer_identity(self) -> None:
        cache = source("src/mxnm_config_path_cache.ahk")
        for required in (
            'static FileName := "mxnm-config-path-cache.ini"',
            "ResolveMxNMConfigPathsFromProcessPath(",
            '"ViewerExe"',
            '"ViewerProcessPath"',
            "LoadValidatedMxNMConfigPathCache(tempPath)",
        ):
            self.assertIn(required, cache)
        for forbidden in (
            "WinGetList",
            "WinGetProcessPath",
            "MainConfigPath",
            "LayoutConfigPath",
            "UIA.",
        ):
            self.assertNotIn(forbidden, cache)


if __name__ == "__main__":
    unittest.main()
