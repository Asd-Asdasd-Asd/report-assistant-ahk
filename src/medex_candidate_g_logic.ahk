class CandidateGCalibrationCode {
    static ROW_OK := "CANDIDATE_G_ROW_OK"
    static UNSUPPORTED_PROFILE := "CANDIDATE_G_UNSUPPORTED_PROFILE"
    static REGION_NOT_FOUND := "CANDIDATE_G_REGION_ANCHOR_NOT_FOUND"
    static REGION_AMBIGUOUS := "CANDIDATE_G_REGION_ANCHOR_AMBIGUOUS"
    static INVALID_GEOMETRY := "CANDIDATE_G_INVALID_GEOMETRY"
}

class CandidateGCalibrationProfile {
    static ProfileName := "medex-0.0.1-1920x1080-100-calibration"
    static SupportedMedExVersion := "0.0.1.0"
    static SupportedScreenWidth := 1920
    static SupportedScreenHeight := 1080
    static SupportedDpi := 96
    static SupportedDisplayScaling := "100%"

    static RegionAnchorName := "检查所见"
    static RegionLeftMin := 272
    static RegionLeftMax := 320
    static RegionWidthMin := 40
    static RegionWidthMax := 80
    static RegionHeightMin := 10
    static RegionHeightMax := 28
    static RegionRowPadding := 6

    ; Calibration estimates only. They are not production constants.
    static EstimatedArrowOffsetX := 320
    static EstimatedArrowOffsetY := 0
    static EstimatedBlackOffsetX := 6
    static EstimatedBlackOffsetY := 83

    static FontSizeNamePattern := "^\d+(?:\.\d+)?px$"
    static OptionalRightAnchorName := "rAI"
    static CorroboratorMinVerticalOverlapRatio := 0.5
    static CorroboratorMaxRegionToFontDistance := 240
}

class CandidateGRelativeMouseProfile {
    static ProfileName := "medex-0.0.1-1920x1080-100-relative-mouse-v1"
    static SupportedMedExVersion := "0.0.1.0"
    static SupportedScreenWidth := 1920
    static SupportedScreenHeight := 1080
    static SupportedDpi := 96
    static SupportedDisplayScaling := "100%"

    static RegionAnchorName := "检查所见"
    static ArrowOffsetX := 320
    static ArrowOffsetY := 0
    static BlackOffsetX := 6
    static BlackOffsetY := 83
    static SignatureSecondSampleDelayMs := 20

    ; Privacy-safe popup signature calibrated on the supported workstation.
    static PopupLightOffsetX := 6
    static PopupLightOffsetY := 16
    static PopupLightColor := 0xFFFFFF
    static PopupLightTolerance := 4
    static BlackSwatchOffsetX := 6
    static BlackSwatchOffsetY := 83
    static BlackSwatchColor := 0x000000
    static BlackSwatchTolerance := 8
    static BeigeSwatchOffsetX := 20
    static BeigeSwatchOffsetY := 83
    static BeigeSwatchColor := 0xEEEDE2
    static BeigeSwatchTolerance := 12
    static BlueSwatchOffsetX := 40
    static BlueSwatchOffsetY := 83
    static BlueSwatchColor := 0x22447A
    static BlueSwatchTolerance := 12
}

