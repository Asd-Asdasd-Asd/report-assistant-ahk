LoadFeatureSettings(configPath := "") {
    return NormalizeFeatureSettings(LoadRawFeatureSettings(configPath))
}

NormalizeFeatureSettings(raw) {
    return FeatureSettings(
        ParseOptionalFeatureEnabled(raw.GlobalHjklArrows)
    )
}

ParseOptionalFeatureEnabled(value) {
    normalized := StrLower(Trim(value, " `t`r`n"))
    return normalized = "true"
}
