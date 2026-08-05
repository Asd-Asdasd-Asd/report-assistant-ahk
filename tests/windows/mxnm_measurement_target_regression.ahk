#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk

RunMxNMMeasurementTargetRegression()

RunMxNMMeasurementTargetRegression() {
    mainGeometry := {
        imageSizeResolved: true,
        imageWidth: 100,
        imageHeight: 100
    }

    validEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 100, height: 100}],
        [
            {left: 0, top: 0, width: 50, height: 50},
            {left: 50, top: 0, width: 50, height: 50},
            {left: 0, top: 50, width: 50, height: 50},
            {left: 50, top: 50, width: 50, height: 50}
        ]
    ])
    parsed := ParseMxNMDeclaredLayoutModels(
        validEntries,
        mainGeometry
    )
    AssertMxNMTarget(parsed.ok, "valid layout schema")
    AssertMxNMTarget(parsed.modelCount = 2, "declared model count")
    safePoint := FindMxNMCrossLayoutSafePoint(
        parsed.models,
        100,
        100
    )
    AssertMxNMTarget(safePoint.ok, "safe point exists")
    AssertMxNMTarget(
        safePoint.point.x = 25 && safePoint.point.y = 25,
        "deterministic top-left tie break"
    )
    AssertMxNMTarget(
        safePoint.minimumClearance = 25,
        "maximin clearance"
    )

    clippedEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 100, height: 101}]
    ])
    clipped := ParseMxNMDeclaredLayoutModels(
        clippedEntries,
        mainGeometry
    )
    AssertMxNMTarget(clipped.ok, "one-percent clipping")
    AssertMxNMTarget(
        clipped.models[1].panes[1].bottom = 100,
        "clipped bottom"
    )

    fieldGeometry := {
        imageSizeResolved: true,
        imageWidth: 750,
        imageHeight: 938
    }
    fieldClippedEntries := BuildMxNMTargetFixtureEntries([
        [
            {left: 0, top: 0, width: 750, height: 938},
            {left: 0, top: 475, width: 372, height: 475},
            {left: 372, top: 475, width: 372, height: 475}
        ]
    ])
    fieldClipped := ParseMxNMDeclaredLayoutModels(
        fieldClippedEntries,
        fieldGeometry
    )
    AssertMxNMTarget(
        fieldClipped.ok,
        "field-observed twelve-pixel clipping"
    )
    AssertMxNMTarget(
        fieldClipped.models[1].panes[2].bottom = 938
            && fieldClipped.models[1].panes[3].bottom = 938,
        "field-observed panes clipped to image bottom"
    )

    excessiveClippingEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 750, height: 955}]
    ])
    excessiveClipping := ParseMxNMDeclaredLayoutModels(
        excessiveClippingEntries,
        fieldGeometry
    )
    AssertMxNMTarget(
        !excessiveClipping.ok,
        "clipping beyond bounded cap fails closed"
    )

    malformedEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 100, height: 100}]
    ])
    malformedEntries.Pop()
    malformed := ParseMxNMDeclaredLayoutModels(
        malformedEntries,
        mainGeometry
    )
    AssertMxNMTarget(!malformed.ok, "missing pane field")

    duplicateEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 100, height: 100}]
    ])
    duplicateEntries.Push(
        MxNMTargetFixtureEntry(
            "ShowModel1",
            "LowWndWidth_1",
            100
        )
    )
    duplicate := ParseMxNMDeclaredLayoutModels(
        duplicateEntries,
        mainGeometry
    )
    AssertMxNMTarget(!duplicate.ok, "duplicate pane field")

    disjointEntries := BuildMxNMTargetFixtureEntries([
        [{left: 0, top: 0, width: 40, height: 100}],
        [{left: 60, top: 0, width: 40, height: 100}]
    ])
    disjoint := ParseMxNMDeclaredLayoutModels(
        disjointEntries,
        mainGeometry
    )
    disjointPoint := FindMxNMCrossLayoutSafePoint(
        disjoint.models,
        100,
        100
    )
    AssertMxNMTarget(!disjointPoint.ok, "no shared safe point")

    lowClearanceEntries := BuildMxNMTargetFixtureEntries([
        [
            {left: 0, top: 0, width: 8, height: 100},
            {left: 8, top: 0, width: 92, height: 100}
        ],
        [{left: 0, top: 0, width: 8, height: 100}]
    ])
    lowClearance := ParseMxNMDeclaredLayoutModels(
        lowClearanceEntries,
        mainGeometry
    )
    lowClearancePoint := FindMxNMCrossLayoutSafePoint(
        lowClearance.models,
        100,
        100
    )
    AssertMxNMTarget(
        !lowClearancePoint.ok,
        "five-percent clearance gate"
    )

    ToolTip "MxNM 自动目标纯逻辑回归通过"
    SetTimer (() => ToolTip()), -2500
}

BuildMxNMTargetFixtureEntries(models) {
    entries := [
        MxNMTargetFixtureEntry(
            "ShowModelGroup",
            "ShowModelSize",
            models.Length
        )
    ]
    for modelIndex, panes in models {
        section := "ShowModel" modelIndex
        entries.Push(
            MxNMTargetFixtureEntry(
                section,
                "LowWndSize",
                panes.Length
            )
        )
        for paneIndex, pane in panes {
            entries.Push(
                MxNMTargetFixtureEntry(
                    section,
                    "LowWndLeft_" paneIndex,
                    pane.left
                )
            )
            entries.Push(
                MxNMTargetFixtureEntry(
                    section,
                    "LowWndTop_" paneIndex,
                    pane.top
                )
            )
            entries.Push(
                MxNMTargetFixtureEntry(
                    section,
                    "LowWndWidth_" paneIndex,
                    pane.width
                )
            )
            entries.Push(
                MxNMTargetFixtureEntry(
                    section,
                    "LowWndHeight_" paneIndex,
                    pane.height
                )
            )
        }
    }
    return entries
}

MxNMTargetFixtureEntry(section, key, value) {
    return {
        source: "MxPetCtTemp",
        section: section,
        key: key,
        value: String(value)
    }
}

AssertMxNMTarget(condition, label) {
    if !condition
        throw Error("MxNM target regression failed: " label)
}
