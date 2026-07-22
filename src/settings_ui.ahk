class ReportAssistantSettingsDefaults {
    static WindowTitle := "MedEx Report Assistant 设置"

    static ModeLabels() {
        return [
            "普通文字",
            "红色标记并恢复黑色",
            "红色标记并调整光标"
        ]
    }

    static ModeValues() {
        return [
            ReportHotstringMode.TEXT,
            ReportHotstringMode.RED_RESET,
            ReportHotstringMode.RED_LEFT4
        ]
    }
}

ShowReportAssistantSettings(*) {
    ReportAssistantSettingsWindow.ShowSettings()
}

class ReportAssistantSettingsWindow {
    static Current := 0

    static ShowSettings() {
        if IsObject(this.Current) {
            this.Current.Activate()
            return
        }

        loadResult := LoadEditableReportHotstringConfig()
        if !loadResult.Ok {
            MsgBox(
                loadResult.Message,
                ReportAssistantSettingsDefaults.WindowTitle,
                "Icon!"
            )
            return
        }

        this.Current := ReportAssistantSettingsWindow(loadResult)
        this.Current.Activate()
    }

    __New(loadResult) {
        this.ConfigPath := loadResult.ConfigPath
        this.OriginalText := loadResult.OriginalText
        this.Entries := loadResult.Entries
        this.OriginalSections := Map()
        for entry in this.Entries
            this.OriginalSections[StrLower(entry.Section)] := true
        this.DeletedSections := []
        this.DeletedSectionKeys := Map()
        this.SelectedRow := 0
        this.Dirty := false
        this.LoadingControls := false
        this.Closing := false

        this.Window := Gui(, ReportAssistantSettingsDefaults.WindowTitle)
        this.Window.SetFont("s9", "Segoe UI")
        this.Window.OnEvent("Close", this.OnClose.Bind(this))
        this.Window.OnEvent("Escape", this.OnClose.Bind(this))

        this.Tabs := this.Window.Add(
            "Tab3", "x12 y12 w876 h570",
            ["报告模板", "快捷键", "其他"]
        )

        this.Tabs.UseTab(1)
        this.TemplateList := this.Window.Add(
            "ListView", "x28 y52 w844 h220 -Multi",
            ["状态", "模板名称", "触发词", "模式"]
        )
        this.TemplateList.ModifyCol(1, 70)
        this.TemplateList.ModifyCol(2, 230)
        this.TemplateList.ModifyCol(3, 160)
        this.TemplateList.ModifyCol(4, 350)
        this.TemplateList.OnEvent(
            "ItemSelect", this.OnTemplateSelected.Bind(this)
        )

        this.AddButton := this.Window.Add(
            "Button", "x28 y282 w92 h28", "添加模板"
        )
        this.AddButton.OnEvent("Click", this.OnAddTemplate.Bind(this))
        this.DeleteButton := this.Window.Add(
            "Button", "x128 y282 w92 h28", "删除模板"
        )
        this.DeleteButton.OnEvent("Click", this.OnDeleteTemplate.Bind(this))

        this.EnabledInput := this.Window.Add(
            "CheckBox", "x28 y326 w120", "启用此模板"
        )
        this.EnabledInput.OnEvent("Click", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x28 y364 w68", "模板名称")
        this.NameInput := this.Window.Add(
            "Edit", "x102 y360 w330 h24"
        )
        this.NameInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x456 y364 w54", "触发词")
        this.TriggerInput := this.Window.Add(
            "Edit", "x516 y360 w356 h24"
        )
        this.TriggerInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x28 y402 w68", "模板模式")
        this.ModeInput := this.Window.Add(
            "DropDownList", "x102 y398 w330",
            ReportAssistantSettingsDefaults.ModeLabels()
        )
        this.ModeInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x28 y440 w68", "模板文字")
        this.TextInput := this.Window.Add(
            "Edit", "x28 y462 w844 h94 +Multi +VScroll"
        )
        this.TextInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Tabs.UseTab(2)
        this.Window.Add(
            "Text", "x40 y70 w820 h30 Center", "快捷键设置将在后续版本开放。"
        )

        this.Tabs.UseTab(3)
        this.Window.Add(
            "Text", "x40 y70 w820 h30 Center", "其他设置将在后续版本开放。"
        )

        this.Tabs.UseTab()
        this.SaveButton := this.Window.Add(
            "Button", "x688 y598 w90 h30 Default", "保存"
        )
        this.SaveButton.OnEvent("Click", this.OnSave.Bind(this))
        this.CancelButton := this.Window.Add(
            "Button", "x786 y598 w90 h30", "取消"
        )
        this.CancelButton.OnEvent("Click", this.OnClose.Bind(this))

        this.RefreshTemplateList()
        if this.Entries.Length > 0
            this.SelectRow(1)
    }

    Activate() {
        this.Window.Show("w900 h640")
        try WinActivate("ahk_id " this.Window.Hwnd)
    }

    RefreshTemplateList() {
        this.LoadingControls := true
        try {
            this.TemplateList.Delete()
            for entry in this.Entries {
                this.TemplateList.Add(
                    ,
                    entry.Enabled ? "启用" : "停用",
                    entry.Name,
                    entry.Trigger,
                    ReportAssistantSettingsModeLabel(entry.Mode)
                )
            }
        } finally {
            this.LoadingControls := false
        }
    }

    SelectRow(row) {
        if row < 1 || row > this.Entries.Length {
            this.SelectedRow := 0
            this.ClearEditor()
            return
        }
        this.LoadingControls := true
        try {
            this.TemplateList.Modify(0, "-Select")
            this.TemplateList.Modify(row, "Select Focus Vis")
            this.SelectedRow := row
            this.LoadEditor(this.Entries[row])
        } finally {
            this.LoadingControls := false
        }
    }

    LoadEditor(entry) {
        this.EnabledInput.Value := entry.Enabled ? 1 : 0
        this.NameInput.Text := entry.Name
        this.TriggerInput.Text := entry.Trigger
        this.TextInput.Text := entry.Text
        this.ModeInput.Choose(ReportAssistantSettingsModeIndex(entry.Mode))
        this.DeleteButton.Enabled := !entry.IsBuiltin
    }

    ClearEditor() {
        this.LoadingControls := true
        try {
            this.EnabledInput.Value := 0
            this.NameInput.Text := ""
            this.TriggerInput.Text := ""
            this.TextInput.Text := ""
            this.ModeInput.Choose(0)
            this.DeleteButton.Enabled := false
        } finally {
            this.LoadingControls := false
        }
    }

    StoreEditorToEntry() {
        if this.SelectedRow < 1 || this.SelectedRow > this.Entries.Length
            return
        entry := this.Entries[this.SelectedRow]
        entry.Enabled := this.EnabledInput.Value = 1
        entry.Name := this.NameInput.Text
        entry.Trigger := this.TriggerInput.Text
        entry.Text := NormalizeEditableReportHotstringText(this.TextInput.Text)
        entry.Mode := ReportAssistantSettingsModeValue(this.ModeInput.Value)
        this.TemplateList.Modify(
            this.SelectedRow,
            ,
            entry.Enabled ? "启用" : "停用",
            entry.Name,
            entry.Trigger,
            ReportAssistantSettingsModeLabel(entry.Mode)
        )
    }

    OnEditorChanged(*) {
        if this.LoadingControls
            return
        this.StoreEditorToEntry()
        this.Dirty := true
    }

    OnTemplateSelected(control, row, selected) {
        if this.LoadingControls || !selected
            return
        this.StoreEditorToEntry()
        this.SelectedRow := row
        this.LoadingControls := true
        try {
            this.LoadEditor(this.Entries[row])
        } finally {
            this.LoadingControls := false
        }
    }

    OnAddTemplate(*) {
        this.StoreEditorToEntry()
        this.Entries.Push(CreateEditableReportHotstring(
            this.Entries, this.DeletedSectionKeys
        ))
        row := this.TemplateList.Add(, "启用", "新的模板", "", "普通文字")
        this.Dirty := true
        this.SelectRow(row)
        this.TriggerInput.Focus()
    }

    OnDeleteTemplate(*) {
        if this.SelectedRow < 1 || this.SelectedRow > this.Entries.Length
            return
        entry := this.Entries[this.SelectedRow]
        if entry.IsBuiltin {
            MsgBox(
                "内置模板不能删除。如暂时不用，可以取消启用。",
                ReportAssistantSettingsDefaults.WindowTitle,
                "Iconi"
            )
            return
        }
        answer := MsgBox(
            "确定删除模板“" entry.Name "”吗？",
            ReportAssistantSettingsDefaults.WindowTitle,
            "YesNo Icon! Default2"
        )
        if answer != "Yes"
            return

        sectionKey := StrLower(entry.Section)
        if this.OriginalSections.Has(sectionKey)
            && !this.DeletedSectionKeys.Has(sectionKey) {
            this.DeletedSections.Push(entry.Section)
            this.DeletedSectionKeys[sectionKey] := true
        }
        deletedRow := this.SelectedRow
        this.LoadingControls := true
        try {
            this.Entries.RemoveAt(deletedRow)
            this.TemplateList.Delete(deletedRow)
        } finally {
            this.LoadingControls := false
        }
        this.Dirty := true
        if this.Entries.Length = 0 {
            this.SelectedRow := 0
            this.ClearEditor()
            return
        }
        this.SelectRow(Min(deletedRow, this.Entries.Length))
    }

    OnSave(*) {
        this.StoreEditorToEntry()
        validation := ValidateEditableReportHotstringEntries(this.Entries)
        if !validation.Ok {
            if validation.Row > 0
                this.FocusValidationError(validation)
            MsgBox(
                validation.Message,
                ReportAssistantSettingsDefaults.WindowTitle,
                "Icon!"
            )
            return
        }

        if !this.Dirty {
            this.DestroyWindow()
            return
        }

        saveResult := SaveEditableReportHotstringConfig(
            this.Entries,
            this.DeletedSections,
            this.OriginalText,
            this.ConfigPath
        )
        if !saveResult.Ok {
            MsgBox(
                saveResult.Message,
                ReportAssistantSettingsDefaults.WindowTitle,
                "Icon!"
            )
            return
        }

        this.OriginalText := saveResult.SavedText
        this.Dirty := false
        try Reload()
        catch as err {
            OutputDebug "Report Assistant settings reload failed: " err.Message
            MsgBox(
                "配置已保存，但程序未能重新启动。`n" .
                "请通过系统托盘选择“重新加载配置”后重试。",
                ReportAssistantSettingsDefaults.WindowTitle,
                "Icon!"
            )
        }
    }

    FocusValidationError(validation) {
        this.SelectRow(validation.Row)
        if validation.Field = "Name"
            this.NameInput.Focus()
        else if validation.Field = "Trigger"
            this.TriggerInput.Focus()
        else if validation.Field = "Mode"
            this.ModeInput.Focus()
    }

    OnClose(*) {
        if this.Closing
            return true
        if this.Dirty {
            answer := MsgBox(
                "设置尚未保存，确定放弃修改吗？",
                ReportAssistantSettingsDefaults.WindowTitle,
                "YesNo Icon! Default2"
            )
            if answer != "Yes"
                return true
        }
        this.DestroyWindow()
        return true
    }

    DestroyWindow() {
        this.Closing := true
        this.Window.Destroy()
        ReportAssistantSettingsWindow.Current := 0
    }
}

ReportAssistantSettingsModeIndex(mode) {
    mode := StrLower(Trim(mode, " `t`r`n"))
    for index, value in ReportAssistantSettingsDefaults.ModeValues() {
        if mode = value
            return index
    }
    return 0
}

ReportAssistantSettingsModeValue(index) {
    values := ReportAssistantSettingsDefaults.ModeValues()
    if index < 1 || index > values.Length
        return ""
    return values[index]
}

ReportAssistantSettingsModeLabel(mode) {
    index := ReportAssistantSettingsModeIndex(mode)
    labels := ReportAssistantSettingsDefaults.ModeLabels()
    return index > 0 ? labels[index] : "未选择"
}
