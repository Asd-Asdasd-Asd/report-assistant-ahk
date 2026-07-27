RegisterConfiguredFeatures(LoadFeatureSettings())

RegisterConfiguredFeatures(settings) {
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
