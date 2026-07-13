class MedExColorResetDefaults {
    ; Both names remain provisional until the target workstation confirms the executable.
    static ProvisionalProcessNames := [
        "medexworkstation.exe",
        "medexworkstations.exe"
    ]
    static ConfirmedProcessName := ""

    ; Derived from the 2026-07 field investigation, not a permanent layout constant.
    static ProvisionalArrowHorizontalRatio := 0.337

    ; Provisional bounded field-test timing values.
    static MenuOpenTimeoutMs := 600
    static MenuPollIntervalMs := 40
    static MaxTriggerAttempts := 2

    static MinHorizontalGap := 100
    static MaxHorizontalGap := 1200
    static MaxVerticalDelta := 24
    static CoordinateTolerance := 4
    static ToolbarPadding := 12
}

ResetMedExInsertionColor(options := 0) {
    startedAt := A_TickCount
    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "foregroundProcess", "UNKNOWN",
        "foregroundWindowHandle", "UNKNOWN",
        "provisionalProcessCandidateAccepted", false,
        "processNameConfirmed", false,
        "toolbarCandidateCount", 0,
        "toolbarCandidateSelected", false,
        "selectedToolbarIndex", 0,
        "colorMenuClickSent", false,
        "blackColorFound", false,
        "blackItemFound", false,
        "invokeAvailable", false,
        "invokeSucceeded", false,
        "blackItemInvokeSucceeded", false,
        "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED",
        "finalInsertionColorVisuallyValidated", false,
        "retryCount", 0,
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
        allowProvisionalProcess := MedExAdapterOption(options, "allowProvisionalProcess", false)
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

        CollectMedExEnvironmentContext(foregroundHwnd, context)

        global UIA
        if !IsSet(UIA) {
            context["uiaReason"] := "UIA-v2NotIncluded"
            return FinishMedExColorReset(false, ColorResetCode.UIA_UNAVAILABLE, context, startedAt, options)
        }

        try context["uiaInterfaceVersion"] := UIA.IUIAutomationVersion
        catch
            context["uiaInterfaceVersion"] := "UNKNOWN"

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

        try fontSizeElements := windowElement.FindElements({Name: "16px"})
        catch as err {
            AddSafeExceptionContext(context, err)
            fontSizeElements := []
        }
        if fontSizeElements.Length = 0 {
            context["lookupElapsedMs"] := A_TickCount - lookupStartedAt
            return FinishMedExColorReset(
                false,
                ColorResetCode.ANCHOR_FONT_SIZE_NOT_FOUND,
                context,
                startedAt,
                options
            )
        }

        try numberButtonElements := windowElement.FindElements({Name: "①"})
        catch as err {
            AddSafeExceptionContext(context, err)
            numberButtonElements := []
        }
        if numberButtonElements.Length = 0 {
            context["lookupElapsedMs"] := A_TickCount - lookupStartedAt
            return FinishMedExColorReset(
                false,
                ColorResetCode.ANCHOR_NUMBER_BUTTON_NOT_FOUND,
                context,
                startedAt,
                options
            )
        }

        try {
            fontSizeRects := UiaElementsToRectangles(fontSizeElements)
            numberButtonRects := UiaElementsToRectangles(numberButtonElements)
        } catch as err {
            AddSafeExceptionContext(context, err)
            context["invalidRectangle"] := "anchorRect"
            return FinishMedExColorReset(false, ColorResetCode.INVALID_RECTANGLE, context, startedAt, options)
        }
        context["fontSizeAnchorRects"] := fontSizeRects
        context["numberButtonAnchorRects"] := numberButtonRects
        context["lookupElapsedMs"] := A_TickCount - lookupStartedAt

        windowRect := GetWindowRectMap(foregroundHwnd)
        clientRectScreen := GetClientRectScreenMap(foregroundHwnd)
        context["windowRect"] := windowRect
        context["clientRectScreen"] := clientRectScreen

        geometryOptions := Map(
            "ratio", MedExAdapterOption(
                options,
                "ratio",
                MedExColorResetDefaults.ProvisionalArrowHorizontalRatio
            ),
            "minHorizontalGap", MedExAdapterOption(
                options,
                "minHorizontalGap",
                MedExColorResetDefaults.MinHorizontalGap
            ),
            "maxHorizontalGap", MedExAdapterOption(
                options,
                "maxHorizontalGap",
                MedExColorResetDefaults.MaxHorizontalGap
            ),
            "maxVerticalDelta", MedExAdapterOption(
                options,
                "maxVerticalDelta",
                MedExColorResetDefaults.MaxVerticalDelta
            ),
            "coordinateTolerance", MedExAdapterOption(
                options,
                "coordinateTolerance",
                MedExColorResetDefaults.CoordinateTolerance
            ),
            "toolbarPadding", MedExAdapterOption(
                options,
                "toolbarPadding",
                MedExColorResetDefaults.ToolbarPadding
            )
        )
        candidateResult := BuildMedExToolbarCandidates(fontSizeRects, numberButtonRects, geometryOptions)
        MergeContext(context, candidateResult.context)
        if !candidateResult.ok
            return FinishMedExColorReset(false, candidateResult.code, context, startedAt, options)

        ; Every accepted pair must share the validated root/window/client coordinate space.
        for candidate in context["toolbarCandidates"] {
            candidateGeometry := ValidateMedExColorResetGeometry(
                context["uiaRootRect"],
                candidate["fontSizeRect"],
                candidate["numberButtonRect"],
                windowRect,
                clientRectScreen,
                geometryOptions
            )
            if !candidateGeometry.ok {
                MergeContext(context, candidateGeometry.context)
                context["candidateGeometryToolbarY"] := candidate["toolbarY"]
                return FinishMedExColorReset(false, candidateGeometry.code, context, startedAt, options)
            }
        }

        selectedGeometry := ValidateMedExColorResetGeometry(
            context["uiaRootRect"],
            context["selectedFontSizeRect"],
            context["selectedNumberButtonRect"],
            windowRect,
            clientRectScreen,
            geometryOptions
        )
        MergeContext(context, selectedGeometry.context)
        if !selectedGeometry.ok
            return FinishMedExColorReset(false, selectedGeometry.code, context, startedAt, options)

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
    menuTimeoutMs := MedExAdapterOption(
        options,
        "menuOpenTimeoutMs",
        MedExColorResetDefaults.MenuOpenTimeoutMs
    )
    pollIntervalMs := MedExAdapterOption(
        options,
        "menuPollIntervalMs",
        MedExColorResetDefaults.MenuPollIntervalMs
    )
    maxAttempts := MedExAdapterOption(
        options,
        "maxTriggerAttempts",
        MedExColorResetDefaults.MaxTriggerAttempts
    )
    maxAttempts := Max(1, Min(2, Integer(maxAttempts)))
    mouseCaptured := false

    try {
        CoordMode "Mouse", "Screen"
        MouseGetPos &originalMouseX, &originalMouseY
        mouseCaptured := true

        blackItem := 0
        menuOpened := false
        loop maxAttempts {
            attempt := A_Index
            context["retryCount"] := attempt - 1
            if !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
                context["processReason"] := "foregroundWindowChangedBeforeTriggerClick"
                return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
            }

            try {
                Click screenPoint["x"], screenPoint["y"]
                context["triggerClickCount"] := attempt
                context["colorMenuClickSent"] := true
            } catch as err {
                AddSafeExceptionContext(context, err)
                return MakeColorResetResult(false, ColorResetCode.TRIGGER_CLICK_FAILED, context)
            }

            menuLookup := WaitForMedExColorMenu(
                foregroundHwnd,
                windowElement,
                menuTimeoutMs,
                pollIntervalMs
            )
            menuOpened := menuLookup["opened"]
            blackItem := menuLookup["blackItem"]
            context["menuDetectionElapsedMs"] := menuLookup["elapsedMs"]
            if menuLookup["foregroundChanged"] {
                context["processReason"] := "foregroundWindowChangedWhileWaitingForMenu"
                return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
            }

            if menuOpened
                break

            if attempt < maxAttempts && !MedExForegroundTargetMatches(foregroundHwnd, foregroundProcess) {
                context["processReason"] := "foregroundWindowChangedBeforeRetry"
                return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
            }
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
            return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
        }

        try {
            blackItem.InvokePattern.Invoke()
            context["invokeSucceeded"] := true
            context["blackItemInvokeSucceeded"] := true
            context["automationChainResult"] := "AUTOMATION_CHAIN_OK"
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

WaitForMedExColorMenu(foregroundHwnd, windowElement, timeoutMs, pollIntervalMs) {
    global UIA

    startedAt := A_TickCount
    knownColorNames := ["000000", "ff0000", "95b3d7"]
    menuObserved := false
    loop {
        if WinExist("A") != foregroundHwnd
            return Map(
                "opened", false,
                "blackItem", 0,
                "elapsedMs", A_TickCount - startedAt,
                "foregroundChanged", true
            )

        ; Refresh the root so a newly-created Chromium popup is not missed.
        try currentWindowElement := UIA.ElementFromHandle(foregroundHwnd)
        catch
            currentWindowElement := windowElement

        try blackItem := currentWindowElement.ElementExist({Type: "Hyperlink", Name: "000000"})
        catch
            blackItem := 0
        if blackItem
            return Map(
                "opened", true,
                "blackItem", blackItem,
                "elapsedMs", A_TickCount - startedAt,
                "foregroundChanged", false
            )

        for colorName in knownColorNames {
            if colorName = "000000"
                continue
            try colorItem := currentWindowElement.ElementExist({Type: "Hyperlink", Name: colorName})
            catch
                colorItem := 0
            if colorItem
                menuObserved := true
        }

        if A_TickCount - startedAt >= timeoutMs
            return Map(
                "opened", menuObserved,
                "blackItem", 0,
                "elapsedMs", A_TickCount - startedAt,
                "foregroundChanged", false
            )
        Sleep Max(10, pollIntervalMs)
    }
}

FindMedExDocument(windowElement, foregroundHwnd) {
    global UIA

    try {
        if windowElement.Type = UIA.ControlType.Document
            return windowElement
    }
    try {
        if documentElement := windowElement.ElementExist({Type: "Document"})
            return documentElement
    }

    ; Chromium fallback remains scoped to the same foreground window.
    try chromiumElement := UIA.ElementFromChromium("ahk_id " foregroundHwnd)
    catch
        return 0

    try {
        if chromiumElement.Type = UIA.ControlType.Document
            return chromiumElement
    }
    try return chromiumElement.ElementExist({Type: "Document"})
    catch
        return 0
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

MedExForegroundTargetMatches(expectedHwnd, expectedProcess) {
    if WinExist("A") != expectedHwnd
        return false
    try currentProcess := WinGetProcessName("ahk_id " expectedHwnd)
    catch
        return false
    return StrLower(currentProcess) = StrLower(expectedProcess)
}

UiaElementsToRectangles(elements) {
    rectangles := []
    for element in elements
        rectangles.Push(UiaRectangleToMap(element.BoundingRectangle))
    return rectangles
}

UiaRectangleToMap(rectangle) {
    return MakeRect(rectangle.l, rectangle.t, rectangle.r, rectangle.b)
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
    result := MakeColorResetResult(ok, code, context)
    if MedExAdapterOption(options, "enableDevelopmentLog", true) {
        try {
            logPath := MedExAdapterOption(options, "logPath", "")
            context["logPath"] := WriteMedExColorResetDiagnostic(result, logPath)
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
