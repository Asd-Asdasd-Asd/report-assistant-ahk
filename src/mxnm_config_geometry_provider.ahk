class MxNMConfigGeometryDefaults {
    static ViewerExe := "MedExNMFusion.exe"
    static RelativeConfigDirectory := "MultNMSoftInfo\1"
    static MainConfigFileName := "MxNMSoft.ini"
    static LayoutConfigFileName := "MxPetCtTemp.ini"
}

class MxNMConfigGeometryCode {
    static READY_FOR_SCHEMA_MAPPING := "READY_FOR_SCHEMA_MAPPING"
    static VIEWER_NOT_FOUND := "VIEWER_NOT_FOUND"
    static VIEWER_PATH_AMBIGUOUS := "VIEWER_PATH_AMBIGUOUS"
    static PROCESS_PATH_UNAVAILABLE := "PROCESS_PATH_UNAVAILABLE"
    static CONFIG_PATH_OUTSIDE_VIEWER_ROOT := "CONFIG_PATH_OUTSIDE_VIEWER_ROOT"
    static CONFIG_FILE_NOT_FOUND := "CONFIG_FILE_NOT_FOUND"
    static CONFIG_FILE_UNREADABLE := "CONFIG_FILE_UNREADABLE"
    static CONFIG_HASH_FAILED := "CONFIG_HASH_FAILED"
    static GEOMETRY_KEYS_NOT_FOUND := "GEOMETRY_KEYS_NOT_FOUND"
    static RUNTIME_FRAME_NOT_UNIQUE := "RUNTIME_FRAME_NOT_UNIQUE"
    static GEOMETRY_MAPPING_FAILED := "GEOMETRY_MAPPING_FAILED"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMConfigGeometryProvider {
    static AuditCurrentConfig(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        return AuditMxNMConfigGeometry(viewerExe)
    }
}

AuditMxNMConfigGeometry(viewerExe) {
    result := {
        ok: false,
        code: MxNMConfigGeometryCode.UNEXPECTED_ERROR,
        viewerExe: viewerExe,
        viewerProcessPathResolved: false,
        configRootRelationValidated: false,
        mainConfigExists: false,
        layoutConfigExists: false,
        mainConfigSha256: "",
        layoutConfigSha256: "",
        mainEntries: [],
        layoutEntries: [],
        mainGeometry: {
            framePositionResolved: false,
            frameX: 0,
            frameY: 0,
            frameSizeResolved: false,
            frameWidth: 0,
            frameHeight: 0,
            imagePositionResolved: false,
            imageX: 0,
            imageY: 0,
            imageSizeResolved: false,
            imageWidth: 0,
            imageHeight: 0
        },
        viewerWindows: [],
        runtimeFrameCandidateCount: 0,
        runtimeFrameResolved: false,
        runtimeFrame: 0,
        mappedImageRectResolved: false,
        mappedImageRect: 0
    }

    try {
        configPaths := ResolveMxNMConfigPathsFromViewer(viewerExe)
        if !configPaths.ok {
            result.code := configPaths.code
            return result
        }
        result.viewerProcessPathResolved := true
        result.configRootRelationValidated := true
        result.mainConfigExists := true
        result.layoutConfigExists := true

        result.mainConfigSha256 := ComputeMxNMConfigSha256(
            configPaths.mainConfigPath
        )
        result.layoutConfigSha256 := ComputeMxNMConfigSha256(
            configPaths.layoutConfigPath
        )
        if result.mainConfigSha256 = "" || result.layoutConfigSha256 = "" {
            result.code := MxNMConfigGeometryCode.CONFIG_HASH_FAILED
            return result
        }

        mainAudit := ReadMxNMGeometryAuditEntries(
            configPaths.mainConfigPath,
            "MxNMSoft"
        )
        if !mainAudit.ok {
            result.code := mainAudit.code
            return result
        }
        layoutAudit := ReadMxNMGeometryAuditEntries(
            configPaths.layoutConfigPath,
            "MxPetCtTemp"
        )
        if !layoutAudit.ok {
            result.code := layoutAudit.code
            return result
        }
        result.mainEntries := mainAudit.entries
        result.layoutEntries := layoutAudit.entries
        result.mainGeometry := ParseMxNMMainGeometry(result.mainEntries)
        result.viewerWindows := CaptureMxNMViewerWindowGeometry(
            viewerExe,
            configPaths.viewerProcessPath
        )
        runtimeFrameResult := ResolveMxNMRuntimeFrame(result.viewerWindows)
        result.runtimeFrameCandidateCount :=
            runtimeFrameResult.candidateCount
        if runtimeFrameResult.ok {
            result.runtimeFrameResolved := true
            result.runtimeFrame := runtimeFrameResult.frame
            mappedImageResult := MapMxNMLogicalImageRectToRuntime(
                result.mainGeometry,
                result.runtimeFrame
            )
            if mappedImageResult.ok {
                result.mappedImageRectResolved := true
                result.mappedImageRect := mappedImageResult.rect
            }
        }
        if result.mainEntries.Length = 0
            && result.layoutEntries.Length = 0 {
            result.code := MxNMConfigGeometryCode.GEOMETRY_KEYS_NOT_FOUND
            return result
        }

        result.ok := true
        result.code := MxNMConfigGeometryCode.READY_FOR_SCHEMA_MAPPING
        return result
    } catch {
        result.code := MxNMConfigGeometryCode.UNEXPECTED_ERROR
        return result
    }
}

ParseMxNMMainGeometry(entries) {
    geometry := {
        framePositionResolved: false,
        frameX: 0,
        frameY: 0,
        frameSizeResolved: false,
        frameWidth: 0,
        frameHeight: 0,
        imagePositionResolved: false,
        imageX: 0,
        imageY: 0,
        imageSizeResolved: false,
        imageWidth: 0,
        imageHeight: 0
    }
    frameX := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "FramePosX"
    )
    frameY := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "FramePosY"
    )
    frameWidth := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "FrameWidth"
    )
    frameHeight := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "FrameHeight"
    )
    imageX := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "ShowImagePosX"
    )
    imageY := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "ShowImagePosY"
    )
    imageWidth := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "ShowImageWidth"
    )
    imageHeight := FindMxNMGeometryAuditNumber(
        entries,
        "ShowSetting",
        "ShowImageHeight"
    )
    if frameX.found && frameY.found {
        geometry.framePositionResolved := true
        geometry.frameX := frameX.value
        geometry.frameY := frameY.value
    }
    if frameWidth.found && frameHeight.found
        && frameWidth.value > 0 && frameHeight.value > 0 {
        geometry.frameSizeResolved := true
        geometry.frameWidth := frameWidth.value
        geometry.frameHeight := frameHeight.value
    }
    if imageX.found && imageY.found {
        geometry.imagePositionResolved := true
        geometry.imageX := imageX.value
        geometry.imageY := imageY.value
    }
    if imageWidth.found && imageHeight.found
        && imageWidth.value > 0 && imageHeight.value > 0 {
        geometry.imageSizeResolved := true
        geometry.imageWidth := imageWidth.value
        geometry.imageHeight := imageHeight.value
    }
    return geometry
}

