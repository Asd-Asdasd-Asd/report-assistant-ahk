class ReportTemplateParseResult {
    __New(ok, renderedText := "", caretIndex := 0, cursorCount := 0,
        redFigureStartIndex := -1, redFigureCount := 0, message := "",
        suvMaxIndex := -1, suvMaxCount := 0,
        suvMaxCaretForced := false, sizeIndex := -1,
        sizeCount := 0, sizeCaretForced := false) {
        this.Ok := ok = true
        this.RenderedText := String(renderedText)
        this.CaretIndex := caretIndex
        this.CursorCount := cursorCount
        this.RedFigureStartIndex := redFigureStartIndex
        this.RedFigureCount := redFigureCount
        this.Message := String(message)
        this.SuvMaxIndex := suvMaxIndex
        this.SuvMaxCount := suvMaxCount
        this.SuvMaxCaretForced := suvMaxCaretForced = true
        this.SizeIndex := sizeIndex
        this.SizeCount := sizeCount
        this.SizeCaretForced := sizeCaretForced = true
    }
}

class ReportTemplatePlan {
    __New(ok, renderedText := "", plainText := "", redText := "",
        caretLeftCount := 0, requiresColorReset := false, message := "") {
        this.Ok := ok = true
        this.RenderedText := String(renderedText)
        this.PlainText := String(plainText)
        this.RedText := String(redText)
        this.CaretLeftCount := caretLeftCount
        this.RequiresColorReset := requiresColorReset = true
        this.Message := String(message)
    }
}

ValidateReportTemplate(templateText) {
    return ParseReportTemplate(templateText, false)
}

RenderReportTemplate(templateText, runtimeContext := 0) {
    return ParseReportTemplate(templateText, true, runtimeContext)
}

