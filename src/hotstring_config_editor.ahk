class EditableReportHotstringEntry {
    __New(section, enabled, name, trigger, text, isBuiltin := false) {
        this.Section := String(section)
        this.Enabled := enabled = true
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
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
    __New(ok, row := 0, field := "", message := "", section := "") {
        this.Ok := ok = true
        this.Row := row
        this.Field := String(field)
        this.Message := String(message)
        this.Section := String(section)
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
            IsBuiltinReportHotstringSection(raw.Section)
        ))
    }
    if entries.Length = 0 {
        return ReportHotstringEditorLoadResult(
            false, configPath, originalText, ,
            "配置文件中没有可编辑的报告模板。"
        )
    }
    validation := ValidateEditableReportHotstringEntries(entries)
    if !validation.Ok {
        return ReportHotstringEditorLoadResult(
            false, configPath, originalText, , validation.Message
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
        section, true, "新的模板", "", "", false
    )
}

NormalizeEditableReportHotstringText(value) {
    return NormalizeReportHotstringTextNewlines(value)
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
                false, index, "Name",
                "模板的内部记录发生冲突，请重新打开设置。",
                entry.Section
            )
        }
        if entry.IsBuiltin {
            if !IsBuiltinReportHotstringSection(entry.Section) {
                return ReportHotstringEditorValidationResult(
                    false, index, "Name",
                    "内置模板记录无效，请重新打开设置。",
                    entry.Section
                )
            }
        } else if !IsCustomReportHotstringSection(entry.Section) {
            return ReportHotstringEditorValidationResult(
                false, index, "Name",
                "自定义模板记录无效，请重新打开设置。",
                entry.Section
            )
        }
        seenSections[sectionKey] := true

        name := Trim(entry.Name, " `t`r`n")
        if name = "" || InStr(entry.Name, "`r") || InStr(entry.Name, "`n") {
            return ReportHotstringEditorValidationResult(
                false, index, "Name",
                "模板名称不能为空或包含换行。",
                entry.Section
            )
        }

        trigger := Trim(entry.Trigger, " `t`r`n")
        if trigger = "" || InStr(entry.Trigger, "`r") || InStr(entry.Trigger, "`n") {
            return ReportHotstringEditorValidationResult(
                false, index, "Trigger",
                "触发词不能为空或包含换行。",
                entry.Section
            )
        }
        triggerKey := StrLower(trigger)
        if seenTriggers.Has(triggerKey) {
            return ReportHotstringEditorValidationResult(
                false, index, "Trigger",
                "触发词“" trigger "”与其他模板重复。",
                entry.Section
            )
        }
        seenTriggers[triggerKey] := true

        templateValidation := ValidateReportTemplate(entry.Text)
        if !templateValidation.Ok {
            return ReportHotstringEditorValidationResult(
                false, index, "Text",
                "模板文字有误：" templateValidation.Message,
                entry.Section
            )
        }
    }
    return ReportHotstringEditorValidationResult(true)
}

