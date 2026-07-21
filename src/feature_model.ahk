class FeatureDefaults {
    static Section := "Features"
    static GlobalHjklArrowsKey := "GlobalHjklArrows"
    static GlobalHjklArrowsDefault := "false"

    static ManagedConfigDefaults() {
        return [
            ManagedConfigEntry(
                this.Section,
                this.GlobalHjklArrowsKey,
                this.GlobalHjklArrowsDefault
            )
        ]
    }
}

class RawFeatureSettings {
    __New(globalHjklArrows) {
        this.GlobalHjklArrows := String(globalHjklArrows)
    }
}

class FeatureSettings {
    __New(globalHjklArrows := false) {
        this.GlobalHjklArrows := globalHjklArrows = true
    }
}

class HotkeyDefinition {
    __New(id, chord, handler) {
        this.Id := String(id)
        this.Chord := String(chord)
        this.Handler := handler
    }
}
