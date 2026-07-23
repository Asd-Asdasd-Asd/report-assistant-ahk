LoadReportHotstringConfig(configPath := "") {
    return NormalizeReportHotstringEntries(
        LoadRawReportHotstringConfig(configPath)
    )
}

NormalizeReportHotstringEntries(rawEntries) {
    entries := []
    seenTriggers := Map()
    for raw in rawEntries {
        entry := NormalizeReportHotstringEntry(raw)
        if !entry {
            OutputDebug(
                "Report hotstring config rejected: INVALID_ENTRY Section=" .
                raw.Section
            )
            return []
        }
        triggerKey := StrLower(entry.Trigger)
        if seenTriggers.Has(triggerKey) {
            OutputDebug(
                "Report hotstring config rejected: DUPLICATE_TRIGGER Section=" .
                raw.Section
            )
            return []
        }
        seenTriggers[triggerKey] := true
        entries.Push(entry)
    }
    return entries
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
