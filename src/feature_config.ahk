LoadRawFeatureSettings(configPath := "") {
    defaults := RawFeatureSettings(FeatureDefaults.GlobalHjklArrowsDefault)
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return defaults
    }
    if !FileExist(configPath)
        return defaults

    try {
        schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
        if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
            return defaults
        return RawFeatureSettings(
            IniRead(
                configPath,
                FeatureDefaults.Section,
                FeatureDefaults.GlobalHjklArrowsKey,
                FeatureDefaults.GlobalHjklArrowsDefault
            )
        )
    } catch {
        return defaults
    }
}
