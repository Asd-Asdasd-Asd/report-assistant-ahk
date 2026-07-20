class MedExColorResetDefaults {
    ; Both names remain provisional until the target workstation confirms the executable.
    static ProvisionalProcessNames := [
        "medexworkstation.exe",
        "medexworkstations.exe"
    ]
    static ConfirmedProcessName := ""
    static AllowProvisionalProcess := true
    static ColorResetStrategy := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED

    ; Field-validated control semantics: one trigger click followed by bounded
    ; adaptive polling for the exact black item.
    static MenuLookupStrategy := "adaptivePolling"
    static MenuOpenTimeoutMs := 600
    static MenuPollIntervalMs := 40

    ; Experimental fixed-attempt strategy. It is never the production default.
    static BlackLookupRetryDelayMs := 20
    static BlackLookupMaxAttempts := 2
    static MenuPreLookupSettleMs := 0

    ; Anchor experiments are independently switchable for single-variable A/B tests.
    static UseCachedAnchorSnapshot := false
    static EnableFontAnchorRetry := false
    static FontAnchorRetryDelayMs := 20

}

ResetMedExInsertionColor(options := 0) {
    selectedStrategy := MedExAdapterOption(
        options,
        "colorResetStrategy",
        MedExColorResetDefaults.ColorResetStrategy
    )
    if selectedStrategy = MedExColorResetStrategy.UIA_INVOKE
        return RunMedExUiaInvokeColorReset(options)

    if selectedStrategy = MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED
        return RunMedExRelativeMousePixelValidatedColorReset(options)

    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "appVersion", AppMetadata.Version,
        "colorResetStrategy", selectedStrategy,
        "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED"
    )
    context["strategyReason"] := "unknownColorResetStrategy"
    return MakeColorResetResult(false, ColorResetCode.UNKNOWN_STRATEGY, context)
}

