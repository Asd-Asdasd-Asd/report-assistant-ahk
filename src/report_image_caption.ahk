class ReportImageCaptionDefaults {
    static CopyTimeoutSeconds := 1
    static ClipboardSettleSeconds := 0.5
    static TargetActivationTimeoutSeconds := 1
    static PasteSettleMs := 80
    static MinCaptionGapPx := 120
    static MinCaptionPaneHeightPx := 40
    static MinCaptionPaneWidthRatio := 0.4
    static MinImageRegionHeightRatio := 0.5
}

class ReportImageCaptionCode {
    static OK := "OK"
    static WRONG_FOREGROUND := "WRONG_FOREGROUND"
    static BUSY := "BUSY"
    static COPY_FAILED := "COPY_FAILED"
    static COPY_EMPTY := "COPY_EMPTY"
    static SOURCE_CHANGED := "SOURCE_CHANGED"
    static TARGET_NOT_UNIQUE := "TARGET_NOT_UNIQUE"
    static TARGET_INVALID := "TARGET_INVALID"
    static CACHE_UNAVAILABLE := "CACHE_UNAVAILABLE"
    static CLIPBOARD_WRITE_FAILED := "CLIPBOARD_WRITE_FAILED"
    static TARGET_ACTIVATION_FAILED := "TARGET_ACTIVATION_FAILED"
    static PASTE_FAILED := "PASTE_FAILED"
    static PARTIAL_SUCCESS := "PARTIAL_SUCCESS"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

global REPORT_IMAGE_CAPTION_CACHE := 0

ReportImageCaptionHotkeyDefinitions(settings) {
    if !settings.ReportImageCaptionEnabled
        || settings.ReportImageCaptionChord = "" {
        return []
    }
    chord := settings.ReportImageCaptionChord
    return [
        HotkeyDefinition(
            "report-image-caption-advance",
            chord,
            InvokeReportImageCaptionHotkey.Bind(chord)
        )
    ]
}

ReportImageCaptionForegroundActive(*) {
    try foregroundHwnd := WinExist("A")
    catch
        return false
    if !foregroundHwnd
        return false
    try processName := WinGetProcessName("ahk_id " foregroundHwnd)
    catch
        return false
    return MedExProcessNameIsApproved(
        processName,
        MedExColorResetDefaults.ProvisionalProcessNames
    )
}

InvokeReportImageCaptionHotkey(chord, *) {
    static active := false
    if active
        return

    try foregroundHwnd := WinExist("A")
    catch
        return
    if !foregroundHwnd || !ReportImageCaptionForegroundActive()
        return

    active := true
    try {
        result := ReportImageCaptionProvider.Invoke(foregroundHwnd)
        if !result.ok
            Flash(ReportImageCaptionFailureMessage(result), 1800)
    } finally {
        try KeyWait ReportImageCaptionTriggerKey(chord)
        active := false
    }
}

ReportImageCaptionTriggerKey(chord) {
    normalized := Trim(String(chord), " `t`r`n")
    if RegExMatch(normalized, "^[!+^#]+(.+)$", &match)
        return match[1]
    return normalized
}

class ReportImageCaptionProvider {
    static Busy := false

    static Invoke(foregroundHwnd := 0) {
        global REPORT_IMAGE_CAPTION_CACHE

        if this.Busy
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.BUSY
            )
        if !foregroundHwnd
            foregroundHwnd := WinExist("A")
        if !foregroundHwnd || WinExist("A") != foregroundHwnd {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.WRONG_FOREGROUND
            )
        }

