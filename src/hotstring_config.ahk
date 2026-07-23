LoadRawReportHotstringConfig(configPath := "") {
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return []
    }
    if !FileExist(configPath)
        return []

    try {
        sectionList := IniRead(configPath)
        schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    } catch {
        return []
    }
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return []

    entries := []
    for section in StrSplit(sectionList, "`n", "`r") {
        if !IsReportHotstringSection(section)
            continue
        try entries.Push(ReadReportHotstringSection(configPath, section))
        catch
            return []
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
        "; MedEx Report Assistant 配置",
        "; 请保持 UTF-16 LE 编码；Text 中的 \n 表示换行。",
        "; Text 可使用 {{cursor}} 标记光标位置，使用 {{date}} 插入当天日期。",
        "; 只有 {{red:（见图）}} 会插入红色（见图），且必须放在模板最后。",
        "[Config]",
        "SchemaVersion=" ReportAssistantConfigDefaults.SchemaVersion,
        "",
        "[" FeatureDefaults.Section "]",
        FeatureDefaults.GlobalHjklArrowsKey "=" FeatureDefaults.GlobalHjklArrowsDefault
    ]
    for entry in defaults {
        lines.Push("")
        lines.Push("[" entry.Section "]")
        lines.Push("Enabled=" entry.Enabled)
        lines.Push("Name=" entry.Name)
        lines.Push("Trigger=" entry.Trigger)
        lines.Push("Text=" EncodeReportHotstringText(entry.Text))
    }
    lines.Push("")
    lines.Push("; ============================================================")
    lines.Push("; 自定义快捷语示例")
    lines.Push("; 请复制下面整段，不要直接修改这一段。")
    lines.Push(";")
    lines.Push("; 复制后必须把方括号里的 example 改成不重复的英文名称。")
    lines.Push("; 这里只使用小写英文字母、数字和减号，例如 lung-note。")
    lines.Push("; 不要使用中文、空格，也不要继续使用 example。")
    lines.Push("; Name 和 Text 可以正常填写中文。")
    lines.Push("; 可在 Text 中使用 {{cursor}}、{{date}} 和 {{red:（见图）}}。")
    lines.Push("; 最后把 Enabled 改成 true。")
    lines.Push("; ============================================================")
    lines.Push("")
    lines.Push("[Hotstring.custom-example]")
    lines.Push("Enabled=false")
    lines.Push("Name=新的快捷语")
    lines.Push("Trigger=;example")
    lines.Push("Text=请输入内容")
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
        DecodeReportHotstringText(IniRead(configPath, section, "Text", ""))
    )
}

EncodeReportHotstringText(value) {
    value := NormalizeReportHotstringTextNewlines(value)
    output := ""
    Loop Parse value {
        if A_LoopField = "\"
            output .= "\\"
        else if A_LoopField = "`n"
            output .= "\n"
        else
            output .= A_LoopField
    }
    return output
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

NormalizeReportHotstringTextNewlines(value) {
    value := StrReplace(String(value), "`r`n", "`n")
    return StrReplace(value, "`r", "`n")
}

ReportHotstringTextForMultilineEdit(value) {
    return StrReplace(
        NormalizeReportHotstringTextNewlines(value),
        "`n",
        "`r`n"
    )
}

ReportHotstringTextFromMultilineEdit(value) {
    return NormalizeReportHotstringTextNewlines(value)
}
