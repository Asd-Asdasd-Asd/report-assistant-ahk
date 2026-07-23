class ReportHotstringDefaults {
    static RedFigureMarker := "（见图）"
    static CursorPlaceholder := "{{cursor}}"
    static DatePlaceholder := "{{date}}"
    static RedFigureReferencePlaceholder := "{{red:（见图）}}"

    static BuiltinDefinitions() {
        return [
            RawHotstringEntry(
                "Hotstring.builtin-red", "true", "红字插入", ";red",
                "{{red:（见图）}}"
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fzg", "true", "放射性摄取增高", ";fzg",
                "放射性摄取增高，SUVmax约为{{cursor}}{{red:（见图）}}"
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fwj", "true", "放射性摄取未见明显增高", ";fwj",
                "放射性摄取未见明显增高{{red:（见图）}}"
            ),
            RawHotstringEntry(
                "Hotstring.builtin-fjd", "true", "放射性摄取降低", ";fjd",
                "放射性摄取降低{{red:（见图）}}"
            ),
            RawHotstringEntry(
                "Hotstring.builtin-cmx", "true", "厘米尺寸模板", ";cmx",
                "cm×{{cursor}}cm"
            )
        ]
    }
}

class RawHotstringEntry {
    __New(section, enabled, name, trigger, text) {
        this.Section := String(section)
        this.Enabled := String(enabled)
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
    }
}

class HotstringEntry {
    __New(section, enabled, name, trigger, text) {
        this.Section := String(section)
        this.Enabled := enabled = true
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
    }
}
