RegisterHotkeyDefinitions(definitions, reservedChords := 0) {
    seenChords := BuildHotkeyChordSet(reservedChords)
    registeredIds := []
    for definition in definitions {
        chordKey := NormalizeHotkeyChord(definition.Chord)
        if chordKey = "" || seenChords.Has(chordKey)
            continue
        try {
            Hotkey(definition.Chord, definition.Handler)
            seenChords[chordKey] := true
            registeredIds.Push(definition.Id)
        }
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
    return StrLower(Trim(chord, " `t`r`n"))
}

ReservedApplicationHotkeyChords() {
    return ["^!Esc", "^!q"]
}
