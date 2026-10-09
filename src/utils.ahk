Flash(message, duration := 1000) {
    ToolTip message
    SetTimer () => ToolTip(), -Abs(duration)
}
