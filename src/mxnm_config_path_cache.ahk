class MxNMConfigPathCacheDefaults {
    static SchemaVersion := 1
    static FileName := "mxnm-config-path-cache.ini"
}

MxNMConfigPathCachePath() {
    configPath := ReportAssistantConfig.Path()
    SplitPath configPath, , &configDirectory
    return configDirectory "\" MxNMConfigPathCacheDefaults.FileName
}

LoadValidatedMxNMConfigPathCache(cachePath := "") {
    if cachePath = "" {
        try cachePath := MxNMConfigPathCachePath()
        catch
            return 0
    }
    if !FileExist(cachePath)
        return 0

    try {
        cache := Map(
            "schemaVersion",
            IniRead(cachePath, "Cache", "SchemaVersion", ""),
            "viewerExe",
            IniRead(cachePath, "Cache", "ViewerExe", ""),
            "viewerProcessPath",
            IniRead(cachePath, "Cache", "ViewerProcessPath", ""),
            "validatedAt",
            IniRead(cachePath, "Cache", "ValidatedAt", "UNKNOWN")
        )
    } catch {
        return 0
    }
    if String(cache["schemaVersion"])
        != String(MxNMConfigPathCacheDefaults.SchemaVersion) {
        return 0
    }
    if cache["viewerExe"] = "" || cache["viewerProcessPath"] = ""
        return 0

    configPaths := ResolveMxNMConfigPathsFromProcessPath(
        cache["viewerExe"],
        cache["viewerProcessPath"]
    )
    if !configPaths.ok
        return 0
    cache["viewerProcessPath"] := configPaths.viewerProcessPath
    cache["configPaths"] := configPaths
    cache["path"] := cachePath
    return cache
}

SaveValidatedMxNMConfigPathCache(
    viewerExe,
    configPaths,
    cachePath := ""
) {
    if !IsObject(configPaths) || !configPaths.ok
        return false
    validatedPaths := ResolveMxNMConfigPathsFromProcessPath(
        viewerExe,
        configPaths.viewerProcessPath
    )
    if !validatedPaths.ok
        return false
    if cachePath = ""
        cachePath := MxNMConfigPathCachePath()

    SplitPath cachePath, , &cacheDirectory
    DirCreate cacheDirectory
    tempPath := cachePath ".write.tmp.ini"
    try {
        try FileDelete tempPath
        IniWrite(
            MxNMConfigPathCacheDefaults.SchemaVersion,
            tempPath,
            "Cache",
            "SchemaVersion"
        )
        IniWrite viewerExe, tempPath, "Cache", "ViewerExe"
        IniWrite(
            validatedPaths.viewerProcessPath,
            tempPath,
            "Cache",
            "ViewerProcessPath"
        )
        IniWrite A_NowUTC, tempPath, "Cache", "ValidatedAt"
        if !LoadValidatedMxNMConfigPathCache(tempPath) {
            FileDelete tempPath
            return false
        }
        FileMove tempPath, cachePath, true
        return true
    } catch {
        try FileDelete tempPath
        return false
    }
}
