RegisterReportHotstrings(LoadReportHotstringConfig())

RegisterReportHotstrings(entries) {
    seenTriggers := Map()
    HotIf (*) => MedExReportHotstringsEnabled()
    try {
        for entry in entries {
            triggerKey := StrLower(entry.Trigger)
            if !entry.Enabled || seenTriggers.Has(triggerKey)
                continue
            try {
                Hotstring(":*?:" entry.Trigger, RunConfiguredReportHotstring.Bind(entry))
                seenTriggers[triggerKey] := true
            }
        }
    } finally {
        HotIf
    }
}

RunConfiguredReportHotstring(entry, *) {
    if entry.Mode = ReportHotstringMode.TEXT {
        SendConfiguredReportText(entry.Text)
        if entry.LegacyCaretLeftCount = 2
            Send("{Left 2}")
        return true
    }
    if entry.Mode = ReportHotstringMode.RED_RESET
        return RunConfiguredRedResetInsertion(entry)
    if entry.Mode = ReportHotstringMode.RED_LEFT4
        return RunConfiguredRedLeft4Insertion(entry)
    return false
}

RunConfiguredRedResetInsertion(entry) {
    parts := SplitConfiguredRedText(entry)
    SendConfiguredReportText(parts.PlainPrefix)
    return RunRedResetInsertion(parts.RedText)
}

RunConfiguredRedLeft4Insertion(entry) {
    parts := SplitConfiguredRedText(entry)
    SendConfiguredReportText(parts.PlainPrefix)
    return RunRedLeft4Insertion(parts.RedText)
}

SplitConfiguredRedText(entry) {
    suffix := entry.LegacyRedSuffix
    if suffix != "" && TextEndsWith(entry.Text, suffix) {
        return {
            PlainPrefix: SubStr(entry.Text, 1, StrLen(entry.Text) - StrLen(suffix)),
            RedText: suffix
        }
    }
    return {PlainPrefix: "", RedText: entry.Text}
}

SendConfiguredReportText(text) {
    lines := StrSplit(text, "`n", "`r")
    for index, line in lines {
        if index > 1
            Send("{Enter}")
        if line != ""
            SendText(line)
    }
}
