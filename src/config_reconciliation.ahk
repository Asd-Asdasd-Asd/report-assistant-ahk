PrepareReportAssistantConfig(managedDefaults, configPath := "") {
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return false
    }
    if !FileExist(configPath) {
        try return CreateDefaultReportHotstringConfig(configPath)
        catch
            return false
    }
    try return ReconcileManagedConfigDefaults(configPath, managedDefaults)
    catch
        return false
}

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
