class ColorResetCode {
    static OK := "COLOR_RESET_OK"
    static AUTOMATION_CHAIN_OK := "AUTOMATION_CHAIN_OK"
    static WRONG_PROCESS := "COLOR_RESET_WRONG_PROCESS"
    static PROCESS_NAME_UNCONFIRMED := "COLOR_RESET_PROCESS_NAME_UNCONFIRMED"
    static UIA_UNAVAILABLE := "COLOR_RESET_UIA_UNAVAILABLE"
    static DOCUMENT_NOT_FOUND := "COLOR_RESET_DOCUMENT_NOT_FOUND"
    static ANCHOR_FONT_SIZE_NOT_FOUND := "COLOR_RESET_ANCHOR_FONT_SIZE_NOT_FOUND"
    static ANCHOR_NUMBER_BUTTON_NOT_FOUND := "COLOR_RESET_ANCHOR_NUMBER_BUTTON_NOT_FOUND"
    static TOOLBAR_CANDIDATE_NOT_FOUND := "COLOR_RESET_TOOLBAR_CANDIDATE_NOT_FOUND"
    static TOOLBAR_PAIRING_AMBIGUOUS := "COLOR_RESET_TOOLBAR_PAIRING_AMBIGUOUS"
    static TOOLBAR_SORT_AMBIGUOUS := "COLOR_RESET_TOOLBAR_SORT_AMBIGUOUS"
    static INVALID_RECTANGLE := "COLOR_RESET_INVALID_RECTANGLE"
    static INVALID_GEOMETRY := "COLOR_RESET_INVALID_GEOMETRY"
    static INVALID_COORDINATE_SPACE := "COLOR_RESET_INVALID_COORDINATE_SPACE"
    static TRIGGER_CLICK_FAILED := "COLOR_RESET_TRIGGER_CLICK_FAILED"
    static MENU_NOT_OPENED := "COLOR_RESET_MENU_NOT_OPENED"
    static BLACK_ITEM_NOT_FOUND := "COLOR_RESET_BLACK_ITEM_NOT_FOUND"
    static INVOKE_UNAVAILABLE := "COLOR_RESET_INVOKE_UNAVAILABLE"
    static INVOKE_FAILED := "COLOR_RESET_INVOKE_FAILED"
    static UNEXPECTED_ERROR := "COLOR_RESET_UNEXPECTED_ERROR"
}

class RedTextOperationCode {
    static OK := "RED_TEXT_OK"
    static PASTE_FAILED := "RED_TEXT_PASTE_FAILED"
    static CLIPBOARD_RESTORE_FAILED := "RED_TEXT_CLIPBOARD_RESTORE_FAILED"
    static RESET_FAILED := "RED_TEXT_RESET_FAILED"
}

MakeColorResetResult(ok, code, context := 0) {
    if Type(context) != "Map"
        context := Map()

    return {
        ok: ok = true,
        code: String(code),
        context: context
    }
}

MakeRect(left, top, right, bottom) {
    return Map(
        "l", left,
        "t", top,
        "r", right,
        "b", bottom
    )
}

IsFiniteCoordinate(value, absoluteLimit := 10000000) {
    if !IsNumber(value)
        return false

    numericValue := value + 0
    if numericValue != numericValue
        return false

    return Abs(numericValue) <= absoluteLimit
}

IsValidRect(rect) {
    if Type(rect) != "Map"
        return false

    for key in ["l", "t", "r", "b"] {
        if !rect.Has(key) || !IsFiniteCoordinate(rect[key])
            return false
    }

    return rect["r"] > rect["l"] && rect["b"] > rect["t"]
}

RectWidth(rect) {
    return rect["r"] - rect["l"]
}

RectHeight(rect) {
    return rect["b"] - rect["t"]
}

RectCenterY(rect) {
    return rect["t"] + RectHeight(rect) / 2
}

MedExToolbarPairIsPlausible(fontSizeRect, numberButtonRect, options := 0) {
    minHorizontalGap := MedExLogicOption(options, "minHorizontalGap", 100)
    maxHorizontalGap := MedExLogicOption(options, "maxHorizontalGap", 1200)
    maxVerticalDelta := MedExLogicOption(options, "maxVerticalDelta", 24)

    if !IsValidRect(fontSizeRect) || !IsValidRect(numberButtonRect)
        return false

    horizontalGap := numberButtonRect["l"] - fontSizeRect["r"]
    verticalDelta := Abs(RectCenterY(fontSizeRect) - RectCenterY(numberButtonRect))
    return horizontalGap >= minHorizontalGap
        && horizontalGap <= maxHorizontalGap
        && verticalDelta <= maxVerticalDelta
}

