ParseSuvMaxMeasurement(rawText) {
    rawValue := String(rawText)
    if !RegExMatch(
        rawValue,
        "^\s*SUVMax\s*:\s*(\d+(?:\.\d+)?)\s*$",
        &match
    ) {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            MeasurementType.SUVMAX,
            rawValue,
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.UNEXPECTED_FORMAT
        )
    }

    numericValue := match[1] + 0
    if numericValue = 0 {
        return MakeMeasurementResult(
            MeasurementState.NOT_ANNOTATED,
            MeasurementType.SUVMAX,
            rawValue
        )
    }

    return MakeMeasurementResult(
        MeasurementState.FOUND,
        MeasurementType.SUVMAX,
        rawValue,
        Format("{:.1f}", numericValue)
    )
}
