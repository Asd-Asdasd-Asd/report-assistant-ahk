if ReportAssistantConfigStartupResult.Ok {
    RegisterReportHotstrings(
        LoadReportHotstringConfig(),
        RunConfiguredReportHotstring
    )
}

class ReportTemplateWriteCode {
    static OK := "OK"
    static INVALID_TEMPLATE := "INVALID_TEMPLATE"
    static TARGET_CHANGED := "TARGET_CHANGED"
    static TEXT_DISPATCH_FAILED := "TEXT_DISPATCH_FAILED"
    static RED_INSERTION_FAILED := "RED_INSERTION_FAILED"
    static CARET_RELOCATION_FAILED := "CARET_RELOCATION_FAILED"
}

RunConfiguredReportHotstring(entry, *) {
    operation := BeginAutomationDiagnosticOperation("ReportHotstring")
    outcome := ReportHotstringOutcome(false, "FAILED", "UNEXPECTED_ERROR")
    try outcome := RunObservedReportHotstring(entry, operation)
    finally operation.Complete(outcome.automationResult, outcome.code)
    return outcome.result
}

ReportHotstringOutcome(result, automationResult, code) {
    return {
        result: result = true,
        automationResult: String(automationResult),
        code: String(code)
    }
}

RunObservedReportHotstring(entry, operation) {
    templateInfo := ValidateReportTemplate(entry.Text)
    if !templateInfo.Ok {
        OutputDebug "Report template render failed: INVALID_TEMPLATE"
        return ReportHotstringOutcome(
            false, "FAILED", ReportTemplateWriteCode.INVALID_TEMPLATE
        )
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
    if IsObject(measurement) {
        operation.Stage("MEASUREMENT_READ")
        operation.SetField("report.measurementType", selectedMeasurementType)
        operation.SetField("report.measurementState", measurement.state)
    }

    plan := BuildReportTemplatePlan(entry.Text, runtimeContext)
    if !plan.Ok {
        OutputDebug "Report template render failed: INVALID_RUNTIME_TEMPLATE"
        ShowReportAssistantVisualFeedback("报告写入未完成")
        return ReportHotstringOutcome(
            false, "FAILED", "INVALID_RUNTIME_TEMPLATE"
        )
    }
    operation.SetField(
        "report.requiresColorReset",
        AutomationDiagnosticBoolean(plan.RequiresColorReset)
    )

    trace := Map()
    writeResult := ExecuteReportTemplatePlan(plan, reportHwnd, trace)
    operation.Stage("REPORT_WRITE_RETURNED")
    operation.SetField("report.writeCode", writeResult.code)
    ; Probe before annotation cleanup moves focus to the Viewer.
    RecordReportHotstringColorDiagnostics(operation, trace, reportHwnd)
    if !writeResult.ok {
        OutputDebug "Report template write failed: " writeResult.code
        ShowReportAssistantVisualFeedback("报告写入未完成")
        return ReportHotstringOutcome(false, "FAILED", writeResult.code)
    }

    ; The write itself succeeded; a popup left open is a degraded result that
    ; the snapshot surfaces with the failures. No corrective action is taken.
    outcome := trace.Has("menuProbe") && trace["menuProbe"]["state"] = "OPEN"
        ? ReportHotstringOutcome(true, "DEGRADED", "COLOR_MENU_LEFT_OPEN")
        : ReportHotstringOutcome(true, "COMPLETED", ReportTemplateWriteCode.OK)
    if !IsObject(measurement)
        return outcome
    if measurement.state = MeasurementState.AUTOMATION_FAILED {
        ShowReportAssistantVisualFeedback(
            selectedMeasurementType = MeasurementType.LINE_AXES
                ? "尺寸获取失败，请手动输入"
                : "SUVMax 获取失败，请手动输入"
        )
        return outcome.automationResult = "COMPLETED"
            ? ReportHotstringOutcome(true, "DEGRADED", "MEASUREMENT_FAILED")
            : outcome
    }
    if measurement.state = MeasurementState.NOT_ANNOTATED
        return outcome

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
        operation.Stage("ANNOTATION_CLEANUP_RETURNED")
        if !cleanup.ok {
            OutputDebug "MxNM annotation cleanup failed: " cleanup.code
            ShowReportAssistantVisualFeedback(
                "报告已写入，标注未清除"
            )
            if outcome.automationResult = "COMPLETED"
                outcome := ReportHotstringOutcome(
                    true, "DEGRADED", "ANNOTATION_CLEANUP_FAILED"
                )
        }
    }
    return outcome
}

