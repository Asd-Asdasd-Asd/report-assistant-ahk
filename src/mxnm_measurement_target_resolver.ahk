class MxNMUiaImageRegionCode {
    static READY_FOR_FIELD_VALIDATION := "READY_FOR_FIELD_VALIDATION"
    static CONFIG_GEOMETRY_UNAVAILABLE := "CONFIG_GEOMETRY_UNAVAILABLE"
    static UIA_UNAVAILABLE := "UIA_UNAVAILABLE"
    static UIA_IMAGE_REGION_NOT_FOUND := "UIA_IMAGE_REGION_NOT_FOUND"
    static UIA_IMAGE_REGION_AMBIGUOUS := "UIA_IMAGE_REGION_AMBIGUOUS"
}

class MxNMMeasurementTargetCode {
    static READY_FOR_FIELD_VALIDATION := "READY_FOR_FIELD_VALIDATION"
    static CONFIG_GEOMETRY_UNAVAILABLE := "CONFIG_GEOMETRY_UNAVAILABLE"
    static LAYOUT_SCHEMA_INVALID := "LAYOUT_SCHEMA_INVALID"
    static LAYOUT_SAFE_POINT_NOT_FOUND := "LAYOUT_SAFE_POINT_NOT_FOUND"
    static UIA_UNAVAILABLE := "UIA_UNAVAILABLE"
    static UIA_IMAGE_REGION_NOT_FOUND := "UIA_IMAGE_REGION_NOT_FOUND"
    static UIA_IMAGE_REGION_AMBIGUOUS := "UIA_IMAGE_REGION_AMBIGUOUS"
    static ACTION_WINDOW_INVALID := "ACTION_WINDOW_INVALID"
    static POINT_OUT_OF_BOUNDS := "POINT_OUT_OF_BOUNDS"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMMeasurementTargetResolver {
    static Resolve(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        return ResolveMxNMMeasurementTarget(viewerExe)
    }
}

ResolveMxNMMeasurementTarget(viewerExe) {
    result := MakeMxNMMeasurementTargetResult()
    try {
        configResult := MxNMConfigGeometryProvider.AuditCurrentConfig(
            viewerExe
        )
        result.configCode := configResult.code
        if !configResult.ok
            return result
        result.configReady := true
        result.runtimeFrameResolved :=
            configResult.runtimeFrameResolved
        result.mappedImageRectResolved :=
            configResult.mappedImageRectResolved
        if !result.runtimeFrameResolved
            || !result.mappedImageRectResolved {
            return result
        }

        layoutResult := ParseMxNMDeclaredLayoutModels(
            configResult.layoutEntries,
            configResult.mainGeometry
        )
        result.layoutModelCount := layoutResult.modelCount
        if !layoutResult.ok {
            result.code := MxNMMeasurementTargetCode.LAYOUT_SCHEMA_INVALID
            return result
        }
        result.layoutReady := true

        safePointResult := FindMxNMCrossLayoutSafePoint(
            layoutResult.models,
            configResult.mainGeometry.imageWidth,
            configResult.mainGeometry.imageHeight
        )
        if !safePointResult.ok {
            result.code :=
                MxNMMeasurementTargetCode.LAYOUT_SAFE_POINT_NOT_FOUND
            return result
        }
        result.logicalPoint := safePointResult.point
        result.minimumLogicalClearance :=
            safePointResult.minimumClearance
        result.minimumRequiredClearance :=
            safePointResult.minimumRequiredClearance

        uiaResult := ResolveMxNMUiaImageRegion(configResult)
        result.uiaPaneCount := uiaResult.paneCount
        result.uiaGeometryMatchCount := uiaResult.geometryMatchCount
        if !uiaResult.ok {
            result.code := MapMxNMUiaCodeToTargetCode(uiaResult.code)
            return result
        }
        result.imageRect := uiaResult.matchedRects[1]
        result.screenPoint := MapMxNMLogicalPointToUiaRect(
            result.logicalPoint,
            configResult.mainGeometry,
            result.imageRect
        )
        if !MxNMPointInsideRect(result.screenPoint, result.imageRect) {
            result.code := MxNMMeasurementTargetCode.POINT_OUT_OF_BOUNDS
            return result
        }

        actionWindowResult := ResolveMxNMActionWindowFromPoint(
            viewerExe,
            result.screenPoint,
            configResult.runtimeFrame.hwnd
        )
        if !actionWindowResult.ok {
            result.code := actionWindowResult.code
            return result
        }
        result.actionHwnd := actionWindowResult.hwnd
        result.actionPid := actionWindowResult.pid
        result.ok := true
        result.code :=
            MxNMMeasurementTargetCode.READY_FOR_FIELD_VALIDATION
        return result
    } catch {
        result.code := MxNMMeasurementTargetCode.UNEXPECTED_ERROR
        return result
    }
}

MakeMxNMMeasurementTargetResult() {
    return {
        ok: false,
        code: MxNMMeasurementTargetCode.CONFIG_GEOMETRY_UNAVAILABLE,
        configCode: "",
        configReady: false,
        runtimeFrameResolved: false,
        mappedImageRectResolved: false,
        layoutReady: false,
        layoutModelCount: 0,
        minimumLogicalClearance: 0,
        minimumRequiredClearance: 0,
        logicalPoint: 0,
        imageRect: 0,
        screenPoint: 0,
        actionHwnd: 0,
        actionPid: 0,
        uiaPaneCount: 0,
        uiaGeometryMatchCount: 0
    }
}

ParseMxNMDeclaredLayoutModels(layoutEntries, mainGeometry) {
    failure := {
        ok: false,
        modelCount: 0,
        models: []
    }
    if !mainGeometry.imageSizeResolved
        return failure

    declaredCount := FindMxNMGeometryAuditNumber(
        layoutEntries,
        "ShowModelGroup",
        "ShowModelSize"
    )
    if !MxNMTargetPositiveInteger(declaredCount)
        return failure
    modelCount := Round(declaredCount.value)
    if modelCount > 100
        return failure

    clippingTolerance := Max(
        1,
        Ceil(
            Max(mainGeometry.imageWidth, mainGeometry.imageHeight)
            * 0.01
        )
    )
    models := []
    loop modelCount {
        modelIndex := A_Index
        section := "ShowModel" modelIndex
        paneCountResult := FindMxNMGeometryAuditNumber(
            layoutEntries,
            section,
            "LowWndSize"
        )
        if !MxNMTargetPositiveInteger(paneCountResult)
            return failure
        paneCount := Round(paneCountResult.value)
        if paneCount > 100
            return failure

        panes := []
        loop paneCount {
            paneIndex := A_Index
            leftResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndLeft_" paneIndex
            )
            topResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndTop_" paneIndex
            )
            widthResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndWidth_" paneIndex
            )
            heightResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndHeight_" paneIndex
            )
            if !MxNMTargetInteger(leftResult)
                || !MxNMTargetInteger(topResult)
                || !MxNMTargetPositiveInteger(widthResult)
                || !MxNMTargetPositiveInteger(heightResult) {
                return failure
            }
            rawLeft := Round(leftResult.value)
            rawTop := Round(topResult.value)
            rawRight := rawLeft + Round(widthResult.value)
            rawBottom := rawTop + Round(heightResult.value)
            if rawLeft < -clippingTolerance
                || rawTop < -clippingTolerance
                || rawRight
                    > mainGeometry.imageWidth + clippingTolerance
                || rawBottom
                    > mainGeometry.imageHeight + clippingTolerance {
                return failure
            }
            pane := {
                left: Max(0, rawLeft),
                top: Max(0, rawTop),
                right: Min(mainGeometry.imageWidth, rawRight),
                bottom: Min(mainGeometry.imageHeight, rawBottom)
            }
            if pane.right <= pane.left || pane.bottom <= pane.top
                return failure
            panes.Push(pane)
        }
        models.Push({
            index: modelIndex,
            panes: panes
        })
    }
    return {
        ok: models.Length = modelCount,
        modelCount: modelCount,
        models: models
    }
}

