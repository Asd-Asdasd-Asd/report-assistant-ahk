FocusReportEditor() {
    return RequireReportEditor()
}

InsertReportRichTextPlaceholder() {
    ; Future: validate editor focus before inserting rich-text content.
    ; CF_HTML red figure-text insertion currently lives in clipboard_html.ahk.
    Flash("Report rich-text insertion is not implemented")
    return false
}

ResetReportFormattingPlaceholder() {
    ; Future: reset editor formatting only after window and focus validation.
    Flash("Report format reset is not implemented")
    return false
}
