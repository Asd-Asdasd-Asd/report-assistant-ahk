; Exception-safe wrappers around User32 window queries plus small rectangle
; helpers. Modules that need a window's PID, root owner, class name or screen
; rectangle call these instead of repeating DllCall boilerplate.
;
; Conventions:
; - Every Win32* query returns 0 / "" / false on failure and never throws.
; - Win32* rectangles are {left, top, right, bottom} in screen coordinates.
;   RectLTRB() converts to the short {l, t, r, b} form that some modules keep;
;   the Rect* predicates accept both forms and Map("l", ...) rects.
; - Point containment is half-open: left/top inclusive, right/bottom exclusive.

class Win32Ancestor {
    static ROOT := 2
    static ROOT_OWNER := 3
}

Win32ForegroundHwnd() {
    try return WinExist("A")
    catch
        return 0
}

Win32ForegroundProcessName() {
    return Win32WindowProcessName(Win32ForegroundHwnd())
}

Win32WindowProcessName(hwnd) {
    if !hwnd
        return ""
    try return WinGetProcessName("ahk_id " hwnd)
    catch
        return ""
}

Win32WindowPid(hwnd) {
    if !hwnd
        return 0
    pid := 0
    try DllCall(
        "User32\GetWindowThreadProcessId",
        "Ptr", hwnd,
        "UInt*", &pid,
        "UInt"
    )
    catch
        return 0
    return pid
}

Win32WindowFromPoint(point) {
    if !IsObject(point)
        return 0
    packedPoint := ((Round(point.y) & 0xFFFFFFFF) << 32)
        | (Round(point.x) & 0xFFFFFFFF)
    try return DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch
        return 0
}

Win32RootOwner(hwnd) {
    return Win32Ancestor_(hwnd, Win32Ancestor.ROOT_OWNER)
}

Win32RootWindow(hwnd) {
    return Win32Ancestor_(hwnd, Win32Ancestor.ROOT)
}

Win32Ancestor_(hwnd, flag) {
    if !hwnd
        return 0
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", flag,
        "Ptr"
    )
    catch
        return 0
}

Win32RootOwnerFromPoint(point) {
    pointHwnd := Win32WindowFromPoint(point)
    return pointHwnd ? Win32RootOwner(pointHwnd) : 0
}

Win32ParentHwnd(hwnd) {
    if !hwnd
        return 0
    try return DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        return 0
}

Win32WindowClass(hwnd) {
    if !hwnd
        return ""
    classNameBuffer := Buffer(512 * 2, 0)
    try length := DllCall(
        "User32\GetClassNameW",
        "Ptr", hwnd,
        "Ptr", classNameBuffer.Ptr,
        "Int", 512,
        "Int"
    )
    catch
        return ""
    return length > 0
        ? StrGet(classNameBuffer, length, "UTF-16")
        : ""
}

