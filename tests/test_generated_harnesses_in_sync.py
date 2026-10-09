#!/usr/bin/env python3
"""Every tracked generated harness must equal its builder's current output."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

from scripts import (
    build_mxnm_context_menu_diagnostic,
    build_mxnm_montage_control_diagnostic,
    build_mxnm_montage_lung_field_test,
    build_mxnm_viewer_adaptive_checkpoint,
    build_readiness_regression,
    build_viewer_state_regression,
)


ROOT = Path(__file__).resolve().parents[1]
BUILDERS = {
    build_mxnm_context_menu_diagnostic.OUTPUT:
        build_mxnm_context_menu_diagnostic.build_diagnostic_text,
    build_mxnm_montage_control_diagnostic.OUTPUT:
        build_mxnm_montage_control_diagnostic.build_diagnostic_text,
    build_mxnm_montage_lung_field_test.OUTPUT:
        build_mxnm_montage_lung_field_test.build_field_test_text,
    build_mxnm_viewer_adaptive_checkpoint.OUTPUT:
        build_mxnm_viewer_adaptive_checkpoint.build_checkpoint_text,
    build_readiness_regression.OUTPUT: build_readiness_regression.build,
    build_viewer_state_regression.OUTPUT: build_viewer_state_regression.build,
}


class GeneratedHarnessSyncTests(unittest.TestCase):
    def test_tracked_generated_harnesses_match_their_builders(self) -> None:
        for output, build in BUILDERS.items():
            with self.subTest(output=output.name):
                self.assertTrue(output.is_file(), f"missing {output}")
                self.assertEqual(output.read_text(encoding="utf-8"), build())

    def test_every_builder_output_is_covered(self) -> None:
        tracked = subprocess.run(
            ["git", "ls-files", "tests/windows/generated"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.split()
        covered = {str(path.relative_to(ROOT)) for path in BUILDERS}
        self.assertEqual(set(tracked), covered)


if __name__ == "__main__":
    unittest.main()
