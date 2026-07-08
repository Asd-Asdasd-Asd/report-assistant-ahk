RequireReportEditor() {
    global REPORT_EDITOR_EXE
    return RequireWindowByExe(REPORT_EDITOR_EXE, "Report editor not active")
}

RequireViewer() {
    global VIEWER_EXE
    return RequireWindowByExe(VIEWER_EXE, "Viewer not active")
}

RequireWindowByExe(exeName, failureMessage) {
    if !IsSet(exeName) || exeName = "" {
        ToolTip failureMessage ": missing executable setting"
        SetTimer () => ToolTip(), -1200
        return false
    }

    windowQuery := "ahk_exe " exeName
    if !WinExist(windowQuery) {
        ToolTip failureMessage
        SetTimer () => ToolTip(), -1200
        return false
    }

    WinActivate windowQuery
    if !WinWaitActive(windowQuery, , 1) {
        ToolTip failureMessage ": activation failed"
        SetTimer () => ToolTip(), -1200
        return false
    }

    return true
}
