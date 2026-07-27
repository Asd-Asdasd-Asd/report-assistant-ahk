#!/usr/bin/env python3
"""Tests for the generated single-file Viewer checkpoint harness."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.build_mxnm_viewer_adaptive_checkpoint import (
    COMPONENTS,
    DIRECTIVES,
    OUTPUT,
    build_checkpoint_text,
    viewer_tool_probe_subset,
)


ROOT = Path(__file__).resolve().parents[1]


class MxNMViewerCheckpointBuildTests(unittest.TestCase):
    def test_generated_checkpoint_matches_sources(self) -> None:
        self.assertEqual(
            OUTPUT.read_text(encoding="utf-8"),
            build_checkpoint_text(),
        )

    def test_generated_checkpoint_is_single_file_and_read_only(self) -> None:
        generated = OUTPUT.read_text(encoding="utf-8")
        self.assertNotIn("#Include", generated)
        self.assertIn("InteractionMode=READ_ONLY", generated)
        self.assertIn('MXNM_ADAPTIVE_CHECKPOINT_VERSION := "1.1"', generated)
        self.assertIn("CheckpointVersion=", generated)
        for directive in DIRECTIVES:
            self.assertEqual(generated.count(directive), 1)
        for forbidden in (
            "PrepareMxNMContextCommand(",
            ".Invoke(",
            '"User32\\PostMessageW"',
            '"User32\\SendMessageW"',
            '"User32\\SendMessageTimeoutW"',
            "MouseMove",
            "Click(",
            "A_Clipboard",
        ):
            self.assertNotIn(forbidden, generated)

    def test_tool_subset_keeps_model_but_removes_dispatch(self) -> None:
        source = (
            ROOT / "src" / "mxnm_viewer_tool_commands.ahk"
        ).read_text(encoding="utf-8")
        subset = viewer_tool_probe_subset(source)
        self.assertIn("class MxNMViewerToolCommand", subset)
        self.assertIn("BuildMxNMViewerToolCommandPlan", subset)
        self.assertIn("ParseMxNMSCBtnPadCommands", subset)
        self.assertIn("MapMxNMViewerToolPointToRuntimeFrame", subset)
        self.assertNotIn("MxNMViewerToolCommandProvider", subset)
        self.assertNotIn("DispatchMxNMViewerToolButton", subset)
        self.assertNotIn("SendMessage", subset)

    def test_builder_fails_when_a_component_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first_component = COMPONENTS[0]
            first_path = root / first_component
            first_path.parent.mkdir(parents=True)
            first_path.write_text("; fixture\n", encoding="utf-8")
            with self.assertRaises(FileNotFoundError):
                build_checkpoint_text(root)

    def test_generated_checkpoint_has_no_bom(self) -> None:
        raw = OUTPUT.read_bytes()
        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        self.assertNotIn("\ufeff", raw.decode("utf-8"))


if __name__ == "__main__":
    unittest.main()
