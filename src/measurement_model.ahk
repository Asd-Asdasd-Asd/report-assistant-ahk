class MeasurementState {
    static FOUND := "FOUND"
    static NOT_ANNOTATED := "NOT_ANNOTATED"
    static AUTOMATION_FAILED := "AUTOMATION_FAILED"
}

class MeasurementType {
    static SUVMAX := "suvmax"
}

class MeasurementSource {
    static MXNM_CONTEXT_COMMAND := "mxnm_context_command"
}

class MeasurementFailureReason {
    static NONE := ""
    static PROVIDER_BUSY := "PROVIDER_BUSY"
    static VIEWER_NOT_FOUND := "VIEWER_NOT_FOUND"
    static VIEWER_AMBIGUOUS := "VIEWER_AMBIGUOUS"
    static IMAGE_POINT_UNAVAILABLE := "IMAGE_POINT_UNAVAILABLE"
    static IMAGE_POINT_OUT_OF_BOUNDS := "IMAGE_POINT_OUT_OF_BOUNDS"
    static POPUP_NOT_CREATED := "POPUP_NOT_CREATED"
    static COMMAND_NOT_FOUND := "COMMAND_NOT_FOUND"
    static COMMAND_ID_INVALID := "COMMAND_ID_INVALID"
    static COMMAND_INVOKE_FAILED := "COMMAND_INVOKE_FAILED"
    static CLIPBOARD_SAVE_FAILED := "CLIPBOARD_SAVE_FAILED"
    static CLIPBOARD_SENTINEL_FAILED := "CLIPBOARD_SENTINEL_FAILED"
    static CLIPBOARD_ACTION_FAILED := "CLIPBOARD_ACTION_FAILED"
    static CLIPBOARD_NOT_UPDATED := "CLIPBOARD_NOT_UPDATED"
    static CLIPBOARD_RESTORE_FAILED := "CLIPBOARD_RESTORE_FAILED"
    static UNEXPECTED_FORMAT := "UNEXPECTED_FORMAT"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MeasurementResult {
    __New(state, measurementType, rawValue := "", formattedValue := "",
        source := MeasurementSource.MXNM_CONTEXT_COMMAND,
        failureReason := MeasurementFailureReason.NONE, context := 0) {
        this.state := String(state)
        this.success := this.state = MeasurementState.FOUND
        this.measurementType := String(measurementType)
        this.rawValue := String(rawValue)
        this.formattedValue := String(formattedValue)
        this.source := String(source)
        this.failureReason := String(failureReason)
        this.context := Type(context) = "Map" ? context : Map()
    }
}

MakeMeasurementResult(state, measurementType := MeasurementType.SUVMAX,
    rawValue := "", formattedValue := "",
    source := MeasurementSource.MXNM_CONTEXT_COMMAND,
    failureReason := MeasurementFailureReason.NONE, context := 0) {
    return MeasurementResult(
        state,
        measurementType,
        rawValue,
        formattedValue,
        source,
        failureReason,
        context
    )
}

MeasurementOption(options, key, defaultValue := 0) {
    if Type(options) = "Map" && options.Has(key)
        return options[key]
    if IsObject(options) && options.HasOwnProp(key)
        return options.%key%
    return defaultValue
}
