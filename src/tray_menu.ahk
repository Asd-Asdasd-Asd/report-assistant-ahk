class ReportAssistantTrayDefaults {
    static SettingsItemName := "设置…"
    static AboutItemName := "关于麦旋风…"
    static CopyDiagnosticItemName := "复制诊断信息"
    static EnableDiagnosticItemName := "开启 10 分钟详细诊断"
    static ClearCaptionItemName := "清除快速标图 caption"
    static ReloadItemName := "重新加载配置"
    static ExitItemName := "E&xit"
}

ConfigureReportAssistantTrayMenu() {
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.SettingsItemName,
        ShowReportAssistantSettings
    )
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.AboutItemName,
        ShowReportAssistantAbout
    )
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.CopyDiagnosticItemName,
        CopyAutomationDiagnosticInformation
    )
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.EnableDiagnosticItemName,
        EnableAutomationDiagnosticsForTenMinutes
    )
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.ClearCaptionItemName,
        ClearReportImageCaptionCache
    )
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.ReloadItemName,
        ReloadReportAssistantFromTray
    )
    A_TrayMenu.Default := ReportAssistantTrayDefaults.SettingsItemName
    A_TrayMenu.ClickCount := 2
}

ShowReportAssistantAbout(*) {
    MsgBox(
        FormatAppVersionInfoText(),
        "关于麦旋风",
        "Iconi"
    )
}

ReloadReportAssistantFromTray(*) {
    try Reload()
    catch as err {
        OutputDebug "Report Assistant reload failed: " err.Message
        MsgBox(
            "无法重新加载配置。当前版本将继续运行。`n" .
            "请检查配置文件后重试。",
            "MedEx Report Assistant"
        )
    }
}
