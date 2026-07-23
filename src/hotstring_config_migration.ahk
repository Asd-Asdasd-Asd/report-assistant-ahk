class LegacyReportHotstringEntry {
    __New(section, enabled, name, trigger, text, mode) {
        this.Section := String(section)
        this.Enabled := String(enabled)
        this.Name := String(name)
        this.Trigger := String(trigger)
        this.Text := String(text)
        this.Mode := String(mode)
    }
}

class ReportConfigMigrationItem {
    __New(legacyEntry, migratedText, expectedRenderedText,
        expectedCaretLeftCount, expectedRedText, expectedColorReset) {
        this.LegacyEntry := legacyEntry
        this.MigratedText := String(migratedText)
        this.ExpectedRenderedText := String(expectedRenderedText)
        this.ExpectedCaretLeftCount := expectedCaretLeftCount
        this.ExpectedRedText := String(expectedRedText)
        this.ExpectedColorReset := expectedColorReset = true
    }
}

class ReportConfigMigrationResult {
    __New(ok, code, message, items := 0, originalText := "",
        backupPath := "") {
        this.Ok := ok = true
        this.Code := String(code)
        this.Message := String(message)
        this.Items := Type(items) = "Array" ? items : []
        this.OriginalText := String(originalText)
        this.BackupPath := String(backupPath)
    }
}

AuditReportAssistantConfigV1(configPath) {
    if !FileExist(configPath) {
        return ReportConfigMigrationResult(
            false, "CONFIG_MISSING", "配置文件不存在。"
        )
    }
    try originalText := FileRead(configPath)
    catch {
        return ReportConfigMigrationResult(
            false, "CONFIG_READ_FAILED", "无法读取配置文件。"
        )
    }

    structure := InspectLegacyIniStructure(originalText)
    if !structure.Ok {
        return ReportConfigMigrationResult(
            false, structure.Code, structure.Message, , originalText
        )
    }
    try {
        schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
        sectionList := IniRead(configPath)
    } catch {
        return ReportConfigMigrationResult(
            false, "CONFIG_PARSE_FAILED", "配置文件格式无法读取。", ,
            originalText
        )
    }
    if schemaValue != "1" {
        return ReportConfigMigrationResult(
            false, "NOT_SCHEMA_1",
            "配置文件不是可迁移的旧版本。", , originalText
        )
    }

    items := []
    seenSections := Map()
    seenTriggers := Map()
    for section in StrSplit(sectionList, "`n", "`r") {
        if !IsReportHotstringSection(section)
            continue
        sectionKey := StrLower(section)
        if seenSections.Has(sectionKey) {
            return ReportConfigMigrationResult(
                false, "DUPLICATE_SECTION",
                "存在重复的模板记录：" section, , originalText
            )
        }
        seenSections[sectionKey] := true
        try legacy := ReadLegacyReportHotstringSection(configPath, section)
        catch {
            return ReportConfigMigrationResult(
                false, "LEGACY_ENTRY_READ_FAILED",
                "无法读取模板记录：" section, , originalText
            )
        }

        enabled := ParseReportHotstringEnabled(legacy.Enabled)
        if enabled = "INVALID" {
            return ReportConfigMigrationResult(
                false, "INVALID_ENABLED",
                "模板启用状态无效：" section, , originalText
            )
        }
        name := Trim(legacy.Name, " `t`r`n")
        trigger := Trim(legacy.Trigger, " `t`r`n")
        if name = "" || InStr(legacy.Name, "`r") || InStr(legacy.Name, "`n") {
            return ReportConfigMigrationResult(
                false, "INVALID_NAME",
                "模板名称为空或包含换行：" section, , originalText
            )
        }
        if trigger = "" || InStr(legacy.Trigger, "`r")
            || InStr(legacy.Trigger, "`n") {
            return ReportConfigMigrationResult(
                false, "INVALID_TRIGGER",
                "模板触发词为空或包含换行：" section, , originalText
            )
        }
        triggerKey := StrLower(trigger)
        if seenTriggers.Has(triggerKey) {
            return ReportConfigMigrationResult(
                false, "DUPLICATE_TRIGGER",
                "存在重复触发词：" trigger, , originalText
            )
        }
        seenTriggers[triggerKey] := true
        if InStr(legacy.Text, "{{") || InStr(legacy.Text, "}}") {
            return ReportConfigMigrationResult(
                false, "LEGACY_PLACEHOLDER_AMBIGUOUS",
                "旧模板已经包含双花括号，需要手工确认：" section, ,
                originalText
            )
        }

        item := BuildLegacyReportHotstringMigrationItem(legacy)
        if !item.Ok {
            return ReportConfigMigrationResult(
                false, item.Code, item.Message, , originalText
            )
        }
        items.Push(item.Item)
    }
    if items.Length = 0 {
        return ReportConfigMigrationResult(
            false, "NO_HOTSTRINGS",
            "旧配置中没有可迁移的报告模板。", , originalText
        )
    }
    return ReportConfigMigrationResult(
        true, "READY_FOR_SCHEMA_2_MIGRATION",
        "旧配置可以安全迁移。", items, originalText
    )
}

