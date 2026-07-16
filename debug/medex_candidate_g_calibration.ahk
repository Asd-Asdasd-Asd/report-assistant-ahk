#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; Candidate G1 calibration only. This script never clicks the black swatch and
; never registers production hotstrings.
#Include ..\src\app_metadata.ahk
#Include ..\src\config.example.ahk
#Include ..\src\window_guard.ahk
#Include ..\src\utils.ahk
#Include ..\src\Lib\UIA.ahk
#Include ..\src\clipboard_html.ahk
#Include ..\src\medex_color_reset_logic.ahk
#Include ..\src\medex_candidate_g_logic.ahk
#Include ..\src\diagnostics.ahk
#Include ..\src\adapters\medex_report_editor.ahk

CANDIDATE_G_RESULT_FILE := A_Temp "\MedExAHK\candidate_g_calibration.txt"
CANDIDATE_G_PINNED_UIA_VERSION := "v1.1.3"
CANDIDATE_G_LAST_OBSERVED_ARROW_POINT := 0

A_IconTip := "MedEx Candidate G1 Calibration"

; Capture the current pointer as the manually observed arrow center.
F8::CaptureCandidateGObservedArrow()

; Capture the current pointer as the manually observed black-swatch center.
; The script does not click it.
F9::CaptureCandidateGObservedBlack()

; Read the closed-state pixel probe grid without clicking.
F10::RunCandidateGClosedPixelProbe()

; Click the validated estimated arrow once and sample at 0/20/40/80 ms.
; The script never clicks black.
F11::RunCandidateGOpenPixelProbe()

CaptureCandidateGObservedArrow() {
    global CANDIDATE_G_LAST_OBSERVED_ARROW_POINT
    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY
    prepared := PrepareCandidateGCalibration()
    if !prepared.ok {
        WriteCandidateGCalibrationResult(prepared)
        return
    }

    observed := Map("x", mouseX, "y", mouseY)
    CANDIDATE_G_LAST_OBSERVED_ARROW_POINT := observed
    regionRect := prepared.context["regionAnchorRect"]
    prepared.context["observedArrowPoint"] := observed
    prepared.context["calculatedArrowOffsetX"] := mouseX - regionRect["r"]
    prepared.context["calculatedArrowOffsetY"] := mouseY - Round(RectCenterY(regionRect))
    prepared.context["calibrationAction"] := "captureObservedArrow"
    WriteCandidateGCalibrationResult(prepared)
}

CaptureCandidateGObservedBlack() {
    global CANDIDATE_G_LAST_OBSERVED_ARROW_POINT
    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY
    context := NewCandidateGCalibrationContext("captureObservedBlack")
    context["observedBlackPoint"] := Map("x", mouseX, "y", mouseY)
    context["blackClickSent"] := false
    if Type(CANDIDATE_G_LAST_OBSERVED_ARROW_POINT) != "Map" {
        context["calibrationReason"] := "observedArrowPointNotCaptured"
        WriteCandidateGCalibrationResult(
            MakeCandidateGResult(false, CandidateGCalibrationCode.INVALID_GEOMETRY, context)
        )
        return
    }

    context["observedArrowPoint"] := CANDIDATE_G_LAST_OBSERVED_ARROW_POINT
    context["calculatedBlackOffsetX"] := mouseX - CANDIDATE_G_LAST_OBSERVED_ARROW_POINT["x"]
    context["calculatedBlackOffsetY"] := mouseY - CANDIDATE_G_LAST_OBSERVED_ARROW_POINT["y"]
    WriteCandidateGCalibrationResult(
        MakeCandidateGResult(true, CandidateGCalibrationCode.ROW_OK, context)
    )
}

RunCandidateGClosedPixelProbe() {
    prepared := PrepareCandidateGCalibration()
    if !prepared.ok {
        WriteCandidateGCalibrationResult(prepared)
        return
    }
    prepared.context["calibrationAction"] := "closedPixelProbe"
    prepared.context["popupProbeState"] := "closed"
    prepared.context["popupSignatureSampleCount"] := 1
    prepared.context["pixelProbeSamples"] := SampleCandidateGPixelGrid(
        prepared.context["estimatedArrowPoint"],
        0
    )
    WriteCandidateGCalibrationResult(prepared)
}