FindMxNMGeometryAuditNumber(entries, expectedSection, expectedKey) {
    found := false
    foundValue := 0
    for entry in entries {
        if StrLower(entry.section) != StrLower(expectedSection)
            || StrLower(entry.key) != StrLower(expectedKey) {
            continue
        }
        if found {
            return {
                found: false,
                value: 0
            }
        }
        found := true
        foundValue := entry.value + 0
    }
    return {
        found: found,
        value: foundValue
    }
}

CaptureMxNMViewerWindowGeometry(viewerExe, expectedProcessPath) {
    windows := []
    try viewerWindows := WinGetList("ahk_exe " viewerExe)
    catch {
        return windows
    }
    normalizedExpectedPath := StrLower(
        NormalizeMxNMConfigPath(expectedProcessPath)
    )
    for viewerHwnd in viewerWindows {
        try processPath := WinGetProcessPath("ahk_id " viewerHwnd)
        catch {
            continue
        }
        if StrLower(NormalizeMxNMConfigPath(processPath))
            != normalizedExpectedPath {
            continue
        }
        try WinGetPos(
            &windowX,
            &windowY,
            &windowWidth,
            &windowHeight,
            "ahk_id " viewerHwnd
        )
        catch {
            continue
        }
        clientRect := Buffer(16, 0)
        if !DllCall(
            "User32\GetClientRect",
            "Ptr", viewerHwnd,
            "Ptr", clientRect.Ptr,
            "Int"
        ) {
            continue
        }
        clientOrigin := Buffer(8, 0)
        if !DllCall(
            "User32\ClientToScreen",
            "Ptr", viewerHwnd,
            "Ptr", clientOrigin.Ptr,
            "Int"
        ) {
            continue
        }
        windows.Push({
            hwnd: viewerHwnd,
            windowX: windowX,
            windowY: windowY,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            clientX: NumGet(clientOrigin, 0, "Int"),
            clientY: NumGet(clientOrigin, 4, "Int"),
            clientWidth: NumGet(clientRect, 8, "Int"),
            clientHeight: NumGet(clientRect, 12, "Int")
        })
    }
    return windows
}