ValidateCandidateGSupportedProfile(environment, options := 0) {
    context := Map(
        "candidateGProfileName", CandidateGLogicOption(
            options,
            "profileName",
            CandidateGCalibrationProfile.ProfileName
        ),
        "supportedProfile", false,
        "unsupportedProfileReason", ""
    )
    if Type(environment) != "Map" {
        context["unsupportedProfileReason"] := "environmentUnavailable"
        return MakeCandidateGResult(false, CandidateGCalibrationCode.UNSUPPORTED_PROFILE, context)
    }

    expected := Map(
        "medExVersion", CandidateGCalibrationProfile.SupportedMedExVersion,
        "screenWidth", CandidateGCalibrationProfile.SupportedScreenWidth,
        "screenHeight", CandidateGCalibrationProfile.SupportedScreenHeight,
        "dpi", CandidateGCalibrationProfile.SupportedDpi,
        "displayScaling", CandidateGCalibrationProfile.SupportedDisplayScaling
    )
    for key, value in expected {
        if !environment.Has(key) || String(environment[key]) != String(value) {
            context["unsupportedProfileReason"] := key "Mismatch"
            return MakeCandidateGResult(
                false,
                CandidateGCalibrationCode.UNSUPPORTED_PROFILE,
                context
            )
        }
    }

    context["supportedProfile"] := true
    return MakeCandidateGResult(true, CandidateGCalibrationCode.ROW_OK, context)
}

BuildCandidateGRuntimeLayoutOptions(options := 0) {
    return Map(
        "profileName", CandidateGLogicOption(options, "profileName", CandidateGRelativeMouseProfile.ProfileName),
        "regionAnchorName", CandidateGLogicOption(options, "regionAnchorName", CandidateGRelativeMouseProfile.RegionAnchorName),
        "arrowOffsetX", CandidateGLogicOption(options, "arrowOffsetX", CandidateGRelativeMouseProfile.ArrowOffsetX),
        "arrowOffsetY", CandidateGLogicOption(options, "arrowOffsetY", CandidateGRelativeMouseProfile.ArrowOffsetY),
        "blackOffsetX", CandidateGLogicOption(options, "blackOffsetX", CandidateGRelativeMouseProfile.BlackOffsetX),
        "blackOffsetY", CandidateGLogicOption(options, "blackOffsetY", CandidateGRelativeMouseProfile.BlackOffsetY)
    )
}

ValidateCandidateGRuntimeProfile(environment, options := 0) {
    runtimeOptions := Map(
        "profileName", CandidateGLogicOption(options, "profileName", CandidateGRelativeMouseProfile.ProfileName)
    )
    context := Map(
        "candidateGProfileName", runtimeOptions["profileName"],
        "supportedProfile", false,
        "unsupportedProfileReason", ""
    )
    if Type(environment) != "Map" {
        context["unsupportedProfileReason"] := "environmentUnavailable"
        return MakeColorResetResult(false, ColorResetCode.UNSUPPORTED_PROFILE, context)
    }
    expected := Map(
        "medExVersion", CandidateGRelativeMouseProfile.SupportedMedExVersion,
        "screenWidth", CandidateGRelativeMouseProfile.SupportedScreenWidth,
        "screenHeight", CandidateGRelativeMouseProfile.SupportedScreenHeight,
        "dpi", CandidateGRelativeMouseProfile.SupportedDpi,
        "displayScaling", CandidateGRelativeMouseProfile.SupportedDisplayScaling
    )
    for key, value in expected {
        if !environment.Has(key) || String(environment[key]) != String(value) {
            context["unsupportedProfileReason"] := key "Mismatch"
            return MakeColorResetResult(false, ColorResetCode.UNSUPPORTED_PROFILE, context)
        }
    }
    context["supportedProfile"] := true
    return MakeColorResetResult(true, ColorResetCode.OK, context)
}

CandidateGPopupSignatureSample(arrowPoint) {
    CoordMode "Pixel", "Screen"
    points := Map(
        "popupLight", Map("x", CandidateGRelativeMouseProfile.PopupLightOffsetX, "y", CandidateGRelativeMouseProfile.PopupLightOffsetY),
        "blackSwatch", Map("x", CandidateGRelativeMouseProfile.BlackSwatchOffsetX, "y", CandidateGRelativeMouseProfile.BlackSwatchOffsetY),
        "beigeSwatch", Map("x", CandidateGRelativeMouseProfile.BeigeSwatchOffsetX, "y", CandidateGRelativeMouseProfile.BeigeSwatchOffsetY),
        "blueSwatch", Map("x", CandidateGRelativeMouseProfile.BlueSwatchOffsetX, "y", CandidateGRelativeMouseProfile.BlueSwatchOffsetY)
    )
    samples := Map()
    for name, offset in points {
        try samples[name] := PixelGetColor(
            arrowPoint["x"] + offset["x"],
            arrowPoint["y"] + offset["y"],
            "RGB"
        ) & 0xFFFFFF
        catch
            samples[name] := "UNKNOWN"
    }
    return samples
}