        this.Busy := true
        try {
            priorCache := IsObject(REPORT_IMAGE_CAPTION_CACHE)
                ? REPORT_IMAGE_CAPTION_CACHE
                : 0
            if IsObject(priorCache)
                && priorCache.targetHwnd
                    = foregroundHwnd {
                return this.InvokeReuse(
                    foregroundHwnd,
                    priorCache
                )
            }
            return this.InvokeCapture(foregroundHwnd, priorCache)
        } catch {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.UNEXPECTED_ERROR
            )
        } finally {
            this.Busy := false
        }
    }

    static InvokeCapture(sourceHwnd, priorCache := 0) {
        global REPORT_IMAGE_CAPTION_CACHE

        sourcePid := ReportImageCaptionWindowPid(sourceHwnd)
        sourceProcess := ReportImageCaptionWindowProcess(sourceHwnd)
        if !sourcePid
            || !MedExProcessNameIsApproved(
                sourceProcess,
                MedExColorResetDefaults.ProvisionalProcessNames
            ) {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.WRONG_FOREGROUND
            )
        }

        capture := CaptureFreshReportImageCaption(sourceHwnd)
        if !capture.ok {
            ClearReportImageCaptionCache(false)
            return capture
        }

        target := ReportImageCaptionSourceBindingValid(
            priorCache,
            sourceHwnd
        )
            ? ResolveCachedReportImageCaptionTarget(
                priorCache,
                priorCache.targetHwnd
            )
            : {ok: false}
        if !target.ok {
            target := ResolveReportImageCaptionTarget(
                sourceHwnd,
                sourcePid
            )
        }
        if !target.ok {
            ClearReportImageCaptionCache(false)
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.TARGET_NOT_UNIQUE,
                false,
                target.candidateCount
            )
        }
        if WinExist("A") != sourceHwnd {
            ClearReportImageCaptionCache(false)
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.SOURCE_CHANGED
            )
        }

        REPORT_IMAGE_CAPTION_CACHE := {
            payload: capture.payload,
            sourceHwnd: sourceHwnd,
            sourcePid: sourcePid,
            targetHwnd: target.hwnd,
            targetPid: target.pid,
            targetClientRectKey: ReportImageCaptionRectKey(
                ReportImageCaptionClientRect(target.hwnd)
            ),
            captionPoint: target.captionPoint,
            imagePoint: target.imagePoint
        }
        return ExecuteReportImageCaptionAction(
            REPORT_IMAGE_CAPTION_CACHE,
            target,
            sourceHwnd
        )
    }

    static InvokeReuse(targetHwnd, cache) {
        if !ReportImageCaptionCacheBindingValid(cache, targetHwnd) {
            ClearReportImageCaptionCache(false)
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.CACHE_UNAVAILABLE
            )
        }

        target := ResolveCachedReportImageCaptionTarget(
            cache,
            targetHwnd
        )
        if !target.ok {
            ClearReportImageCaptionCache(false)
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.TARGET_INVALID
            )
        }
        return ExecuteReportImageCaptionAction(
            cache,
            target,
            targetHwnd
        )
    }
}

CaptureFreshReportImageCaption(sourceHwnd) {
    try {
        A_Clipboard := ""
        SendInput "^c"
        if !ClipWait(ReportImageCaptionDefaults.CopyTimeoutSeconds) {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.COPY_FAILED
            )
        }
        if WinExist("A") != sourceHwnd {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.SOURCE_CHANGED
            )
        }
        copiedText := A_Clipboard
        if Trim(copiedText, " `t`r`n") = "" {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.COPY_EMPTY
            )
        }
        payload := ClipboardAll()
        return {
            ok: true,
            code: ReportImageCaptionCode.OK,
            payload: payload,
            pasteDispatched: false,
            candidateCount: 0
        }
    } catch {
        return MakeReportImageCaptionResult(
            false,
            ReportImageCaptionCode.COPY_FAILED
        )
    }
}

ResolveReportImageCaptionTarget(sourceHwnd, sourcePid) {
    matches := []
    try windows := WinGetList("ahk_pid " sourcePid)
    catch
        windows := []
    for hwnd in windows {
        if hwnd = sourceHwnd
            continue
        if !ReportImageCaptionTopLevelWindowEligible(hwnd, sourcePid)
            continue
        candidate := BuildReportImageCaptionTargetCandidate(
            hwnd,
            sourcePid
        )
        if candidate.ok
            matches.Push(candidate)
    }
    if matches.Length != 1 {
        return {
            ok: false,
            hwnd: 0,
            pid: sourcePid,
            candidateCount: matches.Length
        }
    }
    matches[1].candidateCount := 1
    return matches[1]
}

