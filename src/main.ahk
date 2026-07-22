#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn

#Include app_metadata.ahk
#Include app_config.ahk
#Include app_startup.ahk
#Include config.example.ahk
#Include *i config.local.ahk
#Include window_guard.ahk
#Include utils.ahk
#Include clipboard_html.ahk
#Include <UIA>
#Include medex_color_reset_logic.ahk
#Include medex_candidate_g_logic.ahk
#Include machine_profile.ahk
#Include diagnostics.ahk
#Include adapters\medex_report_editor.ahk
#Include medex_calibration.ahk
#Include report_editor.ahk
#Include viewer_actions.ahk
#Include feature_model.ahk
#Include hotstring_model.ahk
#Include hotstring_config.ahk
#Include hotstring_config_editor.ahk
#Include config_reconciliation.ahk
#Include config_bootstrap.ahk
#Include hotstring_normalization.ahk
#Include hotstring_registration.ahk
#Include hotstrings.ahk
#Include feature_config.ahk
#Include feature_normalization.ahk
#Include hotkey_registration.ahk
#Include global_hjkl_arrows.ahk
#Include features.ahk
#Include settings_ui.ahk
#Include tray_menu.ahk

ConfigureReportAssistantTrayMenu()

#SuspendExempt

^!Esc::
{
    Suspend -1
    if A_IsSuspended
        Flash("Report Assistant suspended")
    else
        Flash("Report Assistant active")
}

^!q::
{
    ExitApp
}

#SuspendExempt False

^!F8::AdvanceMedExCalibration()

#HotIf MedExCalibrationActive()
Esc::CancelMedExCalibration()
#HotIf

Flash("Report Assistant AHK loaded")
