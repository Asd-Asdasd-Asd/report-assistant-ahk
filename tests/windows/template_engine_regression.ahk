#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\app_config.ahk
#Include ..\..\src\feature_model.ahk
#Include ..\..\src\visual_feedback.ahk
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
    TestAdditiveCmaBuiltinReconciliation()
    TestInterimSchema2BuiltinDefaultUpgrade()
    TestUnsafeMigrationLeavesOriginalUntouched()
    MsgBox "Template engine regression passed.", "MedEx test", "Iconi"
    ExitApp 0
}

TestAdditiveCmaBuiltinReconciliation() {
    TestMissingCmaBuiltinIsAdded()
    TestEquivalentCustomCmaIsPreserved()
    TestConflictingCustomCmaGetsDisabledFallback()
}

TestMissingCmaBuiltinIsAdded() {
    TestCmaReconciliationFixture(
        "",
        (configPath) => (
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.builtin-cma",
                    "Enabled",
                    ""
                ) = "true",
                "missing cma builtin was not enabled"
            ),
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.builtin-cma",
                    "Trigger",
                    ""
                ) = ";cma",
                "missing cma builtin did not use default trigger"
            )
        )
    )
}

TestEquivalentCustomCmaIsPreserved() {
    customSection := JoinConfigLines([
        "",
        "[Hotstring.custom-cma]",
        "Enabled=true",
        "Name=Custom CMA",
        "Trigger=;cma",
        "Text={{size}}"
    ])
    TestCmaReconciliationFixture(
        customSection,
        (configPath) => (
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.builtin-cma",
                    "Trigger",
                    "MISSING"
                ) = "MISSING",
                "equivalent custom cma created a duplicate builtin"
            ),
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.custom-cma",
                    "Text",
                    ""
                ) = "{{size}}",
                "equivalent custom cma was modified"
            )
        )
    )
}

TestConflictingCustomCmaGetsDisabledFallback() {
    customSection := JoinConfigLines([
        "",
        "[Hotstring.custom-cma]",
        "Enabled=true",
        "Name=Custom CMA",
        "Trigger=;cma",
        "Text=用户内容"
    ])
    TestCmaReconciliationFixture(
        customSection,
        (configPath) => (
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.builtin-cma",
                    "Enabled",
                    ""
                ) = "false",
                "conflicting cma builtin was not disabled"
            ),
            AssertTemplateTest(
                IniRead(
                    configPath,
                    "Hotstring.builtin-cma",
                    "Trigger",
                    ""
                ) = ";cma-size",
                "conflicting cma builtin did not use fallback trigger"
            ),
            AssertTemplateTest(
                NormalizeReportHotstringEntriesResult(
                    LoadRawReportHotstringConfig(configPath)
                ).Ok,
                "conflicting cma reconciliation invalidated all templates"
            )
        )
    )
}

TestCmaReconciliationFixture(customText, assertionCallback) {
    testDirectory := A_Temp "\MedExCmaBuiltin-" A_TickCount
        . "-" Random(1000, 9999)
    DirCreate testDirectory
    configPath := testDirectory "\config.ini"
    try {
        baseText := JoinConfigLines([
            "[Config]",
            "SchemaVersion=2",
            "",
            "[Hotstring.custom-base]",
            "Enabled=true",
            "Name=Base",
            "Trigger=;base",
            "Text=基础"
        ])
        FileAppend(
            baseText (customText = "" ? "" : "`r`n" customText) "`r`n",
            configPath,
            "UTF-16"
        )
        AssertTemplateTest(
            ReconcileAdditiveReportHotstringBuiltins(configPath),
            "cma builtin reconciliation failed"
        )
        assertionCallback.Call(configPath)
    } finally {
        try DirDelete testDirectory, true
    }
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
            ) = "放射性摄取增高，SUVmax约为{{suvmax}}"
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
    suvFound := BuildReportTemplatePlan(
        "SUVmax{{suvmax}}{{red:（见图）}}",
        Map("suvmaxState", "FOUND", "suvmaxText", "3.2")
    )
    AssertTemplateTest(
        suvFound.Ok
            && suvFound.RenderedText = "SUVmax3.2（见图）"
            && suvFound.CaretLeftCount = 0
            && suvFound.RequiresColorReset,
        "FOUND SUVMax did not use the default end caret"
    )
    suvMissing := BuildReportTemplatePlan(
        "{{cursor}}SUVmax{{suvmax}}{{red:（见图）}}",
        Map("suvmaxState", "NOT_ANNOTATED", "suvmaxText", "")
    )
    AssertTemplateTest(
        suvMissing.Ok
            && suvMissing.RenderedText = "SUVmax（见图）"
            && suvMissing.CaretLeftCount = 4
            && !suvMissing.RequiresColorReset,
        "missing SUVMax did not force the manual-input anchor"
    )
    AssertTemplateTest(
        !BuildReportTemplatePlan("{{suvmax}}").Ok,
        "SUVMax template accepted a missing runtime result"
    )
    sizeFound := BuildReportTemplatePlan(
        "大小{{size}}{{red:（见图）}}",
        Map(
            "sizeState", "FOUND",
            "sizeText", "3.2cm×3.1cm×2.8cm"
        )
    )
    AssertTemplateTest(
        sizeFound.Ok
            && sizeFound.RenderedText
                = "大小3.2cm×3.1cm×2.8cm（见图）"
            && sizeFound.CaretLeftCount = 0
            && sizeFound.RequiresColorReset,
        "FOUND line axes did not use the default end caret"
    )
    for state in ["NOT_ANNOTATED", "AUTOMATION_FAILED"] {
        sizeMissing := BuildReportTemplatePlan(
            "{{cursor}}大小{{size}}{{red:（见图）}}",
            Map("sizeState", state, "sizeText", "")
        )
        AssertTemplateTest(
            sizeMissing.Ok
                && sizeMissing.RenderedText = "大小（见图）"
                && sizeMissing.CaretLeftCount = 4
                && !sizeMissing.RequiresColorReset,
            state " line axes did not force the manual-input anchor"
        )
    }
    AssertTemplateTest(
        !BuildReportTemplatePlan("{{size}}").Ok,
        "line-axes template accepted a missing runtime result"
    )
    AssertTemplateTest(
        !ValidateReportTemplate("{{size}}{{size}}").Ok,
        "duplicate line-axes placeholders were accepted"
    )
    AssertTemplateTest(
        !ValidateReportTemplate("{{suvmax}}{{size}}").Ok,
        "mixed measurement placeholders were accepted"
    )
    for invalidSize in [
        "0.0cm",
        "1.0cm×2.0cm",
        "1.0cm×0.0cm",
        "1.0cm×2.0cm×3.0cm×4.0cm"
    ] {
        AssertTemplateTest(
            !BuildReportTemplatePlan(
                "{{size}}",
                Map("sizeState", "FOUND", "sizeText", invalidSize)
            ).Ok,
            "invalid line-axes runtime value was accepted"
        )
    }

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
