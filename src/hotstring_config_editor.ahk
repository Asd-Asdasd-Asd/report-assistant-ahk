class EditableReportHotstringEntry {
    __New(section, enabled, name, trigger, text, mode, isBuiltin := false) {
        this.Section := String(section)
        this.Enabled := enabled = true
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
        this.Mode := String(mode)
        this.IsBuiltin := isBuiltin = true
    }
}

class ReportHotstringEditorLoadResult {
    __New(ok, configPath := "", originalText := "", entries := 0,
        message := "") {
        this.Ok := ok = true
        this.ConfigPath := String(configPath)
        this.OriginalText := String(originalText)
        this.Entries := Type(entries) = "Array" ? entries : []
        this.Message := String(message)
    }
}

class ReportHotstringEditorValidationResult {
    __New(ok, row := 0, field := "", message := "") {
        this.Ok := ok = true
        this.Row := row
        this.Field := String(field)
        this.Message := String(message)
    }
}

class ReportHotstringEditorSaveResult {
    __New(ok, message := "", savedText := "") {
        this.Ok := ok = true
        this.Message := String(message)
        this.SavedText := String(savedText)
    }
}

LoadEditableReportHotstringConfig(configPath := "") {
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return ReportHotstringEditorLoadResult(
                false, , , , "无法取得配置文件路径。"
            )
    }
    if !FileExist(configPath)
        return ReportHotstringEditorLoadResult(
            false, configPath, , , "配置文件不存在，请重新启动程序后重试。"
        )

    try originalText := FileRead(configPath)
    catch
        return ReportHotstringEditorLoadResult(
            false, configPath, , , "无法读取配置文件。"
        )

    try {
        schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
        sectionList := IniRead(configPath)
    } catch {
        return ReportHotstringEditorLoadResult(
            false, configPath, originalText, , "配置文件格式无法读取。"
        )
    }
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion) {
        return ReportHotstringEditorLoadResult(
            false, configPath, originalText, ,
            "配置文件版本与当前程序不兼容，未进行任何修改。"
        )
    }

    entries := []
    seenSections := Map()
    for section in StrSplit(sectionList, "`n", "`r") {
        if !IsReportHotstringSection(section)
            continue
        sectionKey := StrLower(section)
        if seenSections.Has(sectionKey) {
            return ReportHotstringEditorLoadResult(
                false, configPath, originalText, ,
                "配置文件中存在重复的模板记录，未进行任何修改。"
            )
        }
        seenSections[sectionKey] := true
        try raw := ReadReportHotstringSection(configPath, section)
        catch {
            return ReportHotstringEditorLoadResult(
                false, configPath, originalText, ,
                "其中一个模板无法读取，未进行任何修改。"
            )
        }
        enabled := ParseReportHotstringEnabled(raw.Enabled)
        if enabled = "INVALID" {
            return ReportHotstringEditorLoadResult(
                false, configPath, originalText, ,
                "模板的启用状态无法识别：" raw.Name
            )
        }
        entries.Push(EditableReportHotstringEntry(
            raw.Section,
            enabled,
            raw.Name,
            raw.Trigger,
            raw.Text,
            raw.Mode,
            IsBuiltinReportHotstringSection(raw.Section)
        ))
    }
    if entries.Length = 0 {
        return ReportHotstringEditorLoadResult(
            false, configPath, originalText, ,
            "配置文件中没有可编辑的报告模板。"
        )
    }
    return ReportHotstringEditorLoadResult(
        true, configPath, originalText, entries
    )
}

IsBuiltinReportHotstringSection(section) {
    return RegExMatch(section, "i)^Hotstring\.builtin-.+$")
}

IsCustomReportHotstringSection(section) {
    return RegExMatch(section, "i)^Hotstring\.custom-.+$")
}