BuildMedExToolbarCandidates(fontSizeRects, numberButtonRects, options := 0) {
    context := Map(
        "fontSizeAnchorCount", Type(fontSizeRects) = "Array" ? fontSizeRects.Length : 0,
        "numberButtonAnchorCount", Type(numberButtonRects) = "Array" ? numberButtonRects.Length : 0,
        "toolbarCandidateCount", 0,
        "selectedToolbarIndex", 0
    )
    if Type(fontSizeRects) != "Array" || Type(numberButtonRects) != "Array"
        return MakeColorResetResult(false, ColorResetCode.INVALID_RECTANGLE, context)

    for rect in fontSizeRects {
        if !IsValidRect(rect) {
            context["invalidRectangle"] := "fontSizeAnchor"
            return MakeColorResetResult(false, ColorResetCode.INVALID_RECTANGLE, context)
        }
    }
    for rect in numberButtonRects {
        if !IsValidRect(rect) {
            context["invalidRectangle"] := "numberButtonAnchor"
            return MakeColorResetResult(false, ColorResetCode.INVALID_RECTANGLE, context)
        }
    }

    fontMatches := []
    numberMatches := []
    loop fontSizeRects.Length
        fontMatches.Push([])
    loop numberButtonRects.Length
        numberMatches.Push([])

    for fontIndex, fontRect in fontSizeRects {
        for numberIndex, numberRect in numberButtonRects {
            if MedExToolbarPairIsPlausible(fontRect, numberRect, options) {
                fontMatches[fontIndex].Push(numberIndex)
                numberMatches[numberIndex].Push(fontIndex)
            }
        }
    }

    for matches in fontMatches {
        if matches.Length > 1 {
            context["pairingReason"] := "fontSizeAnchorMatchesMultipleNumberButtons"
            return MakeColorResetResult(false, ColorResetCode.TOOLBAR_PAIRING_AMBIGUOUS, context)
        }
    }
    for matches in numberMatches {
        if matches.Length > 1 {
            context["pairingReason"] := "numberButtonAnchorMatchesMultipleFontSizeAnchors"
            return MakeColorResetResult(false, ColorResetCode.TOOLBAR_PAIRING_AMBIGUOUS, context)
        }
    }

    candidates := []
    for fontIndex, matches in fontMatches {
        if matches.Length != 1
            continue
        numberIndex := matches[1]
        if numberMatches[numberIndex].Length != 1
            continue
        fontRect := fontSizeRects[fontIndex]
        numberRect := numberButtonRects[numberIndex]
        candidates.Push(Map(
            "fontSizeIndex", fontIndex,
            "numberButtonIndex", numberIndex,
            "fontSizeRect", fontRect,
            "numberButtonRect", numberRect,
            "toolbarY", (RectCenterY(fontRect) + RectCenterY(numberRect)) / 2
        ))
    }

    ; Stable insertion sort by the geometry-derived toolbar center Y.
    sortedCandidates := []
    for candidate in candidates {
        inserted := false
        for index, existing in sortedCandidates {
            if candidate["toolbarY"] < existing["toolbarY"] {
                sortedCandidates.InsertAt(index, candidate)
                inserted := true
                break
            }
        }
        if !inserted
            sortedCandidates.Push(candidate)
    }

    minToolbarYSeparation := MedExLogicOption(options, "minToolbarYSeparation", 2)
    if sortedCandidates.Length > 1 {
        loop sortedCandidates.Length - 1 {
            if Abs(sortedCandidates[A_Index + 1]["toolbarY"] - sortedCandidates[A_Index]["toolbarY"])
                < minToolbarYSeparation {
                context["sortingReason"] := "toolbarYValuesNotUnique"
                context["toolbarCandidateCount"] := sortedCandidates.Length
                return MakeColorResetResult(false, ColorResetCode.TOOLBAR_SORT_AMBIGUOUS, context)
            }
        }
    }

    context["toolbarCandidateCount"] := sortedCandidates.Length
    if sortedCandidates.Length < 2 {
        context["candidateReason"] := "secondToolbarCandidateMissing"
        return MakeColorResetResult(false, ColorResetCode.TOOLBAR_CANDIDATE_NOT_FOUND, context)
    }

    selected := sortedCandidates[2]
    context["toolbarCandidates"] := sortedCandidates
    context["toolbarCandidateSelected"] := true
    context["selectedToolbarIndex"] := 2
    context["selectedToolbarY"] := selected["toolbarY"]
    context["selectedFontSizeRect"] := selected["fontSizeRect"]
    context["selectedNumberButtonRect"] := selected["numberButtonRect"]
    return MakeColorResetResult(true, ColorResetCode.OK, context)
}

RectContainsPoint(rect, point, tolerance := 0) {
    return point["x"] >= rect["l"] - tolerance
        && point["x"] <= rect["r"] + tolerance
        && point["y"] >= rect["t"] - tolerance
        && point["y"] <= rect["b"] + tolerance
}

RectContainsRect(outerRect, innerRect, tolerance := 0) {
    return innerRect["l"] >= outerRect["l"] - tolerance
        && innerRect["r"] <= outerRect["r"] + tolerance
        && innerRect["t"] >= outerRect["t"] - tolerance
        && innerRect["b"] <= outerRect["b"] + tolerance
}

