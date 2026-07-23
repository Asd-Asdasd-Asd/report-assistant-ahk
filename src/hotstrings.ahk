RegisterReportHotstrings(
    LoadReportHotstringConfig(),
    RunConfiguredReportHotstring
)

RunConfiguredReportHotstring(entry, *) {
    plan := BuildReportTemplatePlan(entry.Text)
    if !plan.Ok {
        OutputDebug "Report template render failed: INVALID_TEMPLATE"
        return false
    }

    resetReadiness := 0
    if plan.RequiresColorReset {
        resetReadiness := PrepareMedExRedReset()
        if !resetReadiness.ok
            return false
    }

    SendConfiguredReportText(plan.PlainText)
    if plan.RedText = "" {
        if plan.CaretLeftCount > 0
            Send("{Left " plan.CaretLeftCount "}")
        return true
    }
    if plan.CaretLeftCount > 0
        return RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)
    return RunRedResetInsertion(plan.RedText, resetReadiness.options)
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