ParseReportTemplate(templateText, isRuntimeRender, runtimeContext := 0) {
    sourceText := String(templateText)
    output := ""
    cursorCount := 0
    caretIndex := -1
    redFigureStartIndex := -1
    redFigureCount := 0
    suvMaxIndex := -1
    suvMaxCount := 0
    suvMaxCaretForced := false
    sizeIndex := -1
    sizeCount := 0
    sizeCaretForced := false
    position := 1

    while position <= StrLen(sourceText) {
        opener := InStr(sourceText, "{{", false, position)
        closerBeforeOpener := InStr(sourceText, "}}", false, position)
        if closerBeforeOpener && (!opener || closerBeforeOpener < opener) {
            return ReportTemplateParseResult(
                false, , , , , , "存在没有开头的 }}。"
            )
        }
        if !opener {
            output .= SubStr(sourceText, position)
            break
        }

        output .= SubStr(sourceText, position, opener - position)
        closer := InStr(sourceText, "}}", false, opener + 2)
        if !closer {
            return ReportTemplateParseResult(
                false, , , , , , "存在没有结尾的 {{。"
            )
        }
        nestedOpener := InStr(sourceText, "{{", false, opener + 2)
        if nestedOpener && nestedOpener < closer {
            return ReportTemplateParseResult(
                false, , , , , , "占位符不能嵌套。"
            )
        }

        token := SubStr(sourceText, opener + 2, closer - opener - 2)
        if token = "cursor" {
            cursorCount += 1
            if cursorCount > 1 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , ,
                    "每个模板最多只能使用一个 {{cursor}}。"
                )
            }
            caretIndex := StrLen(output)
        } else if token = "date" {
            output .= isRuntimeRender ? FormatTime(, "yyyy-MM-dd")
                : ReportHotstringDefaults.DatePlaceholder
        } else if token = "suvmax" {
            if sizeCount > 0 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , redFigureCount,
                    "{{suvmax}} 和 {{size}} 不能在同一模板中使用。"
                )
            }
            suvMaxCount += 1
            if suvMaxCount > 1 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , redFigureCount,
                    "每个模板最多只能使用一个 {{suvmax}}。",
                    suvMaxIndex, suvMaxCount
                )
            }
            suvMaxIndex := StrLen(output)
            if isRuntimeRender {
                runtimeState := ReportTemplateRuntimeValue(
                    runtimeContext, "suvmaxState", ""
                )
                runtimeText := String(ReportTemplateRuntimeValue(
                    runtimeContext, "suvmaxText", ""
                ))
                if runtimeState = "FOUND" {
                    if !RegExMatch(
                        runtimeText,
                        "^(?:0|[1-9]\d*)\.\d$"
                    ) || Number(runtimeText) <= 0 {
                        return ReportTemplateParseResult(
                            false, , , cursorCount, , redFigureCount,
                            "SUVMax 运行时结果缺少合法数值。",
                            suvMaxIndex, suvMaxCount
                        )
                    }
                    output .= runtimeText
                } else if runtimeState = "NOT_ANNOTATED"
                    || runtimeState = "AUTOMATION_FAILED" {
                    suvMaxCaretForced := true
                } else {
                    return ReportTemplateParseResult(
                        false, , , cursorCount, , redFigureCount,
                        "模板缺少 SUVMax 运行时结果。",
                        suvMaxIndex, suvMaxCount
                    )
                }
            }
        } else if token = "size" {
            if suvMaxCount > 0 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , redFigureCount,
                    "{{suvmax}} 和 {{size}} 不能在同一模板中使用。"
                )
            }
            sizeCount += 1
            if sizeCount > 1 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , redFigureCount,
                    "每个模板最多只能使用一个 {{size}}。",
                    suvMaxIndex, suvMaxCount, suvMaxCaretForced,
                    sizeIndex, sizeCount
                )
            }
            sizeIndex := StrLen(output)
            if isRuntimeRender {
                runtimeState := ReportTemplateRuntimeValue(
                    runtimeContext, "sizeState", ""
                )
                runtimeText := String(ReportTemplateRuntimeValue(
                    runtimeContext, "sizeText", ""
                ))
                if runtimeState = "FOUND" {
                    if !IsValidRenderedLineAxesValue(runtimeText) {
                        return ReportTemplateParseResult(
                            false, , , cursorCount, , redFigureCount,
                            "尺寸运行时结果格式无效。",
                            suvMaxIndex, suvMaxCount,
                            suvMaxCaretForced, sizeIndex, sizeCount
                        )
                    }
                    output .= runtimeText
                } else if runtimeState = "NOT_ANNOTATED"
                    || runtimeState = "AUTOMATION_FAILED" {
                    sizeCaretForced := true
                } else {
                    return ReportTemplateParseResult(
                        false, , , cursorCount, , redFigureCount,
                        "模板缺少尺寸运行时结果。",
                        suvMaxIndex, suvMaxCount,
                        suvMaxCaretForced, sizeIndex, sizeCount
                    )
                }
            }
        } else if token = "red:（见图）" {
            redFigureCount += 1
            if redFigureCount > 1 {
                return ReportTemplateParseResult(
                    false, , , cursorCount, , redFigureCount,
                    "每个模板最多只能使用一个 {{red:（见图）}}。"
                )
            }
            redFigureStartIndex := StrLen(output)
            output .= ReportHotstringDefaults.RedFigureMarker
            position := closer + 2
            if position <= StrLen(sourceText) {
                return ReportTemplateParseResult(
                    false, , , cursorCount, redFigureStartIndex,
                    redFigureCount,
                    "{{red:（见图）}} 必须是模板最后一个元素。"
                )
            }
            continue
        } else {
            shownToken := token = "" ? "空占位符" : "{{" token "}}"
            return ReportTemplateParseResult(
                false, , , cursorCount, , ,
                "无法识别占位符：" shownToken
            )
        }
        position := closer + 2
    }

    if sizeCaretForced
        caretIndex := sizeIndex
    else if suvMaxCaretForced
        caretIndex := suvMaxIndex
    else if caretIndex < 0
        caretIndex := StrLen(output)
    return ReportTemplateParseResult(
        true, output, caretIndex, cursorCount,
        redFigureStartIndex, redFigureCount, "",
        suvMaxIndex, suvMaxCount, suvMaxCaretForced,
        sizeIndex, sizeCount, sizeCaretForced
    )
}

ReportTemplateRuntimeValue(runtimeContext, key, defaultValue := "") {
    if Type(runtimeContext) = "Map" && runtimeContext.Has(key)
        return runtimeContext[key]
    if IsObject(runtimeContext) && runtimeContext.HasOwnProp(key)
        return runtimeContext.%key%
    return defaultValue
}

IsValidRenderedLineAxesValue(value) {
    components := StrSplit(String(value), "×")
    if components.Length < 1 || components.Length > 3
        return false
    previousValue := 0
    for index, component in components {
        if !RegExMatch(
            component,
            "^((?:0|[1-9]\d*)\.\d)cm$",
            &match
        )
            return false
        numericValue := Number(match[1])
        if numericValue <= 0
            return false
        if index > 1 && numericValue > previousValue
            return false
        previousValue := numericValue
    }
    return true
}

BuildReportTemplatePlan(templateText, runtimeContext := 0) {
    rendered := RenderReportTemplate(templateText, runtimeContext)
    if !rendered.Ok
        return ReportTemplatePlan(false, , , , , , rendered.Message)

    renderedText := rendered.RenderedText
    redText := rendered.RedFigureCount = 1
        ? ReportHotstringDefaults.RedFigureMarker
        : ""
    plainText := redText = "" ? renderedText
        : SubStr(renderedText, 1, rendered.RedFigureStartIndex)
    caretLeftCount := StrLen(renderedText) - rendered.CaretIndex
    return ReportTemplatePlan(
        true,
        renderedText,
        plainText,
        redText,
        caretLeftCount,
        caretLeftCount = 0 && redText != ""
    )
}
