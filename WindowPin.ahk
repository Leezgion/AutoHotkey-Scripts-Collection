; =================================================
; 📌 多窗口置顶工具 v2 (重构版)
; =================================================
; 使用模块: i18n, Constants
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ---------- ⚡️ 性能设置 ----------
SetWinDelay(-1)
SetControlDelay(-1)

; ---------- 🖥️ 托盘设置 ----------
#NoTrayIcon

; ---------- 📦 加载模块 ----------
#Include Lib\Constants.ahk
#Include Lib\i18n.ahk

; ---------- 🎨 配置区域 ----------
global Config := {
    BorderThickness: Defaults.PinBorderThickness,
    SoundEnabled: Defaults.PinSoundEnabled,
    FlashCount: Defaults.PinFlashCount,
    FlashInterval: Defaults.PinFlashInterval,
    UpdateInterval: Defaults.PinUpdateInterval
}

; ---------- 核心数据存储 ----------
global PinnedWindows := Map()
global ColorIndex := 0

; ---------- 📦 模块初始化 ----------
Initialize()

Initialize() {
    ; 初始化多语言
    I18n.Init("auto")
}

; =================================================
; 📡 消息监听器 (接收脚本管理器的命令)
; =================================================
OnMessage(MSG.PIN_TOGGLE, OnPinCommand)
OnMessage(MSG.PIN_UNPIN_ALL, OnUnpinAllCommand)
OnMessage(MSG.PIN_SWITCH, OnSwitchCommand)
OnMessage(MSG.PIN_CHANGE_COLOR, OnChangeColorCommand)

OnPinCommand(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(TogglePinCurrentWindow, -50)
    return 1
}

OnUnpinAllCommand(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(UnpinAllWindows, -50)
    return 1
}

OnSwitchCommand(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(SwitchPinnedWindow, -50)
    return 1
}

OnChangeColorCommand(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(ChangeCurrentWindowColor, -50)
    return 1
}

; =================================================
; 快捷键定义
; =================================================

; CapsLock + Space: 切换置顶
CapsLock & Space:: {
    TogglePinCurrentWindow()
}

; CapsLock + Esc: 取消所有置顶
CapsLock & Esc:: {
    UnpinAllWindows()
}

; CapsLock + Tab: 循环切换置顶窗口焦点
CapsLock & Tab:: {
    SwitchPinnedWindow()
}

; CapsLock + C: 更改边框颜色
CapsLock & c:: {
    ChangeCurrentWindowColor()
}

; =================================================
; 封装函数
; =================================================

TogglePinCurrentWindow() {
    global PinnedWindows

    try {
        hwnd := WinGetID("A")
    } catch {
        ShowNotify(T("pin.noWindow"))
        return
    }

    if PinnedWindows.Has(hwnd) {
        title := PinnedWindows[hwnd].Title
        UnpinWindow(hwnd)
        ShowNotify("📌 " T("pin.unpinned") ": " title)
        PlaySound("OFF")
    } else {
        title := WinGetTitle(hwnd)
        PinWindow(hwnd)
        ShowNotify("📌 " T("pin.pinned") ": " title)
        PlaySound("ON")
    }
}

UnpinAllWindows() {
    global PinnedWindows

    count := PinnedWindows.Count
    if (count == 0) {
        ShowNotify(T("pin.noWindow"))
        return
    }

    hwnds := []
    for hwnd in PinnedWindows
        hwnds.Push(hwnd)

    for hwnd in hwnds
        UnpinWindow(hwnd)

    ShowNotify("📌 " T("pin.allUnpinned") " (" count ")")
    PlaySound("OFF")
}

SwitchPinnedWindow() {
    global PinnedWindows

    if (PinnedWindows.Count == 0) {
        ShowNotify(T("pin.noWindow"))
        return
    }

    hwnds := []
    for hwnd in PinnedWindows
        hwnds.Push(hwnd)

    currentHwnd := 0
    try
        currentHwnd := WinGetID("A")

    currentIndex := 0
    for i, h in hwnds {
        if (h == currentHwnd) {
            currentIndex := i
            break
        }
    }

    nextIndex := Mod(currentIndex, hwnds.Length) + 1
    try WinActivate(hwnds[nextIndex])
}

ChangeCurrentWindowColor() {
    global PinnedWindows

    try {
        hwnd := WinGetID("A")
    } catch {
        ShowNotify(T("pin.noWindow"))
        return
    }

    if !PinnedWindows.Has(hwnd) {
        ShowNotify("📌 " T("pin.noWindow"))
        return
    }

    guis := PinnedWindows[hwnd]
    currentColor := guis.Color

    newColor := BorderColors.Pool[1]
    for i, c in BorderColors.Pool {
        if (c == currentColor) {
            nextIndex := Mod(i, BorderColors.Pool.Length) + 1
            newColor := BorderColors.Pool[nextIndex]
            break
        }
    }

    guis.Color := newColor
    guis.Top.BackColor := newColor
    guis.Bot.BackColor := newColor
    guis.Lft.BackColor := newColor
    guis.Rgt.BackColor := newColor

    ShowNotify("🎨 " T("pin.colorChanged") ": #" newColor)
}

; =================================================
; 核心函数
; =================================================