RunMedExRelativeMousePixelValidatedColorReset(options := 0) {
    startedAt := A_TickCount
    performanceContext := MedExAdapterOption(options, "performanceContext", 0)
    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "appVersion", AppMetadata.Version,
        "colorResetStrategy", MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED,
        "candidateGProfileName", CandidateGRelativeMouseProfile.ProfileName,
        "foregroundProcess", "UNKNOWN",
        "foregroundWindowHandle", "UNKNOWN",
        "supportedProfile", false,
        "arrowClickSent", false,
        "arrowClickCount", 0,
        "popupSignatureMatched", false,
        "popupSignatureSampleCount", 0,
        "blackClickSent", false,
        "blackClickCount", 0,
        "mouseRestored", false,
        "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED",
        "finalValidationState", "FINAL_COLOR_PENDING_VISUAL_VALIDATION",
        "finalInsertionColorVisuallyValidated", false
    )
    mouseCaptured := false

    try {
        foregroundHwnd := WinExist("A")
        context["foregroundWindowHandle"] := foregroundHwnd
            ? Format("0x{:X}", foregroundHwnd)
            : "UNKNOWN"
        if !foregroundHwnd {
            context["foregroundGuardReason"] := "noForegroundWindow"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS,
                context, startedAt, options)
        }
        try foregroundProcess := WinGetProcessName("ahk_id " foregroundHwnd)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["foregroundGuardReason"] := "processLookupFailed"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS,
                context, startedAt, options)
        }
        context["foregroundProcess"] := foregroundProcess
        provisionalNames := MedExAdapterOption(
            options,
            "processCandidates",
            MedExColorResetDefaults.ProvisionalProcessNames
        )
        if !MedExProcessNameIsApproved(foregroundProcess, provisionalNames) {
            context["foregroundGuardReason"] := "notInProvisionalCandidateList"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS,
                context, startedAt, options)
        }

        environmentContext := Map()
        CollectMedExEnvironmentContext(foregroundHwnd, environmentContext)
        MergeContext(context, environmentContext)
        environment := Map(
            "medExVersion", MedExContextValue(context, "medExVersion", "UNKNOWN"),
            "screenWidth", A_ScreenWidth,
            "screenHeight", A_ScreenHeight,
            "dpi", MedExContextValue(context, "dpi", "UNKNOWN"),
            "displayScaling", MedExContextValue(context, "displayScaling", "UNKNOWN")
        )
        profileResult := ValidateCandidateGRuntimeProfile(environment, options)
        MergeContext(context, profileResult.context)
        if !profileResult.ok
            return FinishMedExColorReset(false, profileResult.code,
                context, startedAt, options)

        global UIA
        if !IsSet(UIA) {
            context["uiaReason"] := "UIA-v2NotIncluded"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE,
                context, startedAt, options)
        }
        try windowElement := UIA.ElementFromHandle(foregroundHwnd)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["uiaReason"] := "ElementFromHandleFailed"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE,
                context, startedAt, options)
        }

        clientRectScreen := GetClientRectScreenMap(foregroundHwnd)
        context["clientRectScreen"] := clientRectScreen
        queryStartedAt := A_TickCount
        try regionElements := windowElement.FindElements({
            Type: "Text",
            Name: CandidateGRelativeMouseProfile.RegionAnchorName
        })
        catch as err {
            AddSafeExceptionContext(context, err)
            context["uiaReason"] := "RegionExactQueryFailed"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE,
                context, startedAt, options)
        }
        context["regionExactQueryDurationMs"] := A_TickCount - queryStartedAt
        conversion := UiaTextElementsToAnchors(regionElements, false)
        textAnchors := conversion.anchors
        context["regionExactPropertyReadFailureCount"] := conversion.propertyReadFailureCount
        context["corroboratorSnapshotCollected"] := false
        if textAnchors.Length > 1 {
            corroboratorSnapshot := CollectMedExTextAnchorSnapshot(windowElement, false)
            textAnchors := corroboratorSnapshot.anchors
            context["corroboratorSnapshotCollected"] := true
            MergeContext(context, corroboratorSnapshot.context)
        }

        layoutOptions := BuildCandidateGRuntimeLayoutOptions(options)
        rowResult := ResolveCandidateGToolbarRow(textAnchors, clientRectScreen, layoutOptions)
        MergeContext(context, rowResult.context)
        if !rowResult.ok
            return FinishMedExColorReset(false, CandidateGRowFailureCode(rowResult.code),
                context, startedAt, options)

        arrowPoint := context["estimatedArrowPoint"]
        blackPoint := context["estimatedBlackPoint"]
        context["arrowPoint"] := arrowPoint
        context["blackPoint"] := blackPoint
        if !RectContainsPoint(clientRectScreen, arrowPoint)
            return FinishMedExColorReset(false, ColorResetCode.INVALID_ARROW_POINT,
                context, startedAt, options)
        if !RectContainsPoint(clientRectScreen, blackPoint)
            return FinishMedExColorReset(false, ColorResetCode.INVALID_BLACK_POINT,
                context, startedAt, options)

        CoordMode "Mouse", "Screen"
        MouseGetPos &originalMouseX, &originalMouseY
        mouseCaptured := true
        if !MedExForegroundWindowMatches(foregroundHwnd) {
            context["foregroundGuardReason"] := "foregroundChangedBeforeCandidateGArrowClick"
            return FinishMedExColorReset(false, ColorResetCode.FOREGROUND_CHANGED,
                context, startedAt, options)
        }
        skipArrowClickForClosedSignatureTest := MedExAdapterOption(
            options,
            "candidateGSkipArrowClickForClosedSignatureTest",
            false
        ) = true
        context["closedSignatureTestMode"] := skipArrowClickForClosedSignatureTest
        if !skipArrowClickForClosedSignatureTest {
            try {
                Click arrowPoint["x"], arrowPoint["y"]
                RecordOptionalPerformanceTimestamp(
                    performanceContext,
                    "ArrowClickSentMs"
                )
                context["arrowClickSent"] := true
                context["arrowClickCount"] := 1
            } catch as err {
                AddSafeExceptionContext(context, err)
                return FinishMedExColorReset(false, ColorResetCode.TRIGGER_CLICK_FAILED,
                    context, startedAt, options)
            }
        }

        signature := SampleAndEvaluateCandidateGPopupSignature(arrowPoint)
        context["popupSignatureSampleCount"] := 1
        context["popupSignatureFirstReason"] := signature["reason"]
        context["popupSignatureFirstSamples"] := signature["samples"]
        if !signature["matched"] {
            delayMs := Max(0, Min(100, Integer(MedExAdapterOption(
                options,
                "signatureSecondSampleDelayMs",
                CandidateGRelativeMouseProfile.SignatureSecondSampleDelayMs
            ))))
            context["signatureSecondSampleDelayMs"] := delayMs
            if delayMs > 0
                Sleep delayMs
            if !MedExForegroundWindowMatches(foregroundHwnd) {
                context["foregroundGuardReason"] := "foregroundChangedBeforeCandidateGSecondSignatureSample"
                return FinishMedExColorReset(false, ColorResetCode.FOREGROUND_CHANGED,
                    context, startedAt, options)
            }
            signature := SampleAndEvaluateCandidateGPopupSignature(arrowPoint)
            context["popupSignatureSampleCount"] := 2
            context["popupSignatureSecondReason"] := signature["reason"]
            context["popupSignatureSecondSamples"] := signature["samples"]
        }
        context["popupSignatureMatched"] := signature["matched"]
        context["popupSignatureReason"] := signature["reason"]
        if !signature["matched"]
            return FinishMedExColorReset(false, ColorResetCode.POPUP_SIGNATURE_MISMATCH,
                context, startedAt, options)

        if !MedExForegroundWindowMatches(foregroundHwnd) {
            context["foregroundGuardReason"] := "foregroundChangedBeforeCandidateGBlackClick"
            return FinishMedExColorReset(false, ColorResetCode.FOREGROUND_CHANGED,
                context, startedAt, options)
        }
        try {
            Click blackPoint["x"], blackPoint["y"]
            RecordOptionalPerformanceTimestamp(
                performanceContext,
                "BlackClickSentMs"
            )
            context["blackClickSent"] := true
            context["blackClickCount"] := 1
        } catch as err {
            AddSafeExceptionContext(context, err)
            return FinishMedExColorReset(false, ColorResetCode.BLACK_CLICK_FAILED,
                context, startedAt, options)
        }
        context["automationChainResult"] := ColorResetCode.RELATIVE_MOUSE_CHAIN_OK
        return FinishMedExColorReset(true, ColorResetCode.RELATIVE_MOUSE_CHAIN_OK,
            context, startedAt, options)
    } catch as err {
        AddSafeExceptionContext(context, err)
        return FinishMedExColorReset(false, ColorResetCode.UNEXPECTED_ERROR,
            context, startedAt, options)
    } finally {
        if mouseCaptured {
            try {
                MouseMove originalMouseX, originalMouseY, 0
                context["mouseRestored"] := true
            } catch {
                context["mouseRestored"] := false
            }
        }
    }
}

SampleAndEvaluateCandidateGPopupSignature(arrowPoint) {
    samples := CandidateGPopupSignatureSample(arrowPoint)
    evaluation := EvaluateCandidateGPopupSignature(samples)
    evaluation["samples"] := samples
    return evaluation
}