EvaluateCandidateGPopupSignature(samples) {
    expected := [
        ["popupLight", CandidateGRelativeMouseProfile.PopupLightColor, CandidateGRelativeMouseProfile.PopupLightTolerance],
        ["blackSwatch", CandidateGRelativeMouseProfile.BlackSwatchColor, CandidateGRelativeMouseProfile.BlackSwatchTolerance],
        ["beigeSwatch", CandidateGRelativeMouseProfile.BeigeSwatchColor, CandidateGRelativeMouseProfile.BeigeSwatchTolerance],
        ["blueSwatch", CandidateGRelativeMouseProfile.BlueSwatchColor, CandidateGRelativeMouseProfile.BlueSwatchTolerance]
    ]
    if Type(samples) != "Map"
        return Map("matched", false, "reason", "samplesUnavailable")
    for requirement in expected {
        name := requirement[1]
        if !samples.Has(name) || !CandidateGRgbWithinTolerance(samples[name], requirement[2], requirement[3])
            return Map("matched", false, "reason", name "Mismatch")
    }
    return Map("matched", true, "reason", "allRequiredPixelsMatched")
}

CandidateGRgbWithinTolerance(actual, expected, tolerance) {
    if !IsNumber(actual) || !IsNumber(expected) || !IsNumber(tolerance)
        return false
    return Abs(((actual >> 16) & 0xFF) - ((expected >> 16) & 0xFF)) <= tolerance
        && Abs(((actual >> 8) & 0xFF) - ((expected >> 8) & 0xFF)) <= tolerance
        && Abs((actual & 0xFF) - (expected & 0xFF)) <= tolerance
}

