FocusViewer() {
    return RequireViewer()
}

ViewerActionPlaceholder(actionName := "viewer action") {
    ; Viewer actions are coordinate-sensitive and require local calibration.
    ; Legacy click sequences should be migrated one workflow at a time.
    Flash(actionName " is not implemented")
    return false
}

ExampleCalibratedViewerClick() {
    ; Example migration pattern:
    ; if RequireViewer()
    ;     ClickPoint("example_viewer_button")
    return ViewerActionPlaceholder("Example viewer click")
}