MxNMTargetInteger(numberResult) {
    return numberResult.found
        && numberResult.value = Round(numberResult.value)
}

MxNMTargetPositiveInteger(numberResult) {
    return MxNMTargetInteger(numberResult)
        && numberResult.value > 0
}

FindMxNMCrossLayoutSafePoint(models, imageWidth, imageHeight) {
    minimumRequiredClearance :=
        Min(imageWidth, imageHeight) * 0.05
    candidateMap := Map()
    candidates := []
    for model in models {
        for pane in model.panes {
            candidate := {
                x: Round((pane.left + pane.right) / 2),
                y: Round((pane.top + pane.bottom) / 2)
            }
            key := candidate.x "," candidate.y
            if !candidateMap.Has(key) {
                candidateMap[key] := true
                candidates.Push(candidate)
            }
        }
    }

    bestPoint := 0
    bestClearance := -1
    for candidate in candidates {
        candidateClearance := MxNMPointClearanceAcrossLayouts(
            candidate,
            models
        )
        if candidateClearance < 0
            continue
        if candidateClearance > bestClearance
            || (candidateClearance = bestClearance
                && MxNMPointComesBefore(candidate, bestPoint)) {
            bestPoint := candidate
            bestClearance := candidateClearance
        }
    }
    if !IsObject(bestPoint)
        || bestClearance < minimumRequiredClearance {
        return {
            ok: false,
            point: 0,
            minimumClearance: Max(0, bestClearance),
            minimumRequiredClearance: minimumRequiredClearance
        }
    }
    return {
        ok: true,
        point: bestPoint,
        minimumClearance: bestClearance,
        minimumRequiredClearance: minimumRequiredClearance
    }
}

