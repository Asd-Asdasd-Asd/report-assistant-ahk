RegisterConfiguredFeatures(
    LoadFeatureSettings(),
    LoadMxNMMontageSettings()
)

RegisterConfiguredFeatures(settings, montageSettings := 0) {
    if IsObject(montageSettings)
        && montageSettings.ok
        && montageSettings.enabled {
        RegisterHotkeyDefinitions(
            MxNMMontageHotkeyDefinitions(montageSettings),
            ReservedApplicationHotkeyChords(),
            MedExViewerForegroundActive
        )
    }
    RegisterHotkeyDefinitions(
        ReportImageCaptionHotkeyDefinitions(settings),
        ReservedApplicationHotkeyChords(),
        ReportImageCaptionForegroundActive
    )
    if settings.GlobalHjklArrows {
        RegisterHotkeyDefinitions(
            GlobalHjklArrowHotkeyDefinitions(),
            ReservedApplicationHotkeyChords()
        )
    }
    RegisterHotkeyDefinitions(
        ViewerToolHotkeyDefinitions(settings, false),
        ReservedApplicationHotkeyChords(),
        MedExViewerToolForegroundActive
    )
    RegisterHotkeyDefinitions(
        ViewerToolHotkeyDefinitions(settings, true),
        ReservedApplicationHotkeyChords(),
        MedExViewerForegroundActive
    )
    RegisterHotkeyDefinitions(
        ViewerCaptureHotkeyDefinitions(settings),
        ReservedApplicationHotkeyChords(),
        MedExViewerForegroundActive
    )
}
