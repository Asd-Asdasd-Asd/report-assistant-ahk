ReportAssistantManagedConfigDefaults() {
    defaults := []
    for definition in FeatureDefaults.ManagedConfigDefaults()
        defaults.Push(definition)
    return defaults
}

PrepareReportAssistantConfig(managedDefaults, configPath := "") {
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return ReportConfigMigrationResult(
                false, "CONFIG_PATH_UNAVAILABLE", "无法取得配置文件路径。"
            )
    }
    if !FileExist(configPath) {
        try {
            if !CreateDefaultReportHotstringConfig(configPath)
                throw Error("Default config was not created")
            return ReportConfigMigrationResult(
                true, "DEFAULT_CONFIG_CREATED", "已创建默认配置。"
            )
        } catch {
            return ReportConfigMigrationResult(
                false, "DEFAULT_CONFIG_CREATE_FAILED", "无法创建默认配置文件。"
            )
        }
    }

    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch {
        return ReportConfigMigrationResult(
            false, "CONFIG_SCHEMA_READ_FAILED", "无法读取配置文件版本。"
        )
    }
    if schemaValue = "1" {
        migration := MigrateReportAssistantConfigV1ToV2(configPath)
        if !migration.Ok
            return migration
    } else if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion) {
        return ReportConfigMigrationResult(
            false, "UNSUPPORTED_SCHEMA",
            "配置文件版本与当前程序不兼容，原文件未被修改。"
        )
    }

    try reconciled := ReconcileManagedConfigDefaults(configPath, managedDefaults)
    catch
        reconciled := false
    if !reconciled {
        return ReportConfigMigrationResult(
            false, "CONFIG_RECONCILIATION_FAILED",
            "配置文件无法完成安全检查，原有模板未加载。"
        )
    }
    return ReportConfigMigrationResult(
        true, "CONFIG_READY", "配置已就绪。"
    )
}

global ReportAssistantConfigStartupResult := PrepareReportAssistantConfig(
    ReportAssistantManagedConfigDefaults()
)
if !ReportAssistantConfigStartupResult.Ok {
    OutputDebug(
        "Report Assistant config startup failed: " .
        ReportAssistantConfigStartupResult.Code
    )
    MsgBox(
        ReportAssistantConfigStartupResult.Message .
            "`n`n报告模板已停用，其他安全功能仍可继续使用。",
        "MedEx Report Assistant",
        "Icon!"
    )
}