CandidateGRowFailureCode(candidateCode) {
    if candidateCode = CandidateGCalibrationCode.REGION_NOT_FOUND
        return ColorResetCode.REGION_ANCHOR_NOT_FOUND
    if candidateCode = CandidateGCalibrationCode.REGION_AMBIGUOUS
        return ColorResetCode.REGION_ANCHOR_AMBIGUOUS
    return ColorResetCode.INVALID_GEOMETRY
}

RunMedExUiaInvokeColorReset(options := 0) {
    startedAt := A_TickCount
    performanceContext := MedExAdapterOption(options, "performanceContext", 0)
    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "appVersion", AppMetadata.Version,
        "colorResetStrategy", MedExColorResetStrategy.UIA_INVOKE,
        "foregroundProcess", "UNKNOWN",
        "foregroundWindowHandle", "UNKNOWN",
        "provisionalProcessCandidateAccepted", false,
        "processNameConfirmed", false,
        "documentFound", false,
        "regionAnchorFound", false,
        "fontSizeAnchorFound", false,
        "optionalRightAnchorFound", false,
        "colorMenuClickSent", false,
        "blackColorFound", false,
        "blackItemFound", false,
        "invokeAvailable", false,
        "invokeSucceeded", false,
        "blackItemInvokeSucceeded", false,
        "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED",
        "finalInsertionColorVisuallyValidated", false,
        "retryCount", 0,
        "fontAnchorRetryEligible", false,
        "fontAnchorRetryEnabled", false,
        "fontAnchorRetryUsed", false,
        "anchorSnapshotAttemptCount", 0,
        "uiaLibrary", "UIA-v2",
        "uiaLibraryVersionPinned", MedExAdapterOption(options, "uiaLibraryVersionPinned", "UNKNOWN"),
        "uiaLibraryVersionRuntime", "UNKNOWN"
    )

    try {
        foregroundHwnd := WinExist("A")
        context["foregroundWindowHandle"] := foregroundHwnd ? Format("0x{:X}", foregroundHwnd) : "UNKNOWN"
        if !foregroundHwnd {
            context["processReason"] := "noForegroundWindow"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS, context, startedAt, options)
        }

        try foregroundProcess := WinGetProcessName("ahk_id " foregroundHwnd)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["processReason"] := "foregroundProcessLookupFailed"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS, context, startedAt, options)
        }

        context["foregroundProcess"] := foregroundProcess
        provisionalNames := MedExAdapterOption(
            options,
            "processCandidates",
            MedExColorResetDefaults.ProvisionalProcessNames
        )
        if !MedExProcessNameIsApproved(foregroundProcess, provisionalNames) {
            context["processReason"] := "notInProvisionalCandidateList"
            return FinishMedExColorReset(false, ColorResetCode.WRONG_PROCESS, context, startedAt, options)
        }
        context["provisionalProcessCandidateAccepted"] := true

        confirmedProcessName := MedExAdapterOption(
            options,
            "confirmedProcessName",
            MedExColorResetDefaults.ConfirmedProcessName
        )
        allowProvisionalProcess := MedExAdapterOption(
            options,
            "allowProvisionalProcess",
            MedExColorResetDefaults.AllowProvisionalProcess
        )
        if confirmedProcessName != "" && StrLower(foregroundProcess) = StrLower(confirmedProcessName) {
            context["processNameConfirmed"] := true
        } else if !allowProvisionalProcess {
            context["processReason"] := confirmedProcessName = ""
                ? "targetWorkstationProcessNameNotConfirmed"
                : "foregroundProcessDoesNotMatchConfirmedName"
            return FinishMedExColorReset(
                false,
                ColorResetCode.PROCESS_NAME_UNCONFIRMED,
                context,
                startedAt,
                options
            )
        }

        diagnosticMode := MedExAdapterOption(options, "diagnosticMode", "production")
        if diagnosticMode = "field"
            CollectMedExEnvironmentContext(foregroundHwnd, context)

        global UIA
        if !IsSet(UIA) {
            context["uiaReason"] := "UIA-v2NotIncluded"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
        }

        try context["uiaInterfaceVersion"] := UIA.IUIAutomationVersion
        catch
            context["uiaInterfaceVersion"] := "UNKNOWN"
        try context["uiaLibraryVersionRuntime"] := UIA.Version
        catch
            context["uiaLibraryVersionRuntime"] := "UNKNOWN"

        lookupStartedAt := A_TickCount
        try windowElement := UIA.ElementFromHandle(foregroundHwnd)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["uiaReason"] := "ElementFromHandleFailed"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
        }

        try context["uiaRootRect"] := UiaRectangleToMap(windowElement.BoundingRectangle)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["invalidRectangle"] := "uiaRootRect"
            return FinishMedExColorReset(false, ColorResetCode.INVALID_RECTANGLE, context, startedAt, options)
        }

        documentElement := FindMedExDocument(windowElement, foregroundHwnd, context)
        if !documentElement {
            context["uiaReason"] := "reportDocumentNotFoundInForegroundWindow"
            return FinishMedExColorReset(false, ColorResetCode.DOCUMENT_NOT_FOUND, context, startedAt, options)
        }
        context["documentFound"] := true
        try context["documentRect"] := UiaRectangleToMap(documentElement.BoundingRectangle)
        catch
            context["documentRect"] := "UNKNOWN"

        windowRect := GetWindowRectMap(foregroundHwnd)
        clientRectScreen := GetClientRectScreenMap(foregroundHwnd)
        context["windowRect"] := windowRect
        context["clientRectScreen"] := clientRectScreen

        layoutOptions := BuildMedExColorResetLayoutOptions(options)
        useCachedAnchorSnapshot := MedExAdapterOption(
            options,
            "useCachedAnchorSnapshot",
            MedExColorResetDefaults.UseCachedAnchorSnapshot
        ) = true
        context["useCachedAnchorSnapshot"] := useCachedAnchorSnapshot
        try anchorSnapshot := CollectMedExTextAnchorSnapshot(
            windowElement,
            useCachedAnchorSnapshot
        )
        catch as err {
            AddSafeExceptionContext(context, err)
            context["uiaReason"] := "TextElementSnapshotFailed"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
        }
        context["anchorSnapshotAttemptCount"] := 1
        MergeContext(context, anchorSnapshot.context)

        layoutResult := ResolveMedExColorResetLayout(anchorSnapshot.anchors, clientRectScreen, layoutOptions)
        MergeContext(context, layoutResult.context)
        retryEligible := !layoutResult.ok
            && layoutResult.code = ColorResetCode.FONT_SIZE_ANCHOR_NOT_FOUND
            && MedExContextValue(layoutResult.context, "rawFontSizePatternMatchCount", 0) = 0
        context["fontAnchorRetryEligible"] := retryEligible
        enableFontAnchorRetry := MedExAdapterOption(
            options,
            "enableFontAnchorRetry",
            MedExColorResetDefaults.EnableFontAnchorRetry
        ) = true
        context["fontAnchorRetryEnabled"] := enableFontAnchorRetry

        if retryEligible && enableFontAnchorRetry {
            retryDelayMs := MedExAdapterOption(
                options,
                "fontAnchorRetryDelayMs",
                MedExColorResetDefaults.FontAnchorRetryDelayMs
            )
            retryDelayMs := Max(0, Min(100, Integer(retryDelayMs)))
            context["fontAnchorRetryUsed"] := true
            context["fontAnchorRetryDelayMs"] := retryDelayMs
            context["firstAnchorSnapshotQueryDurationMs"] := MedExContextValue(
                anchorSnapshot.context,
                "anchorSnapshotQueryDurationMs",
                "UNKNOWN"
            )
            context["firstRawFontSizePatternMatchCount"] := MedExContextValue(
                layoutResult.context,
                "rawFontSizePatternMatchCount",
                0
            )

            if retryDelayMs > 0
                Sleep retryDelayMs
            if !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
                context["foregroundGuardReason"] := "foregroundTargetChangedBeforeFontAnchorRetry"
                return FinishMedExColorReset(false, ColorResetCode.FOREGROUND_CHANGED, context, startedAt, options)
            }

            try windowElement := UIA.ElementFromHandle(foregroundHwnd)
            catch as err {
                AddSafeExceptionContext(context, err)
                context["uiaReason"] := "ElementFromHandleFailedBeforeFontAnchorRetry"
                return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
            }
            try retrySnapshot := CollectMedExTextAnchorSnapshot(
                windowElement,
                useCachedAnchorSnapshot
            )
            catch as err {
                AddSafeExceptionContext(context, err)
                context["uiaReason"] := "FontAnchorRetrySnapshotFailed"
                return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
            }
            context["anchorSnapshotAttemptCount"] := 2
            context["fontAnchorRetryQueryDurationMs"] := MedExContextValue(
                retrySnapshot.context,
                "anchorSnapshotQueryDurationMs",
                "UNKNOWN"
            )
            MergeContext(context, retrySnapshot.context)
            layoutResult := ResolveMedExColorResetLayout(retrySnapshot.anchors, clientRectScreen, layoutOptions)
            MergeContext(context, layoutResult.context)
        }

        context["lookupElapsedMs"] := A_TickCount - lookupStartedAt
        if !layoutResult.ok
            return FinishMedExColorReset(false, layoutResult.code, context, startedAt, options)
        RecordOptionalPerformanceTimestamp(
            performanceContext,
            "AnchorResolutionCompletedMs"
        )

        interactionResult := RunMedExColorMenuInteraction(
            foregroundHwnd,
            foregroundProcess,
            windowElement,
            context["calculatedScreenPoint"],
            context,
            options
        )
        return FinishMedExColorReset(
            interactionResult.ok,
            interactionResult.code,
            interactionResult.context,
            startedAt,
            options
        )
    } catch as err {
        AddSafeExceptionContext(context, err)
        return FinishMedExColorReset(false, ColorResetCode.UNEXPECTED_ERROR, context, startedAt, options)
    }
}

