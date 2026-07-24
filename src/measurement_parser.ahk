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

ParseLineAxesMeasurement(rawText) {
    rawValue := String(rawText)
    normalized := RegExReplace(
        rawValue,
        "^[\s\x{200B}\x{FEFF}]+|[\s\x{200B}\x{FEFF}]+$"
    )
    if normalized = "" {
        return MakeMeasurementResult(
            MeasurementState.NOT_ANNOTATED,
            MeasurementType.LINE_AXES,
            rawValue
        )
    }

    values := []
    if RegExMatch(
        normalized,
        "^(\d+(?:\.\d+)?)cm$",
        &match
    ) {
        values.Push(match[1] + 0)
    } else if RegExMatch(
        normalized,
        "^(\d+(?:\.\d+)?)cm×(\d+(?:\.\d+)?)cm "
            . "\(长径×短径\)$",
        &match
    ) {
        values.Push(match[1] + 0, match[2] + 0)
    } else if RegExMatch(
        normalized,
        "^(\d+(?:\.\d+)?)cm×(\d+(?:\.\d+)?)cm×"
            . "(\d+(?:\.\d+)?)cm \(长径×短径×上下径\)$",
        &match
    ) {
        values.Push(match[1] + 0, match[2] + 0, match[3] + 0)
    } else {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            MeasurementType.LINE_AXES,
            rawValue,
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.UNEXPECTED_FORMAT
        )
    }

    for value in values {
        if value <= 0 {
            return MakeMeasurementResult(
                MeasurementState.AUTOMATION_FAILED,
                MeasurementType.LINE_AXES,
                rawValue,
                "",
                MeasurementSource.MXNM_CONTEXT_COMMAND,
                MeasurementFailureReason.UNEXPECTED_FORMAT
            )
        }
    }
    SortLineAxisValuesDescending(values)
    components := []
    formattedValue := ""
    for index, value in values {
        formattedComponent := Format("{:.1f}", value)
        formattedValue .= (index = 1 ? "" : "×")
            . formattedComponent "cm"
        components.Push({
            role: "axis_" index,
            value: value,
            unit: "cm"
        })
    }
    return MakeMeasurementResult(
        MeasurementState.FOUND,
        MeasurementType.LINE_AXES,
        rawValue,
        formattedValue,
        MeasurementSource.MXNM_CONTEXT_COMMAND,
        MeasurementFailureReason.NONE,
        0,
        components
    )
}

SortLineAxisValuesDescending(values) {
    index := 2
    while index <= values.Length {
        current := values[index]
        insertionIndex := index - 1
        while insertionIndex >= 1
            && values[insertionIndex] < current {
            values[insertionIndex + 1] := values[insertionIndex]
            insertionIndex -= 1
        }
        values[insertionIndex + 1] := current
        index += 1
    }
}