RecordReportHotstringColorDiagnostics(operation, trace, reportHwnd) {
    readiness := trace.Has("readiness") ? trace["readiness"] : 0
    if IsObject(readiness) {
        for name, value in readiness.diagnostics
            operation.SetField(name, value)
    }
    if trace.Has("redPath")
        operation.SetField("report.redPath", trace["redPath"])
    red := trace.Has("redOperation") ? trace["redOperation"] : 0
    if !IsObject(red)
        return
    if red.HasOwnProp("clipboardRestoreSucceeded")
        operation.SetField(
            "color.clipboardRestored",
            AutomationDiagnosticBoolean(red.clipboardRestoreSucceeded)
        )
    if !red.HasOwnProp("reset") || !IsObject(red.reset)
        return
    performanceContext := trace.Has("performanceContext")
        ? trace["performanceContext"]
        : 0
    resetFields := ReportColorResetDiagnosticFields(
        red.reset, performanceContext
    )
    for name, value in resetFields
        operation.SetField(name, value)
    probe := ProbeMedExColorMenuAfterReset(
        red.reset,
        IsObject(readiness) ? readiness.options : 0,
        reportHwnd,
        performanceContext
    )
    trace["menuProbe"] := probe
    operation.Stage("COLOR_MENU_PROBED")
    operation.SetField("color.menuAfterWrite", probe["state"])
    operation.SetField("color.menuProbeReason", probe["reason"])
    operation.SetField("color.menuProbeDelayMs", probe["delayMs"])
    operation.SetField("color.menuProbeCount", probe["count"])
}

; Privacy-safe scalars only: codes, reasons, counts and tick durations.
ReportColorResetDiagnosticFields(resetResult, performanceContext := 0) {
    context := resetResult.HasOwnProp("context") ? resetResult.context : 0
    fields := Map(
        "color.resultCode", resetResult.code,
        "color.popupSampleCount",
            MedExContextValue(context, "popupSignatureSampleCount", ""),
        "color.popupFirstReason",
            MedExContextValue(context, "popupSignatureFirstReason", ""),
        "color.mouseRestored", AutomationDiagnosticBoolean(
            MedExContextValue(context, "mouseRestored", false)
        ),
        "color.resetElapsedMs", MedExContextValue(context, "elapsedMs", ""),
        "color.resetToArrowMs", PerformanceDuration(
            performanceContext, "ColorResetStartedMs", "ArrowClickSentMs"
        ),
        "color.arrowToBlackMs", PerformanceDuration(
            performanceContext, "ArrowClickSentMs", "BlackClickSentMs"
        ),
        "color.blackToReturnMs", PerformanceDuration(
            performanceContext, "BlackClickSentMs", "ColorResetReturnedMs"
        )
    )
    if !resetResult.ok {
        for key in ["foregroundGuardReason", "unsupportedProfileReason",
            "geometryReason", "coordinateSpaceReason", "anchorSelectionReason",
            "popupSignatureReason", "uiaReason", "strategyReason",
            "exceptionType"] {
            value := MedExContextValue(context, key, "")
            if value != "" {
                fields["color.failureReason"] := key ":" value
                break
            }
        }
    }
    return fields
}

ExecuteReportTemplatePlan(plan, expectedReportHwnd, trace := 0) {
    if Type(trace) != "Map"
        trace := Map()
    if !ReportHotstringTargetMatches(expectedReportHwnd)
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TARGET_CHANGED
        )

    resetReadiness := 0
    if plan.RequiresColorReset {
        resetReadiness := PrepareMedExRedReset()
        trace["readiness"] := resetReadiness
        if !resetReadiness.ok {
            return MakeReportTemplateWriteResult(
                false, ReportTemplateWriteCode.RED_INSERTION_FAILED
            )
        }
        trace["performanceContext"] := Map()
        resetReadiness.options["performanceContext"] :=
            trace["performanceContext"]
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
        targetMatches := ReportHotstringTargetMatches(expectedReportHwnd)
        return MakeReportTemplateWriteResult(
            targetMatches,
            targetMatches
                ? ReportTemplateWriteCode.OK
                : ReportTemplateWriteCode.TARGET_CHANGED
        )
    }

    if !ReportHotstringTargetMatches(expectedReportHwnd)
        return MakeReportTemplateWriteResult(
            false, ReportTemplateWriteCode.TARGET_CHANGED
        )
    trace["redPath"] := plan.CaretLeftCount > 0 ? "caret" : "reset"
    operation := plan.CaretLeftCount > 0
        ? RunRedCaretInsertion(plan.RedText, plan.CaretLeftCount)
        : RunRedResetInsertion(plan.RedText, resetReadiness.options)
    trace["redOperation"] := operation
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
    return MedExProcessNameIsApproved(
        Win32WindowProcessName(expectedHwnd),
        MedExColorResetDefaults.ProvisionalProcessNames
    )
}

ReportMeasurementContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}