RunCandidateGOpenPixelProbe() {
    prepared := PrepareCandidateGCalibration()
    if !prepared.ok {
        WriteCandidateGCalibrationResult(prepared)
        return
    }

    context := prepared.context
    context["calibrationAction"] := "openPixelProbe"
    context["popupProbeState"] := "openAttempt"
    context["arrowClickSent"] := false
    context["blackClickSent"] := false
    foregroundHwnd := prepared.foregroundHwnd
    foregroundProcess := prepared.foregroundProcess
    arrowPoint := context["estimatedArrowPoint"]
    CoordMode "Mouse", "Screen"
    MouseGetPos &originalMouseX, &originalMouseY
    outputResult := prepared
    try {
        if !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
            context["foregroundGuardReason"] := "foregroundChangedBeforeCandidateGArrowClick"
            outputResult := MakeCandidateGResult(
                false,
                ColorResetCode.FOREGROUND_CHANGED,
                context
            )
        } else {
            Click arrowPoint["x"], arrowPoint["y"]
            context["arrowClickSent"] := true
            context["arrowClickCount"] := 1
            samples := []
            previousTargetMs := 0
            for targetMs in [0, 20, 40, 80] {
                delayMs := targetMs - previousTargetMs
                if delayMs > 0
                    Sleep delayMs
                samples.Push(SampleCandidateGPixelGrid(arrowPoint, targetMs))
                previousTargetMs := targetMs
            }
            context["popupSignatureSampleCount"] := samples.Length
            context["pixelProbeSamples"] := FlattenCandidateGProbeSamples(samples)
        }
    } catch as err {
        AddSafeExceptionContext(context, err)
        outputResult := MakeCandidateGResult(
            false,
            ColorResetCode.TRIGGER_CLICK_FAILED,
            context
        )
    } finally {
        try {
            MouseMove originalMouseX, originalMouseY, 0
            context["mouseRestored"] := true
        } catch {
            context["mouseRestored"] := false
        }
    }
    WriteCandidateGCalibrationResult(outputResult)
}

PrepareCandidateGCalibration() {
    startedAt := A_TickCount
    context := NewCandidateGCalibrationContext("prepare")
    foregroundHwnd := WinExist("A")
    context["foregroundWindowHandle"] := foregroundHwnd
        ? Format("0x{:X}", foregroundHwnd)
        : "UNKNOWN"
    if !foregroundHwnd {
        context["foregroundGuardReason"] := "noForegroundWindow"
        return FinishCandidateGPreparation(false, ColorResetCode.WRONG_PROCESS,
            context, startedAt)
    }

    try foregroundProcess := WinGetProcessName("ahk_id " foregroundHwnd)
    catch as err {
        AddSafeExceptionContext(context, err)
        context["foregroundGuardReason"] := "processLookupFailed"
        return FinishCandidateGPreparation(false, ColorResetCode.WRONG_PROCESS,
            context, startedAt)
    }
    context["foregroundProcess"] := foregroundProcess
    if !MedExProcessNameIsApproved(
        foregroundProcess,
        MedExColorResetDefaults.ProvisionalProcessNames
    ) {
        context["foregroundGuardReason"] := "notInProvisionalCandidateList"
        return FinishCandidateGPreparation(false, ColorResetCode.WRONG_PROCESS,
            context, startedAt)
    }

    environmentContext := Map()
    CollectMedExEnvironmentContext(foregroundHwnd, environmentContext)
    context["resolution"] := MedExContextValue(environmentContext, "resolution", "UNKNOWN")
    context["dpi"] := MedExContextValue(environmentContext, "dpi", "UNKNOWN")
    context["displayScaling"] := MedExContextValue(environmentContext, "displayScaling", "UNKNOWN")
    context["medExVersion"] := MedExContextValue(environmentContext, "medExVersion", "UNKNOWN")
    environment := Map(
        "medExVersion", context["medExVersion"],
        "screenWidth", A_ScreenWidth,
        "screenHeight", A_ScreenHeight,
        "dpi", context["dpi"],
        "displayScaling", context["displayScaling"]
    )
    profileResult := ValidateCandidateGSupportedProfile(environment)
    MergeContext(context, profileResult.context)
    if !profileResult.ok
        return FinishCandidateGPreparation(false, profileResult.code, context, startedAt)

    global UIA
    try windowElement := UIA.ElementFromHandle(foregroundHwnd)
    catch as err {
        AddSafeExceptionContext(context, err)
        return FinishCandidateGPreparation(false, ColorResetCode.UIA_UNAVAILABLE,
            context, startedAt)
    }
    clientRectScreen := GetClientRectScreenMap(foregroundHwnd)
    context["clientRectScreen"] := clientRectScreen

    queryStartedAt := A_TickCount
    try regionElements := windowElement.FindElements({
        Type: "Text",
        Name: CandidateGCalibrationProfile.RegionAnchorName
    })
    catch as err {
        AddSafeExceptionContext(context, err)
        return FinishCandidateGPreparation(false, ColorResetCode.UIA_UNAVAILABLE,
            context, startedAt)
    }
    context["regionExactQueryDurationMs"] := A_TickCount - queryStartedAt
    regionConversion := UiaTextElementsToAnchors(regionElements, false)
    textAnchors := regionConversion.anchors
    context["regionExactPropertyReadFailureCount"] := regionConversion.propertyReadFailureCount

    ; Corroborators are collected only when exact region candidates are not
    ; already unique. This keeps the common G1 path narrow and measurable.
    context["corroboratorSnapshotCollected"] := false
    if textAnchors.Length > 1 {
        corroboratorSnapshot := CollectMedExTextAnchorSnapshot(windowElement, false)
        textAnchors := corroboratorSnapshot.anchors
        context["corroboratorSnapshotCollected"] := true
        MergeContext(context, corroboratorSnapshot.context)
    }

    rowResult := ResolveCandidateGToolbarRow(textAnchors, clientRectScreen)
    MergeContext(context, rowResult.context)
    if !rowResult.ok
        return FinishCandidateGPreparation(false, rowResult.code, context, startedAt)

    context["blackClickSent"] := false
    context["elapsedMs"] := A_TickCount - startedAt
    return {
        ok: true,
        code: rowResult.code,
        context: context,
        selectedRegionAnchor: rowResult.selectedRegionAnchor,
        foregroundHwnd: foregroundHwnd,
        foregroundProcess: foregroundProcess
    }
}

