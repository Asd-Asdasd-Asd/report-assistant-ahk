class ReportAssistantSettingsDefaults {
    static WindowTitle := "MedEx Report Assistant 设置"

    static TemplateElementDefinitions() {
        return [
            {
                Label: "光标位置",
                Token: ReportHotstringDefaults.CursorPlaceholder
            },
            {
                Label: "当前日期",
                Token: ReportHotstringDefaults.DatePlaceholder
            },
            {
                Label: "自动获取 SUVMax",
                Token: ReportHotstringDefaults.SuvMaxPlaceholder
            },
            {
                Label: "自动获取尺寸",
                Token: ReportHotstringDefaults.SizePlaceholder
            },
            {
                Label: "红色“（见图）”",
                Token: ReportHotstringDefaults.RedFigureReferencePlaceholder
            }
        ]
    }

    static TemplateElementLabels(definitions := 0) {
        if Type(definitions) != "Array"
            definitions := this.TemplateElementDefinitions()
        labels := []
        for definition in definitions
            labels.Push(definition.Label)
        return labels
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
        this.FeatureSettings := LoadFeatureSettings(this.ConfigPath)
        this.OriginalSections := Map()
        for entry in this.Entries
            this.OriginalSections[StrLower(entry.Section)] := true
        this.DeletedSections := []
        this.DeletedSectionKeys := Map()
        this.ModifiedSectionKeys := Map()
        this.SelectedSection := ""
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
            ["状态", "模板名称", "触发词", ""]
        )
        this.TemplateList.ModifyCol(1, 70)
        this.TemplateList.ModifyCol(2, 420)
        this.TemplateList.ModifyCol(3, 350)
        this.TemplateList.ModifyCol(4, 0)
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

        this.TemplateElementDefinitions :=
            ReportAssistantSettingsDefaults.TemplateElementDefinitions()
        this.Window.Add("Text", "x28 y404 w88", "插入模板元素")
        this.TemplateElementInput := this.Window.Add(
            "DropDownList", "x122 y398 w220",
            ReportAssistantSettingsDefaults.TemplateElementLabels(
                this.TemplateElementDefinitions
            )
        )
        this.InsertTemplateElementButton := this.Window.Add(
            "Button", "x350 y398 w68 h26", "插入"
        )
        this.InsertTemplateElementButton.OnEvent(
            "Click", this.OnInsertTemplateElement.Bind(this)
        )
        this.Window.Add(
            "Text", "x438 y404 w434",
            "红色标记必须是模板最后一个元素。"
        )
        this.Window.Add("Text", "x28 y440 w68", "模板文字")
        this.TextInput := this.Window.Add(
            "Edit", "x28 y462 w844 h94 +Multi +VScroll"
        )
        this.TextInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Tabs.UseTab(2)
        this.Window.Add(
            "Text", "x40 y64 w820 h38",
            "快速标图必须含修饰键；单个字母/数字无修饰键仅在 Viewer 前台生效。"
        )
        this.Window.Add("Text", "x72 y126 w170", "功能")
        this.Window.Add("Text", "x276 y126 w90", "状态")
        this.Window.Add("Text", "x402 y126 w220", "快捷键")
        this.Window.Add("Text", "x648 y126 w70", "Win")

        this.Window.Add("Text", "x72 y174 w170", "快速标图")
        this.ReportImageCaptionEnabledInput := this.Window.Add(
            "CheckBox", "x276 y166 w90 h26", "启用"
        )
        this.ReportImageCaptionChordInput := this.Window.Add(
            "Hotkey", "x402 y166 w220 h26"
        )
        this.ReportImageCaptionWinInput := this.Window.Add(
            "CheckBox", "x648 y166 w70 h26", "使用"
        )

        this.Window.Add("Text", "x72 y222 w170", "箭头")
        this.ViewerArrowEnabledInput := this.Window.Add(
            "CheckBox", "x276 y214 w90 h26", "启用"
        )
        this.ViewerArrowChordInput := this.Window.Add(
            "Hotkey", "x402 y214 w220 h26"
        )
        this.ViewerArrowWinInput := this.Window.Add(
            "CheckBox", "x648 y214 w70 h26", "使用"
        )

        this.Window.Add("Text", "x72 y270 w170", "长度测量")
        this.ViewerLengthEnabledInput := this.Window.Add(
            "CheckBox", "x276 y262 w90 h26", "启用"
        )
        this.ViewerLengthChordInput := this.Window.Add(
            "Hotkey", "x402 y262 w220 h26"
        )
        this.ViewerLengthWinInput := this.Window.Add(
            "CheckBox", "x648 y262 w70 h26", "使用"
        )

        this.Window.Add("Text", "x72 y318 w170", "3D SUV测量")
        this.ViewerSuv3DEnabledInput := this.Window.Add(
            "CheckBox", "x276 y310 w90 h26", "启用"
        )
        this.ViewerSuv3DChordInput := this.Window.Add(
            "Hotkey", "x402 y310 w220 h26"
        )
        this.ViewerSuv3DWinInput := this.Window.Add(
            "CheckBox", "x648 y310 w70 h26", "使用"
        )

        this.Window.Add("Text", "x72 y366 w170", "截图（发送 F12）")
        this.ViewerCaptureEnabledInput := this.Window.Add(
            "CheckBox", "x276 y358 w90 h26", "启用"
        )
        this.ViewerCaptureChordInput := this.Window.Add(
            "Hotkey", "x402 y358 w220 h26"
        )
        this.ViewerCaptureWinInput := this.Window.Add(
            "CheckBox", "x648 y358 w70 h26", "使用"
        )

        this.Window.Add("Text", "x72 y414 w170", "清除全部标注")
        this.ViewerClearEnabledInput := this.Window.Add(
            "CheckBox", "x276 y406 w90 h26", "启用"
        )
        this.ViewerClearChordInput := this.Window.Add(
            "Hotkey", "x402 y406 w220 h26"
        )
        this.ViewerClearWinInput := this.Window.Add(
            "CheckBox", "x648 y406 w70 h26", "使用"
        )
        for control in [
            this.ReportImageCaptionEnabledInput,
            this.ViewerArrowEnabledInput,
            this.ViewerLengthEnabledInput,
            this.ViewerSuv3DEnabledInput,
            this.ViewerCaptureEnabledInput,
            this.ViewerClearEnabledInput,
            this.ReportImageCaptionWinInput,
            this.ViewerArrowWinInput,
            this.ViewerLengthWinInput,
            this.ViewerSuv3DWinInput,
            this.ViewerCaptureWinInput,
            this.ViewerClearWinInput
        ] {
            control.OnEvent("Click", this.OnViewerHotkeyChanged.Bind(this))
        }
        for control in [
            this.ReportImageCaptionChordInput,
            this.ViewerArrowChordInput,
            this.ViewerLengthChordInput,
            this.ViewerSuv3DChordInput,
            this.ViewerCaptureChordInput,
            this.ViewerClearChordInput
        ] {
            control.OnEvent("Change", this.OnViewerHotkeyChanged.Bind(this))
        }
        this.LoadFeatureHotkeyControls()

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
            this.SelectSection(this.Entries[1].Section)
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
                    entry.Section
                )
            }
        } finally {
            this.LoadingControls := false
        }
    }

    SelectSection(section) {
        entryIndex := this.FindEntryIndexBySection(section)
        row := this.FindListRowBySection(section)
        if entryIndex = 0 || row = 0 {
            this.SelectedSection := ""
            this.ClearEditor()
            return
        }
        this.LoadingControls := true
        try {
            this.TemplateList.Modify(0, "-Select")
            this.TemplateList.Modify(row, "Select Focus Vis")
            this.SelectedSection := this.Entries[entryIndex].Section
            this.LoadEditor(this.Entries[entryIndex])
        } finally {
            this.LoadingControls := false
        }
    }

    LoadEditor(entry) {
        this.EnabledInput.Value := entry.Enabled ? 1 : 0
        this.NameInput.Text := entry.Name
        this.TriggerInput.Text := entry.Trigger
        this.TextInput.Text := ReportHotstringTextForMultilineEdit(entry.Text)
        this.DeleteButton.Enabled := !entry.IsBuiltin
    }

    ClearEditor() {
        this.LoadingControls := true
        try {
            this.EnabledInput.Value := 0
            this.NameInput.Text := ""
            this.TriggerInput.Text := ""
            this.TextInput.Text := ""
            this.DeleteButton.Enabled := false
        } finally {
            this.LoadingControls := false
        }
    }

    StoreEditorToEntry() {
        entryIndex := this.FindEntryIndexBySection(this.SelectedSection)
        if entryIndex = 0
            return
        entry := this.Entries[entryIndex]
        entry.Enabled := this.EnabledInput.Value = 1
        entry.Name := this.NameInput.Text
        entry.Trigger := this.TriggerInput.Text
        entry.Text := ReportHotstringTextFromMultilineEdit(this.TextInput.Text)
        row := this.FindListRowBySection(entry.Section)
        if row > 0 {
            this.TemplateList.Modify(
                row,
                ,
                entry.Enabled ? "启用" : "停用",
                entry.Name,
                entry.Trigger,
                entry.Section
            )
        }
    }

    OnEditorChanged(*) {
        if this.LoadingControls
            return
        this.StoreEditorToEntry()
        if this.SelectedSection != ""
            this.ModifiedSectionKeys[StrLower(this.SelectedSection)] := true
        this.Dirty := true
    }

    LoadFeatureHotkeyControls() {
        this.LoadingControls := true
        try {
            this.ReportImageCaptionEnabledInput.Value :=
                this.FeatureSettings.ReportImageCaptionEnabled ? 1 : 0
            this.ReportImageCaptionChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ReportImageCaptionChord
                )
            this.ReportImageCaptionWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ReportImageCaptionChord
                ) ? 1 : 0
            this.ViewerArrowEnabledInput.Value :=
                this.FeatureSettings.ViewerArrowEnabled ? 1 : 0
            this.ViewerArrowChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ViewerArrowChord
                )
            this.ViewerArrowWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ViewerArrowChord
                ) ? 1 : 0
            this.ViewerLengthEnabledInput.Value :=
                this.FeatureSettings.ViewerLengthEnabled ? 1 : 0
            this.ViewerLengthChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ViewerLengthChord
                )
            this.ViewerLengthWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ViewerLengthChord
                ) ? 1 : 0
            this.ViewerSuv3DEnabledInput.Value :=
                this.FeatureSettings.ViewerSuv3DEnabled ? 1 : 0
            this.ViewerSuv3DChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ViewerSuv3DChord
                )
            this.ViewerSuv3DWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ViewerSuv3DChord
                ) ? 1 : 0
            this.ViewerCaptureEnabledInput.Value :=
                this.FeatureSettings.ViewerCaptureEnabled ? 1 : 0
            this.ViewerCaptureChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ViewerCaptureChord
                )
            this.ViewerCaptureWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ViewerCaptureChord
                ) ? 1 : 0
            this.ViewerClearEnabledInput.Value :=
                this.FeatureSettings.ViewerClearEnabled ? 1 : 0
            this.ViewerClearChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.FeatureSettings.ViewerClearChord
                )
            this.ViewerClearWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.FeatureSettings.ViewerClearChord
                ) ? 1 : 0
        } finally {
            this.LoadingControls := false
        }
    }

    StoreFeatureHotkeyControls() {
        this.FeatureSettings := FeatureSettings(
            this.FeatureSettings.GlobalHjklArrows,
            this.ReportImageCaptionEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ReportImageCaptionChordInput.Value,
                this.ReportImageCaptionWinInput.Value = 1
            ),
            this.ViewerArrowEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ViewerArrowChordInput.Value,
                this.ViewerArrowWinInput.Value = 1
            ),
            this.ViewerLengthEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ViewerLengthChordInput.Value,
                this.ViewerLengthWinInput.Value = 1
            ),
            this.ViewerSuv3DEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ViewerSuv3DChordInput.Value,
                this.ViewerSuv3DWinInput.Value = 1
            ),
            this.ViewerCaptureEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ViewerCaptureChordInput.Value,
                this.ViewerCaptureWinInput.Value = 1
            ),
            this.ViewerClearEnabledInput.Value = 1,
            MergeViewerHotkeyChord(
                this.ViewerClearChordInput.Value,
                this.ViewerClearWinInput.Value = 1
            )
        )
    }

    OnViewerHotkeyChanged(*) {
        if this.LoadingControls
            return
        this.StoreFeatureHotkeyControls()
        this.Dirty := true
    }

    OnInsertTemplateElement(*) {
        entryIndex := this.FindEntryIndexBySection(this.SelectedSection)
        definitionIndex := this.TemplateElementInput.Value
        if entryIndex = 0 || definitionIndex < 1
            || definitionIndex > this.TemplateElementDefinitions.Length {
            this.TextInput.Focus()
            return
        }

        definition := this.TemplateElementDefinitions[definitionIndex]
        ReplaceReportTemplateEditSelection(
            this.TextInput,
            definition.Token
        )
        this.TemplateElementInput.Choose(0)
        this.StoreEditorToEntry()
        this.ModifiedSectionKeys[StrLower(this.SelectedSection)] := true
        this.Dirty := true
        this.TextInput.Focus()
    }

    OnTemplateSelected(control, row, selected) {
        if this.LoadingControls || !selected
            return
        section := this.SectionForListRow(row)
        if section = ""
            return
        this.StoreEditorToEntry()
        entryIndex := this.FindEntryIndexBySection(section)
        if entryIndex = 0
            return
        this.SelectedSection := this.Entries[entryIndex].Section
        this.LoadingControls := true
        try {
            this.LoadEditor(this.Entries[entryIndex])
        } finally {
            this.LoadingControls := false
        }
    }

    OnAddTemplate(*) {
        this.StoreEditorToEntry()
        entry := CreateEditableReportHotstring(
            this.Entries, this.DeletedSectionKeys
        )
        this.Entries.Push(entry)
        this.RefreshTemplateList()
        this.Dirty := true
        this.SelectSection(entry.Section)
        this.TriggerInput.Focus()
    }

    OnDeleteTemplate(*) {
        entryIndex := this.FindEntryIndexBySection(this.SelectedSection)
        if entryIndex = 0
            return
        entry := this.Entries[entryIndex]
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
        this.Entries.RemoveAt(entryIndex)
        this.Dirty := true
        this.RefreshTemplateList()
        if this.Entries.Length = 0 {
            this.SelectedSection := ""
            this.ClearEditor()
            return
        }
        nextIndex := Min(entryIndex, this.Entries.Length)
        this.SelectSection(this.Entries[nextIndex].Section)
    }

    OnSave(*) {
        this.StoreEditorToEntry()
        this.StoreFeatureHotkeyControls()
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
        featureValidation := ValidateFeatureHotkeySettings(
            this.FeatureSettings
        )
        if !featureValidation.Ok {
            this.Tabs.Choose(2)
            this.FocusFeatureHotkeyValidationError(
                featureValidation.Field
            )
            MsgBox(
                featureValidation.Message,
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
            this.ModifiedSectionKeys,
            this.ConfigPath,
            this.FeatureSettings
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

    FocusFeatureHotkeyValidationError(field) {
        if field = "ReportImageCaptionChord"
            this.ReportImageCaptionChordInput.Focus()
        else if field = "ViewerArrowChord"
            this.ViewerArrowChordInput.Focus()
        else if field = "ViewerLengthChord"
            this.ViewerLengthChordInput.Focus()
        else if field = "ViewerSuv3DChord"
            this.ViewerSuv3DChordInput.Focus()
        else if field = "ViewerCaptureChord"
            this.ViewerCaptureChordInput.Focus()
        else if field = "ViewerClearChord"
            this.ViewerClearChordInput.Focus()
    }

    FocusValidationError(validation) {
        if validation.Section != ""
            this.SelectSection(validation.Section)
        if validation.Field = "Name"
            this.NameInput.Focus()
        else if validation.Field = "Trigger"
            this.TriggerInput.Focus()
        else if validation.Field = "Text"
            this.TextInput.Focus()
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

    FindEntryIndexBySection(section) {
        sectionKey := StrLower(String(section))
        if sectionKey = ""
            return 0
        for index, entry in this.Entries {
            if StrLower(entry.Section) = sectionKey
                return index
        }
        return 0
    }

    SectionForListRow(row) {
        if row < 1 || row > this.TemplateList.GetCount()
            return ""
        return this.TemplateList.GetText(row, 4)
    }

    FindListRowBySection(section) {
        sectionKey := StrLower(String(section))
        if sectionKey = ""
            return 0
        Loop this.TemplateList.GetCount() {
            if StrLower(this.SectionForListRow(A_Index)) = sectionKey
                return A_Index
        }
        return 0
    }
}

ReplaceReportTemplateEditSelection(editControl, replacementText) {
    if !IsObject(editControl)
        return false
    replacement := String(replacementText)
    DllCall(
        "SendMessageW",
        "Ptr", editControl.Hwnd,
        "UInt", 0x00C2,
        "Ptr", 1,
        "Ptr", StrPtr(replacement),
        "Ptr"
    )
    return true
}
