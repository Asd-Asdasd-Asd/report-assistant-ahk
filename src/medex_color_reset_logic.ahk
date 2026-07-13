class ColorResetCode {
    static OK := "COLOR_RESET_OK"
    static WRONG_PROCESS := "COLOR_RESET_WRONG_PROCESS"
    static PROCESS_NAME_UNCONFIRMED := "COLOR_RESET_PROCESS_NAME_UNCONFIRMED"
    static UIA_UNAVAILABLE := "COLOR_RESET_UIA_UNAVAILABLE"
    static DOCUMENT_NOT_FOUND := "COLOR_RESET_DOCUMENT_NOT_FOUND"
    static ANCHOR_FONT_SIZE_NOT_FOUND := "COLOR_RESET_ANCHOR_FONT_SIZE_NOT_FOUND"
    static ANCHOR_NUMBER_BUTTON_NOT_FOUND := "COLOR_RESET_ANCHOR_NUMBER_BUTTON_NOT_FOUND"
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

ValidateMedExColorResetGeometry(documentRect, fontSizeRect, numberButtonRect, windowRect, clientRectScreen, options := 0) {
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
        ["documentRect", documentRect],
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

    if !RectContainsRect(windowRect, documentRect, coordinateTolerance)
        || !RectContainsRect(windowRect, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(windowRect, numberButtonRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, documentRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(clientRectScreen, numberButtonRect, coordinateTolerance) {
        context["coordinateSpaceReason"] := "uiaRectOutsideForegroundWindowClientArea"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    if !RectContainsRect(documentRect, fontSizeRect, coordinateTolerance)
        || !RectContainsRect(documentRect, numberButtonRect, coordinateTolerance) {
        context["coordinateSpaceReason"] := "anchorOutsideDocument"
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
        || !RectContainsPoint(documentRect, screenPoint) {
        context["coordinateSpaceReason"] := "calculatedPointOutsideValidatedWindowOrDocument"
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
