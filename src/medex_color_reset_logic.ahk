class ColorResetCode {
    static OK := "COLOR_RESET_OK"
    static AUTOMATION_CHAIN_OK := "AUTOMATION_CHAIN_OK"
    static WRONG_PROCESS := "COLOR_RESET_WRONG_PROCESS"
    static PROCESS_NAME_UNCONFIRMED := "COLOR_RESET_PROCESS_NAME_UNCONFIRMED"
    static UIA_UNAVAILABLE := "COLOR_RESET_UIA_UNAVAILABLE"
    static DOCUMENT_NOT_FOUND := "COLOR_RESET_DOCUMENT_NOT_FOUND"
    static REGION_ANCHOR_NOT_FOUND := "COLOR_RESET_REGION_ANCHOR_NOT_FOUND"
    static REGION_ANCHOR_AMBIGUOUS := "COLOR_RESET_REGION_ANCHOR_AMBIGUOUS"
    static FONT_SIZE_ANCHOR_NOT_FOUND := "COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND"
    static FONT_SIZE_ANCHOR_AMBIGUOUS := "COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS"
    ; Retained for historical diagnostic compatibility; the production resolver no longer uses them.
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

class MedExColorResetLayoutProfile {
    static ProfileName := "medex-0.0.1-baseline"
    static RegionAnchorName := "检查所见"
    static FontSizeNamePattern := "^\d+(?:\.\d+)?px$"
    static OptionalRightAnchorName := "rAI"
    static ColorArrowOffsetX := 143
    static ColorArrowOffsetY := 0
    static MinVerticalOverlapRatio := 0.5
    static ToolbarPadding := 4
}

MakeColorResetResult(ok, code, context := 0) {
    if Type(context) != "Map"
        context := Map()
    return {ok: ok = true, code: String(code), context: context}
}

MakeRect(left, top, right, bottom) {
    return Map("l", left, "t", top, "r", right, "b", bottom)
}

MakeTextAnchor(name, rect) {
    return Map("name", String(name), "rect", rect)
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

RectWidth(rect) => rect["r"] - rect["l"]
RectHeight(rect) => rect["b"] - rect["t"]
RectCenterY(rect) => rect["t"] + RectHeight(rect) / 2

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

VerticalOverlapHeight(firstRect, secondRect) {
    return Max(0, Min(firstRect["b"], secondRect["b"]) - Max(firstRect["t"], secondRect["t"]))
}

VerticalOverlapRatio(firstRect, secondRect) {
    shorterHeight := Min(RectHeight(firstRect), RectHeight(secondRect))
    return shorterHeight > 0 ? VerticalOverlapHeight(firstRect, secondRect) / shorterHeight : 0
}

CalculateMedExColorArrowPoint(fontSizeRect, offsetX, offsetY) {
    return Map(
        "x", Round(fontSizeRect["r"] + offsetX),
        "y", Round(RectCenterY(fontSizeRect) + offsetY),
        "offsetX", offsetX,
        "offsetY", offsetY
    )
}

ConvertScreenPointToClient(screenPoint, clientRectScreen) {
    return Map(
        "x", screenPoint["x"] - clientRectScreen["l"],
        "y", screenPoint["y"] - clientRectScreen["t"]
    )
}

ResolveMedExColorResetLayout(textAnchors, clientRectScreen, options := 0) {
    profileName := MedExLogicOption(options, "profileName", MedExColorResetLayoutProfile.ProfileName)
    regionAnchorName := MedExLogicOption(options, "regionAnchorName", MedExColorResetLayoutProfile.RegionAnchorName)
    fontSizeNamePattern := MedExLogicOption(options, "fontSizeNamePattern", MedExColorResetLayoutProfile.FontSizeNamePattern)
    optionalRightAnchorName := MedExLogicOption(options, "optionalRightAnchorName", MedExColorResetLayoutProfile.OptionalRightAnchorName)
    offsetX := MedExLogicOption(options, "colorArrowOffsetX", MedExColorResetLayoutProfile.ColorArrowOffsetX)
    offsetY := MedExLogicOption(options, "colorArrowOffsetY", MedExColorResetLayoutProfile.ColorArrowOffsetY)
    minOverlapRatio := MedExLogicOption(options, "minVerticalOverlapRatio", MedExColorResetLayoutProfile.MinVerticalOverlapRatio)
    toolbarPadding := MedExLogicOption(options, "toolbarPadding", MedExColorResetLayoutProfile.ToolbarPadding)
    context := Map(
        "layoutProfileName", profileName,
        "regionAnchorName", regionAnchorName,
        "regionAnchorFound", false,
        "fontSizeAnchorPattern", fontSizeNamePattern,
        "fontSizeAnchorFound", false,
        "fontSizeCandidateCount", 0,
        "optionalRightAnchorName", optionalRightAnchorName,
        "optionalRightAnchorFound", false,
        "colorArrowOffsetX", offsetX,
        "colorArrowOffsetY", offsetY,
        "minVerticalOverlapRatio", minOverlapRatio,
        "ignoredTextAnchorCount", 0
    )

    if Type(textAnchors) != "Array" || !IsValidRect(clientRectScreen) {
        context["invalidRectangle"] := "clientRectScreenOrTextAnchors"
        return MakeColorResetResult(false, ColorResetCode.INVALID_RECTANGLE, context)
    }

    regionCandidates := []
    for anchor in textAnchors {
        if !IsValidTextAnchor(anchor) {
            context["ignoredTextAnchorCount"] += 1
            continue
        }
        if anchor["name"] = regionAnchorName && RectContainsRect(clientRectScreen, anchor["rect"])
            regionCandidates.Push(anchor)
    }
    context["regionAnchorCandidateCount"] := regionCandidates.Length
    if regionCandidates.Length = 0 {
        context["anchorSelectionReason"] := "regionAnchorNotFound"
        return MakeColorResetResult(false, ColorResetCode.REGION_ANCHOR_NOT_FOUND, context)
    }
    if regionCandidates.Length > 1 {
        context["anchorSelectionReason"] := "multipleRegionAnchors"
        return MakeColorResetResult(false, ColorResetCode.REGION_ANCHOR_AMBIGUOUS, context)
    }

    regionAnchor := regionCandidates[1]
    regionRect := regionAnchor["rect"]
    context["regionAnchorFound"] := true
    context["regionAnchorRect"] := regionRect

    fontCandidates := []
    for anchor in textAnchors {
        if !IsValidTextAnchor(anchor) || !RegExMatch(anchor["name"], fontSizeNamePattern)
            continue
        rect := anchor["rect"]
        if !RectContainsRect(clientRectScreen, rect)
            continue
        if rect["l"] <= regionRect["r"]
            continue
        overlapRatio := VerticalOverlapRatio(regionRect, rect)
        if overlapRatio < minOverlapRatio
            continue
        candidate := MakeTextAnchor(anchor["name"], rect)
        candidate["verticalOverlapRatio"] := overlapRatio
        fontCandidates.Push(candidate)
    }

    context["fontSizeCandidateCount"] := fontCandidates.Length
    if fontCandidates.Length = 0 {
        context["anchorSelectionReason"] := "alignedFontSizeAnchorNotFound"
        return MakeColorResetResult(false, ColorResetCode.FONT_SIZE_ANCHOR_NOT_FOUND, context)
    }
    if fontCandidates.Length > 1 {
        context["anchorSelectionReason"] := "multipleAlignedFontSizeAnchors"
        return MakeColorResetResult(false, ColorResetCode.FONT_SIZE_ANCHOR_AMBIGUOUS, context)
    }

    fontAnchor := fontCandidates[1]
    fontRect := fontAnchor["rect"]
    context["fontSizeAnchorFound"] := true
    context["fontSizeAnchorMatchedName"] := fontAnchor["name"]
    context["fontSizeAnchorRect"] := fontRect
    context["verticalOverlapHeight"] := VerticalOverlapHeight(regionRect, fontRect)
    context["verticalOverlapRatio"] := fontAnchor["verticalOverlapRatio"]
    context["regionToFontDistance"] := fontRect["l"] - regionRect["r"]
    context["anchorSelectionReason"] := "uniqueAlignedFontSizeAnchor"

    if !IsFiniteCoordinate(offsetX) || !IsFiniteCoordinate(offsetY) || offsetX <= 0 {
        context["geometryReason"] := "invalidColorArrowOffsets"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }

    screenPoint := CalculateMedExColorArrowPoint(fontRect, offsetX, offsetY)
    clientPoint := ConvertScreenPointToClient(screenPoint, clientRectScreen)
    toolbarBand := MakeRect(
        regionRect["l"],
        Min(regionRect["t"], fontRect["t"]) - toolbarPadding,
        clientRectScreen["r"],
        Max(regionRect["b"], fontRect["b"]) + toolbarPadding
    )
    context["calculatedScreenPoint"] := screenPoint
    context["calculatedClientPoint"] := clientPoint
    context["toolbarBandRect"] := toolbarBand

    if screenPoint["x"] <= fontRect["r"] {
        context["geometryReason"] := "calculatedPointNotRightOfFontSizeAnchor"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }
    if !RectContainsPoint(toolbarBand, screenPoint) {
        context["geometryReason"] := "calculatedPointOutsideTargetToolbarBand"
        return MakeColorResetResult(false, ColorResetCode.INVALID_GEOMETRY, context)
    }
    if !RectContainsPoint(clientRectScreen, screenPoint) {
        context["coordinateSpaceReason"] := "calculatedPointOutsideForegroundClientArea"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }
    clientBounds := MakeRect(0, 0, RectWidth(clientRectScreen), RectHeight(clientRectScreen))
    if !RectContainsPoint(clientBounds, clientPoint) {
        context["coordinateSpaceReason"] := "calculatedClientPointOutsideClientBounds"
        return MakeColorResetResult(false, ColorResetCode.INVALID_COORDINATE_SPACE, context)
    }

    ResolveOptionalRightAnchor(textAnchors, regionRect, fontRect, optionalRightAnchorName, minOverlapRatio, clientRectScreen, context)
    return MakeColorResetResult(true, ColorResetCode.OK, context)
}

ResolveOptionalRightAnchor(textAnchors, regionRect, fontRect, optionalName, minOverlapRatio, clientRectScreen, context) {
    candidates := []
    if optionalName != "" {
        for anchor in textAnchors {
            if !IsValidTextAnchor(anchor) || anchor["name"] != optionalName
                continue
            rect := anchor["rect"]
            if rect["l"] <= fontRect["r"] || !RectContainsRect(clientRectScreen, rect)
                continue
            if VerticalOverlapRatio(regionRect, rect) >= minOverlapRatio
                candidates.Push(anchor)
        }
    }
    context["optionalRightAnchorCandidateCount"] := candidates.Length
    if candidates.Length = 1 {
        optionalRect := candidates[1]["rect"]
        context["optionalRightAnchorFound"] := true
        context["optionalRightAnchorRect"] := optionalRect
        context["fontToOptionalRightDistance"] := optionalRect["l"] - fontRect["r"]
        context["optionalRightAnchorReason"] := "uniqueAlignedOptionalAnchor"
    } else if candidates.Length = 0 {
        context["optionalRightAnchorReason"] := "optionalAnchorAbsent"
    } else {
        context["optionalRightAnchorReason"] := "optionalAnchorAmbiguousIgnored"
    }
}

IsValidTextAnchor(anchor) {
    return Type(anchor) = "Map"
        && anchor.Has("name")
        && anchor.Has("rect")
        && IsValidRect(anchor["rect"])
}

MedExLogicOption(options, key, defaultValue) {
    if Type(options) = "Map" && options.Has(key)
        return options[key]
    return defaultValue
}
