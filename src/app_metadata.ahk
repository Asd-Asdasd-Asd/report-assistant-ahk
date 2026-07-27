class AppMetadata {
    static Version := "0.6.2"
    static Channel := "internal-test"
    static BuildDate := "UNSTAMPED"
    static SourceRevision := "UNSTAMPED"
}

AppMetadataChannelDisplayName(channel := "") {
    if channel = ""
        channel := AppMetadata.Channel
    if channel = "internal-test"
        return "内部测试"
    return channel
}

AppMetadataShortSourceRevision(sourceRevision := "") {
    if sourceRevision = ""
        sourceRevision := AppMetadata.SourceRevision
    if sourceRevision = "UNSTAMPED"
        return "未标记"
    dirtySuffix := "-dirty"
    suffixStart := StrLen(sourceRevision) - StrLen(dirtySuffix) + 1
    isDirty := suffixStart > 0
        && SubStr(sourceRevision, suffixStart) = dirtySuffix
    revision := isDirty
        ? SubStr(sourceRevision, 1, StrLen(sourceRevision) - StrLen(dirtySuffix))
        : sourceRevision
    shortRevision := SubStr(revision, 1, 7)
    return shortRevision . (isDirty ? dirtySuffix : "")
}

AppMetadataBuildDateDisplay(buildDate := "") {
    if buildDate = ""
        buildDate := AppMetadata.BuildDate
    return buildDate = "UNSTAMPED" ? "开发版本" : buildDate
}

AppMetadataIsDirtyBuild(sourceRevision := "") {
    if sourceRevision = ""
        sourceRevision := AppMetadata.SourceRevision
    dirtySuffix := "-dirty"
    suffixStart := StrLen(sourceRevision) - StrLen(dirtySuffix) + 1
    return suffixStart > 0
        && SubStr(sourceRevision, suffixStart) = dirtySuffix
}

FormatAppVersionInfoText() {
    output := "麦旋风`n`n"
    output .= "版本：" . AppMetadata.Version
        . "（" . AppMetadataChannelDisplayName() . "）`n"
    output .= "构建日期：" . AppMetadataBuildDateDisplay() . "`n"
    output .= "源代码版本：" . AppMetadataShortSourceRevision()
    if AppMetadataIsDirtyBuild() {
        output .= "`n`n"
        output .= "⚠ 此构建包含未提交修改，仅用于测试。"
    } else if AppMetadata.SourceRevision = "UNSTAMPED" {
        output .= "`n`n"
        output .= "⚠ 当前环境没有 Git 元数据，"
            . "源代码版本未标记，仅用于临时测试。"
    }
    return output
}
