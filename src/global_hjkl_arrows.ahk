GlobalHjklArrowHotkeyDefinitions() {
    return [
        HotkeyDefinition(
            "global-hjkl-left", "RAlt & h",
            SendGlobalHjklArrow.Bind("Left")
        ),
        HotkeyDefinition(
            "global-hjkl-down", "RAlt & j",
            SendGlobalHjklArrow.Bind("Down")
        ),
        HotkeyDefinition(
            "global-hjkl-up", "RAlt & k",
            SendGlobalHjklArrow.Bind("Up")
        ),
        HotkeyDefinition(
            "global-hjkl-right", "RAlt & l",
            SendGlobalHjklArrow.Bind("Right")
        )
    ]
}

SendGlobalHjklArrow(direction, *) {
    SendInput("{" direction "}")
}
