#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\app_config.ahk
#Include ..\..\src\feature_model.ahk
#Include ..\..\src\hotstring_model.ahk
#Include ..\..\src\hotstring_config.ahk
#Include ..\..\src\template_renderer.ahk
#Include ..\..\src\hotstring_normalization.ahk
#Include ..\..\src\config_reconciliation.ahk
#Include ..\..\src\hotstring_config_migration.ahk

RunTemplateEngineRegression()

RunTemplateEngineRegression() {
    TestTemplatePlans()
    TestSchema1Migration()
    TestInterimSchema2BuiltinDefaultUpgrade()
    TestUnsafeMigrationLeavesOriginalUntouched()
    MsgBox "Template engine regression passed.", "MedEx test", "Iconi"
    ExitApp 0
}

TestInterimSchema2BuiltinDefaultUpgrade() {
    testDirectory := A_Temp "\MedExSchema2Builtin-" A_TickCount
    DirCreate testDirectory
    configPath := testDirectory "\config.ini"
    try {
        FileAppend InterimSchema2Fixture(), configPath, "UTF-16"
        result := ReconcileSchema2BuiltinTemplateDefaults(configPath)
        AssertTemplateTest(result, "schema 2 builtin upgrade failed")
        AssertTemplateTest(
            DecodeReportHotstringText(
                IniRead(configPath, "Hotstring.builtin-red", "Text", "")
            ) = "{{red:（见图）}}",
            "red builtin was not upgraded"
        )
        AssertTemplateTest(
            DecodeReportHotstringText(
                IniRead(configPath, "Hotstring.builtin-fzg", "Text", "")
            ) = "放射性摄取增高，SUVmax约为{{cursor}}"
                . "{{red:（见图）}}",
            "fzg builtin was not upgraded"
        )
        AssertTemplateTest(
            DecodeReportHotstringText(
                IniRead(configPath, "Hotstring.builtin-fjd", "Text", "")
            ) = "用户已修改（见图）",
            "modified builtin text was overwritten"
        )
        AssertTemplateTest(
            DecodeReportHotstringText(
                IniRead(configPath, "Hotstring.custom-note", "Text", "")
            ) = "自定义内容（见图）",
            "custom template text was overwritten"
        )
    } finally {
        try DirDelete testDirectory, true
    }
}

TestTemplatePlans() {
    internal := BuildReportTemplatePlan(
        "检查日期：{{date}}，SUVmax约为{{cursor}}{{red:（见图）}}"
    )
    AssertTemplateTest(internal.Ok, "internal cursor template failed")
    AssertTemplateTest(
        RegExMatch(internal.RenderedText, "\d{4}-\d{2}-\d{2}"),
        "date was not expanded at execution time"
    )
    AssertTemplateTest(
        internal.CaretLeftCount = 4,
        "date changed the derived caret position"
    )
    AssertTemplateTest(
        !internal.RequiresColorReset,
        "internal cursor unexpectedly requested color reset"
    )

    endRed := BuildReportTemplatePlan(
        "SUVmax约为3.6{{red:（见图）}}"
    )
    AssertTemplateTest(
        endRed.CaretLeftCount = 0 && endRed.RequiresColorReset,
        "end cursor did not request color reset"
    )
    plain := BuildReportTemplatePlan("检查日期：{{date}}")
    AssertTemplateTest(
        plain.RedText = "" && !plain.RequiresColorReset,
        "plain template requested Candidate G"
    )
    literalMarker := BuildReportTemplatePlan("普通文字（见图）")
    AssertTemplateTest(
        literalMarker.RedText = ""
            && !literalMarker.RequiresColorReset,
        "literal marker unexpectedly requested red formatting"
    )
    cmx := BuildReportTemplatePlan("cm×{{cursor}}cm")
    AssertTemplateTest(
        cmx.RenderedText = "cm×cm" && cmx.CaretLeftCount = 2,
        "cmx template contract changed"
    )

    for invalid in [
        "{{cursor}}{{cursor}}",
        "{{cursur}}",
        "{{unknown}}",
        "{{red:重要}}",
        "{{red:}}",
        "{{red:（见图）}}{{red:（见图）}}",
        "{{red:（见图）}}正文",
        "{{red:（见图）}}{{cursor}}",
        "{{red:（见图）}}{{date}}",
        "{{date",
        "date}}"
    ]
        AssertTemplateTest(
            !ValidateReportTemplate(invalid).Ok,
            "invalid placeholder was accepted"
        )
    AssertTemplateTest(
        ValidateReportTemplate("{ordinary}").Ok,
        "ordinary single braces were rejected"
    )
}

