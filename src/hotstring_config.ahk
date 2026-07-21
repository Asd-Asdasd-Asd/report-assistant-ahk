class ReportHotstringMode {
    static TEXT := "text"
    static RED_RESET := "red-reset"
    static RED_LEFT4 := "red-left4"
}

class HotstringEntry {
    __New(section, enabled, name, trigger, text, mode,
        legacyCaretLeftCount := 0, legacyRedSuffix := "") {
        this.Section := String(section)
        this.Enabled := enabled = true
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
        this.Mode := String(mode)
        ; This is runtime compatibility metadata, not a configurable field.
        this.LegacyCaretLeftCount := legacyCaretLeftCount
        this.LegacyRedSuffix := String(legacyRedSuffix)
    }
}

class ReportHotstringConfig {
    static SchemaVersion := 1
    static DirectoryName := "MedExReportAssistant"
    static FileName := "config.ini"

    static Path() {
        localAppData := EnvGet("LOCALAPPDATA")
        if localAppData = ""
            throw Error("LOCALAPPDATA is unavailable")
        return localAppData "\" this.DirectoryName "\" this.FileName
    }

    static BuiltinDefaults() {
        return [
            HotstringEntry(
                "Hotstring.builtin-red", true, "红字插入", ";red",
                "（见图）", ReportHotstringMode.RED_RESET
            ),
            HotstringEntry(
                "Hotstring.builtin-fzg", true, "放射性摄取增高", ";fzg",
                "放射性摄取增高，SUVmax约（见图）",
                ReportHotstringMode.RED_LEFT4, 0, "（见图）"
            ),
            HotstringEntry(
                "Hotstring.builtin-fwj", true, "放射性摄取未见明显增高", ";fwj",
                "放射性摄取未见明显增高（见图）",
                ReportHotstringMode.RED_RESET, 0, "（见图）"
            ),
            HotstringEntry(
                "Hotstring.builtin-fjd", true, "放射性摄取降低", ";fjd",
                "放射性摄取降低（见图）",
                ReportHotstringMode.RED_RESET, 0, "（见图）"
            ),
            HotstringEntry(
                "Hotstring.builtin-cmx", true, "厘米尺寸模板", ";cmx",
                "cm×cm", ReportHotstringMode.TEXT, 2
            )
        ]
    }
}

LoadReportHotstringConfig(configPath := "") {
    defaults := ReportHotstringConfig.BuiltinDefaults()
    if configPath = "" {
        try configPath := ReportHotstringConfig.Path()
        catch
            return defaults
    }
    if !FileExist(configPath) {
        try CreateDefaultReportHotstringConfig(configPath, defaults)
        catch
            return defaults
    }

    try {
        sectionList := IniRead(configPath)
        schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    } catch {
        return defaults
    }
    if schemaValue != String(ReportHotstringConfig.SchemaVersion)
        return defaults

    entries := []
    for section in StrSplit(sectionList, "`n", "`r") {
        if !IsReportHotstringSection(section)
            continue
        try raw := ReadReportHotstringSection(configPath, section)
        catch
            continue
        entry := NormalizeReportHotstringEntry(section, raw)
        if entry
            entries.Push(entry)
    }
    return entries.Length > 0 ? entries : defaults
}

CreateDefaultReportHotstringConfig(configPath, defaults := 0) {
    if FileExist(configPath)
        return false
    if Type(defaults) != "Array"
        defaults := ReportHotstringConfig.BuiltinDefaults()

    SplitPath configPath, , &configDirectory
    DirCreate configDirectory
    if FileExist(configPath)
        return false
    FileAppend BuildDefaultReportHotstringConfig(defaults), configPath, "UTF-16"
    return true
}

