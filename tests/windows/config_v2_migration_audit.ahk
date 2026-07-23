#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\app_config.ahk
#Include ..\..\src\feature_model.ahk
#Include ..\..\src\hotstring_model.ahk
#Include ..\..\src\hotstring_config.ahk
#Include ..\..\src\template_renderer.ahk
#Include ..\..\src\hotstring_normalization.ahk
#Include ..\..\src\config_reconciliation.ahk
#Include ..\..\src\hotstring_config_migration.ahk

RunConfigV2MigrationAudit()

RunConfigV2MigrationAudit() {
    configPath := ReportAssistantConfig.Path()
    outputPath := A_Temp "\MedExAHK\config-v2-migration-audit.txt"
    auditResult := WriteReportAssistantConfigV2Audit(configPath, outputPath)
    if auditResult.Ok {
        message := "只读检查通过，可以升级配置。"
        iconOption := "Iconi"
        exitCode := 0
    } else {
        message := "只读检查未通过，请把检查结果交给维护者。"
        iconOption := "Icon!"
        exitCode := 1
    }
    message .= "`n`n检查结果：" outputPath
    MsgBox(
        message,
        "MedEx 配置升级检查",
        iconOption
    )
    ExitApp exitCode
}