ResolveCachedReportImageCaptionTarget(cache, targetHwnd) {
    failure := {
        ok: false,
        hwnd: targetHwnd,
        pid: cache.targetPid,
        candidateCount: 0,
        captionPoint: 0,
        imagePoint: 0
    }
    if !ReportImageCaptionTopLevelWindowEligible(
        targetHwnd,
        cache.targetPid
    ) || !cache.HasOwnProp("captionPoint")
        || !cache.HasOwnProp("imagePoint")
        || !cache.HasOwnProp("targetClientRectKey")
        || cache.targetClientRectKey
            != ReportImageCaptionRectKey(
                ReportImageCaptionClientRect(targetHwnd)
            )
        || !ReportImageCaptionPointBelongsToTarget(
            targetHwnd,
            cache.captionPoint
        )
        || !ReportImageCaptionPointBelongsToTarget(
            targetHwnd,
            cache.imagePoint
        ) {
        return failure
    }
    return {
        ok: true,
        hwnd: targetHwnd,
        pid: cache.targetPid,
        candidateCount: 1,
        captionPoint: cache.captionPoint,
        imagePoint: cache.imagePoint
    }
}

ReportImageCaptionTopLevelWindowEligible(hwnd, expectedPid) {
    if !hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return false
    if !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        return false
    if ReportImageCaptionWindowPid(hwnd) != expectedPid
        return false
    try className := WinGetClass("ahk_id " hwnd)
    catch
        return false
    if className != "Chrome_WidgetWin_1"
        return false
    return ReportImageCaptionRootOwner(hwnd) = hwnd
}

BuildReportImageCaptionTargetCandidate(hwnd, expectedPid) {
    failure := {
        ok: false,
        hwnd: hwnd,
        pid: expectedPid,
        candidateCount: 0,
        captionPoint: 0,
        imagePoint: 0
    }
    try {
        clientRect := ReportImageCaptionClientRect(hwnd)
        if !IsObject(clientRect)
            return failure
        clientWidth := ReportImageCaptionRectWidth(clientRect)
        clientHeight := ReportImageCaptionRectHeight(clientRect)
        if clientWidth <= 0 || clientHeight <= 0
            return failure

        root := ReportImageCaptionUiaRoot(hwnd)
        if !IsObject(root)
            return failure

        descriptionElements := root.FindElements({
            Type: "Text",
            Name: "图像描述"
        })
        saveElements := root.FindElements({
            Type: "Button",
            Name: "保存"
        })
        if descriptionElements.Length != 1
            || saveElements.Length != 1 {
            return failure
        }
        description := descriptionElements[1]
        saveButton := saveElements[1]
        if !ReportImageCaptionElementUsable(
            description,
            expectedPid
        ) || !ReportImageCaptionElementUsable(
            saveButton,
            expectedPid
        ) {
            return failure
        }

        descriptionRect :=
            ReportImageCaptionElementRect(description)
        saveRect := ReportImageCaptionElementRect(saveButton)
        if !IsObject(descriptionRect)
            || !IsObject(saveRect)
            || !ReportImageCaptionRectContainsRect(
                clientRect,
                descriptionRect
            )
            || !ReportImageCaptionRectContainsRect(
                clientRect,
                saveRect
            ) {
            return failure
        }
        if descriptionRect.t
                < clientRect.t + clientHeight * 0.7
            || saveRect.t < descriptionRect.t
            || saveRect.l <= descriptionRect.r
            || saveRect.l - descriptionRect.r
                < ReportImageCaptionDefaults.MinCaptionGapPx {
            return failure
        }

        captionPoint := {
            x: Round(
                descriptionRect.r
                    + (saveRect.l - descriptionRect.r) * 0.45
            ),
            y: Round((saveRect.t + saveRect.b) / 2)
        }
        captionPaneResult := ResolveReportImageCaptionPane(
            root,
            captionPoint,
            clientRect,
            descriptionRect,
            saveRect,
            expectedPid
        )
        if !captionPaneResult.ok
            return failure
        paneRect := captionPaneResult.rect

        imageResult := ResolveReportImageCaptionImagePoint(
            clientRect,
            paneRect,
            descriptionRect
        )
        if !imageResult.ok
            return failure

        return {
            ok: true,
            hwnd: hwnd,
            pid: expectedPid,
            candidateCount: 1,
            captionPoint: captionPoint,
            imagePoint: imageResult.point
        }
    } catch {
        return failure
    }
}