CalculateMedExColorArrowPoint(fontSizeRect, numberButtonRect, ratio := 0.337) {
    rawX := fontSizeRect["r"] + ratio * (numberButtonRect["l"] - fontSizeRect["r"])
    rawY := fontSizeRect["t"] + 1

    return Map(
        "x", Round(rawX),
        "y", Round(rawY),
        "rawX", rawX,
        "rawY", rawY,
        "ratio", ratio
    )
}

ConvertScreenPointToClient(screenPoint, clientRectScreen) {
    return Map(
        "x", screenPoint["x"] - clientRectScreen["l"],
        "y", screenPoint["y"] - clientRectScreen["t"]
    )
}

ValidateMedExColorResetGeometry(scopeRect, fontSizeRect, numberButtonRect, windowRect, clientRectScreen, options := 0) {
    minHorizontalGap := MedExLogicOption(options, "minHorizontalGap", 100)
    maxHorizontalGap := MedExLogicOption(options, "maxHorizontalGap", 1200)
    maxVerticalDelta := MedExLogicOption(options, "maxVerticalDelta", 24)
    coordinateTolerance := MedExLogicOption(options, "coordinateTolerance", 4)
    toolbarPadding := MedExLogicOption(options, "toolbarPadding", 12)
    ratio := MedExLogicOption(options, "ratio", 0.337)
    context := Map(
        "ratio", ratio,
        "minHorizontalGap", minHorizontalGap,
        "maxHorizontalGap", maxHorizontalGap,
        "maxVerticalDelta", maxVerticalDelta
    )

    for entry in [
        ["scopeRect", scopeRect],
        ["fontSizeRect", fontSizeRect],
        ["numberButtonRect", numberButtonRect],
        ["windowRect", windowRect],
        ["clientRectScreen", clientRectScreen]
    ] {
        if !IsValidRect(entry[2]) {
            context["invalidRectangle"] := entry[1]
            return MakeColorResetResult(false, ColorResetCode.INVALID_RECTANGLE, context)
        }
    }

    if !RectContainsRect(windowRect, scopeRect, coordinateTolerance)
        || !RectContainsRect(windowRect, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(windowRect, numberButtonRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, scopeRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, numberButtonRect, coordinateTolerance) {
        context["coordinateSpaceReason"] := "uiaRectOutsideForegroundWindowClientArea"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    if !RectContainsRect(scopeRect, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(scopeRect, numberButtonRect, coordinateTolerance) {
        context["coordinateSpaceReason"] := "anchorOutsideValidatedUiaRoot"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    horizontalGap := numberButtonRect["l"] - fontSizeRect["r"]
    context["horizontalGap"] := horizontalGap
    if horizontalGap <= 0 {
        context["geometryReason"] := "fontSizeAnchorNotLeftOfNumberButton"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }

    if horizontalGap < minHorizontalGap || horizontalGap > maxHorizontalGap {
        context["geometryReason"] := "horizontalGapOutsidePlausibleRange"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }

    verticalDelta := Abs(RectCenterY(fontSizeRect) - RectCenterY(numberButtonRect))
    context["verticalCenterDelta"] := verticalDelta
    if verticalDelta > maxVerticalDelta {
        context["geometryReason"] := "anchorVerticalAlignmentImplausible"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }

    screenPoint := CalculateMedExColorArrowPoint(fontSizeRect, numberButtonRect, ratio)
    clientPoint := ConvertScreenPointToClient(screenPoint, clientRectScreen)
    toolbarRect := MakeRect(
        fontSizeRect["r"],
        Min(fontSizeRect["t"], numberButtonRect["t"]) - toolbarPadding,
        numberButtonRect["l"],
        Max(fontSizeRect["b"], numberButtonRect["b"]) + toolbarPadding
    )

    context["calculatedScreenPoint"] := screenPoint
    context["calculatedClientPoint"] := clientPoint
    context["toolbarRect"] := toolbarRect

    if !RectContainsPoint(windowRect, screenPoint)
        || !RectContainsPoint(clientRectScreen, screenPoint)
        || !RectContainsPoint(scopeRect, screenPoint) {
        context["coordinateSpaceReason"] := "calculatedPointOutsideValidatedWindowOrUiaRoot"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    clientBounds := MakeRect(0, 0, RectWidth(clientRectScreen), RectHeight(clientRectScreen))
    if !RectContainsPoint(clientBounds, clientPoint) {
        context["coordinateSpaceReason"] := "calculatedClientPointOutsideClientBounds"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    if !RectContainsPoint(toolbarRect, screenPoint) {
        context["geometryReason"] := "calculatedPointOutsideValidatedToolbarRegion"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }

    return MakeColorResetResult(true, ColorResetCode.OK, context)
}

MedExLogicOption(options, key, defaultValue) {
    if Type(options) = "Map" && options.Has(key)
        return options[key]
    return defaultValue
}
