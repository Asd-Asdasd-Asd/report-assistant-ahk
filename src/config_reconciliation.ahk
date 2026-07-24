ReconcileManagedConfigDefaults(configPath, managedDefaults) {
    if !HasUniqueManagedConfigDefaults(managedDefaults)
        return false

    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch
        return false
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return false

    missingDefaults := FindMissingManagedConfigDefaults(
        configPath,
        managedDefaults
    )
    if Type(missingDefaults) != "Array"
        return false
    if missingDefaults.Length = 0
        return true
    return ApplyMissingManagedConfigDefaults(configPath, missingDefaults)
}

ReconcileAdditiveReportHotstringBuiltins(configPath) {
    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch
        return false
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return false

    rawEntries := LoadRawReportHotstringConfig(configPath)
    additions := []
    for definition in ReportHotstringDefaults.AdditiveBuiltinDefinitions() {
        decision := ResolveAdditiveReportHotstringBuiltin(
            rawEntries,
            definition
        )
        if !decision.Ok
            return false
        if decision.ShouldAdd
            additions.Push(decision.Entry)
    }
    if additions.Length = 0
        return true
    return ApplyAdditiveReportHotstringBuiltins(configPath, additions)
}

ResolveAdditiveReportHotstringBuiltin(rawEntries, definition) {
    sectionKey := StrLower(definition.Section)
    defaultTriggerKey := StrLower(definition.Trigger)
    seenTriggers := Map()
    defaultTriggerEntries := []
    for raw in rawEntries {
        if StrLower(raw.Section) = sectionKey {
            return {
                Ok: true,
                ShouldAdd: false,
                Entry: 0,
                Code: "SECTION_EXISTS"
            }
        }
        triggerKey := StrLower(Trim(raw.Trigger, " `t`r`n"))
        if triggerKey = ""
            continue
        seenTriggers[triggerKey] := true
        if triggerKey = defaultTriggerKey
            defaultTriggerEntries.Push(raw)
    }

    for existing in defaultTriggerEntries {
        if existing.Text = definition.Text {
            return {
                Ok: true,
                ShouldAdd: false,
                Entry: 0,
                Code: "EQUIVALENT_TRIGGER_EXISTS"
            }
        }
    }

    if defaultTriggerEntries.Length = 0 {
        entry := RawHotstringEntry(
            definition.Section,
            definition.Enabled,
            definition.Name,
            definition.Trigger,
            definition.Text
        )
        return {
            Ok: true,
            ShouldAdd: true,
            Entry: entry,
            Code: "ADD_DEFAULT"
        }
    }

    fallbackTrigger := FindAvailableAdditiveReportHotstringTrigger(
        definition.Trigger "-size",
        seenTriggers
    )
    if fallbackTrigger = "" {
        return {
            Ok: false,
            ShouldAdd: false,
            Entry: 0,
            Code: "FALLBACK_TRIGGER_UNAVAILABLE"
        }
    }
    return {
        Ok: true,
        ShouldAdd: true,
        Entry: RawHotstringEntry(
            definition.Section,
            "false",
            definition.Name,
            fallbackTrigger,
            definition.Text
        ),
        Code: "ADD_DISABLED_WITH_FALLBACK"
    }
}

FindAvailableAdditiveReportHotstringTrigger(baseTrigger, seenTriggers) {
    Loop 100 {
        candidate := A_Index = 1
            ? baseTrigger
            : baseTrigger A_Index
        if !seenTriggers.Has(StrLower(candidate))
            return candidate
    }
    return ""
}

ApplyAdditiveReportHotstringBuiltins(configPath, additions) {
    tempPath := configPath ".builtin-addition.tmp.ini"
    backupPath := ""
    promoted := false
    try {
        try FileDelete tempPath
        backupPath := CreateReportAssistantConfigBackup(configPath)
        FileCopy configPath, tempPath, true
        for entry in additions {
            IniWrite(entry.Enabled, tempPath, entry.Section, "Enabled")
            IniWrite(entry.Name, tempPath, entry.Section, "Name")
            IniWrite(entry.Trigger, tempPath, entry.Section, "Trigger")
            IniWrite(
                EncodeReportHotstringText(entry.Text),
                tempPath,
                entry.Section,
                "Text"
            )
        }
        if !ValidateAdditiveReportHotstringBuiltins(tempPath, additions)
            throw Error("Additive builtin validation failed")
        FileMove tempPath, configPath, true
        promoted := true
        if !ValidateAdditiveReportHotstringBuiltins(configPath, additions)
            throw Error("Final additive builtin validation failed")
        return true
    } catch {
        try FileDelete tempPath
        if promoted && backupPath != "" && FileExist(backupPath) {
            try FileCopy backupPath, configPath, true
            catch
                return false
        }
        return false
    }
}

ValidateAdditiveReportHotstringBuiltins(configPath, additions) {
    rawEntries := LoadRawReportHotstringConfig(configPath)
    bySection := Map()
    for raw in rawEntries
        bySection[StrLower(raw.Section)] := raw
    for expected in additions {
        sectionKey := StrLower(expected.Section)
        if !bySection.Has(sectionKey)
            return false
        actual := bySection[sectionKey]
        if actual.Enabled != expected.Enabled
            || actual.Name != expected.Name
            || actual.Trigger != expected.Trigger
            || actual.Text != expected.Text {
            return false
        }
    }
    return NormalizeReportHotstringEntriesResult(rawEntries).Ok
}