ResolveReportImageCaptionPane(
    root,
    captionPoint,
    clientRect,
    descriptionRect,
    saveRect,
    expectedPid
) {
    matches := []
    clientWidth := ReportImageCaptionRectWidth(clientRect)
    try panes := root.FindElements({Type: "Pane"})
    catch
        panes := []
    for pane in panes {
        if !ReportImageCaptionElementUsable(pane, expectedPid)
            continue
        paneRect := ReportImageCaptionElementRect(pane)
        if !IsObject(paneRect)
            || !ReportImageCaptionRectContainsRect(
                clientRect,
                paneRect
            )
            || !ReportImageCaptionRectContainsPoint(
                paneRect,
                captionPoint
            )
            || ReportImageCaptionRectWidth(paneRect)
                < clientWidth
                    * ReportImageCaptionDefaults.MinCaptionPaneWidthRatio
            || ReportImageCaptionRectHeight(paneRect)
                < ReportImageCaptionDefaults.MinCaptionPaneHeightPx
            || paneRect.l > descriptionRect.l
            || paneRect.r < saveRect.r
            || paneRect.t <= descriptionRect.t
            || paneRect.t > descriptionRect.b + 40
            || paneRect.b < saveRect.b {
            continue
        }
        matches.Push(paneRect)
    }
    if matches.Length != 1
        return {ok: false, rect: 0, candidateCount: matches.Length}
    return {ok: true, rect: matches[1], candidateCount: 1}
}

ResolveReportImageCaptionImagePoint(
    clientRect,
    captionPaneRect,
    descriptionRect
) {
    clientHeight := ReportImageCaptionRectHeight(clientRect)
    imageRegionHeight := descriptionRect.t - clientRect.t
    if imageRegionHeight
            < clientHeight
                * ReportImageCaptionDefaults.MinImageRegionHeightRatio {
        return {ok: false, point: 0, candidateCount: 0}
    }
    point := {
        x: Round((captionPaneRect.l + captionPaneRect.r) / 2),
        y: Round(clientRect.t + imageRegionHeight * 0.5)
    }
    if !ReportImageCaptionRectContainsPoint(clientRect, point)
        || !ReportImageCaptionRectContainsPoint(
            {
                l: captionPaneRect.l,
                t: clientRect.t,
                r: captionPaneRect.r,
                b: descriptionRect.t
            },
            point
        ) {
        return {ok: false, point: 0, candidateCount: 0}
    }
    return {
        ok: true,
        point: point,
        candidateCount: 1
    }
}

ExecuteReportImageCaptionAction(cache, target, expectedForegroundHwnd) {
    CoordMode "Mouse", "Screen"
    MouseGetPos &originalX, &originalY
    pasteDispatched := false
    try {
        if WinExist("A") != expectedForegroundHwnd {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.SOURCE_CHANGED
            )
        }
        if !SetReportImageCaptionClipboard(cache.payload) {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.CLIPBOARD_WRITE_FAILED
            )
        }
        if WinExist("A") != target.hwnd {
            try WinActivate "ahk_id " target.hwnd
            catch {
                return MakeReportImageCaptionResult(
                    false,
                    ReportImageCaptionCode.TARGET_ACTIVATION_FAILED
                )
            }
            if !WinWaitActive(
                "ahk_id " target.hwnd,
                ,
                ReportImageCaptionDefaults.TargetActivationTimeoutSeconds
            ) {
                return MakeReportImageCaptionResult(
                    false,
                    ReportImageCaptionCode.TARGET_ACTIVATION_FAILED
                )
            }
        }
        if ReportImageCaptionWindowPid(target.hwnd) != target.pid {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.TARGET_INVALID
            )
        }
        if !ReportImageCaptionPointBelongsToTarget(
            target.hwnd,
            target.captionPoint
        ) {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.TARGET_INVALID
            )
        }
        MouseClick(
            "left",
            target.captionPoint.x,
            target.captionPoint.y,
            1,
            0
        )
        if WinExist("A") != target.hwnd {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.TARGET_ACTIVATION_FAILED
            )
        }

        try {
            SendInput "^a"
            SendInput "^v"
        } catch {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.PASTE_FAILED
            )
        }
        pasteDispatched := true
        Sleep ReportImageCaptionDefaults.PasteSettleMs

        if WinExist("A") != target.hwnd
            || !ReportImageCaptionPointBelongsToTarget(
                target.hwnd,
                target.imagePoint
            ) {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.PARTIAL_SUCCESS,
                true
            )
        }
        try {
            MouseMove(
                target.imagePoint.x,
                target.imagePoint.y,
                0
            )
            SendInput "{WheelDown}"
        } catch {
            return MakeReportImageCaptionResult(
                false,
                ReportImageCaptionCode.PARTIAL_SUCCESS,
                true
            )
        }
        return MakeReportImageCaptionResult(
            true,
            ReportImageCaptionCode.OK,
            true
        )
    } catch {
        return MakeReportImageCaptionResult(
            false,
            pasteDispatched
                ? ReportImageCaptionCode.PARTIAL_SUCCESS
                : ReportImageCaptionCode.UNEXPECTED_ERROR,
            pasteDispatched
        )
    } finally {
        MouseMove originalX, originalY, 0
    }
}