ReadLegacyReportHotstringSection(configPath, section) {
    return LegacyReportHotstringEntry(
        section,
        IniRead(configPath, section, "Enabled", "true"),
        IniRead(configPath, section, "Name", ""),
        IniRead(configPath, section, "Trigger", ""),
        DecodeReportHotstringText(IniRead(configPath, section, "Text", "")),
        IniRead(configPath, section, "Mode", "")
    )
}

LegacyTextEndsWith(sourceText, suffix) {
    if suffix = "" || StrLen(sourceText) < StrLen(suffix)
        return false
    suffixStart := StrLen(sourceText) - StrLen(suffix) + 1
    return SubStr(sourceText, suffixStart) = suffix
}

BuildLegacyReportHotstringMigrationItem(legacy) {
    mode := StrLower(Trim(legacy.Mode, " `t`r`n"))
    marker := ReportHotstringDefaults.RedFigureMarker
    oldText := legacy.Text
    migratedText := ""
    renderedText := oldText
    caretLeftCount := 0
    expectedColorReset := false
    expectedRedText := ""
    redPlaceholder := ReportHotstringDefaults.RedFigureReferencePlaceholder

    if mode = "text" {
        if StrLower(legacy.Section) = "hotstring.builtin-cmx" {
            if StrLen(oldText) < 2 {
                return {
                    Ok: false,
                    Code: "CMX_TEXT_TOO_SHORT",
                    Message: "厘米模板内容过短，无法保留光标位置。"
                }
            }
            migratedText := InsertCursorPlaceholderFromEnd(oldText, 2)
            caretLeftCount := 2
        } else {
            migratedText := oldText
        }
    } else if mode = "red-reset" {
        renderedText := LegacyTextEndsWith(oldText, marker)
            ? oldText
            : oldText marker
        migratedText := SubStr(
            renderedText, 1, StrLen(renderedText) - StrLen(marker)
        ) redPlaceholder
        expectedRedText := marker
        expectedColorReset := true
    } else if mode = "red-left4" {
        renderedText := LegacyTextEndsWith(oldText, marker)
            ? oldText
            : oldText marker
        if StrLen(renderedText) < 4 {
            return {
                Ok: false,
                Code: "LEGACY_LEFT4_TEXT_TOO_SHORT",
                Message: "旧模板内容过短，无法保留光标位置：" legacy.Section
            }
        }
        if StrLower(legacy.Section) = "hotstring.builtin-fzg"
            && oldText = "放射性摄取增高，SUVmax约（见图）" {
            migratedText := "放射性摄取增高，SUVmax约为{{cursor}}" .
                redPlaceholder
            renderedText := "放射性摄取增高，SUVmax约为（见图）"
        } else {
            migratedText := SubStr(
                renderedText, 1, StrLen(renderedText) - StrLen(marker)
            ) ReportHotstringDefaults.CursorPlaceholder redPlaceholder
        }
        caretLeftCount := 4
        expectedRedText := marker
    } else {
        return {
            Ok: false,
            Code: "UNKNOWN_LEGACY_MODE",
            Message: "无法识别旧模板行为：" legacy.Section
        }
    }

    validation := ValidateReportTemplate(migratedText)
    if !validation.Ok {
        return {
            Ok: false,
            Code: "MIGRATED_TEMPLATE_INVALID",
            Message: "迁移后的模板无法验证：" legacy.Section
        }
    }
    plan := BuildReportTemplatePlan(migratedText)
    if !plan.Ok || plan.RenderedText != renderedText
        || plan.CaretLeftCount != caretLeftCount
        || plan.RedText != expectedRedText
        || plan.RequiresColorReset != expectedColorReset {
        return {
            Ok: false,
            Code: "MIGRATION_SEMANTICS_MISMATCH",
            Message: "无法完整保留旧模板行为：" legacy.Section
        }
    }
    return {
        Ok: true,
        Item: ReportConfigMigrationItem(
            legacy,
            migratedText,
            renderedText,
            caretLeftCount,
            expectedRedText,
            expectedColorReset
        )
    }
}

