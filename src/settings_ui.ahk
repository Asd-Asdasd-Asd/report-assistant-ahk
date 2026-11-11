class ReportAssistantSettingsDefaults {
    static WindowTitle := "MedEx Report Assistant 设置"

    static HelpTopic(topic) {
        static topics := Map(
            "shortcut-rules", {Title: "快捷键设置", Lines: [
                "可使用 Ctrl、Alt、Shift，并可勾选右侧 Win。",
                "箭头、长度、3D SUV、清除可用单个字母或数字。",
                "无修饰单键仅在 Viewer 前台生效。",
                "快速标图必须包含修饰键；保存设置后重新加载。"]},
            "caption", {Title: "快速标图", Lines: [
                "先在报告中选中文字，再触发快捷键。",
                "文字写入图像描述后，切到下一张图。",
                "在图像窗口继续触发，可复用同一句文字。",
                "可以按住修饰键，每按一次主键标一张。",
                "保存入口校验失败会停止翻页，请检查当前图。"]},
            "viewer-tools", {Title: "Viewer 工具", Lines: [
                "在 MedEx 报告或 Viewer 前台选择测量工具。",
                "完整按下并松开快捷键，执行一次选择。",
                "无修饰字母或数字仅在 Viewer 前台生效。"]},
            "capture", {Title: "截图", Lines: [
                "仅在 Viewer 前台发送一次 F12。",
                "完整按下并松开快捷键后执行。",
                "白闪只表示按键已发送，不代表图片已保存。"]},
            "clear", {Title: "清除全部标注", Lines: [
                "清除当前目标图像里的全部标注。",
                "目标或菜单不明确时停止，不自动重复清除。",
                "不会撤销已经写入报告的内容。"]},
            "montage", {Title: "Montage 排版", Lines: [
                "Body、Head、Lung 使用各自已有预设。",
                "自动调整图注、窗宽、层厚、当前层和缩放。",
                "三种排版共用下方的布局位置。",
                "仅在 Viewer 前台执行，完成后请检查结果。"]},
            "montage-layout", {Title: "Montage 布局位置", Lines: [
                "填写 Viewer 排版面板中的行、列位置。",
                "默认第 4 行、第 4 列，与封面图设置独立。",
                "第 5 行可能被遮挡，修改后请用测试检查验证。"]},
            "cover", {Title: "封面图", Lines: [
                "Viewer 右下 MIP 保存为报告左图。",
                "左下冠状位融合图恢复默认层面后保存为右图。",
                "仅写入报告草稿，不提交、审核或发送报告。",
                "仅在 Viewer 前台执行，完成后请检查左右图。"]},
            "cover-layout", {Title: "封面图布局位置", Lines: [
                "默认第 2 行、第 3 列，与 Montage 设置独立。",
                "对应布局须为左下融合冠状位、右下 MIP 的四格。",
                "布局不符合时停止，修改后请在目标工作站验证。"]},
            "template-elements", {Title: "插入模板元素", Lines: [
                "元素会插入模板文字的当前光标位置。",
                "自动获取 SUVMax 与自动获取尺寸不能混用。",
                "红色“（见图）”必须放在模板最后。",
                "在列表中选择模板，内置模板不能删除。"]},
            "template-trigger", {Title: "触发词", Lines: [
                "输入完整触发词后展开模板，无需空格或回车。",
                "每条模板的触发词必须唯一且不能为空。",
                "仅在 MedEx 范围内生效。"]}
        )
        if !topics.Has(topic)
            throw ValueError("Unknown settings help topic")
        return topics[topic]
    }

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
        this.MontageSettings := LoadMxNMMontageSettings(this.ConfigPath)
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

        this.HelpButtons := []
        this.Window := Gui(, ReportAssistantSettingsDefaults.WindowTitle)
        this.Window.SetFont("s9", "Segoe UI")
        this.Window.OnEvent("Close", this.OnClose.Bind(this))
        this.Window.OnEvent("Escape", this.OnClose.Bind(this))

        this.Tabs := this.Window.Add(
            "Tab3", "x12 y12 w776 h592",
            ["报告模板", "快捷键"]
        )

        this.Tabs.UseTab(1)
        this.TemplateList := this.Window.Add(
            "ListView", "x28 y52 w744 h198 -Multi",
            ["状态", "模板名称", "触发词", ""]
        )
        this.TemplateList.ModifyCol(1, 60)
        this.TemplateList.ModifyCol(2, 330)
        this.TemplateList.ModifyCol(3, 310)
        this.TemplateList.ModifyCol(4, 0)
        this.TemplateList.OnEvent(
            "ItemSelect", this.OnTemplateSelected.Bind(this)
        )

        this.AddButton := this.Window.Add(
            "Button", "x28 y260 w92 h26", "添加模板"
        )
        this.AddButton.OnEvent("Click", this.OnAddTemplate.Bind(this))
        this.DeleteButton := this.Window.Add(
            "Button", "x128 y260 w92 h26", "删除模板"
        )
        this.DeleteButton.OnEvent("Click", this.OnDeleteTemplate.Bind(this))

        this.EnabledInput := this.Window.Add(
            "CheckBox", "x28 y300 w120", "启用此模板"
        )
        this.EnabledInput.OnEvent("Click", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x28 y340 w68", "模板名称")
        this.NameInput := this.Window.Add(
            "Edit", "x102 y336 w260 h24"
        )
        this.NameInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Window.Add("Text", "x380 y340 w54", "触发词")
        this.TriggerInput := this.Window.Add(
            "Edit", "x440 y336 w306 h24"
        )
        this.TriggerInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.TemplateElementDefinitions :=
            ReportAssistantSettingsDefaults.TemplateElementDefinitions()
        this.Window.Add("Text", "x28 y380 w68", "插入元素")
        this.TemplateElementInput := this.Window.Add(
            "DropDownList", "x122 y374 w200",
            ReportAssistantSettingsDefaults.TemplateElementLabels(
                this.TemplateElementDefinitions
            )
        )
        this.InsertTemplateElementButton := this.Window.Add(
            "Button", "x330 y374 w64 h26", "插入"
        )
        this.InsertTemplateElementButton.OnEvent(
            "Click", this.OnInsertTemplateElement.Bind(this)
        )
        this.AddHelpButton("template-elements", 98, 376)
        this.AddHelpButton("template-trigger", 752, 338)
        this.Window.Add("Text", "x28 y416 w68", "模板文字")
        this.TextInput := this.Window.Add(
            "Edit", "x28 y438 w744 h86 +Multi +VScroll"
        )
        this.TextInput.OnEvent("Change", this.OnEditorChanged.Bind(this))
        this.Window.Add("Text", "x28 y532 w250", "执行后复制到剪贴板（可选）")
        this.ClipboardTextInput := this.Window.Add(
            "Edit", "x28 y552 w744 h43 +Multi +VScroll +WantReturn"
        )
        this.ClipboardTextInput.OnEvent("Change", this.OnEditorChanged.Bind(this))

        this.Tabs.UseTab(2)
        this.Window.Add("Text", "x48 y56 w130", "功能")
        this.Window.Add("Text", "x230 y56 w70", "状态")
        this.Window.Add("Text", "x340 y56 w60", "按键")
        this.AddHelpButton("shortcut-rules", 406, 50)
        this.Window.Add("Text", "x560 y56 w60", "Win")
        this.Window.Add("Text", "x48 y92 w130", "快速标图")
        this.AddHelpButton("caption", 186, 89)
        this.ReportImageCaptionEnabledInput := this.Window.Add("CheckBox", "x230 y86 w70 h24", "启用")
        this.ReportImageCaptionChordInput := this.Window.Add("Hotkey", "x340 y86 w190 h24")
        this.ReportImageCaptionWinInput := this.Window.Add("CheckBox", "x560 y86 w60 h24", "使用")
        this.Window.Add("Text", "x48 y128 w130", "箭头")
        this.AddHelpButton("viewer-tools", 186, 125)
        this.ViewerArrowEnabledInput := this.Window.Add("CheckBox", "x230 y122 w70 h24", "启用")
        this.ViewerArrowChordInput := this.Window.Add("Hotkey", "x340 y122 w190 h24")
        this.ViewerArrowWinInput := this.Window.Add("CheckBox", "x560 y122 w60 h24", "使用")
        this.Window.Add("Text", "x48 y164 w130", "长度测量")
        this.AddHelpButton("viewer-tools", 186, 161)
        this.ViewerLengthEnabledInput := this.Window.Add("CheckBox", "x230 y158 w70 h24", "启用")
        this.ViewerLengthChordInput := this.Window.Add("Hotkey", "x340 y158 w190 h24")
        this.ViewerLengthWinInput := this.Window.Add("CheckBox", "x560 y158 w60 h24", "使用")
        this.Window.Add("Text", "x48 y200 w130", "3D SUV")
        this.AddHelpButton("viewer-tools", 186, 197)
        this.ViewerSuv3DEnabledInput := this.Window.Add("CheckBox", "x230 y194 w70 h24", "启用")
        this.ViewerSuv3DChordInput := this.Window.Add("Hotkey", "x340 y194 w190 h24")
        this.ViewerSuv3DWinInput := this.Window.Add("CheckBox", "x560 y194 w60 h24", "使用")
        this.Window.Add("Text", "x48 y236 w130", "截图")
        this.AddHelpButton("capture", 186, 233)
        this.ViewerCaptureEnabledInput := this.Window.Add("CheckBox", "x230 y230 w70 h24", "启用")
        this.ViewerCaptureChordInput := this.Window.Add("Hotkey", "x340 y230 w190 h24")
        this.ViewerCaptureWinInput := this.Window.Add("CheckBox", "x560 y230 w60 h24", "使用")
        this.Window.Add("Text", "x48 y272 w130", "清除全部标注")
        this.AddHelpButton("clear", 186, 269)
        this.ViewerClearEnabledInput := this.Window.Add("CheckBox", "x230 y266 w70 h24", "启用")
        this.ViewerClearChordInput := this.Window.Add("Hotkey", "x340 y266 w190 h24")
        this.ViewerClearWinInput := this.Window.Add("CheckBox", "x560 y266 w60 h24", "使用")

        this.Window.Add("GroupBox", "x28 y308 w744 h168", "Montage 排版")
        this.AddHelpButton("montage", 166, 306)
        this.MontageEnabledInput := this.Window.Add("CheckBox", "x230 y314 w100 h24", "启用全部")
        this.Window.Add("Text", "x48 y354 w130", "Body")
        this.MontageBodyChordInput := this.Window.Add("Hotkey", "x340 y348 w190 h24")
        this.MontageBodyWinInput := this.Window.Add("CheckBox", "x560 y348 w60 h24", "使用")
        this.Window.Add("Text", "x48 y386 w130", "Head")
        this.MontageHeadChordInput := this.Window.Add("Hotkey", "x340 y380 w190 h24")
        this.MontageHeadWinInput := this.Window.Add("CheckBox", "x560 y380 w60 h24", "使用")
        this.Window.Add("Text", "x48 y418 w130", "Lung")
        this.MontageLungChordInput := this.Window.Add("Hotkey", "x340 y412 w190 h24")
        this.MontageLungWinInput := this.Window.Add("CheckBox", "x560 y412 w60 h24", "使用")
        this.Window.Add("Text", "x48 y454 w130", "布局位置")
        this.AddHelpButton("montage-layout", 186, 449)
        this.Window.Add("Text", "x230 y454 w20", "行")
        this.MontageLayoutRowInput := this.Window.Add("DropDownList", "x254 y446 w60", ["1", "2", "3", "4", "5"])
        this.Window.Add("Text", "x340 y454 w20", "列")
        this.MontageLayoutColumnInput := this.Window.Add("DropDownList", "x364 y446 w60", ["1", "2", "3", "4"])

        this.Window.Add("GroupBox", "x28 y492 w744 h102", "封面图")
        this.AddHelpButton("cover", 108, 490)
        this.Window.Add("Text", "x48 y516 w130", "生成封面")
        this.CoverEnabledInput := this.Window.Add("CheckBox", "x230 y510 w70 h24", "启用")
        this.CoverChordInput := this.Window.Add("Hotkey", "x340 y510 w190 h24")
        this.CoverWinInput := this.Window.Add("CheckBox", "x560 y510 w60 h24", "使用")
        this.Window.Add("Text", "x48 y556 w130", "布局位置")
        this.AddHelpButton("cover-layout", 186, 551)
        this.Window.Add("Text", "x230 y556 w20", "行")
        this.CoverLayoutRowInput := this.Window.Add("DropDownList", "x254 y550 w60", ["1", "2", "3", "4", "5"])
        this.Window.Add("Text", "x340 y556 w20", "列")
        this.CoverLayoutColumnInput := this.Window.Add("DropDownList", "x364 y550 w60", ["1", "2", "3", "4"])
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
            this.ViewerClearWinInput,
            this.MontageEnabledInput,
            this.MontageBodyWinInput,
            this.MontageHeadWinInput,
            this.MontageLungWinInput,
            this.CoverEnabledInput,
            this.CoverWinInput
        ] {
            control.OnEvent("Click", this.OnViewerHotkeyChanged.Bind(this))
        }
        for control in [
            this.ReportImageCaptionChordInput,
            this.ViewerArrowChordInput,
            this.ViewerLengthChordInput,
            this.ViewerSuv3DChordInput,
            this.ViewerCaptureChordInput,
            this.ViewerClearChordInput,
            this.MontageBodyChordInput,
            this.MontageHeadChordInput,
            this.MontageLungChordInput,
            this.MontageLayoutRowInput,
            this.MontageLayoutColumnInput,
            this.CoverChordInput,
            this.CoverLayoutRowInput,
            this.CoverLayoutColumnInput
        ] {
            control.OnEvent("Change", this.OnViewerHotkeyChanged.Bind(this))
        }
        this.LoadFeatureHotkeyControls()
        this.LoadMontageHotkeyControls()

        this.Tabs.UseTab()
        this.SaveButton := this.Window.Add(
            "Button", "x588 y616 w84 h28 Default", "保存"
        )
        this.SaveButton.OnEvent("Click", this.OnSave.Bind(this))
        this.CancelButton := this.Window.Add(
            "Button", "x688 y616 w84 h28", "取消"
        )
        this.CancelButton.OnEvent("Click", this.OnClose.Bind(this))

        this.RefreshTemplateList()
        if this.Entries.Length > 0
            this.SelectSection(this.Entries[1].Section)
    }

    Activate() {
        this.Window.Show("w800 h660")
        try WinActivate("ahk_id " this.Window.Hwnd)
    }

    AddHelpButton(topic, x, y) {
        button := this.Window.Add("Button", "x" x " y" y " w18 h18", "?")
        button.OnEvent("Click", this.ShowHelpMenu.Bind(this, topic))
        this.HelpButtons.Push({Topic: topic, Control: button})
        return button
    }

    BuildHelpMenu(topic) {
        definition := ReportAssistantSettingsDefaults.HelpTopic(topic)
        helpMenu := Menu()
        helpMenu.Add(definition.Title, (*) => 0)
        helpMenu.Disable(definition.Title)
        helpMenu.Add()
        for line in definition.Lines
            helpMenu.Add(line, (*) => 0)
        return helpMenu
    }

    ShowHelpMenu(topic, button, *) {
        rect := Win32WindowRect(button.Hwnd)
        if !IsObject(rect)
            return
        helpMenu := this.BuildHelpMenu(topic)
        CoordMode "Menu", "Screen"
        helpMenu.Show(rect.left, rect.bottom + 3)
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
        this.ClipboardTextInput.Text :=
            ReportHotstringTextForMultilineEdit(entry.ClipboardText)
        this.DeleteButton.Enabled := !entry.IsBuiltin
    }

    ClearEditor() {
        this.LoadingControls := true
        try {
            this.EnabledInput.Value := 0
            this.NameInput.Text := ""
            this.TriggerInput.Text := ""
            this.TextInput.Text := ""
            this.ClipboardTextInput.Text := ""
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
        entry.ClipboardText :=
            ReportHotstringTextFromMultilineEdit(this.ClipboardTextInput.Text)
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

    LoadMontageHotkeyControls() {
        this.LoadingControls := true
        try {
            this.CoverEnabledInput.Value := this.MontageSettings.coverEnabled ? 1 : 0
            this.CoverChordInput.Value := ViewerHotkeyNativeChord(this.MontageSettings.coverChord)
            this.CoverWinInput.Value := ViewerHotkeyUsesWin(this.MontageSettings.coverChord) ? 1 : 0
            this.CoverLayoutRowInput.Choose(this.MontageSettings.coverLayoutRow)
            this.CoverLayoutColumnInput.Choose(this.MontageSettings.coverLayoutColumn)
            this.MontageEnabledInput.Value :=
                this.MontageSettings.enabled ? 1 : 0
            this.MontageBodyChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.MontageSettings.chords["body"]
                )
            this.MontageBodyWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.MontageSettings.chords["body"]
                ) ? 1 : 0
            this.MontageHeadChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.MontageSettings.chords["head"]
                )
            this.MontageHeadWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.MontageSettings.chords["head"]
                ) ? 1 : 0
            this.MontageLungChordInput.Value :=
                ViewerHotkeyNativeChord(
                    this.MontageSettings.chords["lung"]
                )
            this.MontageLungWinInput.Value :=
                ViewerHotkeyUsesWin(
                    this.MontageSettings.chords["lung"]
                ) ? 1 : 0
            this.MontageLayoutRowInput.Choose(
                this.MontageSettings.layoutRow
            )
            this.MontageLayoutColumnInput.Choose(
                this.MontageSettings.layoutColumn
            )
        } finally {
            this.LoadingControls := false
        }
    }

    StoreMontageHotkeyControls() {
        this.MontageSettings.coverLayoutRow := this.CoverLayoutRowInput.Value
        this.MontageSettings.coverLayoutColumn := this.CoverLayoutColumnInput.Value
        this.MontageSettings.coverEnabled := this.CoverEnabledInput.Value = 1
        this.MontageSettings.coverChord := MergeViewerHotkeyChord(this.CoverChordInput.Value, this.CoverWinInput.Value = 1)
        this.MontageSettings.enabled :=
            this.MontageEnabledInput.Value = 1
        this.MontageSettings.layoutRow :=
            this.MontageLayoutRowInput.Value
        this.MontageSettings.layoutColumn :=
            this.MontageLayoutColumnInput.Value
        this.MontageSettings.chords["body"] := MergeViewerHotkeyChord(
            this.MontageBodyChordInput.Value,
            this.MontageBodyWinInput.Value = 1
        )
        this.MontageSettings.chords["head"] := MergeViewerHotkeyChord(
            this.MontageHeadChordInput.Value,
            this.MontageHeadWinInput.Value = 1
        )
        this.MontageSettings.chords["lung"] := MergeViewerHotkeyChord(
            this.MontageLungChordInput.Value,
            this.MontageLungWinInput.Value = 1
        )
    }

    OnViewerHotkeyChanged(*) {
        if this.LoadingControls
            return
        this.StoreFeatureHotkeyControls()
        this.StoreMontageHotkeyControls()
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
        this.StoreMontageHotkeyControls()
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
        montageValidation := ValidateMxNMMontageSettings(
            this.MontageSettings,
            this.FeatureSettings
        )
        if !montageValidation.Ok {
            this.Tabs.Choose(2)
            this.FocusMontageValidationError(
                montageValidation.Field
            )
            MsgBox(
                montageValidation.Message,
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
            this.FeatureSettings,
            this.MontageSettings
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

    FocusMontageValidationError(field) {
        if field = "CoverChord" {
            this.CoverChordInput.Focus()
        } else if field = "CoverLayoutRow" {
            this.CoverLayoutRowInput.Focus()
        } else if field = "CoverLayoutColumn" {
            this.CoverLayoutColumnInput.Focus()
        } else if field = "MontageBodyChord"
            this.MontageBodyChordInput.Focus()
        else if field = "MontageHeadChord"
            this.MontageHeadChordInput.Focus()
        else if field = "MontageLungChord"
            this.MontageLungChordInput.Focus()
        else if field = "MontageLayoutRow"
            this.MontageLayoutRowInput.Focus()
        else if field = "MontageLayoutColumn"
            this.MontageLayoutColumnInput.Focus()
        else
            this.MontageEnabledInput.Focus()
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