PinWindow(hwnd) {
    global PinnedWindows, ColorIndex

    ; 设置窗口为始终置顶
    try WinSetAlwaysOnTop(true, hwnd)

    ; 获取下一个颜色
    ColorIndex := Mod(ColorIndex, BorderColors.Pool.Length) + 1
    currentColor := BorderColors.Pool[ColorIndex]

    ; 获取窗口标题
    title := "未知窗口"
    try
        title := WinGetTitle(hwnd)
    if (title == "")
        title := T("pin.noWindow")

    ; 创建 4 个 GUI 窗口作为边框
    guiOpts := "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner" hwnd

    guis := {}
    guis.Top := Gui(guiOpts)
    guis.Bot := Gui(guiOpts)
    guis.Lft := Gui(guiOpts)
    guis.Rgt := Gui(guiOpts)

    guis.Top.BackColor := currentColor
    guis.Bot.BackColor := currentColor
    guis.Lft.BackColor := currentColor
    guis.Rgt.BackColor := currentColor

    guis.LastCoords := ""
    guis.Color := currentColor
    guis.Title := title

    PinnedWindows[hwnd] := guis

    ; 立即刷新边框位置
    UpdateSingleWindow(hwnd, true)

    ; 启动定时器，按配置的间隔刷新边框位置
    SetTimer(UpdateAllVisuals, Config.UpdateInterval)

    ; 播放闪烁动画
    FlashBorder(hwnd)
}

UnpinWindow(hwnd) {
    global PinnedWindows

    ; 检查窗口是否存在并决定是否取消置顶
    if WinExist(hwnd) {
        ; 检测是否是截图悬浮窗（避免取消它的置顶状态）
        isScreenshotFloat := false
        try {
            winClass := WinGetClass(hwnd)
            winPID := WinGetPID(hwnd)
            procName := ProcessGetName(winPID)

            if (winClass = "AutoHotkeyGUI" && InStr(procName, "AutoHotkey")) {
                winTitle := WinGetTitle(hwnd)
                if (StrLen(winTitle) = 0 || winTitle = "") {
                    isScreenshotFloat := true
                }
            }
        }

        if !isScreenshotFloat {
            try WinSetAlwaysOnTop(false, hwnd)
        }
    }

    ; 销毁边框 GUI
    if PinnedWindows.Has(hwnd) {
        guis := PinnedWindows[hwnd]
        try {
            guis.Top.Destroy()
            guis.Bot.Destroy()
            guis.Lft.Destroy()
            guis.Rgt.Destroy()
        }
        PinnedWindows.Delete(hwnd)
    }

    ; 如果没有任何置顶窗口了，关闭定时器
    if (PinnedWindows.Count == 0) {
        SetTimer(UpdateAllVisuals, 0)
    }
}

UpdateAllVisuals() {
    global PinnedWindows

    toRemove := []

    for hwnd, guis in PinnedWindows {
        if !WinExist(hwnd) {
            toRemove.Push(hwnd)
            continue
        }
        UpdateSingleWindow(hwnd)
    }

    for hwnd in toRemove {
        UnpinWindow(hwnd)
    }
}

UpdateSingleWindow(hwnd, force := false) {
    global PinnedWindows

    if !PinnedWindows.Has(hwnd)
        return

    guis := PinnedWindows[hwnd]

    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
        minMax := WinGetMinMax(hwnd)
    } catch {
        return
    }

    ; 最小化时隐藏边框
    if (minMax == -1) {
        if (guis.LastCoords != "Min") {
            guis.Top.Hide()
            guis.Bot.Hide()
            guis.Lft.Hide()
            guis.Rgt.Hide()
            guis.LastCoords := "Min"
        }
        return
    }

    ; 位置缓存优化
    currentCoords := x "," y "," w "," h
    if (!force && guis.LastCoords == currentCoords)
        return

    guis.LastCoords := currentCoords
    bt := Config.BorderThickness

    ; 绘制四条边框
    guis.Top.Show("NA x" x " y" y " w" w " h" bt)
    guis.Bot.Show("NA x" x " y" (y + h - bt) " w" w " h" bt)
    guis.Lft.Show("NA x" x " y" y " w" bt " h" h)
    guis.Rgt.Show("NA x" (x + w - bt) " y" y " w" bt " h" h)
}

FlashBorder(hwnd) {
    global PinnedWindows

    if !PinnedWindows.Has(hwnd)
        return

    guis := PinnedWindows[hwnd]
    flashNum := 0

    FlashStep() {
        if !PinnedWindows.Has(hwnd)
            return

        flashNum++

        if (Mod(flashNum, 2) == 1) {
            guis.Top.Hide()
            guis.Bot.Hide()
            guis.Lft.Hide()
            guis.Rgt.Hide()
        } else {
            UpdateSingleWindow(hwnd, true)
        }

        if (flashNum < Config.FlashCount * 2)
            SetTimer(FlashStep, -Config.FlashInterval)
    }

    SetTimer(FlashStep, -Config.FlashInterval)
}

; =================================================
; 辅助函数
; =================================================

ShowNotify(text) {
    if (StrLen(text) > 50)
        text := SubStr(text, 1, 47) "..."

    ToolTip(text)
    SetTimer(() => ToolTip(), -2000)
}

PlaySound(type) {
    if !Config.SoundEnabled
        return

    if (type == "ON")
        SoundBeep(750, 50)
    else
        SoundBeep(500, 50)
}

; =================================================
; 初始化完成
; =================================================
ShowNotify("📌 " T("pin.title") " - " T("pin.started"))