RunMedExColorMenuInteraction(foregroundHwnd, foregroundProcess, windowElement, screenPoint, context, options) {
    menuLookupStrategy := MedExAdapterOption(
        options,
        "menuLookupStrategy",
        MedExColorResetDefaults.MenuLookupStrategy
    )
    menuTimeoutMs := MedExAdapterOption(
        options,
        "menuOpenTimeoutMs",
        MedExColorResetDefaults.MenuOpenTimeoutMs
    )
    menuTimeoutMs := Max(100, Min(2000, Integer(menuTimeoutMs)))
    menuPollIntervalMs := MedExAdapterOption(
        options,
        "menuPollIntervalMs",
        MedExColorResetDefaults.MenuPollIntervalMs
    )
    menuPollIntervalMs := Max(10, Min(200, Integer(menuPollIntervalMs)))
    retryDelayMs := MedExAdapterOption(
        options,
        "blackLookupRetryDelayMs",
        MedExColorResetDefaults.BlackLookupRetryDelayMs
    )
    retryDelayMs := Max(0, Min(100, Integer(retryDelayMs)))
    preLookupSettleMs := MedExAdapterOption(
        options,
        "menuPreLookupSettleMs",
        MedExColorResetDefaults.MenuPreLookupSettleMs
    )
    preLookupSettleMs := Max(0, Min(100, Integer(preLookupSettleMs)))
    maxLookupAttempts := MedExAdapterOption(
        options,
        "blackLookupMaxAttempts",
        MedExColorResetDefaults.BlackLookupMaxAttempts
    )
    maxLookupAttempts := Max(1, Min(2, Integer(maxLookupAttempts)))
    collectFocusDiagnostics := MedExAdapterOption(options, "collectFocusDiagnostics", false)
    performanceContext := MedExAdapterOption(options, "performanceContext", 0)
    mouseCaptured := false

    try {
        CoordMode "Mouse", "Screen"
        MouseGetPos &originalMouseX, &originalMouseY
        mouseCaptured := true

        if !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
            context["processReason"] := "foregroundWindowChangedBeforeTriggerClick"
            context["foregroundGuardReason"] := "foregroundTargetChangedBeforeTriggerClick"
            return MakeColorResetResult(false, ColorResetCode.FOREGROUND_CHANGED, context)
        }

        if collectFocusDiagnostics
            MergeContext(context, CaptureMedExFocusedElementContext("beforeMenuClick"))

        try {
            Click screenPoint["x"], screenPoint["y"]
            context["triggerClickCount"] := 1
            context["triggerRetryCount"] := 0
            context["colorMenuClickSent"] := true
            RecordOptionalPerformanceTimestamp(performanceContext, "MenuClickSentMs")
        } catch as err {
            AddSafeExceptionContext(context, err)
            return MakeColorResetResult(false, ColorResetCode.TRIGGER_CLICK_FAILED, context)
        }

        if menuLookupStrategy = "fixedAttempts" {
            menuLookup := WaitForMedExColorMenuFixedAttempts(
                foregroundHwnd,
                windowElement,
                preLookupSettleMs,
                retryDelayMs,
                maxLookupAttempts,
                performanceContext
            )
        } else {
            menuLookupStrategy := "adaptivePolling"
            menuLookup := WaitForMedExColorMenu(
                foregroundHwnd,
                windowElement,
                menuTimeoutMs,
                menuPollIntervalMs,
                performanceContext
            )
        }
        menuOpened := menuLookup["opened"]
        blackItem := menuLookup["blackItem"]
        context["menuDetectionElapsedMs"] := menuLookup["elapsedMs"]
        context["immediateLookupSucceeded"] := menuLookup["immediateLookupSucceeded"]
        context["retryUsed"] := menuLookup["retryUsed"]
        context["blackLookupAttemptCount"] := menuLookup["lookupAttemptCount"]
        context["menuLookupStrategy"] := menuLookupStrategy
        context["menuOpenTimeoutMs"] := menuTimeoutMs
        context["menuPollIntervalMs"] := menuPollIntervalMs
        context["blackLookupScope"] := menuLookup["scope"]
        context["menuPreLookupSettleMs"] := menuLookup["preLookupSettleMs"]
        context["blackLookupFirstRootDurationMs"] := menuLookup["firstRootDurationMs"]
        context["blackLookupFirstQueryDurationMs"] := menuLookup["firstQueryDurationMs"]
        context["blackLookupRetryRootDurationMs"] := menuLookup["retryRootDurationMs"]
        context["blackLookupRetryQueryDurationMs"] := menuLookup["retryQueryDurationMs"]
        context["retryCount"] := menuLookup["retryUsed"] ? 1 : 0
        if menuLookup["foregroundChanged"] {
            context["processReason"] := "foregroundWindowChangedWhileWaitingForMenu"
            context["foregroundGuardReason"] := "foregroundTargetChangedWhileWaitingForMenu"
            return MakeColorResetResult(false, ColorResetCode.FOREGROUND_CHANGED, context)
        }

        if !menuOpened
            return MakeColorResetResult(false, ColorResetCode.MENU_NOT_OPENED, context)

        if !blackItem
            return MakeColorResetResult(false, ColorResetCode.BLACK_ITEM_NOT_FOUND, context)

        context["blackColorFound"] := true
        context["blackItemFound"] := true
        try context["invokeAvailable"] := blackItem.IsInvokePatternAvailable = true
        catch as err {
            AddSafeExceptionContext(context, err)
            context["invokeAvailable"] := false
        }
        if !context["invokeAvailable"]
            return MakeColorResetResult(false, ColorResetCode.INVOKE_UNAVAILABLE, context)

        if !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
            context["processReason"] := "foregroundWindowChangedBeforeInvoke"
            context["foregroundGuardReason"] := "foregroundTargetChangedBeforeInvoke"
            return MakeColorResetResult(false, ColorResetCode.FOREGROUND_CHANGED, context)
        }

        try {
            blackItem.InvokePattern.Invoke()
            RecordOptionalPerformanceTimestamp(performanceContext, "BlackInvokeCompletedMs")
            context["invokeSucceeded"] := true
            context["blackItemInvokeSucceeded"] := true
            context["automationChainResult"] := "AUTOMATION_CHAIN_OK"
            if collectFocusDiagnostics
                MergeContext(context, CaptureMedExFocusedElementContext("afterBlackInvoke"))
        } catch as err {
            AddSafeExceptionContext(context, err)
            return MakeColorResetResult(false, ColorResetCode.INVOKE_FAILED, context)
        }

        return MakeColorResetResult(true, ColorResetCode.AUTOMATION_CHAIN_OK, context)
    } finally {
        if mouseCaptured
            MouseMove originalMouseX, originalMouseY, 0
    }
}

