class MxNMViewerRuntimeProbeCode {
    static READY := "READY"
    static VIEWER_NOT_FOUND := "VIEWER_NOT_FOUND"
    static VIEWER_PATH_AMBIGUOUS := "VIEWER_PATH_AMBIGUOUS"
    static PROFILE_ROOT_NOT_FOUND := "PROFILE_ROOT_NOT_FOUND"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMViewerRuntimeProbe {
    static ProfileRootName := "MultNMSoftInfo"
    static MainConfigPattern := "MxNMSoft*.ini"
    static LayoutConfigFileName := "MxPetCtTemp.ini"

    static AuditVendorProfiles(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        return AuditMxNMVendorProfiles(viewerExe)
    }

    static CapturePoint(screenPoint, expectedPid := 0) {
        return CaptureMxNMWindowChainAtPoint(
            screenPoint,
            expectedPid
        )
    }

    static FindCommandControls(
        viewerExe,
        expectedProcessPath,
        commandIds
    ) {
        return FindMxNMViewerCommandControls(
            viewerExe,
            expectedProcessPath,
            commandIds
        )
    }
}

AuditMxNMVendorProfiles(viewerExe) {
    result := {
        ok: false,
        code: MxNMViewerRuntimeProbeCode.UNEXPECTED_ERROR,
        viewerExe: viewerExe,
        viewerProcessPath: "",
        viewerDirectory: "",
        profileRootExists: false,
        candidates: [],
        rootDisplayHints: []
    }
    try {
        viewerPathResult := ResolveMxNMViewerPathForRuntimeProbe(
            viewerExe
        )
        result.code := viewerPathResult.code
        if !viewerPathResult.ok
            return result
        result.viewerProcessPath := viewerPathResult.viewerProcessPath
        result.viewerDirectory := viewerPathResult.viewerDirectory

        profileRoot := NormalizeMxNMConfigPath(
            result.viewerDirectory "\" .
            MxNMViewerRuntimeProbe.ProfileRootName
        )
        if profileRoot = ""
            || !DirExist(profileRoot)
            || !MxNMConfigPathInsideRoot(
                profileRoot,
                result.viewerDirectory
            ) {
            result.code :=
                MxNMViewerRuntimeProbeCode.PROFILE_ROOT_NOT_FOUND
            return result
        }
        result.profileRootExists := true
        result.rootDisplayHints :=
            ReadMxNMRootDisplayHints(profileRoot)

        candidateDirectories := [profileRoot]
        Loop Files profileRoot "\*", "D" {
            candidateDirectory := NormalizeMxNMConfigPath(
                A_LoopFileFullPath
            )
            if candidateDirectory != ""
                && MxNMConfigPathInsideRoot(
                    candidateDirectory,
                    profileRoot
                ) {
                candidateDirectories.Push(candidateDirectory)
            }
        }
        for candidateDirectory in candidateDirectories {
            layoutConfigPath := NormalizeMxNMConfigPath(
                candidateDirectory "\" .
                MxNMViewerRuntimeProbe.LayoutConfigFileName
            )
            if !MxNMConfigFileExists(layoutConfigPath)
                continue
            Loop Files candidateDirectory "\" .
                MxNMViewerRuntimeProbe.MainConfigPattern, "F" {
                mainConfigPath := NormalizeMxNMConfigPath(
                    A_LoopFileFullPath
                )
                if mainConfigPath = ""
                    || !MxNMConfigPathInsideRoot(
                        mainConfigPath,
                        profileRoot
                    ) {
                    continue
                }
                result.candidates.Push(
                    BuildMxNMVendorProfileCandidate(
                        viewerExe,
                        result.viewerProcessPath,
                        profileRoot,
                        candidateDirectory,
                        mainConfigPath,
                        layoutConfigPath
                    )
                )
            }
        }
        result.ok := true
        result.code := MxNMViewerRuntimeProbeCode.READY
        return result
    } catch {
        result.code := MxNMViewerRuntimeProbeCode.UNEXPECTED_ERROR
        return result
    }
}

ResolveMxNMViewerPathForRuntimeProbe(viewerExe) {
    try viewerWindows := WinGetList("ahk_exe " viewerExe)
    catch {
        viewerWindows := []
    }
    if viewerWindows.Length = 0 {
        return {
            ok: false,
            code: MxNMViewerRuntimeProbeCode.VIEWER_NOT_FOUND
        }
    }

    processPaths := Map()
    for viewerHwnd in viewerWindows {
        try processPath := WinGetProcessPath(
            "ahk_id " viewerHwnd
        )
        catch {
            processPath := ""
        }
        normalizedPath := NormalizeMxNMConfigPath(processPath)
        if normalizedPath != ""
            processPaths[StrLower(normalizedPath)] := normalizedPath
    }
    if processPaths.Count = 0 {
        return {
            ok: false,
            code: MxNMViewerRuntimeProbeCode.VIEWER_NOT_FOUND
        }
    }
    if processPaths.Count != 1 {
        return {
            ok: false,
            code:
                MxNMViewerRuntimeProbeCode.VIEWER_PATH_AMBIGUOUS
        }
    }
    viewerProcessPath := ""
    for _, path in processPaths {
        viewerProcessPath := path
        break
    }
    SplitPath viewerProcessPath, , &viewerDirectory
    viewerDirectory := NormalizeMxNMConfigPath(viewerDirectory)
    return {
        ok: viewerDirectory != "",
        code: viewerDirectory != ""
            ? MxNMViewerRuntimeProbeCode.READY
            : MxNMViewerRuntimeProbeCode.VIEWER_NOT_FOUND,
        viewerProcessPath: viewerProcessPath,
        viewerDirectory: viewerDirectory
    }
}

BuildMxNMVendorProfileCandidate(
    viewerExe,
    viewerProcessPath,
    profileRoot,
    candidateDirectory,
    mainConfigPath,
    layoutConfigPath
) {
    candidateId := MxNMVendorProfileCandidateId(
        profileRoot,
        candidateDirectory,
        mainConfigPath
    )
    configPaths := {
        ok: true,
        viewerProcessPath: viewerProcessPath,
        mainConfigPath: mainConfigPath,
        layoutConfigPath: layoutConfigPath
    }
    configResult := MxNMConfigGeometryProvider.LoadStaticConfig(
        viewerExe,
        configPaths
    )
    try configText := FileRead(mainConfigPath)
    catch
        configText := ""
    commandResult := configText != ""
        ? ParseMxNMSCBtnPadCommands(configText)
        : MakeMxNMSCBtnPadParseFailure()
    return {
        id: candidateId,
        productionDefault:
            MxNMVendorProfileIsProductionDefault(
                profileRoot,
                candidateDirectory,
                mainConfigPath
            ),
        configOk: configResult.ok,
        configCode: configResult.code,
        mainConfigSha256: configResult.mainConfigSha256,
        layoutConfigSha256: configResult.layoutConfigSha256,
        geometry: configResult.mainGeometry,
        commandsOk: commandResult.ok,
        rowCount: commandResult.rowCount,
        padX: commandResult.padX,
        padY: commandResult.padY,
        commands: commandResult.entries,
        displayHints: ReadMxNMVendorDisplayHints(
            mainConfigPath,
            candidateId
        )
    }
}

MxNMVendorProfileCandidateId(
    profileRoot,
    candidateDirectory,
    mainConfigPath
) {
    SplitPath mainConfigPath, &mainFileName
    if StrLower(candidateDirectory) = StrLower(profileRoot)
        return "(root)/" mainFileName
    SplitPath candidateDirectory, &directoryName
    return directoryName "/" mainFileName
}

MxNMVendorProfileIsProductionDefault(
    profileRoot,
    candidateDirectory,
    mainConfigPath
) {
    SplitPath mainConfigPath, &mainFileName
    SplitPath candidateDirectory, &directoryName
    return directoryName = "1"
        && StrLower(mainFileName)
            = StrLower(
                MxNMConfigGeometryDefaults.MainConfigFileName
            )
}

ReadMxNMRootDisplayHints(profileRoot) {
    hints := []
    Loop Files profileRoot "\*.ini", "F" {
        for hint in ReadMxNMVendorDisplayHints(
            A_LoopFileFullPath,
            "root/" A_LoopFileName
        ) {
            hints.Push(hint)
        }
    }
    return hints
}

ReadMxNMVendorDisplayHints(path, sourceId) {
    try configText := FileRead(path, "UTF-8")
    catch {
        try configText := FileRead(path)
        catch
            return []
    }
    hints := []
    currentSection := ""
    for line in StrSplit(configText, "`n", "`r") {
        trimmedLine := Trim(line, " `t")
        if RegExMatch(
            trimmedLine,
            "^\[([^\]]+)\]$",
            &sectionMatch
        ) {
            currentSection := sectionMatch[1]
            continue
        }
        if trimmedLine = ""
            || SubStr(trimmedLine, 1, 1) = ";"
            || SubStr(trimmedLine, 1, 1) = "#"
            || !RegExMatch(
                trimmedLine,
                "^([^=]+)=(.*)$",
                &entryMatch
            ) {
            continue
        }
        key := Trim(entryMatch[1], " `t")
        if !RegExMatch(
            key,
            "i)(?:Resolution|Screen|Display|Monitor|Profile|" .
                "Config|Dpi|Scale|Frame(?:Width|Height)|" .
                "ShowImage(?:Width|Height)|SCBtnPadPos)"
        ) {
            continue
        }
        value := Trim(entryMatch[2], " `t")
        safeValue := MxNMVendorSafeDisplayHintValue(value)
        hints.Push({
            source: sourceId,
            section: currentSection,
            key: key,
            value: safeValue
        })
    }
    return hints
}

MxNMVendorSafeDisplayHintValue(value) {
    if RegExMatch(
        value,
        "^[A-Za-z0-9_.:, xX|;/\[\]()-]{1,120}$"
    ) {
        return value
    }
    numericTokens := []
    searchPosition := 1
    while RegExMatch(
        value,
        "-?\d+(?:\.\d+)?",
        &numberMatch,
        searchPosition
    ) {
        numericTokens.Push(numberMatch[0])
        searchPosition := numberMatch.Pos + numberMatch.Len
        if numericTokens.Length >= 24
            break
    }
    if numericTokens.Length = 0
        return "<present>"
    summary := ""
    for index, token in numericTokens
        summary .= (index = 1 ? "" : ",") token
    return "<numeric-tokens:" summary ">"
}

CaptureMxNMWindowChainAtPoint(screenPoint, expectedPid := 0) {
    result := {
        ok: false,
        point: screenPoint,
        pointHwnd: 0,
        rootHwnd: 0,
        rootOwnerHwnd: 0,
        chain: []
    }
    if !IsObject(screenPoint)
        || !screenPoint.HasOwnProp("x")
        || !screenPoint.HasOwnProp("y") {
        return result
    }
    packedPoint := ((Round(screenPoint.y) & 0xFFFFFFFF) << 32)
        | (Round(screenPoint.x) & 0xFFFFFFFF)
    try pointHwnd := DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch
        pointHwnd := 0
    if !pointHwnd
        return result
    result.pointHwnd := pointHwnd
    result.rootHwnd := MxNMProbeGetAncestor(pointHwnd, 2)
    result.rootOwnerHwnd := MxNMProbeGetAncestor(pointHwnd, 3)

    seen := Map()
    currentHwnd := pointHwnd
    loop 16 {
        if !currentHwnd || seen.Has(currentHwnd)
            break
        seen[currentHwnd] := true
        windowInfo := CaptureMxNMRuntimeWindowInfo(
            currentHwnd,
            expectedPid
        )
        windowInfo.depth := A_Index - 1
        result.chain.Push(windowInfo)
        try currentHwnd := DllCall(
            "User32\GetParent",
            "Ptr", currentHwnd,
            "Ptr"
        )
        catch
            currentHwnd := 0
    }
    result.ok := result.chain.Length > 0
        && (!expectedPid || result.chain[1].samePid)
    return result
}

FindMxNMViewerCommandControls(
    viewerExe,
    expectedProcessPath,
    commandIds
) {
    matches := []
    windows := CaptureMxNMViewerWindowGeometry(
        viewerExe,
        expectedProcessPath
    )
    if windows.Length = 0
        return matches
    try expectedPid := WinGetPID(
        "ahk_id " windows[1].hwnd
    )
    catch
        expectedPid := 0
    if !expectedPid
        return matches
    seen := Map()
    for window in windows {
        CollectMxNMCommandControlMatch(
            expectedPid,
            commandIds,
            seen,
            matches,
            window.hwnd,
            0
        )
        callback := CallbackCreate(
            CollectMxNMCommandControlMatch.Bind(
                expectedPid,
                commandIds,
                seen,
                matches
            ),
            "Fast",
            2
        )
        try DllCall(
            "User32\EnumChildWindows",
            "Ptr", window.hwnd,
            "Ptr", callback,
            "Ptr", 0,
            "Int"
        )
        finally CallbackFree(callback)
    }
    return matches
}

CollectMxNMCommandControlMatch(
    expectedPid,
    commandIds,
    seen,
    matches,
    hwnd,
    *
) {
    if !hwnd || seen.Has(hwnd)
        return true
    seen[hwnd] := true
    info := CaptureMxNMRuntimeWindowInfo(hwnd, expectedPid)
    for commandId in commandIds {
        if info.controlId = commandId {
            matches.Push(info)
            break
        }
    }
    return true
}

CaptureMxNMRuntimeWindowInfo(hwnd, expectedPid := 0) {
    try pid := WinGetPID("ahk_id " hwnd)
    catch
        pid := 0
    try parentHwnd := DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        parentHwnd := 0
    try controlId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", hwnd,
        "Int"
    )
    catch
        controlId := 0
    return {
        hwnd: hwnd,
        parentHwnd: parentHwnd,
        pid: pid,
        samePid: expectedPid > 0 && pid = expectedPid,
        className: MxNMProbeWindowClass(hwnd),
        controlId: controlId,
        visible: !!DllCall(
            "User32\IsWindowVisible",
            "Ptr", hwnd,
            "Int"
        ),
        enabled: !!DllCall(
            "User32\IsWindowEnabled",
            "Ptr", hwnd,
            "Int"
        ),
        rect: MxNMProbeWindowRect(hwnd)
    }
}

MxNMProbeGetAncestor(hwnd, flag) {
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", flag,
        "Ptr"
    )
    catch
        return 0
}

MxNMProbeWindowClass(hwnd) {
    classBuffer := Buffer(512, 0)
    try length := DllCall(
        "User32\GetClassNameW",
        "Ptr", hwnd,
        "Ptr", classBuffer.Ptr,
        "Int", 255,
        "Int"
    )
    catch
        length := 0
    return length > 0
        ? StrGet(classBuffer, length, "UTF-16")
        : ""
}

MxNMProbeWindowRect(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall(
        "User32\GetWindowRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    ) {
        return 0
    }
    return {
        left: NumGet(rectBuffer, 0, "Int"),
        top: NumGet(rectBuffer, 4, "Int"),
        right: NumGet(rectBuffer, 8, "Int"),
        bottom: NumGet(rectBuffer, 12, "Int")
    }
}