ResolveMxNMRuntimeFrame(viewerWindows) {
    candidates := []
    for candidateWindow in viewerWindows {
        containsAll := true
        for otherWindow in viewerWindows {
            if !MxNMRuntimeWindowContains(
                candidateWindow,
                otherWindow
            ) {
                containsAll := false
                break
            }
        }
        if containsAll
            candidates.Push(candidateWindow)
    }
    return {
        ok: candidates.Length = 1,
        code: candidates.Length = 1
            ? MxNMConfigGeometryCode.READY_FOR_SCHEMA_MAPPING
            : MxNMConfigGeometryCode.RUNTIME_FRAME_NOT_UNIQUE,
        candidateCount: candidates.Length,
        frame: candidates.Length = 1 ? candidates[1] : 0
    }
}

MxNMRuntimeWindowContains(containerWindow, otherWindow, tolerance := 2) {
    containerRight :=
        containerWindow.windowX + containerWindow.windowWidth
    containerBottom :=
        containerWindow.windowY + containerWindow.windowHeight
    otherRight := otherWindow.windowX + otherWindow.windowWidth
    otherBottom := otherWindow.windowY + otherWindow.windowHeight
    return otherWindow.windowX >= containerWindow.windowX - tolerance
        && otherWindow.windowY >= containerWindow.windowY - tolerance
        && otherRight <= containerRight + tolerance
        && otherBottom <= containerBottom + tolerance
}

MapMxNMLogicalImageRectToRuntime(mainGeometry, runtimeFrame) {
    if !mainGeometry.frameSizeResolved
        || !mainGeometry.imagePositionResolved
        || !mainGeometry.imageSizeResolved {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.GEOMETRY_MAPPING_FAILED
        }
    }
    logicalRight := mainGeometry.imageX + mainGeometry.imageWidth
    logicalBottom := mainGeometry.imageY + mainGeometry.imageHeight
    if mainGeometry.imageX < 0 || mainGeometry.imageY < 0
        || logicalRight > mainGeometry.frameWidth
        || logicalBottom > mainGeometry.frameHeight {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.GEOMETRY_MAPPING_FAILED
        }
    }

    mappedLeft := runtimeFrame.windowX + Round(
        mainGeometry.imageX
        * runtimeFrame.windowWidth
        / mainGeometry.frameWidth
    )
    mappedTop := runtimeFrame.windowY + Round(
        mainGeometry.imageY
        * runtimeFrame.windowHeight
        / mainGeometry.frameHeight
    )
    mappedRight := runtimeFrame.windowX + Round(
        logicalRight
        * runtimeFrame.windowWidth
        / mainGeometry.frameWidth
    )
    mappedBottom := runtimeFrame.windowY + Round(
        logicalBottom
        * runtimeFrame.windowHeight
        / mainGeometry.frameHeight
    )
    if mappedRight <= mappedLeft || mappedBottom <= mappedTop {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.GEOMETRY_MAPPING_FAILED
        }
    }
    return {
        ok: true,
        code: MxNMConfigGeometryCode.READY_FOR_SCHEMA_MAPPING,
        rect: {
            left: mappedLeft,
            top: mappedTop,
            right: mappedRight,
            bottom: mappedBottom,
            width: mappedRight - mappedLeft,
            height: mappedBottom - mappedTop
        }
    }
}