WaitForMedExColorMenu(foregroundHwnd, windowElement, timeoutMs, pollIntervalMs,
    performanceContext := 0) {
    startedAt := A_TickCount
    lookupAttemptCount := 0
    firstRootDurationMs := "UNKNOWN"
    firstQueryDurationMs := "UNKNOWN"
    lastRootDurationMs := "UNKNOWN"
    lastQueryDurationMs := "UNKNOWN"
    currentWindowElement := windowElement

    loop {
        if WinExist("A") != foregroundHwnd
            return MakeMedExMenuLookupResult(false, 0, startedAt, true, false,
                lookupAttemptCount > 1, lookupAttemptCount, 0,
                firstRootDurationMs, firstQueryDurationMs,
                lastRootDurationMs, lastQueryDurationMs)

        rootStartedAt := A_TickCount
        currentWindowElement := RefreshMedExWindowElement(foregroundHwnd, windowElement)
        rootDurationMs := A_TickCount - rootStartedAt
        queryStartedAt := A_TickCount
        blackItem := FindExactMedExColorItem(currentWindowElement, "000000")
        queryDurationMs := A_TickCount - queryStartedAt
        lookupAttemptCount += 1

        if lookupAttemptCount = 1 {
            firstRootDurationMs := rootDurationMs
            firstQueryDurationMs := queryDurationMs
            RecordOptionalPerformanceTimestamp(
                performanceContext,
                "ImmediateBlackLookupCompletedMs"
            )
        } else {
            lastRootDurationMs := rootDurationMs
            lastQueryDurationMs := queryDurationMs
            RecordOptionalPerformanceTimestamp(performanceContext, "RetryLookupCompletedMs")
        }

        if blackItem
            return MakeMedExMenuLookupResult(true, blackItem, startedAt, false,
                lookupAttemptCount = 1, lookupAttemptCount > 1, lookupAttemptCount, 0,
                firstRootDurationMs, firstQueryDurationMs,
                lastRootDurationMs, lastQueryDurationMs)

        if A_TickCount - startedAt >= timeoutMs {
            ; Auxiliary items are queried only after the exact-black polling
            ; window expires, so they do not multiply normal-path tree scans.
            menuObserved := FindExactMedExColorItem(currentWindowElement, "ff0000")
                || FindExactMedExColorItem(currentWindowElement, "95b3d7")
            return MakeMedExMenuLookupResult(menuObserved, 0, startedAt, false,
                false, lookupAttemptCount > 1, lookupAttemptCount, 0,
                firstRootDurationMs, firstQueryDurationMs,
                lastRootDurationMs, lastQueryDurationMs)
        }
        Sleep pollIntervalMs
    }
}

