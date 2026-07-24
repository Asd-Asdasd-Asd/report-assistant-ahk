#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\measurement_model.ahk
#Include ..\..\src\measurement_parser.ahk
#Include ..\..\src\measurement_clipboard.ahk

global NestedMeasurementCaptureResult := 0

RunMeasurementCaptureRegression()

RunMeasurementCaptureRegression() {
    AssertSuvMaxResult(
        ParseSuvMaxMeasurement("SUVMax: 3.599"),
        MeasurementState.FOUND,
        "3.6",
        "positive SUVMax"
    )
    AssertSuvMaxResult(
        ParseSuvMaxMeasurement("  SUVMax : 4  "),
        MeasurementState.FOUND,
        "4.0",
        "integer SUVMax"
    )
    AssertSuvMaxResult(
        ParseSuvMaxMeasurement("SUVMax: 0.000"),
        MeasurementState.NOT_ANNOTATED,
        "",
        "zero SUVMax"
    )
    for malformed in [
        "SUVMax: -1",
        "suvmax: 3.2",
        "SUVMax: 3.2 old",
        ""
    ] {
        result := ParseSuvMaxMeasurement(malformed)
        AssertMeasurement(
            result.state = MeasurementState.AUTOMATION_FAILED,
            "malformed state: " malformed
        )
        AssertMeasurement(
            result.failureReason = MeasurementFailureReason.UNEXPECTED_FORMAT,
            "malformed reason: " malformed
        )
    }

    A_Clipboard := "MEASUREMENT_ORIGINAL"
    capture := CaptureMeasurementClipboardText(
        () => SetMeasurementFixtureClipboard("SUVMax: 2.14"),
        Map(
            "clipboardTimeoutMs", 100,
            "clipboardPollIntervalMs", 5,
            "restoreSettleMs", 0
        )
    )
    AssertMeasurement(capture.ok, "fresh clipboard capture")
    AssertMeasurement(capture.rawText = "SUVMax: 2.14", "fresh raw text")
    AssertMeasurement(
        A_Clipboard = "MEASUREMENT_ORIGINAL",
        "fresh capture clipboard restore"
    )

    noUpdate := CaptureMeasurementClipboardText(
        () => true,
        Map(
            "clipboardTimeoutMs", 30,
            "clipboardPollIntervalMs", 5,
            "restoreSettleMs", 0
        )
    )
    AssertMeasurement(!noUpdate.ok, "no-update capture must fail")
    AssertMeasurement(
        noUpdate.failureReason = MeasurementFailureReason.CLIPBOARD_NOT_UPDATED,
        "no-update failure reason"
    )
    AssertMeasurement(
        A_Clipboard = "MEASUREMENT_ORIGINAL",
        "no-update clipboard restore"
    )

    global NestedMeasurementCaptureResult
    outerCapture := CaptureMeasurementClipboardText(
        RunNestedMeasurementCapture,
        Map(
            "clipboardTimeoutMs", 100,
            "clipboardPollIntervalMs", 5,
            "restoreSettleMs", 0
        )
    )
    AssertMeasurement(outerCapture.ok, "outer capture")
    AssertMeasurement(
        IsObject(NestedMeasurementCaptureResult)
            && NestedMeasurementCaptureResult.failureReason
                = MeasurementFailureReason.PROVIDER_BUSY,
        "nested capture must fail busy"
    )
    AssertMeasurement(
        A_Clipboard = "MEASUREMENT_ORIGINAL",
        "nested clipboard restore"
    )

    MsgBox "Measurement capture regression passed.", "MedEx test", "Iconi"
    ExitApp 0
}

SetMeasurementFixtureClipboard(text) {
    A_Clipboard := text
    return true
}

RunNestedMeasurementCapture() {
    global NestedMeasurementCaptureResult
    NestedMeasurementCaptureResult := CaptureMeasurementClipboardText(
        () => SetMeasurementFixtureClipboard("SUVMax: 9.9"),
        Map("clipboardTimeoutMs", 20, "restoreSettleMs", 0)
    )
    A_Clipboard := "SUVMax: 1.0"
    return true
}

AssertSuvMaxResult(result, expectedState, expectedFormatted, label) {
    AssertMeasurement(result.state = expectedState, label " state")
    AssertMeasurement(
        result.formattedValue = expectedFormatted,
        label " formatted value"
    )
}

AssertMeasurement(condition, message) {
    if !condition
        throw Error(message)
}
