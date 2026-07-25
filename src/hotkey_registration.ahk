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
                seenChords[chordKey] := true
                registeredChords[chordKey] := true
                registeredIds.Push(definition.Id)
            }
        }
    } finally {
        if useContext
            HotIf()
    }
    return registeredIds
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
