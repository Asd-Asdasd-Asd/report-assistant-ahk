#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk

class MxNMUiaImageRegionAuditCode {
    static READY_FOR_FIELD_VALIDATION := "READY_FOR_FIELD_VALIDATION"
    static CONFIG_GEOMETRY_UNAVAILABLE := "CONFIG_GEOMETRY_UNAVAILABLE"
    static UIA_UNAVAILABLE := "UIA_UNAVAILABLE"
    static UIA_IMAGE_REGION_NOT_FOUND := "UIA_IMAGE_REGION_NOT_FOUND"
    static UIA_IMAGE_REGION_AMBIGUOUS := "UIA_IMAGE_REGION_AMBIGUOUS"
}

RunMxNMUiaImageRegionAudit()

RunMxNMUiaImageRegionAudit() {
    configResult := MxNMConfigGeometryProvider.AuditCurrentConfig()
    result := AuditMxNMUiaImageRegion(configResult)
    outputPath := A_Temp "\MedExAHK\mxnm_uia_image_region_audit.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath
    FileAppend(
        FormatMxNMUiaImageRegionAudit(result),
        outputPath,
        "UTF-8"
    )
    ToolTip(
        result.ok
            ? "UIA 主图区候选唯一`n结果已写入：" . outputPath
            : "UIA 主图区审计未通过`n" . result.code .
                "`n结果已写入：" . outputPath
    )
    SetTimer (() => ToolTip()), -4000
}

AuditMxNMUiaImageRegion(configResult) {
    result := {
        ok: false,
        code: MxNMUiaImageRegionAuditCode.CONFIG_GEOMETRY_UNAVAILABLE,
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
        result.code := MxNMUiaImageRegionAuditCode.UIA_UNAVAILABLE
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
                rectKey := rect.left . "," . rect.top . "," .
                    rect.right . "," . rect.bottom
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
        result.code := MxNMUiaImageRegionAuditCode.UIA_UNAVAILABLE
        return result
    }

    result.geometryMatchCount := result.matchedRects.Length
    if result.geometryMatchCount = 0 {
        result.code :=
            MxNMUiaImageRegionAuditCode.UIA_IMAGE_REGION_NOT_FOUND
        return result
    }
    if result.geometryMatchCount != 1 {
        result.code :=
            MxNMUiaImageRegionAuditCode.UIA_IMAGE_REGION_AMBIGUOUS
        return result
    }
    result.ok := true
    result.code :=
        MxNMUiaImageRegionAuditCode.READY_FOR_FIELD_VALIDATION
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

FormatMxNMUiaImageRegionAudit(result) {
    lines := [
        "Test=MxNMUiaImageRegionAudit",
        "State=" . result.code,
        "ConfigReady=" . MxNMUiaAuditBoolean(result.configReady),
        "RuntimeFrameResolved=" .
            MxNMUiaAuditBoolean(result.runtimeFrameResolved),
        "MappedImageRectResolved=" .
            MxNMUiaAuditBoolean(result.mappedImageRectResolved),
        "MappedImageRect=" . MxNMUiaAuditRect(result.mappedRect),
        "UiaPaneCount=" . result.paneCount,
        "UiaGeometryMatchCount=" . result.geometryMatchCount
    ]
    for rect in result.matchedRects
        lines.Push("UiaCandidateRect=" . MxNMUiaAuditRect(rect))

    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

MxNMUiaAuditRect(rect) {
    if !IsObject(rect)
        return ""
    return rect.left . "," . rect.top . "," .
        rect.right . "," . rect.bottom
}

MxNMUiaAuditBoolean(value) {
    return value ? "true" : "false"
}
