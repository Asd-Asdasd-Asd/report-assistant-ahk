#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\mxnm_config_geometry_provider.ahk

RunMxNMConfigGeometryAudit()

RunMxNMConfigGeometryAudit() {
    result := MxNMConfigGeometryProvider.AuditCurrentConfig()
    outputPath := A_Temp "\MedExAHK\mxnm_config_geometry_audit.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath
    FileAppend(
        FormatMxNMConfigGeometryAudit(result),
        outputPath,
        "UTF-8"
    )
    ToolTip(
        result.ok
            ? "MxNM 配置几何审计完成`n结果已写入：" . outputPath
            : "MxNM 配置结构审计失败`n" . result.code .
                "`n结果已写入：" . outputPath
    )
    SetTimer (() => ToolTip()), -3500
}

FormatMxNMConfigGeometryAudit(result) {
    lines := [
        "Test=MxNMConfigGeometryAudit",
        "State=" result.code,
        "ViewerProcessPathResolved=" .
            MxNMConfigAuditBoolean(result.viewerProcessPathResolved),
        "ConfigRootRelationValidated=" .
            MxNMConfigAuditBoolean(result.configRootRelationValidated),
        "MxNMSoftExists=" .
            MxNMConfigAuditBoolean(result.mainConfigExists),
        "MxPetCtTempExists=" .
            MxNMConfigAuditBoolean(result.layoutConfigExists),
        "MxNMSoftSha256=" . result.mainConfigSha256,
        "MxPetCtTempSha256=" . result.layoutConfigSha256,
        "MxNMSoftGeometryEntryCount=" . result.mainEntries.Length,
        "MxPetCtTempGeometryEntryCount=" . result.layoutEntries.Length,
        "FramePositionResolved=" .
            MxNMConfigAuditBoolean(
                result.mainGeometry.framePositionResolved
            ),
        "FramePosition=" .
            FormatMxNMAuditPoint(
                result.mainGeometry.frameX,
                result.mainGeometry.frameY
            ),
        "FrameSizeResolved=" .
            MxNMConfigAuditBoolean(
                result.mainGeometry.frameSizeResolved
            ),
        "FrameSize=" .
            result.mainGeometry.frameWidth . "," .
            result.mainGeometry.frameHeight,
        "ShowImagePositionResolved=" .
            MxNMConfigAuditBoolean(
                result.mainGeometry.imagePositionResolved
            ),
        "ShowImagePosition=" .
            FormatMxNMAuditPoint(
                result.mainGeometry.imageX,
                result.mainGeometry.imageY
            ),
        "ShowImageSizeResolved=" .
            MxNMConfigAuditBoolean(
                result.mainGeometry.imageSizeResolved
            ),
        "ShowImageSize=" .
            result.mainGeometry.imageWidth . "," .
            result.mainGeometry.imageHeight,
        "ViewerWindowCount=" . result.viewerWindows.Length,
        "RuntimeFrameCandidateCount=" .
            result.runtimeFrameCandidateCount,
        "RuntimeFrameResolved=" .
            MxNMConfigAuditBoolean(result.runtimeFrameResolved),
        "MappedImageRectResolved=" .
            MxNMConfigAuditBoolean(result.mappedImageRectResolved),
        "MappedImageRect=" .
            FormatMxNMAuditOptionalRect(result.mappedImageRect)
    ]
    for viewerWindow in result.viewerWindows {
        lines.Push(
            "ViewerWindow=window|" .
            FormatMxNMAuditRect(
                viewerWindow.windowX,
                viewerWindow.windowY,
                viewerWindow.windowWidth,
                viewerWindow.windowHeight
            ) .
            "|client|" .
            FormatMxNMAuditRect(
                viewerWindow.clientX,
                viewerWindow.clientY,
                viewerWindow.clientWidth,
                viewerWindow.clientHeight
            )
        )
    }
    for entry in result.mainEntries
        lines.Push(FormatMxNMConfigAuditEntry(entry))

    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

FormatMxNMAuditPoint(x, y) {
    return x . "," . y
}

FormatMxNMAuditRect(x, y, width, height) {
    return x . "," . y . "," . width . "," . height
}

FormatMxNMAuditOptionalRect(rect) {
    if !IsObject(rect)
        return ""
    return rect.left . "," . rect.top . "," .
        rect.right . "," . rect.bottom
}

FormatMxNMConfigAuditEntry(entry) {
    return "GeometryEntry=" .
        entry.source . "|" .
        entry.section . "|" .
        entry.key . "|" .
        entry.value
}

MxNMConfigAuditBoolean(value) {
    return value ? "true" : "false"
}