SetReportImageCaptionClipboard(payload) {
    try {
        A_Clipboard := payload
        return ClipWait(
            ReportImageCaptionDefaults.ClipboardSettleSeconds
        )
    }
    return false
}

ReportImageCaptionCacheBindingValid(cache, foregroundHwnd) {
    if !IsObject(cache)
        || !cache.HasOwnProp("payload")
        || !cache.HasOwnProp("sourceHwnd")
        || !cache.HasOwnProp("sourcePid")
        || !cache.HasOwnProp("targetHwnd")
        || !cache.HasOwnProp("targetPid")
        || !cache.HasOwnProp("targetClientRectKey")
        || !cache.HasOwnProp("captionPoint")
        || !cache.HasOwnProp("imagePoint") {
        return false
    }
    if foregroundHwnd != cache.targetHwnd
        || ReportImageCaptionWindowPid(cache.targetHwnd)
            != cache.targetPid
        || ReportImageCaptionRootOwner(cache.targetHwnd)
            != cache.targetHwnd {
        return false
    }
    return ReportImageCaptionWindowPid(cache.sourceHwnd)
        = cache.sourcePid
}

ReportImageCaptionSourceBindingValid(cache, sourceHwnd) {
    return IsObject(cache)
        && cache.HasOwnProp("sourceHwnd")
        && cache.HasOwnProp("sourcePid")
        && cache.HasOwnProp("targetHwnd")
        && cache.HasOwnProp("targetPid")
        && cache.HasOwnProp("targetClientRectKey")
        && cache.HasOwnProp("captionPoint")
        && cache.HasOwnProp("imagePoint")
        && sourceHwnd = cache.sourceHwnd
        && ReportImageCaptionWindowPid(sourceHwnd)
            = cache.sourcePid
        && ReportImageCaptionWindowPid(cache.targetHwnd)
            = cache.targetPid
}

ClearReportImageCaptionCache(showFeedback := true, *) {
    global REPORT_IMAGE_CAPTION_CACHE

    if IsObject(REPORT_IMAGE_CAPTION_CACHE)
        REPORT_IMAGE_CAPTION_CACHE.payload := ""
    REPORT_IMAGE_CAPTION_CACHE := 0
    if showFeedback
        Flash("快速标图 caption 已清除", 1200)
}

ReportImageCaptionUiaRoot(hwnd) {
    try return UIA.ElementFromChromium("ahk_id " hwnd)
    catch {
        try return UIA.ElementFromHandle(hwnd, , false)
    }
    return 0
}

ReportImageCaptionElementUsable(element, expectedPid) {
    try return element.ProcessId = expectedPid
        && element.IsEnabled = true
        && element.IsOffscreen != true
    return false
}

ReportImageCaptionElementRect(element) {
    try rectangle := element.BoundingRectangle
    catch
        return 0
    return {
        l: rectangle.l,
        t: rectangle.t,
        r: rectangle.r,
        b: rectangle.b
    }
}

