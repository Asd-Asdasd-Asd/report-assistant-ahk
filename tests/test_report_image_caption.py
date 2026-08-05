#!/usr/bin/env python3
"""Structural regression tests for report-image caption + advance."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ReportImageCaptionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = source("src/report_image_caption.ahk")

    def body(self, start: str, end: str) -> str:
        return self.module.split(start, 1)[1].split(end, 1)[0]

    def test_legacy_chord_is_the_configurable_default(self) -> None:
        features = source("src/features.ahk")
        model = source("src/feature_model.ahk")
        compat = source("legacy/medex_legacy_compat.ahk")
        self.assertIn(
            'static ReportImageCaptionEnabledDefault := "true"',
            model,
        )
        self.assertIn(
            'static ReportImageCaptionChordDefault := "+!s"',
            model,
        )
        self.assertIn(
            "ReportImageCaptionHotkeyDefinitions(settings)",
            features,
        )
        self.assertIn("settings.ReportImageCaptionEnabled", self.module)
        self.assertIn("settings.ReportImageCaptionChord", self.module)
        self.assertIn("ReportImageCaptionForegroundActive", features)
        self.assertNotIn("+!s::", compat)

    def test_hotkey_config_round_trips_through_the_managed_settings_pipeline(
        self,
    ) -> None:
        model = source("src/feature_model.ahk")
        loader = source("src/feature_config.ahk")
        config = source("src/hotstring_config.ahk")
        editor = source("src/hotstring_config_editor.ahk")
        normalization = source("src/feature_normalization.ahk")
        for required in (
            "ReportImageCaptionSection",
            "ReportImageCaptionEnabledKey",
            "ReportImageCaptionChordKey",
        ):
            self.assertIn(required, model)
            self.assertIn(required, loader)
            self.assertIn(required, config)
            self.assertIn(required, editor)
        self.assertIn(
            "ParseOptionalFeatureEnabled(raw.ReportImageCaptionEnabled)",
            normalization,
        )
        self.assertIn(
            "NormalizeOptionalHotkeyChord(raw.ReportImageCaptionChord)",
            normalization,
        )
        self.assertIn("FeatureHotkeySettingsMatch(", editor)

    def test_disabled_hotkey_is_not_registered(self) -> None:
        definitions = self.body(
            "ReportImageCaptionHotkeyDefinitions(settings)",
            "\nReportImageCaptionForegroundActive",
        )
        self.assertIn("if !settings.ReportImageCaptionEnabled", definitions)
        self.assertIn("return []", definitions)
        self.assertIn("chord := settings.ReportImageCaptionChord", definitions)
        self.assertIn("InvokeReportImageCaptionHotkey.Bind(chord)", definitions)

    def test_hotkey_dispatches_on_key_down_and_releases_only_main_key(self) -> None:
        handler = self.body(
            "InvokeReportImageCaptionHotkey(chord, *)",
            "\nclass ReportImageCaptionProvider",
        )
        self.assertIn(
            "ReportImageCaptionProvider.Invoke(foregroundHwnd)",
            handler,
        )
        self.assertNotIn(
            "ViewerHotkeyChordHasPressedComponent",
            handler,
        )
        self.assertNotIn("Sleep 10", handler)
        self.assertIn(
            "KeyWait ReportImageCaptionTriggerKey(chord)",
            handler,
        )
        trigger = self.body(
            "ReportImageCaptionTriggerKey(chord)",
            "\nclass ReportImageCaptionProvider",
        )
        self.assertIn('"^[!+^#]+(.+)$"', trigger)
        self.assertIn("return match[1]", trigger)

    def test_source_capture_requires_fresh_nonempty_clipboard(self) -> None:
        capture = self.body(
            "\nCaptureFreshReportImageCaption(sourceHwnd) {\n",
            "\nResolveReportImageCaptionTarget(",
        )
        self.assertIn('A_Clipboard := ""', capture)
        self.assertEqual(capture.count('SendInput "^c"'), 1)
        self.assertIn("ClipWait(ReportImageCaptionDefaults.CopyTimeoutSeconds)", capture)
        self.assertIn('Trim(copiedText, " `t`r`n") = ""', capture)
        self.assertIn("payload := ClipboardAll()", capture)
        self.assertNotIn("savedClipboard", capture)

    def test_reuse_is_only_selected_for_the_exact_bound_target(self) -> None:
        invoke = self.body(
            "static Invoke(foregroundHwnd := 0)",
            "static InvokeCapture(sourceHwnd)",
        )
        reuse = self.body(
            "static InvokeReuse(targetHwnd, cache)",
            "CaptureFreshReportImageCaption(",
        )
        self.assertIn(
            "priorCache.targetHwnd\n"
            "                    = foregroundHwnd",
            invoke,
        )
        self.assertIn("ClearReportImageCaptionCache(false)", invoke)
        self.assertIn("ReportImageCaptionCacheBindingValid", reuse)
        self.assertIn("ResolveCachedReportImageCaptionTarget", reuse)
        self.assertNotIn('SendInput "^c"', reuse)
        self.assertNotIn(
            "BuildReportImageCaptionTargetCandidate",
            reuse,
        )

    def test_new_source_caption_reuses_stable_target_geometry(self) -> None:
        capture = self.body(
            "static InvokeCapture(sourceHwnd, priorCache := 0)",
            "static InvokeReuse(targetHwnd, cache)",
        )
        cached = self.body(
            "ResolveCachedReportImageCaptionTarget(cache, targetHwnd)",
            "\nReportImageCaptionTopLevelWindowEligible(hwnd, expectedPid)",
        )
        self.assertIn(
            "ReportImageCaptionSourceBindingValid(",
            capture,
        )
        self.assertIn(
            "ResolveCachedReportImageCaptionTarget(",
            capture,
        )
        self.assertIn(
            "ResolveReportImageCaptionTarget(",
            capture,
        )
        self.assertIn("targetClientRectKey", capture)
        self.assertIn("targetClientRectKey", cached)
        self.assertIn("ReportImageCaptionRectKey(", cached)

    def test_target_resolution_uses_unique_structure_not_display_position(self) -> None:
        resolver = self.body(
            "ResolveReportImageCaptionTarget(sourceHwnd, sourcePid)",
            "ResolveCachedReportImageCaptionTarget(",
        )
        candidate = self.body(
            "BuildReportImageCaptionTargetCandidate(hwnd, expectedPid)",
            "\nResolveReportImageCaptionPane(\n",
        )
        self.assertIn("if matches.Length != 1", resolver)
        self.assertIn('Name: "图像描述"', candidate)
        self.assertIn('Name: "保存"', candidate)
        self.assertIn("descriptionElements.Length != 1", candidate)
        self.assertIn("saveElements.Length != 1", candidate)
        for forbidden in (
            "MonitorGet",
            "MonitorGetPrimary",
            "WinGetTitle",
            "2821",
            "2884",
        ):
            self.assertNotIn(forbidden, self.module)

    def test_caption_and_image_points_are_revalidated_in_target_owner(self) -> None:
        candidate = self.body(
            "BuildReportImageCaptionTargetCandidate(hwnd, expectedPid)",
            "\nResolveReportImageCaptionPane(\n",
        )
        pane = self.body(
            "\nResolveReportImageCaptionPane(\n",
            "\nResolveReportImageCaptionImagePoint(\n",
        )
        image = self.body(
            "\nResolveReportImageCaptionImagePoint(\n",
            "\nExecuteReportImageCaptionAction(",
        )
        self.assertIn("ResolveReportImageCaptionPane", candidate)
        self.assertIn('FindElements({Type: "Pane"})', pane)
        self.assertIn("if matches.Length != 1", pane)
        self.assertIn(
            "(captionPaneRect.l + captionPaneRect.r) / 2",
            image,
        )
        self.assertIn(
            "clientRect.t + imageRegionHeight * 0.5",
            image,
        )
        self.assertNotIn('FindElements({Type: "Document"})', image)
        self.assertIn("ReportImageCaptionRootOwner(pointHwnd) = targetHwnd", self.module)

    def test_action_keeps_caption_clipboard_and_restores_only_mouse(self) -> None:
        action = self.body(
            "\nExecuteReportImageCaptionAction(\n    cache,",
            "\nSetReportImageCaptionClipboard(payload)",
        )
        self.assertIn('WinActivate "ahk_id " target.hwnd', action)
        self.assertIn(
            'if WinExist("A") != target.hwnd',
            action,
        )
        self.assertEqual(action.count('SendInput "^v"'), 1)
        self.assertEqual(action.count('SendInput "^a"'), 1)
        self.assertLess(
            action.index('SendInput "^a"'),
            action.index('SendInput "^v"'),
        )
        self.assertEqual(action.count('SendInput "{WheelDown}"'), 1)
        self.assertIn(
            "target.captionPoint.y,\n            1,\n            0",
            action,
        )
        self.assertIn("static CaptionFocusSettleMs := 15", self.module)
        self.assertIn("static PasteSettleMs := 20", self.module)
        self.assertIn("static ExplicitSaveSettleMs := 200", self.module)
        self.assertIn(
            "static CaptureSaveFallbackSettleMs := 550",
            self.module,
        )
        self.assertLess(
            action.index("CaptionFocusSettleMs"),
            action.index('SendInput "^a"'),
        )
        self.assertIn("finally {\n        MouseMove originalX, originalY, 0", action)
        self.assertNotIn("savedClipboard", action)
        self.assertNotIn("A_Clipboard :=", action)
        self.assertIn("SetReportImageCaptionClipboard(cache.payload)", action)

    def test_explicit_save_button_is_dispatched_before_advance(self) -> None:
        candidate = self.body(
            "BuildReportImageCaptionTargetCandidate(hwnd, expectedPid)",
            "\nResolveReportImageCaptionPane(\n",
        )
        action = self.body(
            "\nExecuteReportImageCaptionAction(\n    cache,",
            "\nSetReportImageCaptionClipboard(payload)",
        )
        self.assertIn(
            "x: Round((saveRect.l + saveRect.r) / 2)",
            candidate,
        )
        self.assertIn("savePoint: savePoint", candidate)
        self.assertIn("target.savePoint.x", action)
        self.assertIn("target.savePoint.y", action)
        self.assertIn("Sleep saveSettleMs", action)
        self.assertLess(
            action.index("target.savePoint.x"),
            action.index('SendInput "{WheelDown}"'),
        )
        self.assertIn("SAVE_DISPATCH_FAILED", action)

    def test_only_fresh_caption_capture_uses_vendor_save_fallback_window(self) -> None:
        capture = self.body(
            "static InvokeCapture(sourceHwnd, priorCache := 0)",
            "static InvokeReuse(targetHwnd, cache)",
        )
        reuse = self.body(
            "static InvokeReuse(targetHwnd, cache)",
            "CaptureFreshReportImageCaption(",
        )
        self.assertIn(
            "ReportImageCaptionDefaults.CaptureSaveFallbackSettleMs",
            capture,
        )
        self.assertNotIn(
            "ReportImageCaptionDefaults.CaptureSaveFallbackSettleMs",
            reuse,
        )
        self.assertIn(
            "ReportImageCaptionDefaults.ExplicitSaveSettleMs",
            reuse,
        )

    def test_cache_has_explicit_tray_reset_and_no_persistence(self) -> None:
        tray = source("src/tray_menu.ahk")
        clear = self.body(
            "ClearReportImageCaptionCache(showFeedback := true, *)",
            "ReportImageCaptionUiaRoot(",
        )
        self.assertIn('static ClearCaptionItemName := "清除快速标图 caption"', tray)
        self.assertIn("ClearReportImageCaptionCache", tray)
        self.assertIn("REPORT_IMAGE_CAPTION_CACHE.payload := \"\"", clear)
        for forbidden in ("FileAppend", "IniWrite", "OutputDebug"):
            self.assertNotIn(forbidden, self.module)

    def test_release_builder_orders_feature_before_registration(self) -> None:
        builder = source("scripts/build_release.py")
        main = source("src/main.ahk")
        self.assertIn("#Include report_image_caption.ahk", main)
        self.assertLess(
            builder.index('"report_image_caption.ahk"'),
            builder.index('"features.ahk"'),
        )


if __name__ == "__main__":
    unittest.main()