SaveEditableReportHotstringConfig(
    entries,
    deletedSections,
    originalText,
    modifiedSectionKeys,
    configPath := ""
) {
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
    originalLoad := LoadEditableReportHotstringConfig(configPath)
    if !originalLoad.Ok
        return ReportHotstringEditorSaveResult(
            false, "无法验证保存前的模板配置，未进行任何修改。"
        )
    originalBySection := EditableReportHotstringEntriesBySection(
        originalLoad.Entries
    )
    modifiedKeys := NormalizeEditableReportHotstringSectionKeys(
        modifiedSectionKeys
    )

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
            sectionKey := StrLower(entry.Section)
            if originalBySection.Has(sectionKey)
                && !modifiedKeys.Has(sectionKey)
                continue
            IniDelete(tempPath, entry.Section)
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
        }

        savedLoad := LoadEditableReportHotstringConfig(tempPath)
        if !savedLoad.Ok
            throw Error("Saved configuration could not be read: " savedLoad.Message)
        if !EditableReportHotstringEntriesMatch(entries, savedLoad.Entries)
            throw Error("Saved configuration did not match the edited templates")
        if !ValidateEditableReportHotstringSaveResult(
            originalLoad.Entries,
            entries,
            deletedKeys,
            modifiedKeys,
            savedLoad.Entries
        )
            throw Error("Saved configuration changed an unintended template")

        FileMove tempPath, configPath, true
        promoted := true
        savedText := FileRead(configPath)
        finalLoad := LoadEditableReportHotstringConfig(configPath)
        if !finalLoad.Ok
            throw Error("Final configuration validation failed")
        if !EditableReportHotstringEntriesMatch(entries, finalLoad.Entries)
            throw Error("Final configuration did not match the edited templates")
        if !ValidateEditableReportHotstringSaveResult(
            originalLoad.Entries,
            entries,
            deletedKeys,
            modifiedKeys,
            finalLoad.Entries
        )
            throw Error("Final configuration changed an unintended template")
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
    actualBySection := EditableReportHotstringEntriesBySection(actual)
    if actualBySection.Count != actual.Length
        return false
    for expectedEntry in expected {
        sectionKey := StrLower(expectedEntry.Section)
        if !actualBySection.Has(sectionKey)
            return false
        if !EditableReportHotstringEntryMatches(
            expectedEntry,
            actualBySection[sectionKey]
        )
            return false
    }
    return true
}

EditableReportHotstringEntryMatches(expected, actual) {
    if StrLower(expected.Section) != StrLower(actual.Section)
        return false
    if expected.Enabled != actual.Enabled
        return false
    if Trim(expected.Name, " `t`r`n") != actual.Name
        return false
    if Trim(expected.Trigger, " `t`r`n") != actual.Trigger
        return false
    return NormalizeEditableReportHotstringText(expected.Text) = actual.Text
}

EditableReportHotstringEntriesBySection(entries) {
    bySection := Map()
    if Type(entries) != "Array"
        return bySection
    for entry in entries {
        sectionKey := StrLower(entry.Section)
        if bySection.Has(sectionKey)
            return Map()
        bySection[sectionKey] := entry
    }
    return bySection
}

ValidateEditableReportHotstringSaveResult(
    originalEntries,
    intendedEntries,
    deletedKeys,
    modifiedKeys,
    actualEntries
) {
    if !EditableReportHotstringEntriesMatch(intendedEntries, actualEntries)
        return false

    intendedBySection := EditableReportHotstringEntriesBySection(intendedEntries)
    actualBySection := EditableReportHotstringEntriesBySection(actualEntries)
    if intendedBySection.Count != intendedEntries.Length
        || actualBySection.Count != actualEntries.Length
        return false

    if Type(deletedKeys) = "Map" {
        for sectionKey, unused in deletedKeys {
            if actualBySection.Has(sectionKey)
                return false
        }
    }

    for originalEntry in originalEntries {
        sectionKey := StrLower(originalEntry.Section)
        wasDeleted := Type(deletedKeys) = "Map" && deletedKeys.Has(sectionKey)
        if wasDeleted
            continue
        if !intendedBySection.Has(sectionKey) || !actualBySection.Has(sectionKey)
            return false
        wasModified := Type(modifiedKeys) = "Map"
            && modifiedKeys.Has(sectionKey)
        if !wasModified
            && !EditableReportHotstringEntryMatches(
                originalEntry,
                intendedBySection[sectionKey]
            )
            return false
    }
    return true
}

NormalizeEditableReportHotstringSectionKeys(keys) {
    normalized := Map()
    if Type(keys) = "Map" {
        for key, unused in keys
            normalized[StrLower(String(key))] := true
    } else if Type(keys) = "Array" {
        for key in keys
            normalized[StrLower(String(key))] := true
    }
    return normalized
}