ResolveMxNMConfigPathsFromViewer(viewerExe) {
    try viewerWindows := WinGetList("ahk_exe " viewerExe)
    catch {
        viewerWindows := []
    }
    if viewerWindows.Length = 0 {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.VIEWER_NOT_FOUND
        }
    }

    processPaths := Map()
    for viewerHwnd in viewerWindows {
        try processPath := WinGetProcessPath("ahk_id " viewerHwnd)
        catch {
            processPath := ""
        }
        if processPath = ""
            continue
        normalizedProcessPath := NormalizeMxNMConfigPath(processPath)
        if normalizedProcessPath != ""
            processPaths[StrLower(normalizedProcessPath)] :=
                normalizedProcessPath
    }
    if processPaths.Count = 0 {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.PROCESS_PATH_UNAVAILABLE
        }
    }
    if processPaths.Count != 1 {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.VIEWER_PATH_AMBIGUOUS
        }
    }

    viewerProcessPath := ""
    for _, candidatePath in processPaths {
        viewerProcessPath := candidatePath
        break
    }
    SplitPath viewerProcessPath, , &viewerDirectory
    normalizedViewerDirectory := NormalizeMxNMConfigPath(viewerDirectory)
    configDirectory := NormalizeMxNMConfigPath(
        normalizedViewerDirectory "\" .
        MxNMConfigGeometryDefaults.RelativeConfigDirectory
    )
    mainConfigPath := NormalizeMxNMConfigPath(
        configDirectory "\" .
        MxNMConfigGeometryDefaults.MainConfigFileName
    )
    layoutConfigPath := NormalizeMxNMConfigPath(
        configDirectory "\" .
        MxNMConfigGeometryDefaults.LayoutConfigFileName
    )
    if !MxNMConfigPathInsideRoot(mainConfigPath, normalizedViewerDirectory)
        || !MxNMConfigPathInsideRoot(
            layoutConfigPath,
            normalizedViewerDirectory
        ) {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.CONFIG_PATH_OUTSIDE_VIEWER_ROOT
        }
    }
    if !MxNMConfigFileExists(mainConfigPath)
        || !MxNMConfigFileExists(layoutConfigPath) {
        return {
            ok: false,
            code: MxNMConfigGeometryCode.CONFIG_FILE_NOT_FOUND
        }
    }

    return {
        ok: true,
        code: MxNMConfigGeometryCode.READY_FOR_SCHEMA_MAPPING,
        viewerProcessPath: viewerProcessPath,
        viewerDirectory: normalizedViewerDirectory,
        mainConfigPath: mainConfigPath,
        layoutConfigPath: layoutConfigPath
    }
}

