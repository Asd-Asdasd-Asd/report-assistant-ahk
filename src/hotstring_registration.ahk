RegisterReportHotstrings(entries, executor) {
    seenTriggers := Map()
    HotIf (*) => MedExReportHotstringsEnabled()
    try {
        for entry in entries {
            triggerKey := StrLower(entry.Trigger)
            if !entry.Enabled || seenTriggers.Has(triggerKey)
                continue
            try {
                Hotstring(":*?:" entry.Trigger, executor.Bind(entry))
                seenTriggers[triggerKey] := true
            }
        }
    } finally {
        HotIf
    }
}
