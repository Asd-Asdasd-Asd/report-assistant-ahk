#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\app_metadata.ahk
#Include ..\..\src\app_config.ahk
#Include ..\..\src\feature_model.ahk
#Include ..\..\src\hotstring_model.ahk
#Include ..\..\src\hotstring_config.ahk
#Include ..\..\src\template_renderer.ahk
#Include ..\..\src\hotstring_normalization.ahk
#Include ..\..\src\config_reconciliation.ahk
#Include ..\..\src\hotstring_config_migration.ahk
#Include ..\..\src\hotstring_config_editor.ahk
#Include ..\..\src\settings_ui.ahk

RunSettingsUiRegression()

RunSettingsUiRegression() {
    TestReportHotstringTextCodec()
    TestSettingsListSectionIdentity()
    TestSettingsTemplateElementInsertion()
    TestSettingsDeletePersistence()
    MsgBox "Settings UI regression passed.", "MedEx test", "Iconi"
    ExitApp 0
}

TestReportHotstringTextCodec() {
    cases := [
        "single line",
        "line one`nline two",
        "line one`n`nline three",
        "trailing`n",
        "C:\MedEx\file",
        "literal \n value",
        "mixed \\ path`nnext"
    ]
    for original in cases {
        canonical := NormalizeReportHotstringTextNewlines(original)
        encoded := EncodeReportHotstringText(original)
        decoded := DecodeReportHotstringText(encoded)
        AssertSettingsTest(decoded = canonical, "codec round-trip failed")
        repeated := DecodeReportHotstringText(
            EncodeReportHotstringText(decoded)
        )
        AssertSettingsTest(repeated = canonical, "codec double-escaped")
        editValue := ReportHotstringTextForMultilineEdit(decoded)
        AssertSettingsTest(
            ReportHotstringTextFromMultilineEdit(editValue) = canonical,
            "Edit newline boundary failed"
        )
    }
    AssertSettingsTest(
        EncodeReportHotstringText("literal \n") = "literal \\n",
        "literal backslash-n encoding failed"
    )
}

TestSettingsListSectionIdentity() {
    loadResult := ReportHotstringEditorLoadResult(
        true,
        A_Temp "\unused-config.ini",
        "",
        SettingsTestEntries()
    )
    controller := ReportAssistantSettingsWindow(loadResult)
    try {
        for column in [1, 2, 3] {
            controller.TemplateList.ModifyCol(column, "Sort")
            AssertSettingsListRowsResolve(controller)
            controller.TemplateList.ModifyCol(column, "SortDesc")
            AssertSettingsListRowsResolve(controller)
        }
        multilineSection := "Hotstring.custom-alpha"
        controller.SelectSection(multilineSection)
        index := controller.FindEntryIndexBySection(multilineSection)
        controller.Entries[index].Text := "first`n`nlast`n"
        controller.LoadEditor(controller.Entries[index])
        AssertSettingsTest(
            ReportHotstringTextFromMultilineEdit(controller.TextInput.Text)
                = "first`n`nlast`n",
            "native Edit lost multiline text"
        )
    } finally {
        controller.DestroyWindow()
    }
}

AssertSettingsListRowsResolve(controller) {
    Loop controller.TemplateList.GetCount() {
        section := controller.SectionForListRow(A_Index)
        AssertSettingsTest(section != "", "ListView row lost Section")
        AssertSettingsTest(
            controller.FindEntryIndexBySection(section) > 0,
            "ListView row resolved to the wrong model"
        )
    }
}

