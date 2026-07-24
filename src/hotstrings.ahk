RegisterReportHotstrings(
    LoadReportHotstringConfig(),
    RunConfiguredReportHotstring
)

class ReportTemplateWriteCode {
    static OK := "OK"
    static INVALID_TEMPLATE := "INVALID_TEMPLATE"
    static TARGET_CHANGED := "TARGET_CHANGED"
    static TEXT_DISPATCH_FAILED := "TEXT_DISPATCH_FAILED"
    static RED_INSERTION_FAILED := "RED_INSERTION_FAILED"
    static CARET_RELOCATION_FAILED := "CARET_RELOCATION_FAILED"
}

RunConfiguredReportHotstring(entry, *) {
    templateInfo := ValidateReportTemplate(entry.Text)
    if !templateInfo.Ok {
        OutputDebug "Report template render failed: INVALID_TEMPLATE"
        return false
    }

    reportHwnd := WinExist("A")
    runtimeContext := 0
    measurement := 0
    selectedMeasurementType := ""
    if templateInfo.SuvMaxCount = 1 {
        measurement := MxNMMeasurementProvider.ReadSuvMax()
        selectedMeasurementType := MeasurementType.SUVMAX
        runtimeContext := Map(
            "suvmaxState", measurement.state,
            "suvmaxText", measurement.formattedValue
        )
    } else if templateInfo.SizeCount = 1 {
        measurement := MxNMMeasurementProvider.ReadLineAxes()
        selectedMeasurementType := MeasurementType.LINE_AXES
        runtimeContext := Map(
            "sizeState", measurement.state,
            "sizeText", measurement.formattedValue
        )
    }

    plan := BuildReportTemplatePlan(entry.Text, runtimeContext)
    if !plan.Ok {
        OutputDebug "Report template render failed: INVALID_RUNTIME_TEMPLATE"
        ShowReportAssistantVisualFeedback("报告写入未完成")
        return false
    }

    writeResult := ExecuteReportTemplatePlan(plan, reportHwnd)
    if !writeResult.ok {
        OutputDebug "Report template write failed: " writeResult.code
        ShowReportAssistantVisualFeedback("报告写入未完成")
        return false
    }

    if !IsObject(measurement)
        return true
    if measurement.state = MeasurementState.AUTOMATION_FAILED {
        ShowReportAssistantVisualFeedback(
            selectedMeasurementType = MeasurementType.LINE_AXES
                ? "尺寸获取失败，请手动输入"
                : "SUVMax 获取失败，请手动输入"
        )
        return true
    }
    if measurement.state = MeasurementState.NOT_ANNOTATED
        return true

    if MxNMAnnotationCleanupDefaults.ProductionEnabled {
        cleanup := MxNMAnnotationCleaner.DeleteAll(
            ReportMeasurementContextValue(
                measurement.context, "targetActionHwnd", 0
            ),
            ReportMeasurementContextValue(
                measurement.context, "targetActionPid", 0
            ),
            0,
            selectedMeasurementType
        )
        if !cleanup.ok {
            OutputDebug "MxNM annotation cleanup failed: " cleanup.code
            ShowReportAssistantVisualFeedback(
                "报告已写入，标注未清除"
            )
        }
    }
    return true
}

ExecuteReportTemplatePlan(plan, expectedReportHwnd) {
    if !ReportHotstringTargetMatches(expectedReportHwnd)
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TARGET_CHANGED
        )

    resetReadiness := 0
    if plan.RequiresColorReset {
        resetReadiness := PrepareMedExRedReset()
        if !resetReadiness.ok {
            return MakeReportTemplateWriteResult(
                false, ReportTemplateWriteCode.RED_INSERTION_FAILED
            )
        }
    }

    if !SendConfiguredReportText(plan.PlainText, expectedReportHwnd) {
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TEXT_DISPATCH_FAILED
        )
    }
    if plan.RedText = "" {
        if plan.CaretLeftCount > 0 {
            if !ReportHotstringTargetMatches(expectedReportHwnd)
                return MakeReportTemplateWriteResult(
                    false, ReportTemplateWriteCode.TARGET_CHANGED
                )
            try Send("{Left " plan.CaretLeftCount "}")
            catch {
                return MakeReportTemplateWriteResult(
                    false,
                    ReportTemplateWriteCode.CARET_RELOCATION_FAILED
                )
            }
        }
        return MakeReportTemplateWriteResult(
            ReportHotstringTargetMatches(expectedReportHwnd),
            ReportHotstringTargetMatches(expectedReportHwnd)
                ? ReportTemplateWriteCode.OK
                : ReportTemplateWriteCode.TARGET_CHANGED
        )
    }

    if !ReportHotstringTargetMatches(expectedReportHwnd)
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TARGET_CHANGED
        )
    operation := plan.CaretLeftCount > 0
        ? RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)
        : RunRedResetInsertion(plan.RedText, resetReadiness.options)
    if !IsObject(operation) || !operation.ok {
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.RED_INSERTION_FAILED
        )
    }
    if !ReportHotstringTargetMatches(expectedReportHwnd) {
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TARGET_CHANGED
        )
    }
    return MakeReportTemplateWriteResult(
        true, ReportTemplateWriteCode.OK
    )
}

MakeReportTemplateWriteResult(ok, code) {
    return {
        ok: ok = true,
        code: String(code)
    }
}

SendConfiguredReportText(text, expectedReportHwnd := 0) {
    lines := StrSplit(text, "`n", "`r")
    try {
        for index, line in lines {
            if expectedReportHwnd
                && !ReportHotstringTargetMatches(expectedReportHwnd)
                return false
            if index > 1
                Send("{Enter}")
            if line != ""
                SendText(line)
        }
        return !expectedReportHwnd
            || ReportHotstringTargetMatches(expectedReportHwnd)
    } catch {
        return false
    }
}

ReportHotstringTargetMatches(expectedHwnd) {
    if !MedExForegroundWindowMatches(expectedHwnd)
        return false
    try processName := WinGetProcessName("ahk_id " expectedHwnd)
    catch {
        return false
    }
    return MedExProcessNameIsApproved(
        processName,
        MedExColorResetDefaults.ProvisionalProcessNames
    )
}

ReportMeasurementContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

WarmMxNMMeasurementTarget(*) {
    if MxNMMeasurementProvider.HasReusableTarget() {
        SetTimer WarmMxNMMeasurementTarget, 0
        return
    }
    if !WinExist(
        "ahk_exe " MxNMConfigGeometryDefaults.ViewerExe
    )
        return
    if MedExReportHotstringsEnabled()
        return
    if MxNMMeasurementProvider.WarmTarget()
        SetTimer WarmMxNMMeasurementTarget, 0
}