MxNMPointClearanceAcrossLayouts(point, models) {
    minimumClearance := 0x7FFFFFFF
    for model in models {
        bestModelClearance := -1
        for pane in model.panes {
            if !MxNMPointStrictlyInsideRect(point, pane)
                continue
            clearance := Min(
                point.x - pane.left,
                pane.right - point.x,
                point.y - pane.top,
                pane.bottom - point.y
            )
            bestModelClearance := Max(
                bestModelClearance,
                clearance
            )
        }
        if bestModelClearance < 0
            return -1
        minimumClearance := Min(
            minimumClearance,
            bestModelClearance
        )
    }
    return minimumClearance
}

MxNMPointComesBefore(candidate, currentPoint) {
    if !IsObject(currentPoint)
        return true
    return candidate.y < currentPoint.y
        || (candidate.y = currentPoint.y
            && candidate.x < currentPoint.x)
}

MxNMPointStrictlyInsideRect(point, rect) {
    return point.x > rect.left
        && point.x < rect.right
        && point.y > rect.top
        && point.y < rect.bottom
}

ResolveMxNMUiaImageRegion(configResult) {
    result := {
        ok: false,
        code: MxNMUiaImageRegionCode.CONFIG_GEOMETRY_UNAVAILABLE,
        configReady: false,
        runtimeFrameResolved: false,
        mappedImageRectResolved: false,
        paneCount: 0,
        geometryMatchCount: 0,
        mappedRect: 0,
        matchedRects: []
    }
    if !configResult.ok
        return result
    result.configReady := true
    result.runtimeFrameResolved := configResult.runtimeFrameResolved
    result.mappedImageRectResolved :=
        configResult.mappedImageRectResolved
    if !result.runtimeFrameResolved
        || !result.mappedImageRectResolved {
        return result
    }
    result.mappedRect := configResult.mappedImageRect

    global UIA
    if !IsSet(UIA) {
        result.code := MxNMUiaImageRegionCode.UIA_UNAVAILABLE
        return result
    }

    horizontalTolerance := Max(
        12,
        Round(configResult.runtimeFrame.windowWidth * 0.01)
    )
    verticalTolerance := Max(
        12,
        Round(configResult.runtimeFrame.windowHeight * 0.01)
    )
    seenRects := Map()
    try {
        for viewerWindow in configResult.viewerWindows {
            try rootElement := UIA.ElementFromHandle(
                viewerWindow.hwnd,
                ,
                false
            )
            catch {
                continue
            }
            elements := [rootElement]
            try paneElements := rootElement.FindElements({Type: "Pane"})
            catch {
                paneElements := []
            }
            for paneElement in paneElements
                elements.Push(paneElement)

            for element in elements {
                try elementType := element.Type
                catch {
                    continue
                }
                if elementType != UIA.ControlType.Pane
                    continue
                try rectangle := element.BoundingRectangle
                catch {
                    continue
                }
                rect := {
                    left: Round(rectangle.l),
                    top: Round(rectangle.t),
                    right: Round(rectangle.r),
                    bottom: Round(rectangle.b)
                }
                if rect.right <= rect.left || rect.bottom <= rect.top
                    continue
                rectKey := rect.left "," rect.top ","
                    . rect.right "," rect.bottom
                if seenRects.Has(rectKey)
                    continue
                seenRects[rectKey] := true
                result.paneCount += 1

                try isOffscreen := element.IsOffscreen
                catch {
                    isOffscreen := true
                }
                if isOffscreen
                    continue
                if MxNMUiaRectMatchesMappedGeometry(
                    rect,
                    result.mappedRect,
                    horizontalTolerance,
                    verticalTolerance
                ) {
                    result.matchedRects.Push(rect)
                }
            }
        }
    } catch {
        result.code := MxNMUiaImageRegionCode.UIA_UNAVAILABLE
        return result
    }

    result.geometryMatchCount := result.matchedRects.Length
    if result.geometryMatchCount = 0 {
        result.code :=
            MxNMUiaImageRegionCode.UIA_IMAGE_REGION_NOT_FOUND
        return result
    }
    if result.geometryMatchCount != 1 {
        result.code :=
            MxNMUiaImageRegionCode.UIA_IMAGE_REGION_AMBIGUOUS
        return result
    }
    result.ok := true
    result.code :=
        MxNMUiaImageRegionCode.READY_FOR_FIELD_VALIDATION
    return result
}