TestSettingsTemplateElementInsertion() {
    loadResult := ReportHotstringEditorLoadResult(
        true,
        A_Temp "\unused-config.ini",
        "",
        SettingsTestEntries()
    )
    controller := ReportAssistantSettingsWindow(loadResult)
    try {
        controller.SelectSection("Hotstring.custom-alpha")
        controller.TextInput.Text := "before target after"
        SendMessage(0x00B1, 7, 13, controller.TextInput.Hwnd)

        controller.TemplateElementInput.Choose(1)
        controller.OnInsertTemplateElement()
        AssertSettingsTest(
            controller.TextInput.Text = "before {{cursor}} after",
            "placeholder did not replace the Edit selection"
        )
        selection := SettingsTestEditSelection(controller.TextInput)
        AssertSettingsTest(
            selection.start = 17 && selection.end = 17,
            "caret did not move after the inserted cursor token"
        )
        AssertSettingsTest(
            controller.Dirty
                && controller.ModifiedSectionKeys.Has(
                    "hotstring.custom-alpha"
                ),
            "placeholder insertion did not mark the model dirty"
        )

        SendMessage(0x00B1, 7, 17, controller.TextInput.Hwnd)
        controller.TemplateElementInput.Choose(2)
        controller.OnInsertTemplateElement()
        controller.TemplateElementInput.Choose(2)
        controller.OnInsertTemplateElement()
        AssertSettingsTest(
            controller.TextInput.Text = "before {{date}}{{date}} after",
            "the same dropdown item could not be inserted consecutively"
        )

        SendMessage(
            0x00B1,
            0,
            StrLen(controller.TextInput.Text),
            controller.TextInput.Hwnd
        )
        controller.TemplateElementInput.Choose(3)
        controller.OnInsertTemplateElement()
        AssertSettingsTest(
            controller.TextInput.Text = "{{red:（见图）}}",
            "red template element did not replace the Edit selection"
        )
        selection := SettingsTestEditSelection(controller.TextInput)
        AssertSettingsTest(
            selection.start = StrLen("{{red:（见图）}}")
                && selection.end = selection.start,
            "caret did not move after the red template element"
        )
        AssertSettingsTest(
            controller.Window.FocusedCtrl = controller.TextInput,
            "template editor focus was not restored"
        )
    } finally {
        controller.DestroyWindow()
    }
}

SettingsTestEditSelection(editControl) {
    startBuffer := Buffer(4, 0)
    endBuffer := Buffer(4, 0)
    SendMessage(
        0x00B0,
        startBuffer.Ptr,
        endBuffer.Ptr,
        editControl.Hwnd
    )
    return {
        start: NumGet(startBuffer, 0, "UInt"),
        end: NumGet(endBuffer, 0, "UInt")
    }
}

TestSettingsDeletePersistence() {
    testDirectory := A_Temp "\MedExSettingsRegression-" A_TickCount
    DirCreate testDirectory
    configPath := testDirectory "\config.ini"
    try {
        FileAppend SettingsTestConfigText(), configPath, "UTF-16"
        loaded := LoadEditableReportHotstringConfig(configPath)
        AssertSettingsTest(loaded.Ok, "test config did not load")

        retained := []
        deleted := []
        for entry in loaded.Entries {
            if StrLower(entry.Section) = "hotstring.custom-beta"
                deleted.Push(entry.Section)
            else
                retained.Push(entry)
        }
        AssertSettingsTest(deleted.Length = 1, "delete target was not found")
        saved := SaveEditableReportHotstringConfig(
            retained,
            deleted,
            loaded.OriginalText,
            Map(),
            configPath
        )
        AssertSettingsTest(saved.Ok, "transactional delete failed")

        reloaded := LoadEditableReportHotstringConfig(configPath)
        AssertSettingsTest(reloaded.Ok, "saved config did not reload")
        AssertSettingsTest(
            !EditableReportHotstringSectionExists(
                reloaded.Entries,
                "Hotstring.custom-beta"
            ),
            "deleted Section remained"
        )
        for expected in [
            "Hotstring.builtin-red",
            "Hotstring.custom-alpha",
            "Hotstring.custom-gamma"
        ] {
            AssertSettingsTest(
                EditableReportHotstringSectionExists(reloaded.Entries, expected),
                "unselected Section was removed"
            )
        }
    } finally {
        try DirDelete testDirectory, true
    }
}

SettingsTestEntries() {
    return [
        EditableReportHotstringEntry(
            "Hotstring.builtin-red",
            true,
            "Builtin",
            ";builtin",
            "{{red:（见图）}}",
            true
        ),
        EditableReportHotstringEntry(
            "Hotstring.custom-alpha",
            true,
            "Alpha",
            ";alpha",
            "alpha"
        ),
        EditableReportHotstringEntry(
            "Hotstring.custom-beta",
            false,
            "Beta",
            ";beta",
            "beta{{cursor}}tail"
        ),
        EditableReportHotstringEntry(
            "Hotstring.custom-gamma",
            true,
            "Gamma",
            ";gamma",
            "gamma{{date}}"
        )
    ]
}

SettingsTestConfigText() {
    lines := [
        "[Config]",
        "SchemaVersion=2",
        "",
        "[Features]",
        "GlobalHjklArrows=false"
    ]
    for entry in SettingsTestEntries() {
        lines.Push("")
        lines.Push("[" entry.Section "]")
        lines.Push("Enabled=" (entry.Enabled ? "true" : "false"))
        lines.Push("Name=" entry.Name)
        lines.Push("Trigger=" entry.Trigger)
        lines.Push("Text=" EncodeReportHotstringText(entry.Text))
    }
    return JoinConfigLines(lines) "`r`n"
}

AssertSettingsTest(condition, message) {
    if !condition
        throw Error(message)
}
