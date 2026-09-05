"""Keep the executable Windows behavior harness tied to production definitions."""
import unittest
from scripts.build_viewer_state_regression import ROOT, OUTPUT, build


class ViewerStateRegressionBuildTests(unittest.TestCase):
    def test_generated_harness_matches_production(self):
        self.assertEqual(OUTPUT.read_text(), build())

    def test_harness_is_isolated_from_production_startup_and_patient_data(self):
        text = build()
        for forbidden in ('RegisterConfiguredFeatures(', 'Send "{F12}"', 'A_Clipboard',
                          'FileRead(', 'IniRead(', 'MxNMAnnotationCleaner.DeleteAll('):
            self.assertNotIn(forbidden, text)
        self.assertIn('RunViewerStateRegression()', text)
        self.assertIn('ResolveMxNMViewerToolControlSet(plan,', text)

    def test_caption_gate_is_updated_after_save_dispatch(self):
        text = (ROOT / 'src/report_image_caption.ahk').read_text()
        action = text.split('\nExecuteReportImageCaptionAction(\n', 1)[1].split(
            '\nReportImageCaptionPasteSettle(target)', 1)[0]
        observe = action.index('ReportImageCaptionPasteGate.ObserveSave(target)')
        self.assertLess(action.index('target.savePoint.x'), observe)
        self.assertLess(action.index('Sleep pasteSettle.milliseconds'), observe)
        self.assertNotIn('FirstTargetProcessUse', action)

    def test_viewer_diagnostic_fields_are_allowlisted(self):
        text = (ROOT / 'src/automation_diagnostics.ahk').read_text()
        allowed = text.split('static viewerFields := Map(', 1)[1].split('\n        )', 1)[0]
        for field in ('viewer.dispatchResult', 'viewer.keysBefore', 'viewer.keysAfter',
                      'viewer.releaseMs', 'viewer.effectState', 'viewer.focusHwnd'):
            self.assertIn(field, allowed)
        for forbidden in ('clipboard', 'windowTitle', 'patient', 'caption.text'):
            self.assertNotIn(forbidden, allowed)
