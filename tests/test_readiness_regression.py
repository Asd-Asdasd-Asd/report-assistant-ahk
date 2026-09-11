import unittest
from scripts.build_readiness_regression import ROOT, OUTPUT, build


class ReadinessRegressionTests(unittest.TestCase):
    def test_generated_regression_matches_source(self):
        self.assertEqual(OUTPUT.read_text(), build())

    def test_measurement_timeout_has_no_command_replay(self):
        provider = (ROOT / "src/context_measurement_provider.ahk").read_text()
        dispatch = provider.split("InvokePreparedMxNMContextCommand(actionContext, asynchronous := false) {", 1)[1].split("PackContextMeasurementClientPoint(", 1)[0]
        self.assertNotIn('"User32\\SendMessageW"', dispatch)
        self.assertEqual(dispatch.count('"User32\\SendMessageTimeoutW"'), 1)
        self.assertIn("COMMAND_RESULT_UNKNOWN", dispatch)
        self.assertNotIn("loop {", dispatch)
        self.assertLess(dispatch.index('actionContext["expectedPid"]'), dispatch.index("if asynchronous"))

    def test_popup_ambiguity_and_visibility_guard_dispatch(self):
        provider = (ROOT / "src/context_measurement_provider.ahk").read_text()
        wait = provider.split("WaitForContextMeasurementPopup(viewerPid,", 1)[1].split("FindContextMeasurementCommandControl(", 1)[0]
        self.assertIn("readyPopups.Length = 1", wait)
        self.assertIn("!currentState.visible", wait)
        self.assertIn("IsWindowEnabled", wait)
        self.assertIn("matches.Length = 1 ? matches[1] : 0", provider)

    def test_caption_refresh_does_not_repeat_copy_or_save(self):
        caption = (ROOT / "src/report_image_caption.ahk").read_text()
        wait = caption.split("WaitForReportImageCaptionTarget(sourceHwnd, sourcePid, boundTarget := 0) {", 1)[1].split("ResolveReportImageCaptionTarget(sourceHwnd, sourcePid) {", 1)[0]
        for forbidden in ["SendInput", "MouseClick", "ObserveSave"]:
            self.assertNotIn(forbidden, wait)
        self.assertIn("target.candidateCount > 1", wait)
        self.assertIn("boundTarget, sourcePid", wait)
        self.assertIn("ReportImageCaptionCachedAnchorsValid(cache)", caption)

    def test_readiness_cannot_follow_a_different_viewer(self):
        session = (ROOT / "src/mxnm_context_target_session.ahk").read_text()
        self.assertNotIn("ColdRecoveryConsumed", session)
        self.assertIn("identity.pid != recoveryPid", session)
        self.assertIn("identity.rootHwnd != recoveryRoot", session)
        self.assertIn("A_TickCount - readinessStartedAt < this.ReadinessTimeoutMs", session)
