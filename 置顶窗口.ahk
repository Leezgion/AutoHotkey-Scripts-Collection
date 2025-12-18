; =================================================
; 🔲 多窗口置顶工具 Pro (AutoHotkey v2)
;
; 功能说明：
;   - 将任意窗口设为置顶，并用彩色边框标识
;   - 支持同时置顶多个窗口，每个窗口自动分配不同颜色
;   - 边框实时跟踪窗口位置，最小化时自动隐藏
;   - 系统托盘菜单管理已置顶窗口
;   - 置顶时显示窗口标题提示
;   - 新置顶窗口边框闪烁动画
;
; 快捷键：
;   CapsLock + Space : 切换当前窗口的置顶状态
;   CapsLock + Esc   : 取消所有窗口的置顶
;   CapsLock + Tab   : 在置顶窗口间循环切换焦点
;   CapsLock + C     : 更改当前置顶窗口的边框颜色
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force          ; 只允许运行单个实例
SetWorkingDir A_ScriptDir      ; 设置工作目录为脚本所在目录

; ---------- ⚡️ 性能设置 ----------
SetWinDelay(-1)                ; 移除窗口操作延迟，提升响应速度
SetControlDelay(-1)            ; 移除控件操作延迟

; ---------- 🎨 配置区域 (可自定义) ----------
BorderThickness := 4           ; 边框粗细 (像素)
SoundMode := true              ; 声音反馈开关 (true=开启, false=静音)
FlashCount := 3                ; 新置顶时边框闪烁次数
FlashInterval := 100           ; 闪烁间隔 (毫秒)

; ---------- 🌈 多彩边框颜色池 ----------
; 预定义一组醒目的颜色，每个新置顶窗口自动分配下一个颜色
ColorPool := [
"00FF00",  ; 绿色
"FF6B6B",  ; 珊瑚红
"4ECDC4",  ; 青色
"FFE66D",  ; 金黄
"95E1D3",  ; 薄荷绿
"F38181",  ; 粉红
"AA96DA",  ; 淡紫
"00ADB5",  ; 蓝绿
"FF9F43",  ; 橙色
"74B9FF"   ; 天蓝
]
ColorIndex := 0                ; 当前颜色索引

; ---------- 核心数据存储 ----------
; 使用 Map 存储所有置顶窗口的信息
; 结构: PinnedWindows[hwnd] := {Top, Bot, Lft, Rgt: GUI对象, Color: 颜色, Title: 标题, LastCoords: 坐标缓存}
PinnedWindows := Map()

; ---------- 🖥️ 系统托盘设置 ----------
; 注意：托盘图标由「脚本管理器」统一管理，本脚本隐藏图标
#NoTrayIcon  ; 隐藏托盘图标，由脚本管理器统一显示

; ---------- 📡 消息监听器 (接收脚本管理器的命令) ----------
; 自定义消息编号: 0x1001=置顶, 0x1002=取消全部, 0x1003=切换, 0x1004=换色
OnMessage(0x1001, OnPinCommand)
OnMessage(0x1002, OnUnpinAllCommand)
OnMessage(0x1003, OnSwitchCommand)
OnMessage(0x1004, OnChangeColorCommand)

; 消息处理函数
OnPinCommand(wParam, lParam, msg, hwnd) {
    TogglePinCurrentWindow()
}

OnUnpinAllCommand(wParam, lParam, msg, hwnd) {
    UnpinAllWindows()
}

OnSwitchCommand(wParam, lParam, msg, hwnd) {
    SwitchPinnedWindow()
}

OnChangeColorCommand(wParam, lParam, msg, hwnd) {
    ChangeCurrentWindowColor()
}

; =================================================
; 快捷键定义
; =================================================

; ---------- 快捷键：切换置顶 (CapsLock + Space) ----------
CapsLock & Space:: {
    global PinnedWindows

    try {
        hwnd := WinGetID("A")   ; 获取当前激活窗口的句柄
    } catch {
        return                  ; 没有窗口处于激活状态，直接返回
    }

    ; 判断窗口是否已置顶，执行相反操作
    if PinnedWindows.Has(hwnd) {
        title := PinnedWindows[hwnd].Title
        UnpinWindow(hwnd)
        ShowNotification("📌 取消置顶", title)
        PlaySound("OFF")
    } else {
        title := WinGetTitle(hwnd)
        PinWindow(hwnd)
        ShowNotification("📌 已置顶", title)
        PlaySound("ON")
    }
}

