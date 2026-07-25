ViewerToolHotkeyDefinitions(settings) {
    definitions := []
    if settings.ViewerArrowEnabled && settings.ViewerArrowChord != "" {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-arrow",
            settings.ViewerArrowChord,
            InvokeMxNMViewerToolHotkey.Bind("arrow")
        ))
    }
    if settings.ViewerLengthEnabled && settings.ViewerLengthChord != "" {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-length",
            settings.ViewerLengthChord,
            InvokeMxNMViewerToolHotkey.Bind("length")
        ))
    }
    if settings.ViewerSuv3DEnabled && settings.ViewerSuv3DChord != "" {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-suv3d",
            settings.ViewerSuv3DChord,
            InvokeMxNMViewerToolHotkey.Bind("suv3d")
        ))
    }
    return definitions
}

InvokeMxNMViewerToolHotkey(commandName, *) {
    result := MxNMViewerToolCommandProvider.Invoke(commandName)
    if result.ok || result.code = MxNMViewerToolCode.WRONG_FOREGROUND
        return
    Flash(MxNMViewerToolFailureMessage(result.code), 1600)
}

MxNMViewerToolFailureMessage(code) {
    if code = MxNMViewerToolCode.COMMAND_SCHEMA_INVALID
        return "Viewer 工具配置已变化，快捷键未执行"
    if code = MxNMViewerToolCode.VIEWER_NOT_FOUND
        return "未找到 MedEx Viewer"
    if code = MxNMViewerToolCode.VIEWER_NOT_UNIQUE
        return "MedEx Viewer 窗口不唯一，快捷键未执行"
    if code = MxNMViewerToolCode.BUTTON_TARGET_INVALID
        || code = MxNMViewerToolCode.BUTTON_ID_MISMATCH {
        return "Viewer 工具按钮布局校验失败，未执行点击"
    }
    if code = MxNMViewerToolCode.BUSY
        return "Viewer 工具快捷键正在执行"
    return "Viewer 工具快捷键执行失败"
}
