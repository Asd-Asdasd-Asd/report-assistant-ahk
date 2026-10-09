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
    parts = [
        '; Generated regression. Uses synthetic windows only; does not operate MedEx.',
        '#Requires AutoHotkey v2.0', '#SingleInstance Force', '#Warn',
        section(caption, 'class ReportImageCaptionDefaults {', 'class ReportImageCaptionCode {'),
        section(caption, 'class ReportImageCaptionPasteGate {', 'SetReportImageCaptionClipboard(payload) {'),
        section(hotkeys, 'MxNMViewerReleaseDecision(pressed, foregroundMatches, elapsedMs, timeoutMs) {', 'MxNMViewerModifierState() {'),
        section(diagnostics, 'FindRecentColorResetFailureEvent(lines) {', 'AutomationDiagnosticLineField(line, fieldName, fallback := "") {'),
        section(diagnostics, 'AutomationDiagnosticSafeValue(value) {', 'DefaultAutomationDiagnosticLogPath() {'),
        tools.split('class MxNMViewerToolCommandProvider {', 1)[0],
        'ResolveMxNMViewerToolControlSet(' + tools.split('\nResolveMxNMViewerToolControlSet(', 1)[1],
        (ROOT / 'tests/windows/viewer_state_regression.ahk').read_text(encoding="utf-8"),
    ]
    return '\n\n'.join(parts)


if __name__ == '__main__':
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(build(), encoding='utf-8')
    print(OUTPUT)
