class ReportAssistantConfigDefaults {
    static SchemaVersion := 2
    static DirectoryName := "MedExReportAssistant"
    static FileName := "config.ini"
}

class ReportAssistantConfig {
    static Path() {
        localAppData := EnvGet("LOCALAPPDATA")
        if localAppData = ""
            throw Error("LOCALAPPDATA is unavailable")
        return localAppData "\" ReportAssistantConfigDefaults.DirectoryName "\" ReportAssistantConfigDefaults.FileName
    }
}

class ManagedConfigEntry {
    __New(section, key, defaultValue) {
        this.Section := String(section)
        this.Key := String(key)
        this.DefaultValue := String(defaultValue)
    }
}

; Target process names. These are fixed product constants, not user settings;
; the compiled EXE cannot read a config.local.ahk override.
class TargetProcessDefaults {
    static ReportEditorExe := "medexworkstation.exe"
    static ViewerExe := "MedExNMFusion.exe"
}