CreateEditableReportHotstring(entries, reservedSections := 0) {
    sectionBase := "Hotstring.custom-ui-" FormatTime(, "yyyyMMddHHmmss")
    section := sectionBase
    suffix := 2
    while EditableReportHotstringSectionExists(entries, section)
        || EditableReportHotstringSectionIsReserved(reservedSections, section) {
        section := sectionBase "-" suffix
        suffix += 1
    }
    return EditableReportHotstringEntry(
        section, true, "新的模板", "", "", ReportHotstringMode.TEXT, false
    )
}

NormalizeEditableReportHotstringText(value) {
    value := StrReplace(String(value), "`r`n", "`n")
    return StrReplace(value, "`r", "`n")
}

EditableReportHotstringSectionIsReserved(reservedSections, section) {
    return Type(reservedSections) = "Map"
        && reservedSections.Has(StrLower(section))
}

EditableReportHotstringSectionExists(entries, section) {
    sectionKey := StrLower(section)
    for entry in entries {
        if StrLower(entry.Section) = sectionKey
            return true
    }
    return false
}

ValidateEditableReportHotstringEntries(entries) {
    if Type(entries) != "Array" || entries.Length = 0 {
        return ReportHotstringEditorValidationResult(
            false, 0, "", "至少需要保留一个报告模板。"
        )
    }

    seenSections := Map()
    seenTriggers := Map()
    for index, entry in entries {
        sectionKey := StrLower(Trim(entry.Section, " `t`r`n"))
        if sectionKey = "" || seenSections.Has(sectionKey) {
            return ReportHotstringEditorValidationResult(
                false, index, "Name", "模板的内部记录发生冲突，请重新打开设置。"
            )
        }
        if entry.IsBuiltin {
            if !IsBuiltinReportHotstringSection(entry.Section) {
                return ReportHotstringEditorValidationResult(
                    false, index, "Name", "内置模板记录无效，请重新打开设置。"
                )
            }
        } else if !IsCustomReportHotstringSection(entry.Section) {
            return ReportHotstringEditorValidationResult(
                false, index, "Name", "自定义模板记录无效，请重新打开设置。"
            )
        }
        seenSections[sectionKey] := true

        name := Trim(entry.Name, " `t`r`n")
        if name = "" || InStr(entry.Name, "`r") || InStr(entry.Name, "`n") {
            return ReportHotstringEditorValidationResult(
                false, index, "Name", "模板名称不能为空或包含换行。"
            )
        }

        trigger := Trim(entry.Trigger, " `t`r`n")
        if trigger = "" || InStr(entry.Trigger, "`r") || InStr(entry.Trigger, "`n") {
            return ReportHotstringEditorValidationResult(
                false, index, "Trigger", "触发词不能为空或包含换行。"
            )
        }
        triggerKey := StrLower(trigger)
        if seenTriggers.Has(triggerKey) {
            return ReportHotstringEditorValidationResult(
                false, index, "Trigger",
                "触发词“" trigger "”与其他模板重复。"
            )
        }
        seenTriggers[triggerKey] := true

        mode := StrLower(Trim(entry.Mode, " `t`r`n"))
        if !IsSupportedReportHotstringMode(mode) {
            return ReportHotstringEditorValidationResult(
                false, index, "Mode", "请选择有效的模板模式。"
            )
        }
    }
    return ReportHotstringEditorValidationResult(true)
}

