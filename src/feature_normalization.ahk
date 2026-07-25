LoadFeatureSettings(configPath := "") {
    return NormalizeFeatureSettings(LoadRawFeatureSettings(configPath))
}

NormalizeFeatureSettings(raw) {
    return FeatureSettings(
        ParseOptionalFeatureEnabled(raw.GlobalHjklArrows),
        ParseOptionalFeatureEnabled(raw.ViewerArrowEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerArrowChord),
        ParseOptionalFeatureEnabled(raw.ViewerLengthEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerLengthChord),
        ParseOptionalFeatureEnabled(raw.ViewerSuv3DEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerSuv3DChord)
    )
}

ParseOptionalFeatureEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    return normalized = "true"
}

NormalizeOptionalHotkeyChord(value) {
    return Trim(String(value), " `t`r`n")
}

ValidateViewerToolHotkeySettings(settings) {
    definitions := [
        {
            field: "ViewerArrowChord",
            label: "箭头",
            enabled: settings.ViewerArrowEnabled,
            chord: settings.ViewerArrowChord
        },
        {
            field: "ViewerLengthChord",
            label: "长度测量",
            enabled: settings.ViewerLengthEnabled,
            chord: settings.ViewerLengthChord
        },
        {
            field: "ViewerSuv3DChord",
            label: "3D SUV测量",
            enabled: settings.ViewerSuv3DEnabled,
            chord: settings.ViewerSuv3DChord
        }
    ]
    seen := BuildHotkeyChordSet(ReservedApplicationHotkeyChords())
    if settings.GlobalHjklArrows {
        for definition in GlobalHjklArrowHotkeyDefinitions()
            seen[NormalizeHotkeyChord(definition.Chord)] := true
    }
    for definition in definitions {
        chord := NormalizeOptionalHotkeyChord(definition.chord)
        if InStr(chord, "`r") || InStr(chord, "`n") {
            return MakeViewerToolHotkeyValidation(
                false,
                definition.field,
                definition.label "快捷键格式无效。"
            )
        }
        if !definition.enabled
            continue
        if chord = "" {
            return MakeViewerToolHotkeyValidation(
                false,
                definition.field,
                "启用“" definition.label "”前必须设置快捷键。"
            )
        }
        if !ViewerToolHotkeyChordHasTwoModifiers(chord) {
            return MakeViewerToolHotkeyValidation(
                false,
                definition.field,
                "“" definition.label "”快捷键至少需要两个修饰键。"
            )
        }
        chordKey := NormalizeHotkeyChord(chord)
        if seen.Has(chordKey) {
            return MakeViewerToolHotkeyValidation(
                false,
                definition.field,
                "“" definition.label "”快捷键与其他功能重复。"
            )
        }
        seen[chordKey] := true
    }
    return MakeViewerToolHotkeyValidation(true)
}

ViewerToolHotkeyChordHasTwoModifiers(chord) {
    if !RegExMatch(String(chord), "^([!+^]+)(.+)$", &match)
        return false
    modifierCount := 0
    for modifier in ["^", "!", "+"] {
        if InStr(match[1], modifier)
            modifierCount += 1
    }
    return modifierCount >= 2
}

MakeViewerToolHotkeyValidation(ok, field := "", message := "") {
    return {
        Ok: ok = true,
        Field: String(field),
        Message: String(message)
    }
}

ViewerToolHotkeySettingsMatch(expected, actual) {
    return expected.ViewerArrowEnabled = actual.ViewerArrowEnabled
        && expected.ViewerArrowChord = actual.ViewerArrowChord
        && expected.ViewerLengthEnabled = actual.ViewerLengthEnabled
        && expected.ViewerLengthChord = actual.ViewerLengthChord
        && expected.ViewerSuv3DEnabled = actual.ViewerSuv3DEnabled
        && expected.ViewerSuv3DChord = actual.ViewerSuv3DChord
}
