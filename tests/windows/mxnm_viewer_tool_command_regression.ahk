#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_config_path_cache.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk

RunMxNMViewerToolCommandRegression()

RunMxNMViewerToolCommandRegression() {
    valid := ParseMxNMSCBtnPadCommands(
        BuildMxNMViewerToolFixture([
            "21043",
            "21044",
            "21048",
            "21078",
            "21077",
            "21193"
        ])
    )
    AssertMxNMViewerTool(valid.ok, "valid vertical rows")
    AssertMxNMViewerTool(valid.rowCount = 6, "row count")
    AssertMxNMViewerTool(
        FindMxNMViewerToolFixtureCommand(valid, 21048).row = 3,
        "length row"
    )

    horizontal := ParseMxNMSCBtnPadCommands(
        BuildMxNMViewerToolFixture([
            "21043 | 21048 | 21193"
        ])
    )
    AssertMxNMViewerTool(horizontal.ok, "horizontal row")
    AssertMxNMViewerTool(
        FindMxNMViewerToolFixtureCommand(horizontal, 21193).column = 3,
        "horizontal column"
    )

    reordered := ParseMxNMSCBtnPadCommands(
        BuildMxNMViewerToolFixture([
            "99999",
            "21193",
            "21043",
            "21048"
        ])
    )
    AssertMxNMViewerTool(reordered.ok, "extra and reordered rows")
    AssertMxNMViewerTool(
        FindMxNMViewerToolFixtureCommand(reordered, 21043).row = 3,
        "reordered arrow row"
    )

    missingRow := ParseMxNMSCBtnPadCommands(
        "[SCBtnPadSetting]`nRowNum=2`nRow1=21043"
    )
    AssertMxNMViewerTool(!missingRow.ok, "missing row rejected")

    duplicateRow := ParseMxNMSCBtnPadCommands(
        "[SCBtnPadSetting]`nRowNum=1`nRow1=21043`nRow1=21048"
    )
    AssertMxNMViewerTool(!duplicateRow.ok, "duplicate row rejected")

    malformed := ParseMxNMSCBtnPadCommands(
        "[ShowSetting]`nSCBtnPadPosX=280`nSCBtnPadPosY=360`n"
        . "[SCBtnPadSetting]`nRowNum=1`nRow1=21043|bad"
    )
    AssertMxNMViewerTool(!malformed.ok, "malformed command rejected")

    mapped := MapMxNMViewerToolPointToRuntimeFrame(
        {x: 280, y: 360},
        {x: 17, y: 131},
        {frameWidth: 1348, frameHeight: 1000},
        {
            windowX: 1920,
            windowY: 0,
            windowWidth: 2561,
            windowHeight: 1440
        }
    )
    AssertMxNMViewerTool(
        mapped.x = 2469 && mapped.y = 649,
        "observed arrow center mapping"
    )
    mappedLength := MapMxNMViewerToolPointToRuntimeFrame(
        {x: 280, y: 360},
        {x: 17, y: 207},
        {frameWidth: 1348, frameHeight: 1000},
        {
            windowX: 1920,
            windowY: 0,
            windowWidth: 2561,
            windowHeight: 1440
        }
    )
    AssertMxNMViewerTool(
        mappedLength.x = 2469 && mappedLength.y = 725,
        "observed length center mapping"
    )
    mappedSuv3D := MapMxNMViewerToolPointToRuntimeFrame(
        {x: 280, y: 360},
        {x: 17, y: 321},
        {frameWidth: 1348, frameHeight: 1000},
        {
            windowX: 1920,
            windowY: 0,
            windowWidth: 2561,
            windowHeight: 1440
        }
    )
    AssertMxNMViewerTool(
        mappedSuv3D.x = 2469 && mappedSuv3D.y = 839,
        "observed 3D SUV center mapping"
    )

    ToolTip "Viewer 工具命令配置回归通过"
    SetTimer (() => ToolTip()), -2500
}

BuildMxNMViewerToolFixture(rows) {
    text := "[Other]`nRowNum=99`n"
        . "[ShowSetting]`n"
        . "SCBtnPadPosX=280`n"
        . "SCBtnPadPosY=360`n"
        . "[SCBtnPadSetting]`n"
        . "RowNum=" rows.Length "`n"
    for rowIndex, value in rows
        text .= "Row" rowIndex "=" value "`n"
    return text
}

FindMxNMViewerToolFixtureCommand(parsed, commandId) {
    for entry in parsed.entries {
        if entry.commandId = commandId
            return entry
    }
    return {row: 0, column: 0, commandId: 0}
}

AssertMxNMViewerTool(condition, message) {
    if !condition
        throw Error("Viewer tool command regression failed: " message)
}