SaveEditableReportHotstringConfig(entries, deletedSections, originalText,
    configPath := "") {
    validation := ValidateEditableReportHotstringEntries(entries)
    if !validation.Ok
        return ReportHotstringEditorSaveResult(false, validation.Message)

    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return ReportHotstringEditorSaveResult(false, "无法取得配置文件路径。")
    }
    try currentText := FileRead(configPath)
    catch
        return ReportHotstringEditorSaveResult(false, "无法重新读取配置文件。")
    if currentText != originalText {
        return ReportHotstringEditorSaveResult(
            false,
            "配置文件已被其他程序修改。请关闭设置窗口并重新打开，避免覆盖新内容。"
        )
    }

    tempPath := configPath ".settings.tmp.ini"
    backupPath := ""
    promoted := false
    try {
        try FileDelete tempPath
        backupPath := CreateReportAssistantConfigBackup(configPath)
        FileCopy configPath, tempPath, true

        deletedKeys := Map()
        if Type(deletedSections) = "Array" {
            for section in deletedSections {
                if !IsCustomReportHotstringSection(section)
                    throw Error("Only custom template sections can be deleted")
                sectionKey := StrLower(section)
                if deletedKeys.Has(sectionKey)
                    continue
                deletedKeys[sectionKey] := true
                IniDelete(tempPath, section)
            }
        }

        for entry in entries {
            IniWrite(
                entry.Enabled ? "true" : "false",
                tempPath, entry.Section, "Enabled"
            )
            IniWrite(
                Trim(entry.Name, " `t`r`n"),
                tempPath, entry.Section, "Name"
            )
            IniWrite(
                Trim(entry.Trigger, " `t`r`n"),
                tempPath, entry.Section, "Trigger"
            )
            IniWrite(
                EncodeReportHotstringText(
                    NormalizeEditableReportHotstringText(entry.Text)
                ),
                tempPath, entry.Section, "Text"
            )
            IniWrite(
                StrLower(Trim(entry.Mode, " `t`r`n")),
                tempPath, entry.Section, "Mode"
            )
        }

        savedLoad := LoadEditableReportHotstringConfig(tempPath)
        if !savedLoad.Ok
            throw Error("Saved configuration could not be read: " savedLoad.Message)
        if !EditableReportHotstringEntriesMatch(entries, savedLoad.Entries)
            throw Error("Saved configuration did not match the edited templates")
        for sectionKey, unused in deletedKeys {
            if EditableReportHotstringSectionExists(savedLoad.Entries, sectionKey)
                throw Error("A deleted template section remained in the file")
        }

        FileMove tempPath, configPath, true
        promoted := true
        savedText := FileRead(configPath)
        finalLoad := LoadEditableReportHotstringConfig(configPath)
        if !finalLoad.Ok
            throw Error("Final configuration validation failed")
        if !EditableReportHotstringEntriesMatch(entries, finalLoad.Entries)
            throw Error("Final configuration did not match the edited templates")
        return ReportHotstringEditorSaveResult(true, , savedText)
    } catch as err {
        try FileDelete tempPath
        OutputDebug "Report Assistant settings save failed: " err.Message
        if promoted && backupPath != "" && FileExist(backupPath) {
            try {
                FileCopy backupPath, configPath, true
                promoted := false
            } catch as restoreError {
                OutputDebug "Report Assistant settings restore failed: " restoreError.Message
                return ReportHotstringEditorSaveResult(
                    false,
                    "配置保存失败，并且无法自动恢复。请联系维护者。`n" .
                    "备份文件：" backupPath
                )
            }
        }
        return ReportHotstringEditorSaveResult(
            false, "无法保存配置，原配置未被本次操作覆盖。"
        )
    }
}

EditableReportHotstringEntriesMatch(expected, actual) {
    if Type(expected) != "Array" || Type(actual) != "Array"
        return false
    if expected.Length != actual.Length
        return false
    for index, expectedEntry in expected {
        actualEntry := actual[index]
        if expectedEntry.Section != actualEntry.Section
            return false
        if expectedEntry.Enabled != actualEntry.Enabled
            return false
        if Trim(expectedEntry.Name, " `t`r`n") != actualEntry.Name
            return false
        if Trim(expectedEntry.Trigger, " `t`r`n") != actualEntry.Trigger
            return false
        if NormalizeEditableReportHotstringText(expectedEntry.Text)
            != actualEntry.Text
            return false
        if StrLower(Trim(expectedEntry.Mode, " `t`r`n")) != actualEntry.Mode
            return false
    }
    return true
}
