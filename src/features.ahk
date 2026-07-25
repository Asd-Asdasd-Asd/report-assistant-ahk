RegisterConfiguredFeatures(LoadFeatureSettings())

RegisterConfiguredFeatures(settings) {
    if settings.GlobalHjklArrows {
        RegisterHotkeyDefinitions(
            GlobalHjklArrowHotkeyDefinitions(),
            ReservedApplicationHotkeyChords()
        )
    }
    RegisterHotkeyDefinitions(
        ViewerToolHotkeyDefinitions(settings),
        ReservedApplicationHotkeyChords(),
        MedExViewerToolForegroundActive
    )
    RegisterHotkeyDefinitions(
        ViewerCaptureHotkeyDefinitions(settings),
        ReservedApplicationHotkeyChords(),
        MedExViewerForegroundActive
    )
}