; ---------- 快捷键：取消所有置顶 (CapsLock + Esc) ----------
CapsLock & Esc:: {
    global PinnedWindows

    count := PinnedWindows.Count
    if (count == 0) {
        ShowNotification("📌 提示", "没有置顶的窗口")
        return
    }

    ; 收集所有 hwnd（避免遍历时修改 Map）
    hwnds := []
    for hwnd in PinnedWindows
        hwnds.Push(hwnd)

    ; 逐一取消置顶
    for hwnd in hwnds
        UnpinWindow(hwnd)

    ShowNotification("📌 全部取消", "已取消 " count " 个窗口的置顶")
    PlaySound("OFF")
}

; ---------- 快捷键：循环切换置顶窗口焦点 (CapsLock + Tab) ----------
CapsLock & Tab:: {
    global PinnedWindows

    if (PinnedWindows.Count == 0) {
        ShowNotification("📌 提示", "没有置顶的窗口")
        return
    }

    ; 获取所有置顶窗口句柄
    hwnds := []
    for hwnd in PinnedWindows
        hwnds.Push(hwnd)

    ; 找到当前激活窗口在列表中的位置
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

    ; 切换到下一个窗口
    nextIndex := Mod(currentIndex, hwnds.Length) + 1
    try WinActivate(hwnds[nextIndex])
}

; ---------- 快捷键：更改当前窗口边框颜色 (CapsLock + C) ----------
CapsLock & c:: {
    global PinnedWindows, ColorPool

    try {
        hwnd := WinGetID("A")
    } catch {
        return
    }

    if !PinnedWindows.Has(hwnd) {
        ShowNotification("📌 提示", "当前窗口未置顶")
        return
    }

    ; 获取下一个颜色
    guis := PinnedWindows[hwnd]
    currentColor := guis.Color

    ; 找到当前颜色索引并切换到下一个
    for i, c in ColorPool {
        if (c == currentColor) {
            nextIndex := Mod(i, ColorPool.Length) + 1
            newColor := ColorPool[nextIndex]
            break
        }
    }
    if !IsSet(newColor)
        newColor := ColorPool[1]

    ; 更新颜色
    guis.Color := newColor
    guis.Top.BackColor := newColor
    guis.Bot.BackColor := newColor
    guis.Lft.BackColor := newColor
    guis.Rgt.BackColor := newColor

    ShowNotification("🎨 颜色已更改", "边框颜色: #" newColor)
}

; =================================================
; 封装函数 (供消息监听器调用)
; =================================================

; -------------------------------------------------
; TogglePinCurrentWindow - 切换当前窗口置顶状态
; -------------------------------------------------
TogglePinCurrentWindow() {
    global PinnedWindows

    try {
        hwnd := WinGetID("A")
    } catch {
        ShowNotification("📌 提示", "没有活动窗口")
        return
    }

    if PinnedWindows.Has(hwnd) {
        title := PinnedWindows[hwnd].Title
        UnpinWindow(hwnd)
        ShowNotification("📌 取消置顶", title)
        PlaySound("OFF")
    } else {
        title := WinGetTitle(hwnd)
        PinWindow(hwnd)
        ShowNotification("📌 已置顶", title)
        PlaySound("ON")
    }
}

; -------------------------------------------------
; UnpinAllWindows - 取消所有窗口置顶
; -------------------------------------------------
UnpinAllWindows() {
    global PinnedWindows

    count := PinnedWindows.Count
    if (count == 0) {
        ShowNotification("📌 提示", "没有置顶的窗口")
        return
    }

    hwnds := []
    for hwnd in PinnedWindows
        hwnds.Push(hwnd)

    for hwnd in hwnds
        UnpinWindow(hwnd)

    ShowNotification("📌 全部取消", "已取消 " count " 个窗口的置顶")
    PlaySound("OFF")
}

