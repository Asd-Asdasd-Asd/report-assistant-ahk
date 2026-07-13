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
        "processNameConfirmed", false,
        "blackColorFound", false,
        "invokeAvailable", false,
        "invokeSucceeded", false,
        "retryCount", 0,
        "uiaLibrary", "UIA-v2",
        "uiaLibraryVersion", MedExAdapterOption(options, "uiaLibraryVersion", "UNKNOWN")
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

        documentElement := FindMedExDocument(windowElement, foregroundHwnd)
        if !documentElement {
            context["lookupElapsedMs"] := A_TickCount - lookupStartedAt
            return FinishMedExColorReset(false, ColorResetCode.DOCUMENT_NOT_FOUND, context, startedAt, options)
        }

        try context["documentRect"] := UiaRectangleToMap(documentElement.BoundingRectangle)
        catch as err {
            AddSafeExceptionContext(context, err)
            context["invalidRectangle"] := "documentRect"
            return FinishMedExColorReset(false, ColorResetCode.INVALID_RECTANGLE, context, startedAt, options)
        }

        try fontSizeElement := documentElement.ElementExist({Name: "16px"})
        catch as err {
            AddSafeExceptionContext(context, err)
            fontSizeElement := 0
        }
        if !fontSizeElement {
            context["lookupElapsedMs"] := A_TickCount - lookupStartedAt
            return FinishMedExColorReset(
                false,
                ColorResetCode.ANCHOR_FONT_SIZE_NOT_FOUND,
                context,
                startedAt,
                options
            )
        }

        try numberButtonElement := documentElement.ElementExist({Name: "①"})
        catch as err {
            AddSafeExceptionContext(context, err)
            numberButtonElement := 0
        }
        if !numberButtonElement {
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
            context["fontSizeRect"] := UiaRectangleToMap(fontSizeElement.BoundingRectangle)
            context["numberButtonRect"] := UiaRectangleToMap(numberButtonElement.BoundingRectangle)
        } catch as err {
            AddSafeExceptionContext(context, err)
            context["invalidRectangle"] := "anchorRect"
            return FinishMedExColorReset(false, ColorResetCode.INVALID_RECTANGLE, context, startedAt, options)
        }
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
        geometryResult := ValidateMedExColorResetGeometry(
            context["documentRect"],
            context["fontSizeRect"],
            context["numberButtonRect"],
            windowRect,
            clientRectScreen,
            geometryOptions
        )
        MergeContext(context, geometryResult.context)
        if !geometryResult.ok
            return FinishMedExColorReset(false, geometryResult.code, context, startedAt, options)

        interactionResult := RunMedExColorMenuInteraction(
            foregroundHwnd,
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

RunMedExColorMenuInteraction(foregroundHwnd, windowElement, screenPoint, context, options) {
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
            if WinExist("A") != foregroundHwnd {
                context["processReason"] := "foregroundWindowChangedBeforeTriggerClick"
                return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
            }

            try {
                Click screenPoint["x"], screenPoint["y"]
                context["triggerClickCount"] := attempt
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

            if attempt < maxAttempts && WinExist("A") != foregroundHwnd {
                context["processReason"] := "foregroundWindowChangedBeforeRetry"
                return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
            }
        }

        if !menuOpened
            return MakeColorResetResult(false, ColorResetCode.MENU_NOT_OPENED, context)

        if !blackItem
            return MakeColorResetResult(false, ColorResetCode.BLACK_ITEM_NOT_FOUND, context)

        context["blackColorFound"] := true
        try context["invokeAvailable"] := blackItem.IsInvokePatternAvailable = true
        catch as err {
            AddSafeExceptionContext(context, err)
            context["invokeAvailable"] := false
        }
        if !context["invokeAvailable"]
            return MakeColorResetResult(false, ColorResetCode.INVOKE_UNAVAILABLE, context)

        if WinExist("A") != foregroundHwnd {
            context["processReason"] := "foregroundWindowChangedBeforeInvoke"
            return MakeColorResetResult(false, ColorResetCode.WRONG_PROCESS, context)
        }

        try {
            blackItem.InvokePattern.Invoke()
            context["invokeSucceeded"] := true
        } catch as err {
            AddSafeExceptionContext(context, err)
            return MakeColorResetResult(false, ColorResetCode.INVOKE_FAILED, context)
        }

        return MakeColorResetResult(true, ColorResetCode.OK, context)
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
