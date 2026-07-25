class FeatureDefaults {
    static Section := "Features"
    static GlobalHjklArrowsKey := "GlobalHjklArrows"
    static GlobalHjklArrowsDefault := "false"
    static ViewerToolSection := "ViewerToolHotkeys"
    static ViewerArrowEnabledKey := "ArrowEnabled"
    static ViewerArrowChordKey := "ArrowChord"
    static ViewerLengthEnabledKey := "LengthEnabled"
    static ViewerLengthChordKey := "LengthChord"
    static ViewerSuv3DEnabledKey := "Suv3DEnabled"
    static ViewerSuv3DChordKey := "Suv3DChord"
    static ViewerCaptureEnabledKey := "CaptureEnabled"
    static ViewerCaptureChordKey := "CaptureChord"
    static ViewerToolEnabledDefault := "false"
    static ViewerArrowChordDefault := "^!1"
    static ViewerLengthChordDefault := "^!2"
    static ViewerSuv3DChordDefault := "^!3"
    static ViewerCaptureChordDefault := "^!4"

    static ManagedConfigDefaults() {
        return [
            ManagedConfigEntry(
                this.Section,
                this.GlobalHjklArrowsKey,
                this.GlobalHjklArrowsDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerArrowEnabledKey,
                this.ViewerToolEnabledDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerArrowChordKey,
                this.ViewerArrowChordDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerLengthEnabledKey,
                this.ViewerToolEnabledDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerLengthChordKey,
                this.ViewerLengthChordDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerSuv3DEnabledKey,
                this.ViewerToolEnabledDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerSuv3DChordKey,
                this.ViewerSuv3DChordDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerCaptureEnabledKey,
                this.ViewerToolEnabledDefault
            ),
            ManagedConfigEntry(
                this.ViewerToolSection,
                this.ViewerCaptureChordKey,
                this.ViewerCaptureChordDefault
            )
        ]
    }
}

class RawFeatureSettings {
    __New(
        globalHjklArrows,
        viewerArrowEnabled,
        viewerArrowChord,
        viewerLengthEnabled,
        viewerLengthChord,
        viewerSuv3DEnabled,
        viewerSuv3DChord,
        viewerCaptureEnabled,
        viewerCaptureChord
    ) {
        this.GlobalHjklArrows := String(globalHjklArrows)
        this.ViewerArrowEnabled := String(viewerArrowEnabled)
        this.ViewerArrowChord := String(viewerArrowChord)
        this.ViewerLengthEnabled := String(viewerLengthEnabled)
        this.ViewerLengthChord := String(viewerLengthChord)
        this.ViewerSuv3DEnabled := String(viewerSuv3DEnabled)
        this.ViewerSuv3DChord := String(viewerSuv3DChord)
        this.ViewerCaptureEnabled := String(viewerCaptureEnabled)
        this.ViewerCaptureChord := String(viewerCaptureChord)
    }
}

class FeatureSettings {
    __New(
        globalHjklArrows := false,
        viewerArrowEnabled := false,
        viewerArrowChord := "",
        viewerLengthEnabled := false,
        viewerLengthChord := "",
        viewerSuv3DEnabled := false,
        viewerSuv3DChord := "",
        viewerCaptureEnabled := false,
        viewerCaptureChord := ""
    ) {
        this.GlobalHjklArrows := globalHjklArrows = true
        this.ViewerArrowEnabled := viewerArrowEnabled = true
        this.ViewerArrowChord := String(viewerArrowChord)
        this.ViewerLengthEnabled := viewerLengthEnabled = true
        this.ViewerLengthChord := String(viewerLengthChord)
        this.ViewerSuv3DEnabled := viewerSuv3DEnabled = true
        this.ViewerSuv3DChord := String(viewerSuv3DChord)
        this.ViewerCaptureEnabled := viewerCaptureEnabled = true
        this.ViewerCaptureChord := String(viewerCaptureChord)
    }
}

class HotkeyDefinition {
    __New(id, chord, handler) {
        this.Id := String(id)
        this.Chord := String(chord)
        this.Handler := handler
    }
}
