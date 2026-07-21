LoadReportHotstringConfig(configPath := "") {
    entries := NormalizeReportHotstringEntries(
        LoadRawReportHotstringConfig(configPath)
    )
    return entries.Length > 0 ? entries : NormalizeReportHotstringEntries(
        ReportHotstringDefaults.BuiltinDefinitions()
    )
}

NormalizeReportHotstringEntries(rawEntries) {
    entries := []
    for raw in rawEntries {
        entry := NormalizeReportHotstringEntry(raw)
        if entry
            entries.Push(entry)
    }
    return entries
}

NormalizeReportHotstringEntry(raw) {
    enabled := ParseReportHotstringEnabled(raw.Enabled)
    if enabled = "INVALID"
        return false
    section := raw.Section
    trigger := Trim(raw.Trigger, " `t`r`n")
    mode := StrLower(Trim(raw.Mode, " `t`r`n"))
    if trigger = "" || InStr(trigger, "`r") || InStr(trigger, "`n")
        return false
    if !IsSupportedReportHotstringMode(mode)
        return false

    text := raw.Text
    plainText := text
    redText := ""
    if IsRedReportHotstringMode(mode) {
        marker := ReportHotstringDefaults.RedFigureMarker
        plainText := TextEndsWith(text, marker)
            ? SubStr(text, 1, StrLen(text) - StrLen(marker))
            : text
        redText := marker
    }

    postTextCaretLeftCount := section = "Hotstring.builtin-cmx"
        && mode = ReportHotstringMode.TEXT ? 2 : 0
    return HotstringEntry(
        section,
        enabled,
        raw.Name,
        trigger,
        mode,
        plainText,
        redText,
        postTextCaretLeftCount
    )
}

IsRedReportHotstringMode(mode) {
    return mode = ReportHotstringMode.RED_RESET
        || mode = ReportHotstringMode.RED_LEFT4
}

TextEndsWith(text, suffix) {
    if suffix = "" || StrLen(text) < StrLen(suffix)
        return false
    suffixStart := StrLen(text) - StrLen(suffix) + 1
    return SubStr(text, suffixStart) = suffix
}

ParseReportHotstringEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    if normalized = "true"
        return true
    if normalized = "false"
        return false
    return "INVALID"
}

IsSupportedReportHotstringMode(mode) {
    return mode = ReportHotstringMode.TEXT
        || mode = ReportHotstringMode.RED_RESET
        || mode = ReportHotstringMode.RED_LEFT4
}