WaitForMedExColorMenuFixedAttempts(foregroundHwnd, windowElement, preLookupSettleMs, retryDelayMs,
    maxLookupAttempts, performanceContext := 0) {
    global UIA

    startedAt := A_TickCount
    if WinExist("A") != foregroundHwnd
        return MakeMedExMenuLookupResult(false, 0, startedAt, true, false, false, 0,
            preLookupSettleMs)

    if preLookupSettleMs > 0
        Sleep preLookupSettleMs

    rootStartedAt := A_TickCount
    currentWindowElement := RefreshMedExWindowElement(foregroundHwnd, windowElement)
    firstRootDurationMs := A_TickCount - rootStartedAt
    queryStartedAt := A_TickCount
    blackItem := FindExactMedExColorItem(currentWindowElement, "000000")
    firstQueryDurationMs := A_TickCount - queryStartedAt
    RecordOptionalPerformanceTimestamp(
        performanceContext,
        "ImmediateBlackLookupCompletedMs"
    )
    if blackItem
        return MakeMedExMenuLookupResult(true, blackItem, startedAt, false, true, false, 1,
            preLookupSettleMs, firstRootDurationMs, firstQueryDurationMs)

    if maxLookupAttempts < 2
        return MakeMedExMenuLookupResult(false, 0, startedAt, false, false, false, 1,
            preLookupSettleMs, firstRootDurationMs, firstQueryDurationMs)

    if retryDelayMs > 0
        Sleep retryDelayMs

    if WinExist("A") != foregroundHwnd
        return MakeMedExMenuLookupResult(false, 0, startedAt, true, false, true, 1,
            preLookupSettleMs, firstRootDurationMs, firstQueryDurationMs)

    retryRootStartedAt := A_TickCount
    currentWindowElement := RefreshMedExWindowElement(foregroundHwnd, windowElement)
    retryRootDurationMs := A_TickCount - retryRootStartedAt
    retryQueryStartedAt := A_TickCount
    blackItem := FindExactMedExColorItem(currentWindowElement, "000000")
    retryQueryDurationMs := A_TickCount - retryQueryStartedAt
    RecordOptionalPerformanceTimestamp(performanceContext, "RetryLookupCompletedMs")
    if blackItem
        return MakeMedExMenuLookupResult(true, blackItem, startedAt, false, false, true, 2,
            preLookupSettleMs, firstRootDurationMs, firstQueryDurationMs,
            retryRootDurationMs, retryQueryDurationMs)

    ; Auxiliary colors are queried only on failure to distinguish an opened
    ; menu with a missing black item from a menu that was not exposed at all.
    menuObserved := FindExactMedExColorItem(currentWindowElement, "ff0000")
        || FindExactMedExColorItem(currentWindowElement, "95b3d7")
    return MakeMedExMenuLookupResult(menuObserved, 0, startedAt, false, false, true, 2,
        preLookupSettleMs, firstRootDurationMs, firstQueryDurationMs,
        retryRootDurationMs, retryQueryDurationMs)
}

