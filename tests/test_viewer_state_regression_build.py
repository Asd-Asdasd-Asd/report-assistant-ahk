"""Keep the executable Windows behavior harness tied to production definitions."""
import unittest
from scripts.build_viewer_state_regression import ROOT, OUTPUT, build


class ViewerStateRegressionBuildTests(unittest.TestCase):
    def test_generated_harness_matches_production(self):
        self.assertEqual(OUTPUT.read_text(encoding="utf-8"), build())

    def test_harness_is_isolated_from_production_startup_and_patient_data(self):
        text = build()
        for forbidden in ('RegisterConfiguredFeatures(', 'Send "{F12}"', 'A_Clipboard',
                          'FileRead(', 'IniRead(', 'MxNMAnnotationCleaner.DeleteAll('):
            self.assertNotIn(forbidden, text)
        self.assertIn('RunViewerStateRegression()', text)
        self.assertIn('ResolveMxNMViewerToolControlSet(plan,', text)

    def test_caption_settle_and_target_validation_precede_save_and_advance(self):
        text = (ROOT / 'src/report_image_caption.ahk').read_text(encoding="utf-8")
        action = text.split('\nExecuteReportImageCaptionAction(\n', 1)[1].split(
            '\nValidateReportImageCaptionSaveTarget(', 1)[0]
        self.assertLess(action.index('Sleep ReportImageCaptionDefaults.PasteToSaveSettleMs'),
                        action.index('if !saveTarget.ok'))
        self.assertLess(action.index('if !saveTarget.ok'), action.index('target.savePoint.x'))
        self.assertLess(action.index('target.savePoint.x'), action.index('SendInput "{WheelDown}"'))
        self.assertNotIn('FirstTargetProcessUse', action)

    def test_viewer_diagnostic_fields_are_allowlisted(self):
        text = (ROOT / 'src/automation_diagnostics.ahk').read_text(encoding="utf-8")
        allowed = text.split('static viewerFields := Map(', 1)[1].split('\n        )', 1)[0]
        for field in ('viewer.dispatchResult', 'viewer.keysBefore', 'viewer.keysAfter',
                      'viewer.releaseMs', 'viewer.effectState', 'viewer.focusHwnd'):
            self.assertIn(field, allowed)
        for forbidden in ('clipboard', 'windowTitle', 'patient', 'caption.text'):
            self.assertNotIn(forbidden, allowed)
