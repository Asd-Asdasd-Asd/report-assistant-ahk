class ReportTemplateParseResult {
    __New(ok, renderedText := "", caretIndex := 0, cursorCount := 0,
        redFigureStartIndex := -1, redFigureCount := 0, message := "") {
        this.Ok := ok = true
        this.RenderedText := String(renderedText)
        this.CaretIndex := caretIndex
        this.CursorCount := cursorCount
        this.RedFigureStartIndex := redFigureStartIndex
        this.RedFigureCount := redFigureCount
        this.Message := String(message)
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

RenderReportTemplate(templateText) {
    return ParseReportTemplate(templateText, true)
}

ParseReportTemplate(templateText, expandDate) {
    sourceText := String(templateText)
    output := ""
    cursorCount := 0
    caretIndex := -1
    redFigureStartIndex := -1
    redFigureCount := 0
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
            output .= expandDate ? FormatTime(, "yyyy-MM-dd")
                : ReportHotstringDefaults.DatePlaceholder
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

    if caretIndex < 0
        caretIndex := StrLen(output)
    return ReportTemplateParseResult(
        true, output, caretIndex, cursorCount,
        redFigureStartIndex, redFigureCount
    )
}

BuildReportTemplatePlan(templateText) {
    rendered := RenderReportTemplate(templateText)
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