MxNMUiaRectMatchesMappedGeometry(
    actualRect,
    mappedRect,
    horizontalTolerance,
    verticalTolerance
) {
    return Abs(actualRect.left - mappedRect.left)
            <= horizontalTolerance
        && Abs(actualRect.right - mappedRect.right)
            <= horizontalTolerance
        && Abs(actualRect.top - mappedRect.top)
            <= verticalTolerance
        && Abs(actualRect.bottom - mappedRect.bottom)
            <= verticalTolerance
}

MapMxNMLogicalPointToUiaRect(point, mainGeometry, uiaRect) {
    return {
        x: uiaRect.left + Round(
            point.x
            * (uiaRect.right - uiaRect.left)
            / mainGeometry.imageWidth
        ),
        y: uiaRect.top + Round(
            point.y
            * (uiaRect.bottom - uiaRect.top)
            / mainGeometry.imageHeight
        )
    }
}

MxNMPointInsideRect(point, rect) {
    return IsObject(point)
        && IsObject(rect)
        && point.x >= rect.left
        && point.x < rect.right
        && point.y >= rect.top
        && point.y < rect.bottom
}

MapMxNMUiaCodeToTargetCode(uiaCode) {
    if uiaCode = MxNMUiaImageRegionCode.UIA_UNAVAILABLE
        return MxNMMeasurementTargetCode.UIA_UNAVAILABLE
    if uiaCode = MxNMUiaImageRegionCode.UIA_IMAGE_REGION_NOT_FOUND
        return MxNMMeasurementTargetCode.UIA_IMAGE_REGION_NOT_FOUND
    if uiaCode = MxNMUiaImageRegionCode.UIA_IMAGE_REGION_AMBIGUOUS
        return MxNMMeasurementTargetCode.UIA_IMAGE_REGION_AMBIGUOUS
    return MxNMMeasurementTargetCode.CONFIG_GEOMETRY_UNAVAILABLE
}

ResolveMxNMActionWindowFromPoint(
    viewerExe,
    screenPoint,
    runtimeFrameHwnd
) {
    packedPoint := ((Round(screenPoint.y) & 0xFFFFFFFF) << 32)
        | (Round(screenPoint.x) & 0xFFFFFFFF)
    try pointHwnd := DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch {
        pointHwnd := 0
    }
    if !pointHwnd {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.ACTION_WINDOW_INVALID
        }
    }
    try rootHwnd := DllCall(
        "User32\GetAncestor",
        "Ptr", pointHwnd,
        "UInt", 2,
        "Ptr"
    )
    catch {
        rootHwnd := 0
    }
    if !rootHwnd
        rootHwnd := pointHwnd

    try processName := WinGetProcessName("ahk_id " rootHwnd)
    catch {
        processName := ""
    }
    try actionPid := WinGetPID("ahk_id " rootHwnd)
    catch {
        actionPid := 0
    }
    try runtimePid := WinGetPID("ahk_id " runtimeFrameHwnd)
    catch {
        runtimePid := 0
    }
    if StrLower(processName) != StrLower(viewerExe)
        || !actionPid || actionPid != runtimePid {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.ACTION_WINDOW_INVALID
        }
    }
    clientRect := MxNMTargetClientRectScreen(rootHwnd)
    if !IsObject(clientRect)
        || !MxNMPointInsideRect(screenPoint, clientRect) {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.POINT_OUT_OF_BOUNDS
        }
    }
    return {
        ok: true,
        code: MxNMMeasurementTargetCode.READY_FOR_FIELD_VALIDATION,
        hwnd: rootHwnd,
        pid: actionPid
    }
}

MxNMTargetClientRectScreen(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall(
        "User32\GetClientRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    ) {
        return 0
    }
    topLeft := Buffer(8, 0)
    bottomRight := Buffer(8, 0)
    NumPut("Int", NumGet(rectBuffer, 0, "Int"), topLeft, 0)
    NumPut("Int", NumGet(rectBuffer, 4, "Int"), topLeft, 4)
    NumPut("Int", NumGet(rectBuffer, 8, "Int"), bottomRight, 0)
    NumPut("Int", NumGet(rectBuffer, 12, "Int"), bottomRight, 4)
    if !DllCall(
        "User32\ClientToScreen",
        "Ptr", hwnd,
        "Ptr", topLeft.Ptr,
        "Int"
    ) {
        return 0
    }
    if !DllCall(
        "User32\ClientToScreen",
        "Ptr", hwnd,
        "Ptr", bottomRight.Ptr,
        "Int"
    ) {
        return 0
    }
    return {
        left: NumGet(topLeft, 0, "Int"),
        top: NumGet(topLeft, 4, "Int"),
        right: NumGet(bottomRight, 0, "Int"),
        bottom: NumGet(bottomRight, 4, "Int")
    }
}
