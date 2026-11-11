#!/usr/bin/env python3
"""Build isolated AHK state and native-control regression from production code."""
try:
    from scripts.ahk_bundle import ROOT, between as section
except ModuleNotFoundError:  # executed directly from scripts/
    from ahk_bundle import ROOT, between as section

OUTPUT = ROOT / 'tests/windows/generated/viewer_state_regression_standalone.ahk'


def build() -> str:
    caption = (ROOT / 'src/report_image_caption.ahk').read_text(encoding="utf-8")
    hotkeys = (ROOT / 'src/viewer_tool_hotkeys.ahk').read_text(encoding="utf-8")
    tools = (ROOT / 'src/mxnm_viewer_tool_commands.ahk').read_text(encoding="utf-8")
    diagnostics = (ROOT / 'src/automation_diagnostics.ahk').read_text(encoding="utf-8")
    hotstrings = (ROOT / 'src/hotstrings.ahk').read_text(encoding="utf-8")
    report_diagnostics = (ROOT / 'src/diagnostics.ahk').read_text(encoding="utf-8")
    parts = [
        '; Generated regression. Uses synthetic windows only; does not operate MedEx.',
        '#Requires AutoHotkey v2.0', '#SingleInstance Force', '#Warn',
        (ROOT / 'src/core/win32_window.ahk').read_text(encoding="utf-8"),
        section(caption, 'class ReportImageCaptionDefaults {', 'class ReportImageCaptionCode {'),
        section(hotkeys, 'MxNMViewerReleaseDecision(pressed, foregroundMatches, elapsedMs, timeoutMs) {', 'MxNMViewerModifierState() {'),
        section(diagnostics, 'NewerAutomationDiagnosticEvent(automationEvent, viewerEvent) {', 'AutomationDiagnosticLineField(line, fieldName, fallback := "") {'),
        section(diagnostics, 'AutomationDiagnosticStageList(stages) {', 'DefaultAutomationDiagnosticLogPath() {'),
        section(hotstrings, 'ReportColorResetDiagnosticFields(resetResult, performanceContext := 0) {', 'ExecuteReportTemplatePlan(plan, expectedReportHwnd, trace := 0) {'),
        section(report_diagnostics, 'PerformanceDuration(context, startKey, endKey) {', 'PerformanceDurationToFirstAvailable(context, startKey, endKeys) {'),
        section(report_diagnostics, 'MedExContextValue(context, key, defaultValue) {', 'FormatDiagnosticRect(rect) {'),
        tools.split('class MxNMViewerToolCommandProvider {', 1)[0],
        'ResolveMxNMViewerToolControlSet(' + tools.split('\nResolveMxNMViewerToolControlSet(', 1)[1],
        (ROOT / 'tests/windows/viewer_state_regression.ahk').read_text(encoding="utf-8"),
    ]
    return '\n\n'.join(parts)


if __name__ == '__main__':
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(build(), encoding='utf-8')
    print(OUTPUT)
