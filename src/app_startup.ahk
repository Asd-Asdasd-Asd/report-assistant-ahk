class ReportAssistantStartupDefaults {
    static MutexName := "Local\MedExReportAssistant.Singleton"
    static ErrorAlreadyExists := 183
    static LogDirectoryName := "logs"
    static LogFileName := "startup.log"
}

global REPORT_ASSISTANT_SINGLETON_HANDLE := 0

StartReportAssistantRuntime()

StartReportAssistantRuntime() {
    global REPORT_ASSISTANT_SINGLETON_HANDLE

    handle := DllCall(
        "CreateMutexW",
        "Ptr", 0,
        "Int", false,
        "Str", ReportAssistantStartupDefaults.MutexName,
        "Ptr"
    )
    createError := A_LastError

    if !handle {
        WriteReportAssistantStartupDiagnostic("SINGLETON_UNAVAILABLE")
        MsgBox(
            "MedEx Report Assistant 无法建立单实例保护。`n" .
            "为避免同时运行多个版本，程序不会启动。`n" .
            "请联系维护者。",
            "MedEx Report Assistant"
        )
        ExitApp
    }

    if createError = ReportAssistantStartupDefaults.ErrorAlreadyExists {
        DllCall("CloseHandle", "Ptr", handle)
        WriteReportAssistantStartupDiagnostic("INSTANCE_CONFLICT")
        MsgBox(
            "MedEx Report Assistant 已在运行。`n" .
            "请先通过系统托盘退出当前版本，再启动此版本。",
            "MedEx Report Assistant"
        )
        ExitApp
    }

    REPORT_ASSISTANT_SINGLETON_HANDLE := handle
    OnExit CloseReportAssistantSingleton
    WriteReportAssistantStartupDiagnostic("STARTED")
}

CloseReportAssistantSingleton(*) {
    global REPORT_ASSISTANT_SINGLETON_HANDLE

    if !REPORT_ASSISTANT_SINGLETON_HANDLE
        return
    DllCall("CloseHandle", "Ptr", REPORT_ASSISTANT_SINGLETON_HANDLE)
    REPORT_ASSISTANT_SINGLETON_HANDLE := 0
}

WriteReportAssistantStartupDiagnostic(startupResult) {
    try configPath := ReportAssistantConfig.Path()
    catch
        configPath := "UNAVAILABLE"

    block := FormatReportAssistantStartupDiagnostic(startupResult, configPath)
    if configPath = "UNAVAILABLE" {
        OutputDebug block
        return false
    }

    try {
        logPath := ReportAssistantStartupLogPath(configPath)
        SplitPath logPath, , &logDirectory
        if !DirExist(logDirectory)
            DirCreate logDirectory
        FileAppend block "`r`n`r`n", logPath, "UTF-8"
        return true
    } catch {
        OutputDebug block
        return false
    }
}

ReportAssistantStartupLogPath(configPath) {
    SplitPath configPath, , &configDirectory
    return configDirectory "\" ReportAssistantStartupDefaults.LogDirectoryName "\" ReportAssistantStartupDefaults.LogFileName
}

FormatReportAssistantStartupDiagnostic(startupResult, configPath) {
    lines := [
        "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "StartupResult=" startupResult,
        "AppVersion=" AppMetadata.Version,
        "SourceRevision=" AppMetadata.SourceRevision,
        "ExecutablePath=" A_ScriptFullPath,
        "ConfigPath=" configPath
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output
}