; -------------------------------------------------
; SwitchPinnedWindow - 切换到下一个置顶窗口
; -------------------------------------------------
SwitchPinnedWindow() {
    global PinnedWindows

    if (PinnedWindows.Count == 0) {
        ShowNotification("📌 提示", "没有置顶的窗口")
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

; -------------------------------------------------
; ChangeCurrentWindowColor - 更改当前窗口边框颜色
; -------------------------------------------------
ChangeCurrentWindowColor() {
    global PinnedWindows, ColorPool

    try {
        hwnd := WinGetID("A")
    } catch {
        ShowNotification("📌 提示", "没有活动窗口")
        return
    }

    if !PinnedWindows.Has(hwnd) {
        ShowNotification("📌 提示", "当前窗口未置顶")
        return
    }

    guis := PinnedWindows[hwnd]
    currentColor := guis.Color

    newColor := ColorPool[1]
    for i, c in ColorPool {
        if (c == currentColor) {
            nextIndex := Mod(i, ColorPool.Length) + 1
            newColor := ColorPool[nextIndex]
            break
        }
    }

    guis.Color := newColor
    guis.Top.BackColor := newColor
    guis.Bot.BackColor := newColor
    guis.Lft.BackColor := newColor
    guis.Rgt.BackColor := newColor

    ShowNotification("🎨 颜色已更改", "边框颜色: #" newColor)
}

; =================================================
; 核心函数
; =================================================

; -------------------------------------------------
; PinWindow - 将窗口设为置顶并添加边框
; 参数: hwnd - 窗口句柄
; -------------------------------------------------
PinWindow(hwnd) {
    global PinnedWindows, ColorPool, ColorIndex, BorderThickness

    ; 设置窗口为始终置顶
    try WinSetAlwaysOnTop(true, hwnd)

    ; 获取下一个颜色
    ColorIndex := Mod(ColorIndex, ColorPool.Length) + 1
    currentColor := ColorPool[ColorIndex]

    ; 获取窗口标题
    title := "未知窗口"
    try
    title := WinGetTitle(hwnd)
    if (title == "")
        title := "无标题窗口"

    ; 创建 4 个 GUI 窗口作为边框 (上、下、左、右)
    ; GUI 选项说明：
    ;   +AlwaysOnTop : 边框也要置顶
    ;   -Caption     : 无标题栏
    ;   +ToolWindow  : 不在任务栏显示
    ;   +E0x20       : 鼠标穿透 (WS_EX_TRANSPARENT)
    ;   +Owner       : 设置父窗口，随父窗口一起关闭
    guiOpts := "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner" hwnd

    guis := {}
    guis.Top := Gui(guiOpts)    ; 上边框
    guis.Bot := Gui(guiOpts)    ; 下边框
    guis.Lft := Gui(guiOpts)    ; 左边框
    guis.Rgt := Gui(guiOpts)    ; 右边框

    ; 设置边框颜色
    guis.Top.BackColor := currentColor
    guis.Bot.BackColor := currentColor
    guis.Lft.BackColor := currentColor
    guis.Rgt.BackColor := currentColor

    ; 初始化记录
    guis.LastCoords := ""
    guis.Color := currentColor
    guis.Title := title

    ; 存入 Map
    PinnedWindows[hwnd] := guis

    ; 立即刷新边框位置
    UpdateSingleWindow(hwnd, true)

    ; 启动定时器，每 10ms 刷新一次边框位置
    SetTimer(UpdateAllVisuals, 10)

    ; 播放闪烁动画
    FlashBorder(hwnd)
}

; -------------------------------------------------
; UnpinWindow - 取消窗口置顶并移除边框
; 参数: hwnd - 窗口句柄
; -------------------------------------------------
UnpinWindow(hwnd) {
    global PinnedWindows

    ; 如果窗口还存在，取消其置顶状态
    ; 但保留截图悬浮窗的置顶状态（它本身需要始终置顶）
    if WinExist(hwnd) {
        ; 检测是否是截图悬浮窗（通过窗口类名和进程判断）
        isScreenshotFloat := false
        try {
            winClass := WinGetClass(hwnd)
            winPID := WinGetPID(hwnd)
            procName := ProcessGetName(winPID)
            ; 截图悬浮窗是 AutoHotkey GUI，进程名包含 AutoHotkey
            ; 并且窗口类名是 AutoHotkeyGUI
            if (winClass = "AutoHotkeyGUI" && InStr(procName, "AutoHotkey")) {
                ; 进一步检查是否来自截图悬浮脚本（通过检测窗口特征）
                ; 截图悬浮窗没有标题，且有边框
                winTitle := WinGetTitle(hwnd)
                winStyle := WinGetStyle(hwnd)
                ; 截图悬浮窗的特征：无标题或极短标题，有 WS_BORDER 样式
                if (StrLen(winTitle) = 0 || winTitle = "") {
                    isScreenshotFloat := true
                }
            }
        }
        
        ; 只有非截图悬浮窗才取消置顶
        if !isScreenshotFloat {
            try WinSetAlwaysOnTop(false, hwnd)
        }
    }

    ; 销毁边框 GUI 并从 Map 中移除
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

    ; 如果没有任何置顶窗口了，关闭定时器以节省资源
    if (PinnedWindows.Count == 0) {
        SetTimer(UpdateAllVisuals, 0)  ; 0 = 关闭定时器
    }
}

; -------------------------------------------------
; UpdateAllVisuals - 定时器回调，刷新所有边框位置
; -------------------------------------------------
UpdateAllVisuals() {
    global PinnedWindows

    ; 收集需要取消的窗口（避免遍历时修改 Map）
    toRemove := []

    for hwnd, guis in PinnedWindows {
        ; 检查窗口是否已关闭
        if !WinExist(hwnd) {
            toRemove.Push(hwnd)
            continue
        }
        UpdateSingleWindow(hwnd)
    }

    ; 移除已关闭的窗口
    for hwnd in toRemove {
        UnpinWindow(hwnd)
    }
}

; -------------------------------------------------
; UpdateSingleWindow - 更新单个窗口的边框位置
; 参数: hwnd  - 窗口句柄
;       force - 是否强制刷新 (忽略缓存)
; -------------------------------------------------
UpdateSingleWindow(hwnd, force := false) {
    global PinnedWindows, BorderThickness

    if !PinnedWindows.Has(hwnd)
        return

    guis := PinnedWindows[hwnd]

    ; 获取窗口位置和状态
    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
        minMax := WinGetMinMax(hwnd)   ; -1=最小化, 0=正常, 1=最大化
    } catch {
        return  ; 窗口可能刚被关闭
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

    ; 位置缓存优化：位置没变则跳过重绘
    currentCoords := x "," y "," w "," h
    if (!force && guis.LastCoords == currentCoords)
        return

    guis.LastCoords := currentCoords

    ; 绘制四条边框
    ; 上边框
    guis.Top.Show("NA x" x " y" y " w" w " h" BorderThickness)

    ; 下边框
    by := y + h - BorderThickness
    guis.Bot.Show("NA x" x " y" by " w" w " h" BorderThickness)

    ; 左边框
    guis.Lft.Show("NA x" x " y" y " w" BorderThickness " h" h)

    ; 右边框
    bx := x + w - BorderThickness
    guis.Rgt.Show("NA x" bx " y" y " w" BorderThickness " h" h)
}

; -------------------------------------------------
; FlashBorder - 边框闪烁动画
; 参数: hwnd - 窗口句柄
; -------------------------------------------------
FlashBorder(hwnd) {
    global PinnedWindows, FlashCount, FlashInterval

    if !PinnedWindows.Has(hwnd)
        return

    guis := PinnedWindows[hwnd]

    ; 使用闭包进行异步闪烁
    flashNum := 0

    FlashStep() {
        if !PinnedWindows.Has(hwnd)
            return

        flashNum++

        if (Mod(flashNum, 2) == 1) {
            ; 隐藏
            guis.Top.Hide()
            guis.Bot.Hide()
            guis.Lft.Hide()
            guis.Rgt.Hide()
        } else {
            ; 显示
            UpdateSingleWindow(hwnd, true)
        }

        if (flashNum < FlashCount * 2)
            SetTimer(FlashStep, -FlashInterval)
    }

    SetTimer(FlashStep, -FlashInterval)
}

; =================================================
; 辅助函数
; =================================================

; -------------------------------------------------
; ShowNotification - 显示通知提示
; 参数: title - 标题
;       text  - 内容
; -------------------------------------------------
ShowNotification(title, text) {
    ; 截断过长文本
    if (StrLen(text) > 50)
        text := SubStr(text, 1, 47) "..."

    ToolTip(title "`n" text)
    SetTimer(() => ToolTip(), -2000)  ; 2秒后关闭
}

; -------------------------------------------------
; PlaySound - 播放提示音
; 参数: type - "ON"=置顶, "OFF"=取消置顶
; -------------------------------------------------
PlaySound(type) {
    global SoundMode

    if !SoundMode
        return

    if (type == "ON")
        SoundBeep(750, 50)    ; 高音 = 置顶
    else
        SoundBeep(500, 50)    ; 低音 = 取消
}

; =================================================
; 初始化完成
; =================================================
ShowNotification("📌 窗口置顶工具 Pro", "已启动！`nCapsLock+Space 置顶窗口")