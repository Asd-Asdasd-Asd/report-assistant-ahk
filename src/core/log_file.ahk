; Append-only log files under the user's config directory with size-based
; rotation. Every diagnostic log (viewer failures, automation events, montage
; progress) goes through here; writers never throw.

class ReportAssistantLogDefaults {
    static DirectoryName := "logs"
}

ReportAssistantLogPath(fileName) {
    configPath := ReportAssistantConfig.Path()
    SplitPath configPath, , &configDirectory
    return configDirectory "\" ReportAssistantLogDefaults.DirectoryName "\" fileName
}

; Appends block (already newline-terminated) to logPath, creating the directory
; and rotating first when the file has reached maxFileBytes. rotatedFileCount
; keeps logPath.1 .. logPath.N; 0 disables rotation. Returns logPath, or ""
; when the write failed.
AppendRotatedLogBlock(logPath, block, maxFileBytes := 0, rotatedFileCount := 0) {
    try {
        SplitPath logPath, , &logDirectory
        if !DirExist(logDirectory)
            DirCreate logDirectory
        if rotatedFileCount > 0
            RotateLogFile(logPath, maxFileBytes, rotatedFileCount)
        FileAppend block, logPath, "UTF-8"
        return logPath
    } catch {
        return ""
    }
}

RotateLogFile(logPath, maxFileBytes, rotatedFileCount) {
    if !FileExist(logPath)
        return
    try size := FileGetSize(logPath)
    catch
        return
    if size < maxFileBytes
        return
    Loop rotatedFileCount - 1 {
        index := rotatedFileCount - A_Index
        sourcePath := logPath "." index
        targetPath := logPath "." (index + 1)
        if FileExist(sourcePath)
            try FileMove sourcePath, targetPath, true
    }
    try FileMove logPath, logPath ".1", true
}
