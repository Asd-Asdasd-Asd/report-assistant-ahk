#!/usr/bin/env python3
"""Structural regression tests for v0.6.0 measurement capture foundations."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def parse_suvmax_fixture(raw_text: str) -> tuple[str, str]:
    match = re.fullmatch(r"\s*SUVMax\s*:\s*(\d+(?:\.\d+)?)\s*", raw_text)
    if match is None:
        return ("AUTOMATION_FAILED", "")
    value = float(match.group(1))
    if value == 0:
        return ("NOT_ANNOTATED", "")
    return ("FOUND", f"{value:.1f}")


class MeasurementCaptureTests(unittest.TestCase):
    def test_result_contract_uses_state_as_the_canonical_outcome(self) -> None:
        model = source("src/measurement_model.ahk")
        for state in ("FOUND", "NOT_ANNOTATED", "AUTOMATION_FAILED"):
            self.assertIn(f'static {state} := "{state}"', model)
        for field in (
            "state",
            "success",
            "measurementType",
            "rawValue",
            "formattedValue",
            "source",
            "failureReason",
            "context",
            "components",
        ):
            self.assertIn(f"this.{field} :=", model)
        self.assertIn(
            "this.success := this.state = MeasurementState.FOUND", model
        )
        self.assertIn('static LINE_AXES := "line_axes"', model)
        self.assertIn("components.Clone()", model)

    def test_command_spec_defines_the_generic_provider_boundary(self) -> None:
        model = source("src/measurement_model.ahk")
        provider = source("src/context_measurement_provider.ahk")
        for required in (
            "class MeasurementCommandSpec",
            "this.measurementType := String(measurementType)",
            "this.commandText := String(commandText)",
            "this.parserCallback := parserCallback",
            "IsValidMeasurementCommandSpec(spec)",
            'static INVALID_MEASUREMENT_SPEC := "INVALID_MEASUREMENT_SPEC"',
        ):
            self.assertIn(required, model)
        for required in (
            "static ReadMeasurement(spec, options := 0)",
            "ReadCurrentMeasurementWithoutFocusSwitch(spec, options := 0)",
            "BuildSuvMaxMeasurementCommandSpec()",
            "return this.ReadMeasurement(BuildSuvMaxMeasurementCommandSpec(), options)",
        ):
            self.assertIn(required, provider)
        self.assertLess(
            provider.index("if !IsValidMeasurementCommandSpec(spec)"),
            provider.index("ResolveContextMeasurementViewer("),
        )

    def test_suvmax_parser_is_strict_and_formats_one_decimal(self) -> None:
        parser = source("src/measurement_parser.ahk")
        self.assertIn(r"^\s*SUVMax\s*:\s*(\d+(?:\.\d+)?)\s*$", parser)
        self.assertIn("if numericValue = 0", parser)
        self.assertIn("MeasurementState.NOT_ANNOTATED", parser)
        self.assertIn('Format("{:.1f}", numericValue)', parser)
        self.assertIn("MeasurementFailureReason.UNEXPECTED_FORMAT", parser)

        fixtures = {
            "SUVMax: 3.599": ("FOUND", "3.6"),
            "  SUVMax : 4  ": ("FOUND", "4.0"),
            "SUVMax: 0.000": ("NOT_ANNOTATED", ""),
            "SUVMax: -1": ("AUTOMATION_FAILED", ""),
            "suvmax: 3.2": ("AUTOMATION_FAILED", ""),
            "SUVMax: 3.2 old": ("AUTOMATION_FAILED", ""),
            "": ("AUTOMATION_FAILED", ""),
        }
        for raw_text, expected in fixtures.items():
            with self.subTest(raw_text=raw_text):
                self.assertEqual(parse_suvmax_fixture(raw_text), expected)

    def test_measurement_clipboard_transaction_has_one_restore_owner(self) -> None:
        transaction = source("src/measurement_clipboard.ahk")
        body = transaction.split(
            "CaptureMeasurementClipboardText(actionCallback, options := 0,", 1
        )[1].split("\n\nBuildMeasurementClipboardRequestId", 1)[0]
        self.assertIn("savedClipboard := ClipboardAll()", body)
        self.assertIn("__MEDEX_MEASUREMENT_", body)
        self.assertIn("GetMeasurementClipboardSequenceNumber()", body)
        self.assertIn("prepareCallback.Call()", body)
        self.assertIn("actionCallback.Call()", body)
        self.assertIn("WaitForMeasurementClipboardUpdate(", body)
        self.assertEqual(body.count("A_Clipboard := savedClipboard"), 1)
        self.assertLess(body.index("} finally {"), body.index("A_Clipboard := savedClipboard"))
        self.assertLess(
            body.index("prepareCallback.Call()"),
            body.index(
                "result.sequenceBeforeCommand := "
                "GetMeasurementClipboardSequenceNumber()"
            ),
        )
        self.assertLess(
            body.index(
                "result.sequenceBeforeCommand := "
                "GetMeasurementClipboardSequenceNumber()"
            ),
            body.index("actionCallback.Call()"),
        )
        self.assertNotIn("WithClipboardRestore(", transaction)

    def test_clipboard_freshness_requires_post_command_sequence_and_new_text(self) -> None:
        transaction = source("src/measurement_clipboard.ahk")
        wait = transaction.split(
            "WaitForMeasurementClipboardUpdate(", 1
        )[1]
        self.assertIn("sequence != sequenceBeforeCommand", wait)
        self.assertIn('rawText != "" && rawText != sentinel', wait)
        self.assertIn('"User32\\GetClipboardOwner"', transaction)
        self.assertIn("static busy := false", transaction)
        self.assertIn("MeasurementFailureReason.PROVIDER_BUSY", transaction)

    def test_provider_uses_background_messages_and_dynamic_runtime_identity(self) -> None:
        provider = source("src/context_measurement_provider.ahk")
        for required in (
            '"User32\\PostMessageW"',
            "0x0204",
            "0x0205",
            '"User32\\SendMessageW"',
            "0x0111",
            '"User32\\GetDlgCtrlID"',
            "WinGetControlsHwnd",
            "ControlGetText",
            "SnapshotContextMeasurementPopups",
            "PrepareContextMeasurementCopyCommand",
            "InvokePreparedContextMeasurementCommand",
        ):
            self.assertIn(required, provider)
        for forbidden in (
            "WinActivate",
            "WinWaitActive",
            "MouseMove",
            "MouseClick",
            "ControlClick",
            "Button10",
            "Button11",
        ):
            self.assertNotIn(forbidden, provider)

    def test_provider_parses_only_after_a_fresh_capture(self) -> None:
        provider = source("src/context_measurement_provider.ahk")
        capture_failure = provider.index("if !capture.ok")
        parser_call = provider.index(
            "spec.parserCallback.Call(capture.rawText)"
        )
        self.assertLess(capture_failure, parser_call)
        self.assertIn(
            "failureReason := actionContext[\"failureReason\"]", provider
        )
        self.assertIn(
            "result.measurementType != requestedMeasurementType", provider
        )
        self.assertNotIn('context["rawText"]', provider)
        self.assertNotIn('context["rawValue"]', provider)

    def test_provider_is_not_connected_to_production_hotstrings(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        self.assertNotIn("ContextMeasurementProvider", hotstrings)
        self.assertNotIn("ReadCurrentSuvMaxWithoutFocusSwitch", hotstrings)

    def test_geometry_is_owned_by_one_resolver_and_fails_closed(self) -> None:
        provider = source("src/context_measurement_provider.ahk")
        self.assertIn("ResolveContextMeasurementImagePoint(", provider)
        self.assertIn("ResolveContextMeasurementViewerFromPoint(", provider)
        self.assertIn('"User32\\WindowFromPoint"', provider)
        self.assertIn('"User32\\GetAncestor"', provider)
        self.assertIn("WinGetProcessName", provider)
        self.assertIn('"imagePointResolver"', provider)
        self.assertIn('"imageScreenPoint"', provider)
        self.assertIn('ImagePointKey := "measurement_image_point"', provider)
        self.assertIn(
            "MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE", provider
        )
        self.assertIn(
            "MeasurementFailureReason.IMAGE_POINT_OUT_OF_BOUNDS", provider
        )

    def test_release_builder_keeps_measurement_dependencies_ordered(self) -> None:
        build = source("scripts/build_release.py")
        ordered_components = (
            '"measurement_model.ahk"',
            '"measurement_parser.ahk"',
            '"measurement_clipboard.ahk"',
            '"context_measurement_provider.ahk"',
            '"hotstrings.ahk"',
        )
        positions = [build.index(component) for component in ordered_components]
        self.assertEqual(positions, sorted(positions))

    def test_generated_release_contains_measurement_foundation(self) -> None:
        release = source("release/report_assistant.ahk")
        for component in (
            "measurement_model.ahk",
            "measurement_parser.ahk",
            "measurement_clipboard.ahk",
            "context_measurement_provider.ahk",
        ):
            self.assertIn(f"; --- BEGIN {component} ---", release)
        for symbol in (
            "class MeasurementState",
            "ParseSuvMaxMeasurement(rawText)",
            "CaptureMeasurementClipboardText(actionCallback",
            "class ContextMeasurementProvider",
            "class MeasurementCommandSpec",
            "static ReadMeasurement(spec, options := 0)",
        ):
            self.assertIn(symbol, release)

    def test_windows_harness_uses_production_measurement_modules(self) -> None:
        harness = source("tests/windows/measurement_capture_regression.ahk")
        for include in (
            "measurement_model.ahk",
            "measurement_parser.ahk",
            "measurement_clipboard.ahk",
        ):
            self.assertIn(include, harness)
        self.assertIn("ParseSuvMaxMeasurement(", harness)
        self.assertIn("CaptureMeasurementClipboardText(", harness)

    def test_field_harness_is_non_focus_stealing_and_privacy_safe(self) -> None:
        harness = source("tests/windows/context_measurement_provider_field.ahk")
        self.assertIn("ContextMeasurementProvider.ReadSuvMax(", harness)
        self.assertIn('CoordMode "Mouse", "Screen"', harness)
        self.assertIn("MouseGetPos", harness)
        self.assertNotIn("MouseMove", harness)
        self.assertNotIn("WinActivate", harness)
        self.assertNotIn("WinWaitActive", harness)
        self.assertNotIn("result.rawValue", harness)
        self.assertNotIn("result.formattedValue", harness)
        self.assertNotIn("SoundBeep", harness)
        self.assertIn("ToolTip message", harness)
        self.assertIn(
            r'A_Temp "\MedExAHK\context_measurement_provider_field.txt"',
            harness,
        )

    def test_deleted_tag_names_are_absent_from_documentation(self) -> None:
        documentation = "\n".join(
            path.read_text(encoding="utf-8")
            for root in ("docs", "tests")
            for path in (ROOT / root).rglob("*.md")
        )
        self.assertNotIn("v0.6.0-candidate-g", documentation)
        self.assertNotIn("v0.5.0-color-reset-field-validated", documentation)


if __name__ == "__main__":
    unittest.main()