RefreshMedExWindowElement(foregroundHwnd, fallbackElement) {
    global UIA
    try return UIA.ElementFromHandle(foregroundHwnd)
    catch
        return fallbackElement
}

FindExactMedExColorItem(windowElement, colorName) {
    try return windowElement.ElementExist({Type: "Hyperlink", Name: colorName})
    catch
        return 0
}

MakeMedExMenuLookupResult(opened, blackItem, startedAt, foregroundChanged,
    immediateLookupSucceeded, retryUsed, lookupAttemptCount, preLookupSettleMs,
    firstRootDurationMs := "UNKNOWN", firstQueryDurationMs := "UNKNOWN",
    retryRootDurationMs := "UNKNOWN", retryQueryDurationMs := "UNKNOWN") {
    return Map(
        "opened", opened = true,
        "blackItem", blackItem,
        "elapsedMs", A_TickCount - startedAt,
        "foregroundChanged", foregroundChanged = true,
        "immediateLookupSucceeded", immediateLookupSucceeded = true,
        "retryUsed", retryUsed = true,
        "lookupAttemptCount", lookupAttemptCount,
        "scope", "foregroundWindowDescendants",
        "preLookupSettleMs", preLookupSettleMs,
        "firstRootDurationMs", firstRootDurationMs,
        "firstQueryDurationMs", firstQueryDurationMs,
        "retryRootDurationMs", retryRootDurationMs,
        "retryQueryDurationMs", retryQueryDurationMs
    )
}

FindMedExDocument(windowElement, foregroundHwnd, context := 0) {
    global UIA
    startedAt := A_TickCount

    try {
        if windowElement.Type = UIA.ControlType.Document {
            RecordMedExDocumentLookup(context, "foregroundRoot", startedAt)
            return windowElement
        }
    }
    try {
        if documentElement := windowElement.ElementExist({Type: "Document"}) {
            RecordMedExDocumentLookup(context, "foregroundRootDescendant", startedAt)
            return documentElement
        }
    }

    ; Chromium fallback remains scoped to the same foreground window.
    try chromiumElement := UIA.ElementFromChromium("ahk_id " foregroundHwnd)
    catch {
        RecordMedExDocumentLookup(context, "chromiumRootUnavailable", startedAt)
        return 0
    }

    try {
        if chromiumElement.Type = UIA.ControlType.Document {
            RecordMedExDocumentLookup(context, "chromiumRoot", startedAt)
            return chromiumElement
        }
    }
    try {
        documentElement := chromiumElement.ElementExist({Type: "Document"})
        RecordMedExDocumentLookup(context,
            documentElement ? "chromiumRootDescendant" : "notFound", startedAt)
        return documentElement
    } catch {
        RecordMedExDocumentLookup(context, "chromiumDescendantQueryFailed", startedAt)
        return 0
    }
}

RecordMedExDocumentLookup(context, path, startedAt) {
    if Type(context) = "Map" {
        context["documentLookupPath"] := path
        context["documentLookupDurationMs"] := A_TickCount - startedAt
    }
}

CaptureMedExFocusedElementContext(prefix) {
    global UIA
    context := Map()
    startedAt := A_TickCount
    context[prefix "FocusedElementCaptured"] := false
    try {
        element := UIA.GetFocusedElement()
        context[prefix "FocusedElementCaptured"] := true
        for propertyName in ["ControlType", "ClassName", "AutomationId", "NativeWindowHandle", "ProcessId"] {
            try context[prefix "FocusedElement" propertyName] := element.%propertyName%
            catch
                context[prefix "FocusedElement" propertyName] := "UNKNOWN"
        }
        try context[prefix "FocusedElementRect"] := UiaRectangleToMap(element.BoundingRectangle)
        catch
            context[prefix "FocusedElementRect"] := "UNKNOWN"
    } catch as err {
        context[prefix "FocusedElementReason"] := "focusedElementQueryFailed"
        context[prefix "FocusedElementExceptionType"] := Type(err)
    }
    context[prefix "FocusedElementQueryDurationMs"] := A_TickCount - startedAt
    return context
}

MedExProcessNameIsApproved(processName, candidates) {
    if Type(candidates) != "Array"
        return false
    for candidate in candidates {
        if StrLower(processName) = StrLower(candidate)
            return true
    }
    return false
}

MedExReportHotstringsEnabled() {
    for processName in MedExColorResetDefaults.ProvisionalProcessNames {
        if WinActive("ahk_exe " processName)
            return true
    }
    return false
}

MedExForegroundWindowMatches(expectedHwnd) {
    return expectedHwnd && WinExist("A") = expectedHwnd
}

MedExForegroundTargetMatches(expectedHwnd, expectedProcess) {
    if WinExist("A") != expectedHwnd
        return false
    try currentProcess := WinGetProcessName("ahk_id " expectedHwnd)
    catch
        return false
    return StrLower(currentProcess) = StrLower(expectedProcess)
}

CollectMedExTextAnchorSnapshot(windowElement, useCachedProperties := false) {
    global UIA

    queryStartedAt := A_TickCount
    if useCachedProperties {
        cacheRequest := UIA.CreateCacheRequest(["Name", "BoundingRectangle"])
        textElements := windowElement.FindElements({Type: "Text"}, 4, 0, 0, cacheRequest)
    } else {
        textElements := windowElement.FindElements({Type: "Text"})
    }
    queryCompletedAt := A_TickCount
    conversion := UiaTextElementsToAnchors(textElements, useCachedProperties)
    context := Map(
        "anchorSnapshotScope", "foregroundWindowDescendants",
        "anchorSnapshotShared", true,
        "anchorSnapshotMode", useCachedProperties ? "cachedProperties" : "liveProperties",
        "anchorSnapshotTextElementCount", textElements.Length,
        "anchorSnapshotQueryDurationMs", queryCompletedAt - queryStartedAt,
        "anchorSnapshotConversionDurationMs", A_TickCount - queryCompletedAt,
        "anchorSnapshotPropertyReadFailureCount", conversion.propertyReadFailureCount,
        "anchorSnapshotPropertyReadFailureReasons", conversion.propertyReadFailureReasons
    )
    return {anchors: conversion.anchors, context: context}
}