NormalizeMxNMConfigPath(path) {
    if String(path) = ""
        return ""
    requiredLength := DllCall(
        "Kernel32\GetFullPathNameW",
        "Str", path,
        "UInt", 0,
        "Ptr", 0,
        "Ptr", 0,
        "UInt"
    )
    if requiredLength = 0
        return ""
    pathBuffer := Buffer(requiredLength * 2, 0)
    writtenLength := DllCall(
        "Kernel32\GetFullPathNameW",
        "Str", path,
        "UInt", requiredLength,
        "Ptr", pathBuffer.Ptr,
        "Ptr", 0,
        "UInt"
    )
    if writtenLength = 0 || writtenLength >= requiredLength
        return ""
    return RTrim(StrGet(pathBuffer, writtenLength, "UTF-16"), "\")
}

MxNMConfigPathInsideRoot(candidatePath, rootPath) {
    if candidatePath = "" || rootPath = ""
        return false
    normalizedRoot := RTrim(StrLower(rootPath), "\") "\"
    normalizedCandidate := StrLower(candidatePath)
    return SubStr(normalizedCandidate, 1, StrLen(normalizedRoot))
        = normalizedRoot
}

MxNMConfigFileExists(path) {
    attributes := FileExist(path)
    return attributes != "" && !InStr(attributes, "D")
}

ReadMxNMGeometryAuditEntries(path, sourceName) {
    try configText := FileRead(path, "UTF-8")
    catch {
        try configText := FileRead(path)
        catch {
            return {
                ok: false,
                code: MxNMConfigGeometryCode.CONFIG_FILE_UNREADABLE,
                entries: []
            }
        }
    }

    entries := []
    currentSection := ""
    for line in StrSplit(configText, "`n", "`r") {
        trimmedLine := Trim(line, " `t")
        if RegExMatch(trimmedLine, "^\[([^\]]+)\]$", &sectionMatch) {
            currentSection := sectionMatch[1]
            continue
        }
        if trimmedLine = ""
            || SubStr(trimmedLine, 1, 1) = ";"
            || SubStr(trimmedLine, 1, 1) = "#" {
            continue
        }
        if !RegExMatch(trimmedLine, "^([^=]+)=(.*)$", &entryMatch)
            continue

        key := Trim(entryMatch[1], " `t")
        value := Trim(entryMatch[2], " `t")
        if !MxNMGeometryAuditKeyAllowed(
            sourceName,
            currentSection,
            key
        ) {
            continue
        }
        if !RegExMatch(
            value,
            "^-?\d+(?:\.\d+)?(?:\s*,\s*-?\d+(?:\.\d+)?)*$"
        ) {
            continue
        }
        entries.Push({
            source: sourceName,
            section: currentSection,
            key: key,
            value: RegExReplace(value, "\s+", "")
        })
    }
    return {
        ok: true,
        code: MxNMConfigGeometryCode.READY_FOR_SCHEMA_MAPPING,
        entries: entries
    }
}

MxNMGeometryAuditKeyAllowed(sourceName, section, key) {
    if sourceName = "MxNMSoft" {
        return StrLower(section) = "showsetting"
            && RegExMatch(
                key,
                "i)^(?:FramePos[XY]|Frame(?:Width|Height)|" .
                "ShowImagePos[XY]|ShowImage(?:Width|Height))$"
            )
    }
    if sourceName = "MxPetCtTemp" {
        return RegExMatch(key, "i)^(ShowModel|LowWnd)[A-Za-z0-9_]*$")
    }
    return false
}

ComputeMxNMConfigSha256(path) {
    algorithmHandle := 0
    hashHandle := 0
    fileHandle := 0
    try {
        status := DllCall(
            "Bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &algorithmHandle,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            return ""

        objectLength := ReadMxNMBcryptUIntProperty(
            algorithmHandle,
            "ObjectLength"
        )
        digestLength := ReadMxNMBcryptUIntProperty(
            algorithmHandle,
            "HashDigestLength"
        )
        if objectLength <= 0 || digestLength <= 0
            return ""

        hashObject := Buffer(objectLength, 0)
        status := DllCall(
            "Bcrypt\BCryptCreateHash",
            "Ptr", algorithmHandle,
            "Ptr*", &hashHandle,
            "Ptr", hashObject.Ptr,
            "UInt", hashObject.Size,
            "Ptr", 0,
            "UInt", 0,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            return ""

        fileHandle := FileOpen(path, "r")
        if !IsObject(fileHandle)
            return ""
        chunk := Buffer(65536, 0)
        loop {
            bytesRead := fileHandle.RawRead(chunk)
            if bytesRead = 0
                break
            status := DllCall(
                "Bcrypt\BCryptHashData",
                "Ptr", hashHandle,
                "Ptr", chunk.Ptr,
                "UInt", bytesRead,
                "UInt", 0,
                "UInt"
            )
            if status != 0
                return ""
        }

        digest := Buffer(digestLength, 0)
        status := DllCall(
            "Bcrypt\BCryptFinishHash",
            "Ptr", hashHandle,
            "Ptr", digest.Ptr,
            "UInt", digest.Size,
            "UInt", 0,
            "UInt"
        )
        if status != 0
            return ""

        hexDigest := ""
        loop digest.Size
            hexDigest .= Format(
                "{:02x}",
                NumGet(digest, A_Index - 1, "UChar")
            )
        return hexDigest
    } catch {
        return ""
    } finally {
        if IsObject(fileHandle)
            fileHandle.Close()
        if hashHandle
            DllCall("Bcrypt\BCryptDestroyHash", "Ptr", hashHandle)
        if algorithmHandle
            DllCall(
                "Bcrypt\BCryptCloseAlgorithmProvider",
                "Ptr", algorithmHandle,
                "UInt", 0
            )
    }
}

ReadMxNMBcryptUIntProperty(algorithmHandle, propertyName) {
    valueBuffer := Buffer(4, 0)
    bytesWritten := 0
    status := DllCall(
        "Bcrypt\BCryptGetProperty",
        "Ptr", algorithmHandle,
        "WStr", propertyName,
        "Ptr", valueBuffer.Ptr,
        "UInt", valueBuffer.Size,
        "UInt*", &bytesWritten,
        "UInt", 0,
        "UInt"
    )
    if status != 0 || bytesWritten != 4
        return 0
    return NumGet(valueBuffer, 0, "UInt")
}