FinishCandidateGPreparation(ok, code, context, startedAt) {
    context["blackClickSent"] := false
    context["elapsedMs"] := A_TickCount - startedAt
    result := MakeCandidateGResult(ok, code, context)
    result.DefineProp("foregroundHwnd", {Value: 0})
    result.DefineProp("foregroundProcess", {Value: "UNKNOWN"})
    return result
}

NewCandidateGCalibrationContext(action) {
    return Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "appVersion", AppMetadata.Version,
        "sourceRevision", AppMetadata.SourceRevision,
        "test", "MedExCandidateG1Calibration",
        "calibrationAction", action,
        "candidateGProfileName", CandidateGCalibrationProfile.ProfileName,
        "arrowClickSent", false,
        "arrowClickCount", 0,
        "blackClickSent", false,
        "popupSignatureSampleCount", 0,
        "pixelProbeSamples", []
    )
}

SampleCandidateGPixelGrid(arrowPoint, sampleTimeMs) {
    samples := []
    for offsetX in [-4, 6, 20, 40, 64] {
        for offsetY in [4, 16, 32, 48, 64, 83, 96] {
            screenX := arrowPoint["x"] + offsetX
            screenY := arrowPoint["y"] + offsetY
            try color := PixelGetColor(screenX, screenY, "RGB")
            catch
                color := "UNKNOWN"
            colorText := IsNumber(color) ? Format("#{:06X}", color & 0xFFFFFF) : color
            samples.Push(
                "t=" sampleTimeMs
                . ",dx=" offsetX
                . ",dy=" offsetY
                . ",x=" screenX
                . ",y=" screenY
                . ",rgb=" colorText
            )
        }
    }
    return samples
}

FlattenCandidateGProbeSamples(sampleSets) {
    flattened := []
    for sampleSet in sampleSets {
        for sample in sampleSet
            flattened.Push(sample)
    }
    return flattened
}