UiaTextElementsToAnchors(elements, useCachedProperties := false) {
    anchors := []
    propertyReadFailureCount := 0
    propertyReadFailureReasons := []
    for element in elements {
        try name := useCachedProperties ? element.CachedName : element.Name
        catch {
            propertyReadFailureCount += 1
            propertyReadFailureReasons.Push("nameReadFailed")
            continue
        }

        try rect := UiaRectangleToMap(
            useCachedProperties ? element.CachedBoundingRectangle : element.BoundingRectangle
        )
        catch {
            propertyReadFailureCount += 1
            propertyReadFailureReasons.Push("rectangleReadFailed")
            rect := 0
        }
        anchors.Push(MakeTextAnchor(name, rect))
    }
    return {
        anchors: anchors,
        propertyReadFailureCount: propertyReadFailureCount,
        propertyReadFailureReasons: propertyReadFailureReasons
    }
}

UiaRectangleToMap(rectangle) {
    return MakeRect(rectangle.l, rectangle.t, rectangle.r, rectangle.b)
}

BuildMedExColorResetLayoutOptions(options) {
    return Map(
        "profileName", MedExAdapterOption(options, "layoutProfileName", MedExColorResetLayoutProfile.ProfileName),
        "regionAnchorName", MedExAdapterOption(options, "regionAnchorName", MedExColorResetLayoutProfile.RegionAnchorName),
        "fontSizeNamePattern", MedExAdapterOption(options, "fontSizeNamePattern", MedExColorResetLayoutProfile.FontSizeNamePattern),
        "optionalRightAnchorName", MedExAdapterOption(options, "optionalRightAnchorName", MedExColorResetLayoutProfile.OptionalRightAnchorName),
        "colorArrowOffsetX", MedExAdapterOption(options, "colorArrowOffsetX", MedExColorResetLayoutProfile.ColorArrowOffsetX),
        "colorArrowOffsetY", MedExAdapterOption(options, "colorArrowOffsetY", MedExColorResetLayoutProfile.ColorArrowOffsetY),
        "minVerticalOverlapRatio", MedExAdapterOption(options, "minVerticalOverlapRatio", MedExColorResetLayoutProfile.MinVerticalOverlapRatio),
        "toolbarPadding", MedExAdapterOption(options, "toolbarPadding", MedExColorResetLayoutProfile.ToolbarPadding)
    )
}

GetWindowRectMap(hwnd) {
    WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
    return MakeRect(x, y, x + width, y + height)
}

GetClientRectScreenMap(hwnd) {
    WinGetClientPos &x, &y, &width, &height, "ahk_id " hwnd
    return MakeRect(x, y, x + width, y + height)
}

CollectMedExEnvironmentContext(hwnd, context) {
    context["resolution"] := A_ScreenWidth "x" A_ScreenHeight
    try {
        dpi := DllCall("User32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        if dpi {
            context["dpi"] := dpi
            context["displayScaling"] := Round(dpi / 96 * 100) "%"
        } else {
            context["dpi"] := "UNKNOWN"
            context["displayScaling"] := "UNKNOWN"
        }
    } catch {
        context["dpi"] := "UNKNOWN"
        context["displayScaling"] := "UNKNOWN"
    }

    try {
        processPath := WinGetProcessPath("ahk_id " hwnd)
        version := FileGetVersion(processPath)
        context["medExVersion"] := version != "" ? version : "UNKNOWN"
    } catch {
        context["medExVersion"] := "UNKNOWN"
    }
}

FinishMedExColorReset(ok, code, context, startedAt, options) {
    context["elapsedMs"] := A_TickCount - startedAt
    performanceContext := MedExAdapterOption(options, "performanceContext", 0)
    RecordOptionalPerformanceTimestamp(performanceContext, "ColorResetCompletedMs")
    result := MakeColorResetResult(ok, code, context)
    diagnosticMode := MedExAdapterOption(options, "diagnosticMode", "production")
    if diagnosticMode = "field" {
        try {
            logPath := MedExAdapterOption(options, "logPath", "")
            context["logPath"] := WriteMedExColorResetDiagnostic(result, logPath)
        } catch as err {
            context["diagnosticWriteFailed"] := true
            context["diagnosticErrorType"] := Type(err)
        }
    } else if diagnosticMode = "production" && !ok {
        try {
            logPath := MedExAdapterOption(options, "logPath", "")
            context["logPath"] := WriteMedExColorResetFailureDiagnostic(result, logPath)
        } catch as err {
            context["diagnosticWriteFailed"] := true
            context["diagnosticErrorType"] := Type(err)
        }
    }
    return result
}

AddSafeExceptionContext(context, err) {
    context["exceptionType"] := Type(err)
    context["exceptionMessage"] := SafeDiagnosticValue(err.Message)
}

MergeContext(target, source) {
    if Type(target) != "Map" || Type(source) != "Map"
        return target
    for key, value in source
        target[key] := value
    return target
}

MedExAdapterOption(options, key, defaultValue) {
    if Type(options) = "Map" && options.Has(key)
        return options[key]
    return defaultValue
}