TestSchema1Migration() {
    testDirectory := A_Temp "\MedExTemplateMigration-" A_TickCount
    DirCreate testDirectory
    configPath := testDirectory "\config.ini"
    try {
        FileAppend SafeSchema1Fixture(), configPath, "UTF-16"
        result := MigrateReportAssistantConfigV1ToV2(configPath)
        AssertTemplateTest(result.Ok, "safe schema 1 migration failed")
        AssertTemplateTest(
            FileExist(result.BackupPath),
            "migration backup was not created"
        )
        AssertTemplateTest(
            IniRead(configPath, "Config", "SchemaVersion", "") = "2",
            "schema version was not promoted"
        )
        AssertTemplateTest(
            IniRead(
                configPath,
                "Hotstring.custom-left",
                "Mode",
                "MISSING"
            ) = "MISSING",
            "legacy Mode remained after migration"
        )
        AssertTemplateTest(
            IniRead(configPath, "Unknown", "Keep", "") = "yes",
            "unknown non-hotstring content changed"
        )
        AssertTemplateTest(
            InStr(
                FileRead(configPath),
                "; preserve this non-hotstring comment"
            ),
            "non-hotstring comment changed"
        )
        migrated := ReadReportHotstringSection(
            configPath, "Hotstring.custom-left"
        )
        plan := BuildReportTemplatePlan(migrated.Text)
        AssertTemplateTest(
            plan.CaretLeftCount = 4
                && plan.RedText = ReportHotstringDefaults.RedFigureMarker
                && !plan.RequiresColorReset,
            "custom red-left4 semantics changed"
        )
        migratedBlack := ReadReportHotstringSection(
            configPath, "Hotstring.custom-black-marker"
        )
        blackPlan := BuildReportTemplatePlan(migratedBlack.Text)
        AssertTemplateTest(
            blackPlan.RenderedText = "普通文字（见图）"
                && blackPlan.RedText = ""
                && !blackPlan.RequiresColorReset,
            "legacy text-mode literal marker gained red semantics"
        )
    } finally {
        try DirDelete testDirectory, true
    }
}

TestUnsafeMigrationLeavesOriginalUntouched() {
    testDirectory := A_Temp "\MedExTemplateBlocked-" A_TickCount
    DirCreate testDirectory
    configPath := testDirectory "\config.ini"
    try {
        FileAppend UnsafeSchema1Fixture(), configPath, "UTF-16"
        before := FileRead(configPath)
        result := MigrateReportAssistantConfigV1ToV2(configPath)
        after := FileRead(configPath)
        AssertTemplateTest(!result.Ok, "unsafe migration unexpectedly succeeded")
        AssertTemplateTest(
            result.Code = "UNKNOWN_LEGACY_MODE",
            "unsafe migration returned the wrong reason"
        )
        AssertTemplateTest(before = after, "blocked migration changed the original")
    } finally {
        try DirDelete testDirectory, true
    }
}

SafeSchema1Fixture() {
    return JoinConfigLines([
        "; preserve this non-hotstring comment",
        "[Config]",
        "SchemaVersion=1",
        "",
        "[Features]",
        "GlobalHjklArrows=false",
        "",
        "[Unknown]",
        "Keep=yes",
        "",
        "[Hotstring.builtin-fzg]",
        "Enabled=true",
        "Name=FZG",
        "Trigger=;fzg",
        "Text=放射性摄取增高，SUVmax约（见图）",
        "Mode=red-left4",
        "",
        "[Hotstring.builtin-cmx]",
        "Enabled=true",
        "Name=CMX",
        "Trigger=;cmx",
        "Text=cm×cm",
        "Mode=text",
        "",
        "[Hotstring.custom-left]",
        "Enabled=false",
        "Name=Custom",
        "Trigger=;custom",
        "Text=内容（见图）",
        "Mode=red-left4",
        "",
        "[Hotstring.custom-black-marker]",
        "Enabled=true",
        "Name=Black marker",
        "Trigger=;black-marker",
        "Text=普通文字（见图）",
        "Mode=text"
    ]) "`r`n"
}

UnsafeSchema1Fixture() {
    return JoinConfigLines([
        "[Config]",
        "SchemaVersion=1",
        "",
        "[Hotstring.custom-unsafe]",
        "Enabled=true",
        "Name=Unsafe",
        "Trigger=;unsafe",
        "Text=content",
        "Mode=unknown-mode"
    ]) "`r`n"
}

InterimSchema2Fixture() {
    return JoinConfigLines([
        "[Config]",
        "SchemaVersion=2",
        "",
        "[Features]",
        "GlobalHjklArrows=false",
        "",
        "[Hotstring.builtin-red]",
        "Enabled=true",
        "Name=Red",
        "Trigger=;red",
        "Text=（见图）",
        "",
        "[Hotstring.builtin-fzg]",
        "Enabled=true",
        "Name=FZG",
        "Trigger=;fzg",
        "Text=放射性摄取增高，SUVmax约为{{cursor}}（见图）",
        "",
        "[Hotstring.builtin-fwj]",
        "Enabled=true",
        "Name=FWJ",
        "Trigger=;fwj",
        "Text=放射性摄取未见明显增高（见图）",
        "",
        "[Hotstring.builtin-fjd]",
        "Enabled=true",
        "Name=FJD",
        "Trigger=;fjd",
        "Text=用户已修改（见图）",
        "",
        "[Hotstring.custom-note]",
        "Enabled=true",
        "Name=Custom",
        "Trigger=;custom",
        "Text=自定义内容（见图）"
    ]) "`r`n"
}

AssertTemplateTest(condition, message) {
    if !condition
        throw Error(message)
}
