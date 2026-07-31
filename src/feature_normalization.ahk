LoadFeatureSettings(configPath := "") {
    return NormalizeFeatureSettings(LoadRawFeatureSettings(configPath))
}

NormalizeFeatureSettings(raw) {
    return FeatureSettings(
        ParseOptionalFeatureEnabled(raw.GlobalHjklArrows),
        ParseOptionalFeatureEnabled(raw.ReportImageCaptionEnabled),
        NormalizeOptionalHotkeyChord(raw.ReportImageCaptionChord),
        ParseOptionalFeatureEnabled(raw.ViewerArrowEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerArrowChord),
        ParseOptionalFeatureEnabled(raw.ViewerLengthEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerLengthChord),
        ParseOptionalFeatureEnabled(raw.ViewerSuv3DEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerSuv3DChord),
        ParseOptionalFeatureEnabled(raw.ViewerCaptureEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerCaptureChord),
        ParseOptionalFeatureEnabled(raw.ViewerClearEnabled),
        NormalizeOptionalHotkeyChord(raw.ViewerClearChord)
    )
}

ParseOptionalFeatureEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    return normalized = "true"
}

NormalizeOptionalHotkeyChord(value) {
    return Trim(String(value), " `t`r`n")
}

ValidateFeatureHotkeySettings(settings) {
    definitions := [
        {
            field: "ReportImageCaptionChord",
            label: "快速标图",
            enabled: settings.ReportImageCaptionEnabled,
            chord: settings.ReportImageCaptionChord,
            allowBare: false
        },
        {
            field: "ViewerArrowChord",
            label: "箭头",
            enabled: settings.ViewerArrowEnabled,
            chord: settings.ViewerArrowChord,
            allowBare: true
        },
        {
            field: "ViewerLengthChord",
            label: "长度测量",
            enabled: settings.ViewerLengthEnabled,
            chord: settings.ViewerLengthChord,
            allowBare: true
        },
        {
            field: "ViewerSuv3DChord",
            label: "3D SUV测量",
            enabled: settings.ViewerSuv3DEnabled,
            chord: settings.ViewerSuv3DChord,
            allowBare: true
        },
        {
            field: "ViewerCaptureChord",
            label: "截图",
            enabled: settings.ViewerCaptureEnabled,
            chord: settings.ViewerCaptureChord,
            allowBare: true
        },
        {
            field: "ViewerClearChord",
            label: "清除全部标注",
            enabled: settings.ViewerClearEnabled,
            chord: settings.ViewerClearChord,
            allowBare: true
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
        if !ViewerToolHotkeyChordIsSafe(chord)
            || (!definition.allowBare
                && ViewerHotkeyChordIsBare(chord)) {
            requirement := definition.allowBare
                ? "需要至少一个修饰键；"
                    . "无修饰时只能使用单个字母或数字，"
                    . "且仅在 Viewer 前台生效。"
                : "必须包含至少一个修饰键。"
            return MakeViewerToolHotkeyValidation(
                false,
                definition.field,
                "“" definition.label "”快捷键" requirement
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

ViewerToolHotkeyChordIsSafe(chord) {
    normalized := Trim(String(chord), " `t`r`n")
    if RegExMatch(normalized, "^([!+^#]+)([^!+^#].*)$", &match)
        return match[2] != ""
    return ViewerHotkeyIsSafeBareChord(normalized)
}

ViewerHotkeyIsSafeBareChord(chord) {
    return RegExMatch(
        Trim(String(chord), " `t`r`n"),
        "i)^[a-z0-9]$"
    ) > 0
}

ViewerHotkeyChordIsBare(chord) {
    return ViewerHotkeyIsSafeBareChord(chord)
}

MakeViewerToolHotkeyValidation(ok, field := "", message := "") {
    return {
        Ok: ok = true,
        Field: String(field),
        Message: String(message)
    }
}

FeatureHotkeySettingsMatch(expected, actual) {
    return expected.ReportImageCaptionEnabled
            = actual.ReportImageCaptionEnabled
        && expected.ReportImageCaptionChord
            = actual.ReportImageCaptionChord
        && expected.ViewerArrowEnabled = actual.ViewerArrowEnabled
        && expected.ViewerArrowChord = actual.ViewerArrowChord
        && expected.ViewerLengthEnabled = actual.ViewerLengthEnabled
        && expected.ViewerLengthChord = actual.ViewerLengthChord
        && expected.ViewerSuv3DEnabled = actual.ViewerSuv3DEnabled
        && expected.ViewerSuv3DChord = actual.ViewerSuv3DChord
        && expected.ViewerCaptureEnabled = actual.ViewerCaptureEnabled
        && expected.ViewerCaptureChord = actual.ViewerCaptureChord
        && expected.ViewerClearEnabled = actual.ViewerClearEnabled
        && expected.ViewerClearChord = actual.ViewerClearChord
}

ViewerHotkeyUsesWin(chord) {
    if !RegExMatch(
        Trim(String(chord), " `t`r`n"),
        "^([!+^#]+)",
        &match
    ) {
        return false
    }
    return InStr(match[1], "#") > 0
}

ViewerHotkeyNativeChord(chord) {
    normalized := Trim(String(chord), " `t`r`n")
    if !RegExMatch(normalized, "^([!+^#]+)(.+)$", &match)
        return normalized
    return StrReplace(match[1], "#") . match[2]
}

MergeViewerHotkeyChord(nativeChord, usesWin) {
    normalized := Trim(String(nativeChord), " `t`r`n")
    if normalized = ""
        return ""
    return NormalizeHotkeyChord((usesWin ? "#" : "") . normalized)
}
