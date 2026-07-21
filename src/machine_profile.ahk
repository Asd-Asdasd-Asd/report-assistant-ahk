class MedExMachineProfileDefaults {
    static SchemaVersion := 1
    static FileName := "machine-profile.ini"
    static Status := "validated"
    static SupportedDpi := 96
    static SupportedDisplayScaling := "100%"
    static ArrowOffsetXMin := 40
    static ArrowOffsetXMax := 800
    static ArrowOffsetYAbsMax := 40
    static BlackOffsetAbsMax := 300
}

MedExMachineProfilePath() {
    configPath := ReportAssistantConfig.Path()
    SplitPath configPath, , &configDirectory
    return configDirectory "\" MedExMachineProfileDefaults.FileName
}

LoadValidatedMedExMachineProfile(profilePath := "") {
    if profilePath = "" {
        try profilePath := MedExMachineProfilePath()
        catch
            return 0
    }
    if !FileExist(profilePath)
        return 0

    try {
        profile := Map(
            "schemaVersion", IniRead(profilePath, "Profile", "SchemaVersion", ""),
            "status", IniRead(profilePath, "Profile", "Status", ""),
            "dpi", IniRead(profilePath, "Environment", "Dpi", ""),
            "displayScaling", IniRead(profilePath, "Environment", "DisplayScaling", ""),
            "arrowOffsetX", IniRead(profilePath, "Offsets", "ArrowOffsetX", ""),
            "arrowOffsetY", IniRead(profilePath, "Offsets", "ArrowOffsetY", ""),
            "blackOffsetX", IniRead(profilePath, "Offsets", "BlackOffsetX", ""),
            "blackOffsetY", IniRead(profilePath, "Offsets", "BlackOffsetY", ""),
            "validatedAt", IniRead(profilePath, "Diagnostics", "ValidatedAt", "UNKNOWN")
        )
    } catch {
        return 0
    }
    if !ValidateMedExMachineProfile(profile)
        return 0
    for key in ["dpi", "arrowOffsetX", "arrowOffsetY", "blackOffsetX", "blackOffsetY"]
        profile[key] := Integer(profile[key])
    profile["path"] := profilePath
    return profile
}

ValidateMedExMachineProfile(profile) {
    if Type(profile) != "Map"
        return false
    required := [
        "schemaVersion", "status", "dpi", "displayScaling",
        "arrowOffsetX", "arrowOffsetY", "blackOffsetX", "blackOffsetY"
    ]
    for key in required {
        if !profile.Has(key)
            return false
    }
    if String(profile["schemaVersion"]) != String(MedExMachineProfileDefaults.SchemaVersion)
        return false
    if StrLower(String(profile["status"])) != MedExMachineProfileDefaults.Status
        return false
    for key in ["dpi", "arrowOffsetX", "arrowOffsetY", "blackOffsetX", "blackOffsetY"] {
        if !IsInteger(profile[key])
            return false
    }
    if Integer(profile["dpi"]) != MedExMachineProfileDefaults.SupportedDpi
        return false
    if String(profile["displayScaling"]) != MedExMachineProfileDefaults.SupportedDisplayScaling
        return false
    if Integer(profile["arrowOffsetX"]) < MedExMachineProfileDefaults.ArrowOffsetXMin
        return false
    if Integer(profile["arrowOffsetX"]) > MedExMachineProfileDefaults.ArrowOffsetXMax
        return false
    if Abs(Integer(profile["arrowOffsetY"])) > MedExMachineProfileDefaults.ArrowOffsetYAbsMax
        return false
    if Abs(Integer(profile["blackOffsetX"])) > MedExMachineProfileDefaults.BlackOffsetAbsMax
        return false
    if Abs(Integer(profile["blackOffsetY"])) > MedExMachineProfileDefaults.BlackOffsetAbsMax
        return false
    return true
}

BuildMedExMachineProfileOptions(profile) {
    if !ValidateMedExMachineProfile(profile)
        return 0
    blackOffsetX := Integer(profile["blackOffsetX"])
    blackOffsetY := Integer(profile["blackOffsetY"])
    return Map(
        "profileName", "machine-calibrated-relative-mouse-v1",
        "candidateGMachineProfileValidated", true,
        "arrowOffsetX", Integer(profile["arrowOffsetX"]),
        "arrowOffsetY", Integer(profile["arrowOffsetY"]),
        "blackOffsetX", blackOffsetX,
        "blackOffsetY", blackOffsetY,
        "popupLightOffsetX", blackOffsetX,
        "popupLightOffsetY", blackOffsetY - 67,
        "blackSwatchOffsetX", blackOffsetX,
        "blackSwatchOffsetY", blackOffsetY,
        "beigeSwatchOffsetX", blackOffsetX + 14,
        "beigeSwatchOffsetY", blackOffsetY,
        "blueSwatchOffsetX", blackOffsetX + 34,
        "blueSwatchOffsetY", blackOffsetY
    )
}

SaveValidatedMedExMachineProfile(profile, profilePath := "") {
    if !ValidateMedExMachineProfile(profile)
        return false
    if profilePath = ""
        profilePath := MedExMachineProfilePath()
    SplitPath profilePath, , &profileDirectory
    DirCreate profileDirectory
    tempPath := profilePath ".write.tmp.ini"
    try {
        try FileDelete tempPath
        IniWrite MedExMachineProfileDefaults.SchemaVersion, tempPath, "Profile", "SchemaVersion"
        IniWrite MedExMachineProfileDefaults.Status, tempPath, "Profile", "Status"
        IniWrite profile["dpi"], tempPath, "Environment", "Dpi"
        IniWrite profile["displayScaling"], tempPath, "Environment", "DisplayScaling"
        IniWrite profile["arrowOffsetX"], tempPath, "Offsets", "ArrowOffsetX"
        IniWrite profile["arrowOffsetY"], tempPath, "Offsets", "ArrowOffsetY"
        IniWrite profile["blackOffsetX"], tempPath, "Offsets", "BlackOffsetX"
        IniWrite profile["blackOffsetY"], tempPath, "Offsets", "BlackOffsetY"
        IniWrite MedExMachineProfileValue(profile, "validatedAt", FormatTime(, "yyyy-MM-ddTHH:mm:ss")), tempPath, "Diagnostics", "ValidatedAt"
        if !LoadValidatedMedExMachineProfile(tempPath)
            throw Error("Machine profile validation failed")
        if FileExist(profilePath)
            BackupMedExMachineProfile(profilePath)
        FileMove tempPath, profilePath, true
        return !!LoadValidatedMedExMachineProfile(profilePath)
    } catch {
        try FileDelete tempPath
        return false
    }
}

BackupMedExMachineProfile(profilePath) {
    SplitPath profilePath, , &profileDirectory
    backupDirectory := profileDirectory "\backups"
    DirCreate backupDirectory
    timestamp := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    Loop 100 {
        suffix := A_Index = 1 ? "" : "-" A_Index
        backupPath := backupDirectory "\machine-profile-" timestamp suffix ".ini"
        if FileExist(backupPath)
            continue
        FileCopy profilePath, backupPath, false
        return backupPath
    }
    throw Error("A unique machine profile backup path was unavailable")
}

MedExMachineProfileValue(profile, key, defaultValue) {
    return Type(profile) = "Map" && profile.Has(key) ? profile[key] : defaultValue
}
