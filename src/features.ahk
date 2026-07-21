RegisterConfiguredFeatures(LoadFeatureSettings())

RegisterConfiguredFeatures(settings) {
    if settings.GlobalHjklArrows {
        RegisterHotkeyDefinitions(
            GlobalHjklArrowHotkeyDefinitions(),
            ReservedApplicationHotkeyChords()
        )
    }
}
