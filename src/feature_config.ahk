LoadRawFeatureSettings(configPath := "") {
    defaults := RawFeatureSettings(
        FeatureDefaults.GlobalHjklArrowsDefault,
        FeatureDefaults.ReportImageCaptionEnabledDefault,
        FeatureDefaults.ReportImageCaptionChordDefault,
        FeatureDefaults.ViewerToolEnabledDefault,
        FeatureDefaults.ViewerArrowChordDefault,
        FeatureDefaults.ViewerToolEnabledDefault,
        FeatureDefaults.ViewerLengthChordDefault,
        FeatureDefaults.ViewerToolEnabledDefault,
        FeatureDefaults.ViewerSuv3DChordDefault,
        FeatureDefaults.ViewerToolEnabledDefault,
        FeatureDefaults.ViewerCaptureChordDefault,
        FeatureDefaults.ViewerToolEnabledDefault,
        FeatureDefaults.ViewerClearChordDefault
    )
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
            ),
            IniRead(
                configPath,
                FeatureDefaults.ReportImageCaptionSection,
                FeatureDefaults.ReportImageCaptionEnabledKey,
                FeatureDefaults.ReportImageCaptionEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ReportImageCaptionSection,
                FeatureDefaults.ReportImageCaptionChordKey,
                FeatureDefaults.ReportImageCaptionChordDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerArrowEnabledKey,
                FeatureDefaults.ViewerToolEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerArrowChordKey,
                FeatureDefaults.ViewerArrowChordDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerLengthEnabledKey,
                FeatureDefaults.ViewerToolEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerLengthChordKey,
                FeatureDefaults.ViewerLengthChordDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerSuv3DEnabledKey,
                FeatureDefaults.ViewerToolEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerSuv3DChordKey,
                FeatureDefaults.ViewerSuv3DChordDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerCaptureEnabledKey,
                FeatureDefaults.ViewerToolEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerCaptureChordKey,
                FeatureDefaults.ViewerCaptureChordDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerClearEnabledKey,
                FeatureDefaults.ViewerToolEnabledDefault
            ),
            IniRead(
                configPath,
                FeatureDefaults.ViewerToolSection,
                FeatureDefaults.ViewerClearChordKey,
                FeatureDefaults.ViewerClearChordDefault
            )
        )
    } catch {
        return defaults
    }
}