BuildDefaultReportHotstringConfig(defaults := 0) {
    if Type(defaults) != "Array"
        defaults := ReportHotstringConfig.BuiltinDefaults()
    lines := [
        "; MedEx Report Assistant hotstrings",
        "; Encoding: UTF-16 LE with BOM. Use \\n inside Text for a line break.",
        "[Config]",
        "SchemaVersion=" ReportHotstringConfig.SchemaVersion
    ]
    for entry in defaults {
        lines.Push("")
        lines.Push("[" entry.Section "]")
        lines.Push("Enabled=" (entry.Enabled ? "true" : "false"))
        lines.Push("Name=" entry.Name)
        lines.Push("Trigger=" entry.Trigger)
        lines.Push("Text=" EncodeReportHotstringText(entry.Text))
        lines.Push("Mode=" entry.Mode)
    }
    return JoinConfigLines(lines) "`r`n"
}

JoinConfigLines(lines) {
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output
}

IsReportHotstringSection(section) {
    return RegExMatch(section, "^Hotstring\.(?:builtin|custom)-.+$")
}

ReadReportHotstringSection(configPath, section) {
    return Map(
        "Enabled", IniRead(configPath, section, "Enabled", "true"),
        "Name", IniRead(configPath, section, "Name", ""),
        "Trigger", IniRead(configPath, section, "Trigger", ""),
        "Text", IniRead(configPath, section, "Text", ""),
        "Mode", IniRead(configPath, section, "Mode", "")
    )
}

NormalizeReportHotstringEntry(section, raw) {
    enabled := ParseReportHotstringEnabled(raw["Enabled"])
    if enabled = "INVALID"
        return false
    trigger := Trim(raw["Trigger"], " `t`r`n")
    mode := StrLower(Trim(raw["Mode"], " `t`r`n"))
    if trigger = "" || InStr(trigger, "`r") || InStr(trigger, "`n")
        return false
    if !IsSupportedReportHotstringMode(mode)
        return false

    legacyCaretLeftCount := section = "Hotstring.builtin-cmx"
        && mode = ReportHotstringMode.TEXT ? 2 : 0
    decodedText := DecodeReportHotstringText(raw["Text"])
    legacyRedSuffix := IsLegacyMixedColorBuiltin(section)
        && IsRedReportHotstringMode(mode)
        && TextEndsWith(decodedText, "（见图）") ? "（见图）" : ""
    return HotstringEntry(
        section,
        enabled,
        raw["Name"],
        trigger,
        decodedText,
        mode,
        legacyCaretLeftCount,
        legacyRedSuffix
    )
}

IsLegacyMixedColorBuiltin(section) {
    return section = "Hotstring.builtin-fzg"
        || section = "Hotstring.builtin-fwj"
        || section = "Hotstring.builtin-fjd"
}

IsRedReportHotstringMode(mode) {
    return mode = ReportHotstringMode.RED_RESET
        || mode = ReportHotstringMode.RED_LEFT4
}

TextEndsWith(text, suffix) {
    if suffix = "" || StrLen(text) < StrLen(suffix)
        return false
    suffixStart := StrLen(text) - StrLen(suffix) + 1
    return SubStr(text, suffixStart) = suffix
}

ParseReportHotstringEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    if normalized = "true"
        return true
    if normalized = "false"
        return false
    return "INVALID"
}

IsSupportedReportHotstringMode(mode) {
    return mode = ReportHotstringMode.TEXT
        || mode = ReportHotstringMode.RED_RESET
        || mode = ReportHotstringMode.RED_LEFT4
}

EncodeReportHotstringText(value) {
    return StrReplace(StrReplace(String(value), "\", "\\"), "`n", "\n")
}

DecodeReportHotstringText(value) {
    value := String(value)
    output := ""
    index := 1
    while index <= StrLen(value) {
        pair := SubStr(value, index, 2)
        if pair = "\n" {
            output .= "`n"
            index += 2
        } else if pair = "\\" {
            output .= "\"
            index += 2
        } else {
            output .= SubStr(value, index, 1)
            index += 1
        }
    }
    return output
}
