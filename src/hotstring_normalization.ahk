LoadReportHotstringConfig(configPath := "") {
    result := NormalizeReportHotstringEntriesResult(
        LoadRawReportHotstringConfig(configPath)
    )
    if result.Ok
        return result.Entries

    OutputDebug(
        "Report hotstring config rejected: " result.Code
            . " Section=" result.Section
    )
    ShowReportAssistantVisualFeedback(
        "模板配置存在错误，本次未加载任何模板",
        4000
    )
    return []
}

NormalizeReportHotstringEntries(rawEntries) {
    return NormalizeReportHotstringEntriesResult(rawEntries).Entries
}

NormalizeReportHotstringEntriesResult(rawEntries) {
    entries := []
    seenTriggers := Map()
    for raw in rawEntries {
        entry := NormalizeReportHotstringEntry(raw)
        if !entry {
            return ReportHotstringNormalizationResult(
                false, "INVALID_ENTRY", raw.Section
            )
        }
        triggerKey := StrLower(entry.Trigger)
        if seenTriggers.Has(triggerKey) {
            return ReportHotstringNormalizationResult(
                false, "DUPLICATE_TRIGGER", raw.Section
            )
        }
        seenTriggers[triggerKey] := true
        entries.Push(entry)
    }
    return ReportHotstringNormalizationResult(true, "OK", "", entries)
}

ReportHotstringNormalizationResult(
    ok,
    code,
    section := "",
    entries := 0
) {
    return {
        Ok: ok = true,
        Code: String(code),
        Section: String(section),
        Entries: Type(entries) = "Array" ? entries : []
    }
}

NormalizeReportHotstringEntry(raw) {
    enabled := ParseReportHotstringEnabled(raw.Enabled)
    if enabled = "INVALID"
        return false
    section := raw.Section
    name := Trim(raw.Name, " `t`r`n")
    trigger := Trim(raw.Trigger, " `t`r`n")
    if name = "" || InStr(raw.Name, "`r") || InStr(raw.Name, "`n")
        return false
    if trigger = "" || InStr(trigger, "`r") || InStr(trigger, "`n")
        return false
    templateValidation := ValidateReportTemplate(raw.Text)
    if !templateValidation.Ok
        return false

    return HotstringEntry(
        section,
        enabled,
        name,
        trigger,
        raw.Text
    )
}

ParseReportHotstringEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    if normalized = "true"
        return true
    if normalized = "false"
        return false
    return "INVALID"
}
