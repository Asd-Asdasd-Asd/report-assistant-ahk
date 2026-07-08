; Copy this file to config.local.ahk and calibrate values on the target workstation.
; Do not store patient data, credentials, hospital identifiers, or sensitive logs here.

REPORT_EDITOR_EXE := "medexworkstation.exe"
VIEWER_EXE := "MedExNMFusion.exe"

COORDINATES := Map(
    "example_viewer_button", { x: 100, y: 100 },
    "example_report_field", { x: 200, y: 200 }
)
