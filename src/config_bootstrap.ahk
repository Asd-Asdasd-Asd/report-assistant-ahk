PrepareReportAssistantConfig(ReportAssistantManagedConfigDefaults())

ReportAssistantManagedConfigDefaults() {
    defaults := []
    for definition in FeatureDefaults.ManagedConfigDefaults()
        defaults.Push(definition)
    return defaults
}
