#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\hotstring_model.ahk
#Include ..\..\src\template_renderer.ahk

RunCmxTemplateRegression()

RunCmxTemplateRegression() {
    testGui := Gui(, "cmx template regression")
    testEditControl := testGui.Add("Edit", "w420 h80")
    testGui.Show()
    testEditControl.Focus()

    HotIf (*) => true
    Hotstring(":*?:;cmx", RunCmxTemplateTest)
    HotIf

    SendLevel 1
    SendText "3.5;cmx"
    Sleep 250

    actualEditText := testEditControl.Text
    selectionStartBuffer := Buffer(4, 0)
    selectionEndBuffer := Buffer(4, 0)
    SendMessage(
        0x00B0,
        selectionStartBuffer.Ptr,
        selectionEndBuffer.Ptr,
        testEditControl.Hwnd
    )
    selectionStart := NumGet(selectionStartBuffer, 0, "UInt")
    selectionEnd := NumGet(selectionEndBuffer, 0, "UInt")
    if actualEditText != "3.5cm×cm"
        throw Error("cmx text mismatch: " actualEditText)
    if selectionStart != 6 || selectionEnd != 6
        throw Error("cmx caret mismatch: " selectionStart)

    MsgBox "cmx template regression passed.", "MedEx test", "Iconi"
    ExitApp 0
}

RunCmxTemplateTest(*) {
    plan := BuildReportTemplatePlan("cm×{{cursor}}cm")
    if !plan.Ok || plan.RedText != "" || plan.RequiresColorReset
        throw Error("cmx plan was not plain text")
    SendText plan.RenderedText
    if plan.CaretLeftCount > 0
        Send "{Left " plan.CaretLeftCount "}"
}
