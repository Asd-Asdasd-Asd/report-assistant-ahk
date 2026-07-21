class ReportHotstringConfig {
    static Path() {
        localAppData := EnvGet("LOCALAPPDATA")
        if localAppData = ""
            throw Error("LOCALAPPDATA is unavailable")
        return localAppData "\" ReportHotstringDefaults.DirectoryName "\" ReportHotstringDefaults.FileName
    }
}

LoadRawReportHotstringConfig(configPath := "") {
    defaults := ReportHotstringDefaults.BuiltinDefinitions()
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
    if schemaValue != String(ReportHotstringDefaults.SchemaVersion)
        return defaults

    entries := []
    for section in StrSplit(sectionList, "`n", "`r") {
        if !IsReportHotstringSection(section)
            continue
        try entries.Push(ReadReportHotstringSection(configPath, section))
    }
    return entries
}

CreateDefaultReportHotstringConfig(configPath, defaults := 0) {
    if FileExist(configPath)
        return false
    if Type(defaults) != "Array"
        defaults := ReportHotstringDefaults.BuiltinDefinitions()

    SplitPath configPath, , &configDirectory
    DirCreate configDirectory
    if FileExist(configPath)
        return false
    FileAppend BuildDefaultReportHotstringConfig(defaults), configPath, "UTF-16"
    return true
}

BuildDefaultReportHotstringConfig(defaults := 0) {
    if Type(defaults) != "Array"
        defaults := ReportHotstringDefaults.BuiltinDefinitions()
    lines := [
        "; MedEx Report Assistant hotstrings",
        "; Encoding: UTF-16 LE with BOM. Use \\n inside Text for a line break.",
        "[Config]",
        "SchemaVersion=" ReportHotstringDefaults.SchemaVersion
    ]
    for entry in defaults {
        lines.Push("")
        lines.Push("[" entry.Section "]")
        lines.Push("Enabled=" entry.Enabled)
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
    return RawHotstringEntry(
        section,
        IniRead(configPath, section, "Enabled", "true"),
        IniRead(configPath, section, "Name", ""),
        IniRead(configPath, section, "Trigger", ""),
        DecodeReportHotstringText(IniRead(configPath, section, "Text", "")),
        IniRead(configPath, section, "Mode", "")
    )
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
