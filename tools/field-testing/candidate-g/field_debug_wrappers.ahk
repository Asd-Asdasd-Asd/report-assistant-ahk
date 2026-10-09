; Field-debug compatibility wrappers around the production insertion chain.
; Production templates do not dispatch by legacy mode or section identity.
; Include after ..\..\..\src\report_editor.ahk.

RunRedInsertion(resetOptions := 0) {
    return RunRedResetInsertion("（见图）", resetOptions)
}

RunFzgInsertion(resetOptions := 0) {
    return RunRedCaretInsertion(
        "放射性摄取增高，SUVmax约（见图）",
        4,
        resetOptions
    )
}