ResolveCandidateGToolbarRow(textAnchors, clientRectScreen, options := 0) {
    regionName := CandidateGLogicOption(
        options,
        "regionAnchorName",
        CandidateGCalibrationProfile.RegionAnchorName
    )
    context := Map(
        "candidateGProfileName", CandidateGLogicOption(
            options,
            "profileName",
            CandidateGCalibrationProfile.ProfileName
        ),
        "regionAnchorName", regionName,
        "rawRegionAnchorCandidateCount", 0,
        "geometryValidRegionCandidateCount", 0,
        "toolbarRowCorroborationCount", 0,
        "toolbarRowSelectionReason", "",
        "regionCandidateIgnoredReasons", [],
        "regionAnchorFound", false
    )
    if Type(textAnchors) != "Array" || !IsValidRect(clientRectScreen) {
        context["toolbarRowSelectionReason"] := "invalidInput"
        return MakeCandidateGResult(false, CandidateGCalibrationCode.INVALID_GEOMETRY, context)
    }

    rawCandidates := []
    for anchor in textAnchors {
        if Type(anchor) = "Map" && anchor.Has("name") && anchor["name"] = regionName
            rawCandidates.Push(anchor)
    }
    context["rawRegionAnchorCandidateCount"] := rawCandidates.Length
    if rawCandidates.Length = 0 {
        context["toolbarRowSelectionReason"] := "regionAnchorNotFound"
        return MakeCandidateGResult(false, CandidateGCalibrationCode.REGION_NOT_FOUND, context)
    }

    geometryCandidates := []
    for index, anchor in rawCandidates {
        reason := CandidateGRegionGeometryReason(anchor, clientRectScreen, options)
        if reason != "" {
            context["regionCandidateIgnoredReasons"].Push(index ":" reason)
            continue
        }
        candidate := Map(
            "anchor", anchor,
            "corroborationCount", CandidateGToolbarRowCorroborationCount(
                anchor,
                textAnchors,
                options
            )
        )
        geometryCandidates.Push(candidate)
    }
    context["geometryValidRegionCandidateCount"] := geometryCandidates.Length
    if geometryCandidates.Length = 0 {
        context["toolbarRowSelectionReason"] := "noGeometryValidRegionAnchor"
        return MakeCandidateGResult(false, CandidateGCalibrationCode.INVALID_GEOMETRY, context)
    }

    selected := 0
    if geometryCandidates.Length = 1 {
        selected := geometryCandidates[1]
        context["toolbarRowSelectionReason"] := "uniqueGeometryValidRegionAnchor"
    } else {
        highestScore := -1
        highestCandidates := []
        for candidate in geometryCandidates {
            score := candidate["corroborationCount"]
            if score > highestScore {
                highestScore := score
                highestCandidates := [candidate]
            } else if score = highestScore {
                highestCandidates.Push(candidate)
            }
        }
        if highestScore < 1 || highestCandidates.Length != 1 {
            context["toolbarRowSelectionReason"] := highestScore < 1
                ? "multipleCandidatesWithoutCorroboration"
                : "corroborationTie"
            return MakeCandidateGResult(
                false,
                CandidateGCalibrationCode.REGION_AMBIGUOUS,
                context
            )
        }
        selected := highestCandidates[1]
        context["toolbarRowSelectionReason"] := "uniqueCorroboratedRegionAnchor"
    }

    regionAnchor := selected["anchor"]
    regionRect := regionAnchor["rect"]
    arrowPoint := CalculateCandidateGArrowPoint(regionRect, options)
    blackPoint := CalculateCandidateGBlackPoint(arrowPoint, options)
    context["toolbarRowCorroborationCount"] := selected["corroborationCount"]
    context["regionAnchorFound"] := true
    context["regionAnchorRect"] := regionRect
    context["estimatedArrowPoint"] := arrowPoint
    context["estimatedBlackPoint"] := blackPoint
    context["estimatedArrowOffsetX"] := arrowPoint["offsetX"]
    context["estimatedArrowOffsetY"] := arrowPoint["offsetY"]
    context["estimatedBlackOffsetX"] := blackPoint["offsetX"]
    context["estimatedBlackOffsetY"] := blackPoint["offsetY"]
    return MakeCandidateGResult(
        true,
        CandidateGCalibrationCode.ROW_OK,
        context,
        regionAnchor
    )
}

CandidateGRegionGeometryReason(anchor, clientRectScreen, options := 0) {
    if Type(anchor) != "Map" || !anchor.Has("rect") || !IsValidRect(anchor["rect"])
        return "invalidRectangle"
    rect := anchor["rect"]
    if !RectContainsRect(clientRectScreen, rect)
        return "outsideClient"

    leftMin := CandidateGLogicOption(options, "regionLeftMin", CandidateGCalibrationProfile.RegionLeftMin)
    leftMax := CandidateGLogicOption(options, "regionLeftMax", CandidateGCalibrationProfile.RegionLeftMax)
    widthMin := CandidateGLogicOption(options, "regionWidthMin", CandidateGCalibrationProfile.RegionWidthMin)
    widthMax := CandidateGLogicOption(options, "regionWidthMax", CandidateGCalibrationProfile.RegionWidthMax)
    heightMin := CandidateGLogicOption(options, "regionHeightMin", CandidateGCalibrationProfile.RegionHeightMin)
    heightMax := CandidateGLogicOption(options, "regionHeightMax", CandidateGCalibrationProfile.RegionHeightMax)
    if rect["l"] < leftMin || rect["l"] > leftMax
        return "leftOutsideProfile"
    if RectWidth(rect) < widthMin || RectWidth(rect) > widthMax
        return "widthOutsideProfile"
    if RectHeight(rect) < heightMin || RectHeight(rect) > heightMax
        return "heightOutsideProfile"

    arrowPoint := CalculateCandidateGArrowPoint(rect, options)
    if !RectContainsPoint(clientRectScreen, arrowPoint)
        return "arrowPointOutsideClient"
    padding := CandidateGLogicOption(options, "regionRowPadding", CandidateGCalibrationProfile.RegionRowPadding)
    rowBand := MakeRect(rect["l"], rect["t"] - padding, clientRectScreen["r"], rect["b"] + padding)
    if !RectContainsPoint(rowBand, arrowPoint)
        return "arrowPointOutsideToolbarBand"
    return ""
}