InsertCursorPlaceholderFromEnd(text, leftCount) {
    length := StrLen(text)
    insertionIndex := length - leftCount
    return SubStr(text, 1, insertionIndex)
        . ReportHotstringDefaults.CursorPlaceholder
        . SubStr(text, insertionIndex + 1)
}

InspectLegacyIniStructure(originalText) {
    sectionCounts := Map()
    hotstringKeys := Map()
    currentSection := ""
    for line in StrSplit(
        NormalizeReportHotstringTextNewlines(originalText), "`n"
    ) {
        trimmed := Trim(line, " `t")
        if trimmed = "" || SubStr(trimmed, 1, 1) = ";"
            || SubStr(trimmed, 1, 1) = "#"
            continue
        if RegExMatch(trimmed, "^\[([^\]]+)\]$", &match) {
            currentSection := match[1]
            sectionKey := StrLower(currentSection)
            sectionCounts[sectionKey] := sectionCounts.Has(sectionKey)
                ? sectionCounts[sectionKey] + 1
                : 1
            if sectionCounts[sectionKey] > 1 {
                return {
                    Ok: false,
                    Code: "DUPLICATE_SECTION",
                    Message: "配置中存在重复 section：" currentSection
                }
            }
            if IsReportHotstringSection(currentSection)
                hotstringKeys[sectionKey] := Map()
            continue
        }
        if currentSection = "" || !IsReportHotstringSection(currentSection)
            continue
        equalsPosition := InStr(line, "=")
        if !equalsPosition
            continue
        key := StrLower(Trim(SubStr(line, 1, equalsPosition - 1), " `t"))
        sectionKey := StrLower(currentSection)
        keys := hotstringKeys[sectionKey]
        if keys.Has(key) {
            return {
                Ok: false,
                Code: "DUPLICATE_HOTSTRING_KEY",
                Message: "模板中存在重复字段：" currentSection
            }
        }
        keys[key] := true
    }
    return {Ok: true}
}

