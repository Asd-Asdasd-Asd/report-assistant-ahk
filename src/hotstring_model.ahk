class ReportHotstringMode {
    static TEXT := "text"
    static RED_RESET := "red-reset"
    static RED_LEFT4 := "red-left4"
}

class ReportHotstringDefaults {
    static SchemaVersion := 1
    static DirectoryName := "MedExReportAssistant"
    static FileName := "config.ini"
    static RedFigureMarker := "（见图）"

    static BuiltinDefinitions() {
        return [
            RawHotstringEntry(
                "Hotstring.builtin-red", "true", "红字插入", ";red",
                "（见图）", ReportHotstringMode.RED_RESET
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fzg", "true", "放射性摄取增高", ";fzg",
                "放射性摄取增高，SUVmax约（见图）",
                ReportHotstringMode.RED_LEFT4
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fwj", "true", "放射性摄取未见明显增高", ";fwj",
                "放射性摄取未见明显增高（见图）",
                ReportHotstringMode.RED_RESET
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fjd", "true", "放射性摄取降低", ";fjd",
                "放射性摄取降低（见图）",
                ReportHotstringMode.RED_RESET
            ),
            RawHotstringEntry(
                "Hotstring.builtin-cmx", "true", "厘米尺寸模板", ";cmx",
                "cm×cm", ReportHotstringMode.TEXT
            )
        ]
    }
}

class RawHotstringEntry {
    __New(section, enabled, name, trigger, text, mode) {
        this.Section := String(section)
        this.Enabled := String(enabled)
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
        this.Mode := String(mode)
    }
}

class HotstringEntry {
    __New(section, enabled, name, trigger, mode, plainText, redText,
        postTextCaretLeftCount := 0) {
        this.Section := String(section)
        this.Enabled := enabled = true
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Mode := String(mode)
        this.PlainText := String(plainText)
        this.RedText := String(redText)
        ; This is normalized builtin policy, not a configurable field.
        this.PostTextCaretLeftCount := postTextCaretLeftCount
    }
}
