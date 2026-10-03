RegisterHotkeyDefinitions(
    definitions,
    reservedChords := 0,
    contextCallback := 0
) {
    static registeredChords := Map()
    seenChords := BuildHotkeyChordSet(reservedChords)
    for registeredChord, _ in registeredChords
        seenChords[registeredChord] := true
    registeredIds := []
    failedChords := []
    useContext := HasMethod(contextCallback, "Call")
    if useContext
        HotIf(contextCallback)
    try {
        for definition in definitions {
            chordKey := NormalizeHotkeyChord(definition.Chord)
            if chordKey = "" || seenChords.Has(chordKey)
                continue
            try {
                Hotkey(definition.Chord, definition.Handler)
            } catch {
                failedChords.Push(definition.Chord)
                continue
            }
            seenChords[chordKey] := true
            registeredChords[chordKey] := true
            registeredIds.Push(definition.Id)
        }
    } finally {
        if useContext
            HotIf()
    }
    if failedChords.Length > 0
        ReportHotkeyRegistrationFailures(failedChords)
    return registeredIds
}

ReportHotkeyRegistrationFailures(chords) {
    message := "以下快捷键未能启用："
    for chord in chords
        message .= "`n" chord
    message .= "`n`n请在设置中检查并重新选择按键。其他已启用的快捷键可继续使用。"
    MsgBox(message, "MedEx Report Assistant", "Icon!")
}

BuildHotkeyChordSet(chords := 0) {
    chordSet := Map()
    if Type(chords) != "Array"
        return chordSet
    for chord in chords {
        chordKey := NormalizeHotkeyChord(chord)
        if chordKey != ""
            chordSet[chordKey] := true
    }
    return chordSet
}

NormalizeHotkeyChord(chord) {
    normalized := StrLower(Trim(chord, " `t`r`n"))
    if !RegExMatch(normalized, "^([!+^#]+)(.+)$", &match)
        return normalized
    canonicalModifiers := ""
    for modifier in ["^", "!", "+", "#"] {
        if InStr(match[1], modifier)
            canonicalModifiers .= modifier
    }
    return canonicalModifiers match[2]
}

ReservedApplicationHotkeyChords() {
    return ["^!Esc", "^!q", "^!F8"]
}
