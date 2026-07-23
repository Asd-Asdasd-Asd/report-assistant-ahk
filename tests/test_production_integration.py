#!/usr/bin/env python3
"""Static integration checks for the production Color Reset V1 call chain."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def function_body(text: str, name: str, next_name: str) -> str:
    return text.split(f"{name}(", 1)[1].split(f"{next_name}(", 1)[0]


class ProductionColorResetIntegrationTests(unittest.TestCase):
    def test_hotstrings_use_report_editor_orchestration(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        self.assertIn(
            "RunRedResetInsertion(plan.RedText, resetReadiness.options)", hotstrings
        )
        self.assertIn(
            "RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)", hotstrings
        )
        self.assertNotIn("ResetMedExInsertionColor(", hotstrings)

    def test_plain_text_precedes_fixed_red_marker_insertion(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        dispatcher = hotstrings.split("RunConfiguredReportHotstring(entry, *)", 1)[1].split(
            "\n}\n\nSendConfiguredReportText", 1
        )[0]
        self.assertLess(
            dispatcher.index("SendConfiguredReportText(plan.PlainText)"),
            dispatcher.index("RunRedResetInsertion(plan.RedText, resetReadiness.options)"),
        )
        self.assertLess(
            dispatcher.index("SendConfiguredReportText(plan.PlainText)"),
            dispatcher.index("RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)"),
        )

    def test_report_hotstrings_share_medex_only_scope(self) -> None:
        registration = source("src/hotstring_registration.ahk")
        self.assertIn("HotIf (*) => MedExReportHotstringsEnabled()", registration)
        self.assertIn('Hotstring(":*?:" entry.Trigger,', registration)
        self.assertIn("} finally {\n        HotIf\n", registration)
        self.assertNotIn(":*?:;", registration)

    def test_medex_hotstring_scope_uses_production_process_candidates(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        predicate = function_body(
            adapter,
            "MedExReportHotstringsEnabled",
            "MedExForegroundWindowMatches",
        )
        self.assertIn("MedExColorResetDefaults.ProvisionalProcessNames", predicate)
        self.assertIn('WinActive("ahk_exe " processName)', predicate)
        self.assertIn("return false", predicate)
        self.assertNotIn("REPORT_EDITOR_EXE", predicate)

    def test_release_resets_hotif_before_global_control_hotkeys(self) -> None:
        release = source("release/report_assistant.ahk")
        scoped = release.index("HotIf (*) => MedExReportHotstringsEnabled()")
        reset = release.index("\n        HotIf\n", scoped)
        suspend_exempt = release.index("#SuspendExempt", reset)
        pause = release.index("^!Esc::", suspend_exempt)
        exit_hotkey = release.index("^!q::", pause)
        self.assertLess(scoped, reset)
        self.assertLess(reset, suspend_exempt)
        self.assertLess(suspend_exempt, pause)
        self.assertLess(pause, exit_hotkey)

    def test_template_caret_path_preserves_validated_settle_contract(self) -> None:
        hotstrings = source("src/hotstrings.ahk")
        report_editor = source("src/report_editor.ahk")
        release = source("release/report_assistant.ahk")
        caret = report_editor.split(
            "RunRedCaretInsertion(text, caretLeftCount, resetOptions := 0)", 1
        )[1].split(
            "\n\nInsertRedFigureTextForCaretRelocation(text, caretLeftCount,", 1
        )[0]
        self.assertNotIn("FzgCursorRestoreDelayMs", report_editor)
        self.assertNotIn("ReportHotstringTimingDefaults", report_editor)
        self.assertNotIn("Sleep", caret)
        self.assertNotIn("FzgCursorRestoreDelayMs", release)
        self.assertIn("static RedCaretAfterPasteSettleMs := 60", report_editor)
        self.assertIn(
            "Sleep ReportEditorTimingDefaults.RedCaretAfterPasteSettleMs",
            report_editor,
        )
        self.assertIn('Send("{Left " caretLeftCount "}")', report_editor)
        self.assertNotIn('Send("{Left 3}")', hotstrings + report_editor)
        self.assertIn("InsertRedFigureTextForCaretRelocation", caret)
        self.assertNotIn("InsertRedFigureTextAndRestoreState", caret)
        self.assertNotIn("ResetMedExInsertionColor", caret)

    def test_fzg_caret_relocation_skips_color_reset_with_structured_status(self) -> None:
        report_editor = source("src/report_editor.ahk")
        logic = source("src/medex_color_reset_logic.ahk")
        body = report_editor.split(
            "InsertRedFigureTextForCaretRelocation(text, caretLeftCount,", 1
        )[1].split("\n\nSendRedFigureCaretRelocation(", 1)[0]
        self.assertIn("PasteRedFigureTextDetailed(", body)
        self.assertIn("() => SendRedFigureCaretRelocation(", body)
        self.assertIn("if !pasteResult.beforeRestoreSucceeded", body)
        self.assertIn("caretLeftCount", body)
        self.assertIn("ColorResetCode.NOT_REQUIRED", body)
        self.assertIn('"colorResetReason", "caretMovesBeforeRedMarker"', body)
        self.assertNotIn("ResetMedExInsertionColor", body)
        self.assertIn('static NOT_REQUIRED := "COLOR_RESET_NOT_REQUIRED"', logic)

    def test_orchestration_pastes_then_resets_and_preserves_partial_failure(self) -> None:
        report_editor = source("src/report_editor.ahk")
        body = function_body(
            report_editor,
            "InsertRedFigureTextAndRestoreState",
            "ResetReportFormattingPlaceholder",
        )
        paste = body.index("PasteRedFigureTextDetailed(")
        reset = body.index("ResetRedInsertionColorBeforeClipboardRestore(")
        self.assertLess(paste, reset)
        self.assertIn("() => ResetRedInsertionColorBeforeClipboardRestore(", body)
        self.assertIn("resetResult := pasteResult.beforeRestoreResult", body)
        self.assertIn("RedTextOperationCode.PASTE_FAILED", body)
        self.assertIn("RedTextOperationCode.RESET_FAILED", body)
        self.assertIn("pasteDispatched: true", body)
        for forbidden in ("MsgBox", "ToolTip", "TrayTip", "Flash("):
            self.assertNotIn(forbidden, body)

    def test_generic_clipboard_module_has_no_medex_or_uia_dependency(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        self.assertNotIn("MedEx", clipboard)
        self.assertNotIn("UIA", clipboard)
        body = function_body(clipboard, "PasteHtmlFragmentDetailed", "BuildCfHtml")
        for forbidden in ("MsgBox", "ToolTip", "TrayTip", "Flash("):
            self.assertNotIn(forbidden, body)

    def test_html_clipboard_keeps_restore_safety_with_zero_dispatch_settle(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        transaction = clipboard.split(
            "WithClipboardRestore(callback, performanceContext := 0,", 1
        )[1].split("\n\nWaitForSafeClipboardRestore(", 1)[0]
        safe_wait = clipboard.split("\nWaitForSafeClipboardRestore(", 1)[1].split(
            "\n\nPasteHtmlFragmentWithoutRestore(fragment,", 1
        )[0]
        html_paste = clipboard.split(
            "PasteHtmlFragmentWithoutRestore(fragment, performanceContext := 0,", 1
        )[1].split("\n\nPastePlainTextWithoutRestore(text)", 1)[0]
        self.assertIn("static HtmlPasteDispatchSettleMs := 0", clipboard)
        self.assertIn("static ClipboardPreRestoreSettleMs := 100", clipboard)
        self.assertIn("static ClipboardPostRestoreSettleMs := 100", clipboard)
        self.assertIn("static SafeMinPasteToRestoreMs := 300", clipboard)
        before_restore = transaction.index("beforeRestoreCallback.Call()")
        finally_block = transaction.index("} finally {")
        restore = transaction.index("A_Clipboard := savedClipboard")
        post_restore = transaction.index(
            "Sleep ClipboardTransactionDefaults.ClipboardPostRestoreSettleMs"
        )
        self.assertLess(before_restore, finally_block)
        self.assertLess(finally_block, restore)
        self.assertLess(restore, post_restore)
        self.assertIn("SafeMinPasteToRestoreMs", safe_wait)
        self.assertIn("- elapsedMs", safe_wait)
        self.assertIn("loop {", safe_wait)
        self.assertIn("if waitMs <= 0", safe_wait)
        self.assertIn("break", safe_wait)
        self.assertIn("Sleep waitMs", safe_wait)
        self.assertIn("ClipboardPreRestoreSettleMs", safe_wait)
        self.assertIn("Send(\"^v\")", html_paste)
        self.assertIn('restoreTimingContext["pasteSentAt"] := pasteSentAt', html_paste)
        self.assertIn(
            "Sleep ClipboardTransactionDefaults.HtmlPasteDispatchSettleMs",
            html_paste,
        )
        self.assertNotIn("HtmlPasteSettleMs := 50", clipboard)

    def test_step_three_callback_result_and_restore_timing_are_exposed(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        detailed = function_body(
            clipboard,
            "PasteHtmlFragmentDetailed",
            "BuildCfHtml",
        )
        self.assertIn("restoreTimingContext := Map()", detailed)
        self.assertIn("beforeRestoreCallback,", detailed)
        self.assertIn("restoreTimingContext", detailed)
        for field in (
            "beforeRestoreAttempted",
            "beforeRestoreSucceeded",
            "beforeRestoreResult",
            "beforeRestoreError",
        ):
            self.assertIn(field, detailed)

    def test_step_three_restore_is_single_finally_owner(self) -> None:
        clipboard = source("src/clipboard_html.ahk")
        transaction = clipboard.split(
            "WithClipboardRestore(callback, performanceContext := 0,", 1
        )[1].split("\n\nWaitForSafeClipboardRestore(", 1)[0]
        self.assertEqual(transaction.count("A_Clipboard := savedClipboard"), 1)
        self.assertLess(
            transaction.index("} finally {"),
            transaction.index("A_Clipboard := savedClipboard"),
        )

    def test_step_three_failure_feedback_runs_after_transaction_result(self) -> None:
        report_editor = source("src/report_editor.ahk")
        orchestration = report_editor.split(
            "InsertRedFigureTextAndRestoreState(text :=", 1
        )[1].split("\n\nResetRedInsertionColorBeforeClipboardRestore(", 1)[0]
        transaction_return = orchestration.index(
            "resetResult := pasteResult.beforeRestoreResult"
        )
        feedback = orchestration.index('SoundBeep(650, 150)')
        self.assertLess(transaction_return, feedback)

    def test_step_three_fast_failure_harness_preserves_clipboard(self) -> None:
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn("^!F10::", field_debug)
        self.assertIn("RunMedExProductionTimingFieldDebug(true)", field_debug)
        self.assertIn('options["processCandidates"] := ["__step3_fast_failure__.exe"]', field_debug)
        self.assertIn('"Step3FastFailure"', field_debug)
        timing = field_debug.split(
            "RunMedExProductionTimingFieldDebug(fastFailure := false)", 1
        )[1]
        self.assertIn("if !fastFailure {", timing)
        self.assertIn("A_Clipboard := output", timing)

    def test_provisional_process_allowlist_is_exact_and_enabled_for_baseline(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        self.assertIn('"medexworkstation.exe"', adapter)
        self.assertIn('"medexworkstations.exe"', adapter)
        self.assertIn("static AllowProvisionalProcess := true", adapter)
        self.assertIn('"processNameConfirmed", false', adapter)

    def test_foreground_change_has_stable_distinct_result_code(self) -> None:
        logic = source("src/medex_color_reset_logic.ahk")
        adapter = source("src/adapters/medex_report_editor.ahk")
        self.assertIn("COLOR_RESET_FOREGROUND_CHANGED", logic)
        self.assertGreaterEqual(adapter.count("ColorResetCode.FOREGROUND_CHANGED"), 3)
        self.assertIn("ColorResetCode.WRONG_PROCESS", adapter)

    def test_candidate_g_interaction_rechecks_only_original_active_hwnd(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        candidate_g = adapter.split(
            "RunMedExRelativeMousePixelValidatedColorReset(options := 0)", 1
        )[1].split("\n\nSampleAndEvaluateCandidateGPopupSignature(arrowPoint, options := 0)", 1)[0]
        self.assertEqual(candidate_g.count("WinGetProcessName("), 1)
        self.assertEqual(candidate_g.count("MedExForegroundWindowMatches("), 3)
        self.assertNotIn("MedExForegroundTargetMatches(", candidate_g)
        helper = adapter.split(
            "\nMedExForegroundWindowMatches(expectedHwnd) {", 1
        )[1].split("\nMedExForegroundTargetMatches(expectedHwnd, expectedProcess) {", 1)[0]
        self.assertIn('WinExist("A") = expectedHwnd', helper)
        self.assertNotIn("WinGetProcessName", helper)

    def test_production_and_field_share_core_with_different_diagnostic_modes(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn('MedExAdapterOption(options, "diagnosticMode", "production")', adapter)
        self.assertIn('"diagnosticMode", "field"', field_debug)
        self.assertIn("ResetMedExInsertionColor(options)", field_debug)
        self.assertNotIn("ResolveMedExColorResetLayout(", field_debug)

    def test_production_menu_lookup_uses_one_click_and_adaptive_exact_polling(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        interaction = adapter.split("\nRunMedExColorMenuInteraction(", 1)[1].split(
            "\nWaitForMedExColorMenu(", 1
        )[0]
        lookup = adapter.split("\nWaitForMedExColorMenu(", 1)[1].split(
            "\nWaitForMedExColorMenuFixedAttempts(", 1
        )[0]
        self.assertIn('static MenuLookupStrategy := "adaptivePolling"', adapter)
        self.assertIn("static MenuOpenTimeoutMs := 600", adapter)
        self.assertIn("static MenuPollIntervalMs := 40", adapter)
        self.assertEqual(interaction.count("Click screenPoint"), 1)
        self.assertIn("loop {", lookup)
        self.assertEqual(lookup.count('FindExactMedExColorItem(currentWindowElement, "000000")'), 1)
        self.assertEqual(lookup.count("Sleep pollIntervalMs"), 1)
        self.assertIn("A_TickCount - startedAt >= timeoutMs", lookup)
        self.assertGreater(lookup.index('"ff0000"'), lookup.index('"000000"'))
        self.assertIn('menuLookupStrategy = "fixedAttempts"', interaction)

    def test_anchor_resolution_uses_one_cached_text_snapshot(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        snapshot = adapter.split("\nCollectMedExTextAnchorSnapshot(", 1)[1].split(
            "\nUiaTextElementsToAnchors(", 1
        )[0]
        self.assertEqual(snapshot.count('FindElements({Type: "Text"}'), 2)
        self.assertIn('CreateCacheRequest(["Name", "BoundingRectangle"])', snapshot)
        self.assertIn("CachedName", adapter)
        self.assertIn("CachedBoundingRectangle", adapter)
        self.assertIn('"anchorSnapshotShared", true', snapshot)
        self.assertIn('"anchorSnapshotMode"', snapshot)
        self.assertIn("static UseCachedAnchorSnapshot := false", adapter)

    def test_font_anchor_retry_is_zero_raw_match_only_and_bounded(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        reset = function_body(
            adapter,
            "ResetMedExInsertionColor",
            "RunMedExColorMenuInteraction",
        )
        self.assertIn('"rawFontSizePatternMatchCount", 0) = 0', reset)
        self.assertIn("static EnableFontAnchorRetry := false", adapter)
        self.assertIn("retryEligible && enableFontAnchorRetry", reset)
        self.assertEqual(reset.count("if retryEligible"), 1)
        self.assertIn('context["anchorSnapshotAttemptCount"] := 2', reset)
        self.assertNotIn("while", reset.lower())
        self.assertNotIn("loop", reset.lower())

    def test_diagnostic_mode_exposes_filter_query_and_cursor_evidence(self) -> None:
        diagnostics = source("src/diagnostics.ahk")
        for field in (
            "RawFontSizePatternMatchCount",
            "ValidFontSizeRectCount",
            "AlignedFontSizeCandidateCount",
            "IgnoredFontSizeReasons",
            "AnchorSnapshotQueryDurationMs",
            "FontAnchorRetryUsed",
            "BlackLookupFirstQueryDurationMs",
            "BlackLookupRetryQueryDurationMs",
            "FocusedElementBeforeCursorRestore",
            "CursorRestoreRequestedCount",
            "CursorRestoreCommandSent",
        ):
            self.assertIn(field, diagnostics)

    def test_focus_diagnostics_are_explicit_not_production_default(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn('MedExAdapterOption(options, "collectFocusDiagnostics", false)', adapter)
        self.assertIn('DEBUG_COLLECT_FOCUS_DIAGNOSTICS := false', field_debug)
        self.assertIn('"collectFocusDiagnostics", DEBUG_COLLECT_FOCUS_DIAGNOSTICS', field_debug)
        self.assertNotIn("CaptureMedExFocusedElementContext", source("src/main.ahk"))

    def test_field_debug_does_not_register_production_hotstrings(self) -> None:
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertNotIn("ApplyMedExFieldDebugRuntimeOverrides", field_debug)
        self.assertNotIn("#Include ..\\src\\hotstrings.ahk", field_debug)
        self.assertNotIn(":*?:;red::", field_debug)
        self.assertNotIn(":*?:;fzg::", field_debug)
        self.assertIn("RunRedInsertion(options)", field_debug)
        self.assertIn(
            'options["colorResetStrategy"] := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED',
            field_debug,
        )
        self.assertIn("DEBUG_USE_CACHED_ANCHOR_SNAPSHOT := MedExColorResetDefaults.UseCachedAnchorSnapshot", field_debug)
        self.assertIn("static UseCachedAnchorSnapshot := false", source("src/adapters/medex_report_editor.ahk"))

    def test_field_debug_loads_candidate_g_before_adapter(self) -> None:
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        candidate_g_include = "#Include ..\\src\\medex_candidate_g_logic.ahk"
        adapter_include = "#Include ..\\src\\adapters\\medex_report_editor.ahk"
        self.assertEqual(field_debug.count(candidate_g_include), 1)
        self.assertLess(
            field_debug.index(candidate_g_include),
            field_debug.index(adapter_include),
        )

    def test_color_reset_strategy_boundary_has_no_automatic_fallback(self) -> None:
        logic = source("src/medex_color_reset_logic.ahk")
        adapter = source("src/adapters/medex_report_editor.ahk")
        dispatcher = adapter.split("ResetMedExInsertionColor(options := 0)", 1)[1].split(
            "\n\nRunMedExUiaInvokeColorReset(options := 0)", 1
        )[0]
        self.assertIn('static UIA_INVOKE := "uiaInvoke"', logic)
        self.assertIn(
            'static RELATIVE_MOUSE_PIXEL_VALIDATED := "relativeMousePixelValidated"',
            logic,
        )
        self.assertIn(
            "static ColorResetStrategy := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED",
            adapter,
        )
        self.assertIn("RunMedExUiaInvokeColorReset(options)", dispatcher)
        self.assertIn("RunMedExRelativeMousePixelValidatedColorReset(options)", dispatcher)
        relative_branch = dispatcher.split(
            "MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED", 1
        )[1]
        self.assertNotIn("RunMedExUiaInvokeColorReset(options)", relative_branch)

    def test_field_debug_uses_explicit_uia_strategy_override(self) -> None:
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn("DEBUG_COLOR_RESET_STRATEGY := MedExColorResetStrategy.UIA_INVOKE", field_debug)
        self.assertGreaterEqual(field_debug.count('"colorResetStrategy", DEBUG_COLOR_RESET_STRATEGY'), 2)

    def test_production_success_skips_field_environment_and_full_output(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        reset = function_body(
            adapter,
            "ResetMedExInsertionColor",
            "RunMedExColorMenuInteraction",
        )
        self.assertIn('if diagnosticMode = "field"', reset)
        self.assertIn("CollectMedExEnvironmentContext", reset)
        self.assertNotIn('diagnosticMode = "production"', reset)
        self.assertNotIn("FormatMedExFieldDebugResult", reset)

    def test_production_logs_only_lightweight_failures_by_default(self) -> None:
        adapter = source("src/adapters/medex_report_editor.ahk")
        diagnostics = source("src/diagnostics.ahk")
        self.assertIn('diagnosticMode = "production" && !ok', adapter)
        self.assertIn("WriteMedExColorResetFailureDiagnostic", adapter)
        lightweight = function_body(
            diagnostics,
            "FormatMedExColorResetFailureLogLine",
            "FormatMedExColorResetLogLine",
        )
        self.assertIn('"appVersion="', lightweight)
        self.assertIn('"resultCode="', lightweight)
        self.assertIn('"medExVersion="', lightweight)
        self.assertIn('"calibratedMedExVersion="', lightweight)
        self.assertIn('"medExVersionMatchState="', lightweight)
        self.assertIn('"candidateGProfileName="', lightweight)
        self.assertIn('"horizontalGeometryPolicy="', lightweight)
        self.assertIn('"regionAnchorScreenX="', lightweight)
        self.assertIn('"regionAnchorClientX="', lightweight)
        for heavy_field in ("uiaRootRect", "regionAnchorRect", "fontSizeAnchorRect", "calculatedScreenPoint"):
            self.assertNotIn(heavy_field, lightweight)
        self.assertIn("FormatMedExFieldDebugResult", diagnostics)
        self.assertIn('"RegionAnchorRect="', diagnostics)

    def test_performance_diagnostics_are_explicit_and_privacy_safe(self) -> None:
        diagnostics = source("src/diagnostics.ahk")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        for field in (
            "HotstringTriggeredMs",
            "PasteCommandSentMs",
            "ColorResetStartedMs",
            "ArrowClickSentMs",
            "BlackClickSentMs",
            "FunctionReturnedMs",
            "TriggerToBlackClickMs",
            "PasteToClipboardRestoreMs",
            "HotstringStartMs",
            "PasteSentMs",
            "ClipboardRestoreCompletedMs",
            "ColorResetStartMs",
            "AnchorResolutionCompletedMs",
            "MenuClickSentMs",
            "ImmediateBlackLookupCompletedMs",
            "RetryLookupCompletedMs",
            "BlackInvokeCompletedMs",
            "CursorRestoreSentMs",
            "HotstringReturnMs",
            "TotalHotstringMs",
            "SafeMinPasteToRestoreMs",
            "ClipboardRestoreSafetyWaitMs",
            "BlackClickToClipboardRestoreMs",
        ):
            self.assertIn(field, diagnostics)
        self.assertIn('"diagnosticMode", "performance"', field_debug)
        self.assertIn("RunRedInsertion(options)", field_debug)
        for forbidden in ("patient", "clipboard text", "report content"):
            self.assertNotIn(forbidden, diagnostics.lower())

    def test_step_one_timing_keeps_ordering_and_records_candidate_g_clicks(self) -> None:
        report_editor = source("src/report_editor.ahk")
        clipboard = source("src/clipboard_html.ahk")
        adapter = source("src/adapters/medex_report_editor.ahk")
        wrapper = function_body(
            report_editor, "RunRedResetInsertion", "RunRedCaretInsertion"
        )
        orchestration = function_body(
            report_editor,
            "InsertRedFigureTextAndRestoreState",
            "ResetReportFormattingPlaceholder",
        )
        self.assertLess(
            wrapper.index('"HotstringTriggeredMs"'),
            wrapper.index("InsertRedFigureTextAndRestoreState"),
        )
        self.assertGreater(
            wrapper.index('"FunctionReturnedMs"'),
            wrapper.index("InsertRedFigureTextAndRestoreState"),
        )
        self.assertIn('"PasteCommandSentMs"', clipboard)
        self.assertIn('"ColorResetStartedMs"', orchestration)
        self.assertIn('"ArrowClickSentMs"', adapter)
        self.assertIn('"BlackClickSentMs"', adapter)
        candidate_g = adapter.split(
            "RunMedExRelativeMousePixelValidatedColorReset(options := 0)", 1
        )[1].split("\n\nSampleAndEvaluateCandidateGPopupSignature(arrowPoint, options := 0)", 1)[0]
        self.assertEqual(
            candidate_g.count(
                'performanceContext := MedExAdapterOption(options, "performanceContext", 0)'
            ),
            1,
        )
        self.assertEqual(candidate_g.count("RecordOptionalPerformanceTimestamp("), 2)
        self.assertEqual(candidate_g.count("performanceContext,"), 2)
        self.assertEqual(
            orchestration.index("PasteRedFigureTextDetailed"),
            min(
                orchestration.index("PasteRedFigureTextDetailed"),
                orchestration.index("ResetMedExInsertionColor"),
            ),
        )
        self.assertIn("static HtmlPasteDispatchSettleMs := 0", clipboard)
        self.assertIn("static ClipboardPreRestoreSettleMs := 100", clipboard)
        self.assertIn("static ClipboardPostRestoreSettleMs := 100", clipboard)
        self.assertIn("static SafeMinPasteToRestoreMs := 300", clipboard)

    def test_candidate_g_definitions_precede_adapter_references_in_release(self) -> None:
        candidate_g = source("src/medex_candidate_g_logic.ahk")
        adapter = source("src/adapters/medex_report_editor.ahk")
        release = source("release/report_assistant.ahk")
        self.assertIn("class CandidateGRelativeMouseProfile", candidate_g)
        self.assertIn("CandidateGRelativeMouseProfile.ProfileName", adapter)
        self.assertEqual(
            release.count("; --- BEGIN medex_candidate_g_logic.ahk ---"),
            1,
        )
        self.assertLess(
            release.index("class CandidateGRelativeMouseProfile"),
            release.index("CandidateGRelativeMouseProfile.ProfileName"),
        )

    def test_version_and_uia_dependency_are_production_owned(self) -> None:
        metadata = source("src/app_metadata.ahk")
        main = source("src/main.ahk")
        build = source("scripts/build_release.py")
        field_debug = source("debug/medex_color_reset_field_debug.ahk")
        self.assertIn('static Version := "0.5.0"', metadata)
        self.assertIn('static Channel := "internal-test"', metadata)
        self.assertIn("#Include app_metadata.ahk", main)
        self.assertIn("#Include <UIA>", main)
        self.assertTrue((SRC / "Lib" / "UIA.ahk").is_file())
        self.assertFalse((ROOT / "debug" / "Lib" / "UIA.ahk").exists())
        self.assertIn('"Lib/UIA.ahk"', build)
        self.assertIn("..\\src\\Lib\\UIA.ahk", field_debug)

    def test_step_five_version_metadata_is_bundled_without_exact_gate(self) -> None:
        release = source("release/report_assistant.ahk")
        diagnostics = source("src/diagnostics.ahk")
        self.assertNotIn("SupportedMedExVersion", release)
        self.assertEqual(
            release.count('static CalibratedMedExVersion := "0.0.1.0"'),
            2,
        )
        for field in (
            "ProfileValidationMedExVersion",
            "CalibratedMedExVersion",
            "MedExVersionMatchState",
            "MedExVersionMetadataOverrideApplied",
        ):
            self.assertIn(field, diagnostics)
            self.assertIn(field, release)

    def test_production_sources_are_relocatable(self) -> None:
        app_sources = [
            path
            for path in SRC.rglob("*.ahk")
            if path.name != "UIA.ahk"
        ]
        combined = "\n".join(path.read_text(encoding="utf-8") for path in app_sources)
        for forbidden in (
            "/Users/",
            "debug/field-result-",
            "debug\\field-result-",
            "NAS",
        ):
            self.assertNotIn(forbidden, combined)
        self.assertIsNone(re.search(r'(?i)[A-Z]:\\(?:Users|AutoHotKey|Project)\\', combined))

    def test_generated_release_is_self_contained_after_build(self) -> None:
        release = source("release/report_assistant.ahk")
        self.assertIn("class AppMetadata", release)
        self.assertIn('static Version := "0.5.0"', release)
        self.assertIn('static Channel := "internal-test"', release)
        self.assertIn('static Version => "1.1.3"', release)
        self.assertIn("class MedExColorResetLayoutProfile", release)
        self.assertIn("ResetMedExInsertionColor(options := 0)", release)
        self.assertNotIn("#Include", release)
        self.assertNotIn("if !A_IsCompiled && A_LineFile = A_ScriptFullPath", release)
        self.assertNotIn("UIA.Viewer()", release)


if __name__ == "__main__":
    unittest.main()
