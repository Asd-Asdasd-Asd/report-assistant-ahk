class ReportAssistantTrayDefaults {
    static SettingsItemName := "设置…"
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
        ReportAssistantTrayDefaults.ReloadItemName,
        ReloadReportAssistantFromTray
    )
    A_TrayMenu.Default := ReportAssistantTrayDefaults.SettingsItemName
    A_TrayMenu.ClickCount := 2
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
