RegisterReportHotstrings(
    LoadReportHotstringConfig(),
    RunConfiguredReportHotstring
)

RunConfiguredReportHotstring(entry, *) {
    SendConfiguredReportText(entry.PlainText)
    if entry.Mode = ReportHotstringMode.TEXT {
        if entry.PostTextCaretLeftCount = 2
            Send("{Left 2}")
        return true
    }
    if entry.Mode = ReportHotstringMode.RED_RESET
        return RunRedResetInsertion(entry.RedText)
    if entry.Mode = ReportHotstringMode.RED_LEFT4
        return RunRedLeft4Insertion(entry.RedText)
    return false
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