ReportImageCaptionClientRect(hwnd) {
    try {
        WinGetClientPos(
            &x,
            &y,
            &width,
            &height,
            "ahk_id " hwnd
        )
        return {l: x, t: y, r: x + width, b: y + height}
    }
    return 0
}

ReportImageCaptionPointBelongsToTarget(targetHwnd, point) {
    clientRect := ReportImageCaptionClientRect(targetHwnd)
    if !IsObject(clientRect)
        || !ReportImageCaptionRectContainsPoint(clientRect, point) {
        return false
    }
    pointHwnd := ReportImageCaptionWindowFromPoint(point)
    return pointHwnd
        && ReportImageCaptionRootOwner(pointHwnd) = targetHwnd
}

ReportImageCaptionWindowFromPoint(point) {
    packedPoint := point.y << 32 | (point.x & 0xFFFFFFFF)
    return DllCall(
        "User32\WindowFromPoint",
        "Int64",
        packedPoint,
        "Ptr"
    )
}

ReportImageCaptionRootOwner(hwnd) {
    if !hwnd
        return 0
    return DllCall(
        "User32\GetAncestor",
        "Ptr",
        hwnd,
        "UInt",
        3,
        "Ptr"
    )
}

ReportImageCaptionWindowPid(hwnd) {
    if !hwnd
        return 0
    try return WinGetPID("ahk_id " hwnd)
    return 0
}

ReportImageCaptionWindowProcess(hwnd) {
    if !hwnd
        return ""
    try return WinGetProcessName("ahk_id " hwnd)
    return ""
}

ReportImageCaptionRectWidth(rect) {
    return Max(0, rect.r - rect.l)
}

ReportImageCaptionRectHeight(rect) {
    return Max(0, rect.b - rect.t)
}

ReportImageCaptionRectKey(rect) {
    return IsObject(rect)
        ? rect.l "," rect.t "," rect.r "," rect.b
        : ""
}

ReportImageCaptionRectContainsPoint(rect, point) {
    return point.x >= rect.l
        && point.x < rect.r
        && point.y >= rect.t
        && point.y < rect.b
}

ReportImageCaptionRectContainsRect(outer, inner) {
    return inner.l >= outer.l
        && inner.t >= outer.t
        && inner.r <= outer.r
        && inner.b <= outer.b
        && inner.r > inner.l
        && inner.b > inner.t
}

MakeReportImageCaptionResult(
    ok,
    code,
    pasteDispatched := false,
    candidateCount := 0
) {
    return {
        ok: ok = true,
        code: code,
        pasteDispatched: pasteDispatched = true,
        candidateCount: candidateCount
    }
}

ReportImageCaptionFailureMessage(result) {
    if result.code = ReportImageCaptionCode.COPY_FAILED
        || result.code = ReportImageCaptionCode.COPY_EMPTY {
        return "未复制到报告文字，快速标图未执行"
    }
    if result.code = ReportImageCaptionCode.SOURCE_CHANGED
        return "报告窗口已变化，快速标图未执行"
    if result.code = ReportImageCaptionCode.TARGET_NOT_UNIQUE
        return "未唯一找到报告图像窗口（"
            . result.candidateCount
            . "）"
    if result.code = ReportImageCaptionCode.CACHE_UNAVAILABLE
        return "快速标图 caption 已失效，请重新选择文字"
    if result.code = ReportImageCaptionCode.TARGET_INVALID
        return "报告图像窗口结构校验失败，未执行"
    if result.code = ReportImageCaptionCode.CLIPBOARD_WRITE_FAILED
        return "caption 写入剪贴板失败，未执行"
    if result.code = ReportImageCaptionCode.TARGET_ACTIVATION_FAILED
        return "报告图像窗口未激活，未执行粘贴"
    if result.code = ReportImageCaptionCode.PASTE_FAILED
        return "caption 粘贴失败"
    if result.code = ReportImageCaptionCode.PARTIAL_SUCCESS
        return "caption 已粘贴，但未能翻到下一张"
    if result.code = ReportImageCaptionCode.BUSY
        return "快速标图正在执行"
    return "快速标图失败"
}
