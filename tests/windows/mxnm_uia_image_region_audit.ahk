#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk

RunMxNMUiaImageRegionAudit()

RunMxNMUiaImageRegionAudit() {
    configResult := MxNMConfigGeometryProvider.AuditCurrentConfig()
    result := ResolveMxNMUiaImageRegion(configResult)
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
