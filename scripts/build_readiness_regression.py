"""Build synthetic Windows regressions without operating MedEx or its clipboard."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "tests/windows/generated/readiness_regression_standalone.ahk"


def between(text, start, end):
    return start + text.split(start, 1)[1].split(end, 1)[0]


def build():
    clipboard = (ROOT / "src/measurement_clipboard.ahk").read_text()
    model = (ROOT / "src/measurement_model.ahk").read_text()
    provider = (ROOT / "src/context_measurement_provider.ahk").read_text()
    # Substitute only the clipboard read boundary. The polling/empty/error
    # control flow is the production function, not a Python reimplementation.
    wait = clipboard.split("WaitForMeasurementClipboardUpdate(sequenceBeforeCommand,", 1)[1]
    wait = "WaitForMeasurementClipboardUpdate(sequenceBeforeCommand," + wait
    wait = wait.replace("rawText := A_Clipboard", "rawText := ReadTestClipboard()")
    return "\n\n".join([
        "; Generated synthetic regression; never operates MedEx.",
        "#Requires AutoHotkey v2.0\n#SingleInstance Off\n#Warn",
        between(model, "class MeasurementFailureReason {", "class MeasurementCommandSpec {"),
        between(clipboard, "class MeasurementClipboardDefaults {", "CaptureMeasurementClipboardText("),
        wait,
        between(provider, "InvokePreparedMxNMContextCommand(actionContext, asynchronous := false) {",
                "PackContextMeasurementClientPoint("),
        (ROOT / "tests/windows/readiness_regression.ahk").read_text(),
    ])


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(build(), encoding="utf-8")
    print(OUTPUT)
