class ReportAssistantTrayDefaults {
    static ReloadItemName := "重新加载配置"
    static ExitItemName := "E&xit"
}

ConfigureReportAssistantTrayMenu() {
    A_TrayMenu.Insert(
        ReportAssistantTrayDefaults.ExitItemName,
        ReportAssistantTrayDefaults.ReloadItemName,
        ReloadReportAssistantFromTray
    )
    ; Keep tray-icon double-click unassigned for the future settings UI.
    A_TrayMenu.Default := ""
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