FormatCandidateGCalibrationResult(result) {
    context := result.context
    fields := [
        "Test=MedExCandidateG1Calibration",
        "AppVersion=" SafeDiagnosticValue(MedExContextValue(context, "appVersion", "UNKNOWN")),
        "SourceRevision=" SafeDiagnosticValue(MedExContextValue(context, "sourceRevision", "UNKNOWN")),
        "Timestamp=" SafeDiagnosticValue(MedExContextValue(context, "timestamp", "UNKNOWN")),
        "ResultCode=" SafeDiagnosticValue(result.code),
        "CalibrationAction=" SafeDiagnosticValue(MedExContextValue(context, "calibrationAction", "UNKNOWN")),
        "CandidateGProfileName=" SafeDiagnosticValue(MedExContextValue(context, "candidateGProfileName", "UNKNOWN")),
        "SupportedProfile=" FormatDiagnosticBoolean(MedExContextValue(context, "supportedProfile", false)),
        "UnsupportedProfileReason=" SafeDiagnosticValue(MedExContextValue(context, "unsupportedProfileReason", "")),
        "Process=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "WindowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "Resolution=" SafeDiagnosticValue(MedExContextValue(context, "resolution", "UNKNOWN")),
        "Dpi=" SafeDiagnosticValue(MedExContextValue(context, "dpi", "UNKNOWN")),
        "DisplayScaling=" SafeDiagnosticValue(MedExContextValue(context, "displayScaling", "UNKNOWN")),
        "MedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "RawRegionAnchorCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "rawRegionAnchorCandidateCount", 0)),
        "GeometryValidRegionCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "geometryValidRegionCandidateCount", 0)),
        "ToolbarRowCorroborationCount=" SafeDiagnosticValue(MedExContextValue(context, "toolbarRowCorroborationCount", 0)),
        "ToolbarRowSelectionReason=" SafeDiagnosticValue(MedExContextValue(context, "toolbarRowSelectionReason", "")),
        "RegionCandidateIgnoredReasons=" FormatDiagnosticList(MedExContextValue(context, "regionCandidateIgnoredReasons", [])),
        "RegionAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "regionAnchorRect", 0)),
        "EstimatedArrowPoint=" FormatDiagnosticPoint(MedExContextValue(context, "estimatedArrowPoint", 0)),
        "EstimatedBlackPoint=" FormatDiagnosticPoint(MedExContextValue(context, "estimatedBlackPoint", 0)),
        "ObservedArrowPoint=" FormatDiagnosticPoint(MedExContextValue(context, "observedArrowPoint", 0)),
        "ObservedBlackPoint=" FormatDiagnosticPoint(MedExContextValue(context, "observedBlackPoint", 0)),
        "CalculatedArrowOffsetX=" SafeDiagnosticValue(MedExContextValue(context, "calculatedArrowOffsetX", "UNKNOWN")),
        "CalculatedArrowOffsetY=" SafeDiagnosticValue(MedExContextValue(context, "calculatedArrowOffsetY", "UNKNOWN")),
        "CalculatedBlackOffsetX=" SafeDiagnosticValue(MedExContextValue(context, "calculatedBlackOffsetX", "UNKNOWN")),
        "CalculatedBlackOffsetY=" SafeDiagnosticValue(MedExContextValue(context, "calculatedBlackOffsetY", "UNKNOWN")),
        "RegionExactQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "regionExactQueryDurationMs", "UNKNOWN")),
        "CorroboratorSnapshotCollected=" FormatDiagnosticBoolean(MedExContextValue(context, "corroboratorSnapshotCollected", false)),
        "ArrowClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "arrowClickSent", false)),
        "ArrowClickCount=" SafeDiagnosticValue(MedExContextValue(context, "arrowClickCount", 0)),
        "PopupSignatureSampleCount=" SafeDiagnosticValue(MedExContextValue(context, "popupSignatureSampleCount", 0)),
        "BlackClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "blackClickSent", false)),
        "MouseRestored=" FormatDiagnosticBoolean(MedExContextValue(context, "mouseRestored", false)),
        "ForegroundGuardReason=" SafeDiagnosticValue(MedExContextValue(context, "foregroundGuardReason", "")),
        "PixelProbeSamples=" FormatDiagnosticList(MedExContextValue(context, "pixelProbeSamples", [])),
        "ElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN"))
    ]
    return JoinDiagnosticFields(fields, "`r`n") "`r`n"
}

WriteCandidateGCalibrationResult(result) {
    global CANDIDATE_G_RESULT_FILE
    output := FormatCandidateGCalibrationResult(result)
    A_Clipboard := output
    ClipWait(1)
    try {
        SplitPath CANDIDATE_G_RESULT_FILE, , &resultDirectory
        if resultDirectory != "" && !DirExist(resultDirectory)
            DirCreate resultDirectory
        FileAppend "---`r`n" output, CANDIDATE_G_RESULT_FILE, "UTF-8"
    }
}