Win32IsWindow(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindow", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsWindowVisible(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsWindowEnabled(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindowEnabled", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsChild(parentHwnd, hwnd) {
    if !parentHwnd || !hwnd
        return false
    try return DllCall(
        "User32\IsChild",
        "Ptr", parentHwnd,
        "Ptr", hwnd,
        "Int"
    ) != 0
    catch
        return false
}

Win32WindowRect(hwnd) {
    if !hwnd
        return 0
    rectBuffer := Buffer(16, 0)
    try ok := DllCall(
        "User32\GetWindowRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    )
    catch
        return 0
    if !ok
        return 0
    return {
        left: NumGet(rectBuffer, 0, "Int"),
        top: NumGet(rectBuffer, 4, "Int"),
        right: NumGet(rectBuffer, 8, "Int"),
        bottom: NumGet(rectBuffer, 12, "Int")
    }
}

Win32ClientRectScreen(hwnd) {
    if !hwnd
        return 0
    rectBuffer := Buffer(16, 0)
    topLeft := Buffer(8, 0)
    bottomRight := Buffer(8, 0)
    try {
        if !DllCall(
            "User32\GetClientRect",
            "Ptr", hwnd,
            "Ptr", rectBuffer.Ptr,
            "Int"
        ) {
            return 0
        }
        NumPut("Int", NumGet(rectBuffer, 0, "Int"), topLeft, 0)
        NumPut("Int", NumGet(rectBuffer, 4, "Int"), topLeft, 4)
        NumPut("Int", NumGet(rectBuffer, 8, "Int"), bottomRight, 0)
        NumPut("Int", NumGet(rectBuffer, 12, "Int"), bottomRight, 4)
        if !DllCall(
            "User32\ClientToScreen",
            "Ptr", hwnd,
            "Ptr", topLeft.Ptr,
            "Int"
        ) {
            return 0
        }
        if !DllCall(
            "User32\ClientToScreen",
            "Ptr", hwnd,
            "Ptr", bottomRight.Ptr,
            "Int"
        ) {
            return 0
        }
    } catch {
        return 0
    }
    return {
        left: NumGet(topLeft, 0, "Int"),
        top: NumGet(topLeft, 4, "Int"),
        right: NumGet(bottomRight, 0, "Int"),
        bottom: NumGet(bottomRight, 4, "Int")
    }
}

Win32ScreenToClient(hwnd, screenPoint) {
    if !hwnd || !IsObject(screenPoint)
        return 0
    pointBuffer := Buffer(8, 0)
    NumPut("Int", screenPoint.x, pointBuffer, 0)
    NumPut("Int", screenPoint.y, pointBuffer, 4)
    try ok := DllCall(
        "User32\ScreenToClient",
        "Ptr", hwnd,
        "Ptr", pointBuffer.Ptr,
        "Int"
    )
    catch
        return 0
    if !ok
        return 0
    return {
        x: NumGet(pointBuffer, 0, "Int"),
        y: NumGet(pointBuffer, 4, "Int")
    }
}

Win32WindowIsSameOrDescendant(hwnd, ancestorHwnd) {
    if !hwnd || !ancestorHwnd
        return false
    seen := Map()
    while hwnd && !seen.Has(hwnd) {
        if hwnd = ancestorHwnd
            return true
        seen[hwnd] := true
        hwnd := Win32ParentHwnd(hwnd)
    }
    return false
}

; Parent-chain distance from hwnd up to rootHwnd; 32 when unreachable.
Win32WindowDepth(hwnd, rootHwnd) {
    if hwnd = rootHwnd
        return 0
    depth := 0
    seen := Map()
    while hwnd && !seen.Has(hwnd) && depth < 32 {
        seen[hwnd] := true
        hwnd := Win32ParentHwnd(hwnd)
        depth += 1
        if hwnd = rootHwnd
            return depth
    }
    return 32
}

Win32VirtualScreenRect() {
    left := SysGet(76)
    top := SysGet(77)
    width := SysGet(78)
    height := SysGet(79)
    return {
        left: left,
        top: top,
        right: left + width,
        bottom: top + height,
        width: width,
        height: height
    }
}

PointInsideVirtualScreen(point) {
    if !IsObject(point)
        return false
    screen := Win32VirtualScreenRect()
    return screen.width > 0
        && screen.height > 0
        && point.x >= screen.left
        && point.x < screen.right
        && point.y >= screen.top
        && point.y < screen.bottom
}

; Normalise any supported rect form to {left, top, right, bottom}; 0 otherwise.
RectEdges(rect) {
    if !IsObject(rect)
        return 0
    if Type(rect) = "Map" {
        if !rect.Has("l")
            return 0
        return {
            left: rect["l"],
            top: rect["t"],
            right: rect["r"],
            bottom: rect["b"]
        }
    }
    if rect.HasOwnProp("left")
        return rect
    if rect.HasOwnProp("l")
        return {left: rect.l, top: rect.t, right: rect.r, bottom: rect.b}
    return 0
}

RectLTRB(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges)
        return 0
    return {l: edges.left, t: edges.top, r: edges.right, b: edges.bottom}
}

RectIsEmpty(rect) {
    edges := RectEdges(rect)
    return !IsObject(edges)
        || edges.right <= edges.left
        || edges.bottom <= edges.top
}

RectKey(rect) {
    edges := RectEdges(rect)
    return IsObject(edges)
        ? edges.left "," edges.top "," edges.right "," edges.bottom
        : ""
}

RectHasPoint(rect, point) {
    edges := RectEdges(rect)
    return IsObject(edges)
        && IsObject(point)
        && point.x >= edges.left
        && point.x < edges.right
        && point.y >= edges.top
        && point.y < edges.bottom
}

; True when inner is non-empty and lies entirely inside outer.
RectEncloses(outer, inner) {
    outerEdges := RectEdges(outer)
    innerEdges := RectEdges(inner)
    return IsObject(outerEdges)
        && IsObject(innerEdges)
        && innerEdges.right > innerEdges.left
        && innerEdges.bottom > innerEdges.top
        && innerEdges.left >= outerEdges.left
        && innerEdges.top >= outerEdges.top
        && innerEdges.right <= outerEdges.right
        && innerEdges.bottom <= outerEdges.bottom
}

RectVisibleScreenArea(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges)
        return 0
    screen := Win32VirtualScreenRect()
    width := Max(0, Min(edges.right, screen.right) - Max(edges.left, screen.left))
    height := Max(0, Min(edges.bottom, screen.bottom) - Max(edges.top, screen.top))
    return width * height
}

RectIntersectsScreen(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges) || edges.right <= edges.left || edges.bottom <= edges.top
        return false
    screen := Win32VirtualScreenRect()
    return Min(edges.right, screen.right) > Max(edges.left, screen.left)
        && Min(edges.bottom, screen.bottom) > Max(edges.top, screen.top)
}