CandidateGToolbarRowCorroborationCount(regionAnchor, textAnchors, options := 0) {
    if Type(regionAnchor) != "Map" || !regionAnchor.Has("rect")
        return 0
    regionRect := regionAnchor["rect"]
    fontPattern := CandidateGLogicOption(options, "fontSizeNamePattern", CandidateGCalibrationProfile.FontSizeNamePattern)
    optionalRightName := CandidateGLogicOption(options, "optionalRightAnchorName", CandidateGCalibrationProfile.OptionalRightAnchorName)
    minOverlap := CandidateGLogicOption(options, "corroboratorMinVerticalOverlapRatio", CandidateGCalibrationProfile.CorroboratorMinVerticalOverlapRatio)
    maxFontDistance := CandidateGLogicOption(options, "corroboratorMaxRegionToFontDistance", CandidateGCalibrationProfile.CorroboratorMaxRegionToFontDistance)
    fontFound := false
    optionalRightFound := false
    for anchor in textAnchors {
        if !IsValidTextAnchor(anchor)
            continue
        rect := anchor["rect"]
        if rect["l"] <= regionRect["r"] || VerticalOverlapRatio(regionRect, rect) < minOverlap
            continue
        if !fontFound && RegExMatch(anchor["name"], fontPattern)
            && rect["l"] - regionRect["r"] <= maxFontDistance
            fontFound := true
        if !optionalRightFound && anchor["name"] = optionalRightName
            optionalRightFound := true
    }
    return (fontFound ? 1 : 0) + (optionalRightFound ? 1 : 0)
}

CalculateCandidateGArrowPoint(regionRect, options := 0) {
    offsetX := CandidateGLogicOption(options, "arrowOffsetX", CandidateGCalibrationProfile.EstimatedArrowOffsetX)
    offsetY := CandidateGLogicOption(options, "arrowOffsetY", CandidateGCalibrationProfile.EstimatedArrowOffsetY)
    return Map(
        "x", Round(regionRect["r"] + offsetX),
        "y", Round(RectCenterY(regionRect) + offsetY),
        "offsetX", offsetX,
        "offsetY", offsetY
    )
}

CalculateCandidateGBlackPoint(arrowPoint, options := 0) {
    offsetX := CandidateGLogicOption(options, "blackOffsetX", CandidateGCalibrationProfile.EstimatedBlackOffsetX)
    offsetY := CandidateGLogicOption(options, "blackOffsetY", CandidateGCalibrationProfile.EstimatedBlackOffsetY)
    return Map(
        "x", Round(arrowPoint["x"] + offsetX),
        "y", Round(arrowPoint["y"] + offsetY),
        "offsetX", offsetX,
        "offsetY", offsetY
    )
}

MakeCandidateGResult(ok, code, context := 0, selectedRegionAnchor := 0) {
    if Type(context) != "Map"
        context := Map()
    return {
        ok: ok = true,
        code: String(code),
        context: context,
        selectedRegionAnchor: selectedRegionAnchor
    }
}

CandidateGLogicOption(options, key, defaultValue) {
    if Type(options) = "Map" && options.Has(key)
        return options[key]
    return defaultValue
}