MigrateReportAssistantConfigV1ToV2(configPath) {
    audit := AuditReportAssistantConfigV1(configPath)
    if !audit.Ok
        return audit

    tempPath := configPath ".schema2.tmp.ini"
    backupPath := ""
    promoted := false
    try {
        try FileDelete tempPath
        backupPath := CreateReportAssistantConfigBackup(configPath)
        FileCopy configPath, tempPath, true
        IniWrite(
            ReportAssistantConfigDefaults.SchemaVersion,
            tempPath,
            "Config",
            "SchemaVersion"
        )
        for item in audit.Items
            IniDelete(tempPath, item.LegacyEntry.Section)
        for item in audit.Items {
            entry := item.LegacyEntry
            IniWrite(
                ParseReportHotstringEnabled(entry.Enabled) ? "true" : "false",
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
                EncodeReportHotstringText(item.MigratedText),
                tempPath, entry.Section, "Text"
            )
        }
        if !ValidateMigratedReportAssistantConfig(tempPath, audit.Items)
            throw Error("Temporary schema 2 validation failed")

        FileMove tempPath, configPath, true
        promoted := true
        if !ValidateMigratedReportAssistantConfig(configPath, audit.Items)
            throw Error("Final schema 2 validation failed")
        return ReportConfigMigrationResult(
            true, "SCHEMA_2_MIGRATION_OK",
            "配置已升级。", audit.Items, audit.OriginalText, backupPath
        )
    } catch as err {
        try FileDelete tempPath
        OutputDebug "Report config migration failed: " err.Message
        if promoted && backupPath != "" && FileExist(backupPath) {
            try FileCopy backupPath, configPath, true
            catch as restoreError {
                OutputDebug(
                    "Report config migration restore failed: " .
                    restoreError.Message
                )
                return ReportConfigMigrationResult(
                    false, "MIGRATION_RESTORE_FAILED",
                    "配置升级失败，并且无法自动恢复。请联系维护者。",
                    , audit.OriginalText, backupPath
                )
            }
        }
        return ReportConfigMigrationResult(
            false, "MIGRATION_WRITE_FAILED",
            "配置升级失败，原配置未被本次操作覆盖。",
            , audit.OriginalText, backupPath
        )
    }
}

ValidateMigratedReportAssistantConfig(configPath, expectedItems) {
    try {
        if IniRead(configPath, "Config", "SchemaVersion", "")
            != String(ReportAssistantConfigDefaults.SchemaVersion)
            return false
        rawEntries := LoadRawReportHotstringConfig(configPath)
    } catch {
        return false
    }
    if rawEntries.Length != expectedItems.Length
        return false
    actualBySection := Map()
    for raw in rawEntries {
        key := StrLower(raw.Section)
        if actualBySection.Has(key)
            return false
        actualBySection[key] := raw
    }
    for item in expectedItems {
        expected := item.LegacyEntry
        key := StrLower(expected.Section)
        if !actualBySection.Has(key)
            return false
        actual := actualBySection[key]
        if actual.Enabled != (ParseReportHotstringEnabled(expected.Enabled)
            ? "true" : "false")
            || actual.Name != Trim(expected.Name, " `t`r`n")
            || actual.Trigger != Trim(expected.Trigger, " `t`r`n")
            || actual.Text != item.MigratedText
            return false
        plan := BuildReportTemplatePlan(actual.Text)
        if !plan.Ok || plan.RenderedText != item.ExpectedRenderedText
            || plan.CaretLeftCount != item.ExpectedCaretLeftCount
            || plan.RedText != item.ExpectedRedText
            || plan.RequiresColorReset != item.ExpectedColorReset
            return false
    }
    return true
}

WriteReportAssistantConfigV2Audit(configPath, outputPath) {
    audit := AuditReportAssistantConfigV1(configPath)
    lines := [
        "ConfigMigrationAudit",
        "Result=" audit.Code,
        "Ready=" (audit.Ok ? "true" : "false")
    ]
    if audit.Ok {
        for item in audit.Items {
            entry := item.LegacyEntry
            lines.Push("")
            lines.Push("Section=" entry.Section)
            lines.Push("Name=" entry.Name)
            lines.Push("Trigger=" entry.Trigger)
            lines.Push("LegacyMode=" entry.Mode)
            lines.Push("Migration=READY")
        }
    }
    SplitPath outputPath, , &outputDirectory
    DirCreate outputDirectory
    try FileDelete outputPath
    FileAppend JoinConfigLines(lines) "`r`n", outputPath, "UTF-8"
    return audit
}