ReconcileSchema2BuiltinTemplateDefaults(configPath) {
    static MissingValue := "{A3FE0E44-FC11-4A12-83C4-ED719CA613A8}"
    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch
        return false
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return false

    updates := []
    for definition in ReportHotstringDefaults.LegacySchema2BuiltinTextUpgrades() {
        try encodedText := IniRead(
            configPath,
            definition.Section,
            "Text",
            MissingValue
        )
        catch
            return false
        if encodedText = MissingValue
            continue
        if DecodeReportHotstringText(encodedText) != definition.FromText
            continue
        updates.Push({
            Section: definition.Section,
            ExpectedEncodedText: encodedText,
            NewEncodedText: EncodeReportHotstringText(definition.ToText)
        })
    }
    if updates.Length = 0
        return true
    return ApplySchema2BuiltinTemplateUpdates(configPath, updates)
}

ApplySchema2BuiltinTemplateUpdates(configPath, updates) {
    tempPath := configPath ".builtin-template-update.tmp.ini"
    backupPath := ""
    promoted := false
    try {
        try FileDelete tempPath
        backupPath := CreateReportAssistantConfigBackup(configPath)
        FileCopy configPath, tempPath, true
        for update in updates {
            if IniRead(tempPath, update.Section, "Text", "")
                != update.ExpectedEncodedText
                throw Error("Builtin template changed during reconciliation")
            IniWrite(
                update.NewEncodedText,
                tempPath,
                update.Section,
                "Text"
            )
        }
        if !ValidateSchema2BuiltinTemplateUpdates(tempPath, updates)
            throw Error("Builtin template update validation failed")
        FileMove tempPath, configPath, true
        promoted := true
        if !ValidateSchema2BuiltinTemplateUpdates(configPath, updates)
            throw Error("Final builtin template validation failed")
        return true
    } catch {
        try FileDelete tempPath
        if promoted && backupPath != "" && FileExist(backupPath) {
            try FileCopy backupPath, configPath, true
            catch
                return false
        }
        return false
    }
}

ValidateSchema2BuiltinTemplateUpdates(configPath, updates) {
    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch
        return false
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return false
    for update in updates {
        try encodedText := IniRead(configPath, update.Section, "Text", "")
        catch
            return false
        if encodedText != update.NewEncodedText
            return false
        validation := ValidateReportTemplate(
            DecodeReportHotstringText(encodedText)
        )
        if !validation.Ok
            return false
    }
    return true
}

HasUniqueManagedConfigDefaults(managedDefaults) {
    if Type(managedDefaults) != "Array"
        return false
    seenKeys := Map()
    for definition in managedDefaults {
        keyId := ManagedConfigEntryId(definition)
        if keyId = "" || seenKeys.Has(keyId)
            return false
        seenKeys[keyId] := true
    }
    return true
}

ManagedConfigEntryId(definition) {
    section := StrLower(Trim(definition.Section, " `t`r`n"))
    key := StrLower(Trim(definition.Key, " `t`r`n"))
    if section = "" || key = ""
        return ""
    return section "`n" key
}

FindMissingManagedConfigDefaults(configPath, managedDefaults) {
    static MissingValue := "{A8EF2E83-27E4-4D3A-9B24-915C70B990B7}"
    missingDefaults := []
    for definition in managedDefaults {
        try value := IniRead(
            configPath,
            definition.Section,
            definition.Key,
            MissingValue
        )
        catch
            return false
        if value = MissingValue
            missingDefaults.Push(definition)
    }
    return missingDefaults
}

ApplyMissingManagedConfigDefaults(configPath, missingDefaults) {
    tempPath := configPath ".update.tmp.ini"
    try {
        CreateReportAssistantConfigBackup(configPath)
        FileCopy configPath, tempPath, true
        for definition in missingDefaults {
            IniWrite(
                definition.DefaultValue,
                tempPath,
                definition.Section,
                definition.Key
            )
        }
        if !ValidateManagedConfigUpdate(tempPath, missingDefaults)
            throw Error("Updated configuration validation failed")
        FileMove tempPath, configPath, true
        return true
    } catch {
        try FileDelete tempPath
        return false
    }
}

CreateReportAssistantConfigBackup(configPath) {
    SplitPath configPath, , &configDirectory
    backupDirectory := configDirectory "\backups"
    DirCreate backupDirectory
    timestamp := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    Loop 100 {
        suffix := A_Index = 1 ? "" : "-" A_Index
        backupPath := backupDirectory "\config-" timestamp suffix ".ini"
        if FileExist(backupPath)
            continue
        FileCopy configPath, backupPath, false
        return backupPath
    }
    throw Error("A unique configuration backup path was unavailable")
}

ValidateManagedConfigUpdate(configPath, updatedDefaults) {
    static MissingValue := "{5C0D5578-DC2A-448B-BD8C-E9302C9898C9}"
    try schemaValue := IniRead(configPath, "Config", "SchemaVersion", "")
    catch
        return false
    if schemaValue != String(ReportAssistantConfigDefaults.SchemaVersion)
        return false

    for definition in updatedDefaults {
        try value := IniRead(
            configPath,
            definition.Section,
            definition.Key,
            MissingValue
        )
        catch
            return false
        if value != definition.DefaultValue
            return false
    }
    return true
}
