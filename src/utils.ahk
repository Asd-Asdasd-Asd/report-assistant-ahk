Flash(message, duration := 1000) {
    ToolTip message
    SetTimer () => ToolTip(), -Abs(duration)
}

WithMouseRestore(callback) {
    if !HasMethod(callback, "Call") {
        Flash("Invalid callback")
        return false
    }

    MouseGetPos &originalX, &originalY
    try {
        callback.Call()
        return true
    } catch as err {
        Flash("Action failed: " err.Message)
        return false
    } finally {
        MouseMove originalX, originalY, 0
    }
}

ClickPoint(name, clicks := 1) {
    global COORDINATES

    if !IsSet(COORDINATES) || Type(COORDINATES) != "Map" {
        Flash("Coordinate map is not configured")
        return false
    }

    if !COORDINATES.Has(name) {
        Flash("Unknown point: " name)
        return false
    }

    point := COORDINATES[name]
    if !point.HasOwnProp("x") || !point.HasOwnProp("y") {
        Flash("Invalid point: " name)
        return false
    }

    safeClicks := Max(1, Integer(clicks))
    return WithMouseRestore(() => Click(point.x, point.y, safeClicks))
}
