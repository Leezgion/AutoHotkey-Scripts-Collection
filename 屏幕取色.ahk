; =================================================
; 🎨 屏幕取色工具 (AutoHotkey v2)
;
; 功能说明：
;   - 实时预览鼠标位置的颜色
;   - 显示多种颜色格式 (HEX, RGB, HSL)
;   - 点击复制颜色值到剪贴板
;   - 放大镜效果，精确取色
;   - 历史颜色记录
;
; 快捷键：
;   Win + Shift + C : 开始取色
;   ESC            : 取消取色
;   左键点击       : 复制颜色并退出
;   右键点击       : 切换颜色格式
;   滚轮           : 调整放大倍数
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ---------- 🖥️ 托盘设置 ----------
; 隐藏托盘图标，由脚本管理器统一管理
#NoTrayIcon

; ---------- 🎨 配置区域 ----------
global DefaultColorFormat := "HEX"      ; 默认颜色格式: HEX, RGB, HSL
global MagnifierSize := 150             ; 放大镜窗口大小
global MagnifierZoom := 8               ; 默认放大倍数
global MinZoom := 2                     ; 最小放大倍数
global MaxZoom := 20                    ; 最大放大倍数
global PreviewSize := 50                ; 颜色预览块大小
global MaxHistory := 10                 ; 最大历史记录数

; ---------- 核心数据 ----------
global IsPicking := false               ; 是否正在取色
global PickerGui := ""                  ; 取色器GUI
global MagnifierGui := ""               ; 放大镜GUI
global HistoryGui := ""                 ; 历史记录GUI
global CurrentFormat := DefaultColorFormat
global CurrentZoom := MagnifierZoom
global ColorHistory := []               ; 颜色历史
global LastColor := ""                  ; 上次颜色
global LButtonWasDown := false          ; 左键状态跟踪
global RButtonWasDown := false          ; 右键状态跟踪

; ---------- GDI+ 初始化 ----------
global pToken := 0
global hGdip := 0
InitGDIPlus()

; =================================================
; 快捷键定义
; =================================================

; Win + Shift + C: 开始取色
#+c:: {
    StartColorPicker()
}

; =================================================
; 消息监听 - 脚本管理器集成
; 消息编号: 0x3001=开始取色, 0x3002=显示历史
; =================================================
OnMessage(0x3001, OnMsgStartPicker)
OnMessage(0x3002, OnMsgShowHistory)

OnMsgStartPicker(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(DoStartPicker, -100)
    return 1
}

DoStartPicker() {
    StartColorPicker()
}

OnMsgShowHistory(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(DoShowHistory, -100)
    return 1
}

DoShowHistory() {
    ShowColorHistory()
}

; =================================================
; 取色器核心函数
; =================================================

; -------------------------------------------------
; StartColorPicker - 开始取色
; -------------------------------------------------
StartColorPicker() {
    global IsPicking, PickerGui, MagnifierGui, CurrentZoom, MagnifierZoom, LButtonWasDown, RButtonWasDown

    if IsPicking
        return

    IsPicking := true
    CurrentZoom := MagnifierZoom
    LButtonWasDown := false
    RButtonWasDown := false

    ; 创建放大镜窗口
    CreateMagnifierGui()

    ; 创建信息面板
    CreatePickerGui()

    ; 设置鼠标为十字准星
    SetSystemCursor("cross")

    ; 开始跟踪鼠标（包含点击检测）
    SetTimer(UpdatePicker, 16)  ; ~60 FPS

    ; 绑定ESC键和滚轮
    Hotkey("*Escape", OnPickerCancel, "On")
    Hotkey("*WheelUp", OnZoomIn, "On")
    Hotkey("*WheelDown", OnZoomOut, "On")
}

; -------------------------------------------------
; CreateMagnifierGui - 创建放大镜窗口
; -------------------------------------------------
CreateMagnifierGui() {
    global MagnifierGui, MagnifierSize

    MagnifierGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
    MagnifierGui.BackColor := "000000"
    MagnifierGui.MarginX := 0
    MagnifierGui.MarginY := 0

    ; 添加图片控件用于显示放大的屏幕
    MagnifierGui.AddPicture("vMagView x0 y0 w" MagnifierSize " h" MagnifierSize, "")

    ; 添加中心十字线标记
    MagnifierGui.SetFont("s8 cWhite", "Consolas")
}

; -------------------------------------------------
; CreatePickerGui - 创建信息面板
; -------------------------------------------------
CreatePickerGui() {
    global PickerGui, PreviewSize

    PickerGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    PickerGui.BackColor := "1a1a1a"
    PickerGui.MarginX := 10
    PickerGui.MarginY := 8

    ; 颜色预览块 - 使用 Progress 控件可以动态更新颜色
    PickerGui.AddProgress("vColorPreview x10 y8 w" PreviewSize " h" PreviewSize " Background000000", 100)

    ; 颜色值显示
    PickerGui.SetFont("s11 cWhite Bold", "Consolas")
    PickerGui.AddText("vColorValue x" (PreviewSize + 20) " y10 w150 h24", "#000000")

    PickerGui.SetFont("s9 cSilver", "Segoe UI")
    PickerGui.AddText("vColorRGB x" (PreviewSize + 20) " y36 w150 h18", "RGB(0, 0, 0)")
    PickerGui.AddText("vColorHSL x" (PreviewSize + 20) " y54 w150 h18", "HSL(0°, 0%, 0%)")

    ; 坐标显示
    PickerGui.SetFont("s8 c888888", "Consolas")
    PickerGui.AddText("vCoords x10 y" (PreviewSize + 15) " w200 h16", "X: 0  Y: 0")

    ; 操作提示
    PickerGui.SetFont("s8 c666666", "Segoe UI")
    PickerGui.AddText("vTips x10 y" (PreviewSize + 33) " w200 h32", "左键复制 | 右键切换格式 | 滚轮缩放")
}

; -------------------------------------------------
; UpdatePicker - 更新取色器显示
; -------------------------------------------------
; -------------------------------------------------
; UpdatePicker - 更新取色器显示
; -------------------------------------------------
UpdatePicker() {
    global IsPicking, PickerGui, MagnifierGui, CurrentZoom, MagnifierSize, LastColor
    global LButtonWasDown, RButtonWasDown

    if !IsPicking
        return

    ; 确保 GUI 对象有效
    if !IsObject(PickerGui) || !IsObject(MagnifierGui)
        return

    ; 使用 GetAsyncKeyState 检测鼠标状态（全局有效，不受窗口影响）
    ; 返回值最高位为1表示按下
    lButtonDown := DllCall("GetAsyncKeyState", "Int", 0x01, "Short") & 0x8000  ; VK_LBUTTON
    rButtonDown := DllCall("GetAsyncKeyState", "Int", 0x02, "Short") & 0x8000  ; VK_RBUTTON

    ; 检测鼠标左键点击（释放时触发）
    if (LButtonWasDown && !lButtonDown) {
        ; 左键刚释放 - 复制颜色
        LButtonWasDown := false
        SetTimer(UpdatePicker, 0)  ; 先停止定时器
        DoPickerClick()
        return
    }
    LButtonWasDown := lButtonDown

    ; 检测鼠标右键点击（释放时触发）
    if (RButtonWasDown && !rButtonDown) {
        ; 右键刚释放 - 切换格式
        RButtonWasDown := false
        DoFormatSwitch()
    }
    RButtonWasDown := rButtonDown

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    ; 获取当前像素颜色
    color := GetPixelColor(mx, my)

    ; 更新放大镜
    UpdateMagnifier(mx, my)

    ; 更新信息面板
    if (color != LastColor) {
        LastColor := color
        UpdateColorInfo(color)
    }

    ; 定位GUI位置（避免遮挡鼠标）
    PositionGuis(mx, my)
}

; -------------------------------------------------
; UpdateMagnifier - 更新放大镜内容
; -------------------------------------------------
; -------------------------------------------------
UpdateMagnifier(mx, my) {
    global MagnifierGui, MagnifierSize, CurrentZoom

    if !IsObject(MagnifierGui)
        return

    ; 计算要截取的屏幕区域
    captureSize := MagnifierSize // CurrentZoom
    halfCapture := captureSize // 2

    ; 截取屏幕区域
    sx := mx - halfCapture
    sy := my - halfCapture

    ; 创建临时文件
    tempFile := A_Temp "\ahk_magnifier_" A_TickCount ".bmp"

    ; 使用 GDI 截取并缩放
    CaptureAndScale(sx, sy, captureSize, captureSize, MagnifierSize, MagnifierSize, tempFile)

    ; 更新显示
    try {
        ctrl := MagnifierGui["MagView"]
        ctrl.Value := tempFile
    }

    ; 延迟删除临时文件
    SetTimer(() => TryDeleteFile(tempFile), -500)
}

; -------------------------------------------------
; CaptureAndScale - 截取并缩放屏幕区域
; -------------------------------------------------
CaptureAndScale(sx, sy, sw, sh, dw, dh, filePath) {
    ; 获取屏幕 DC
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", dw, "Int", dh, "Ptr")
    hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

    ; 设置缩放模式为高质量
    DllCall("SetStretchBltMode", "Ptr", hdcMem, "Int", 4)  ; HALFTONE

    ; 缩放复制
    DllCall("StretchBlt"
        , "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", dw, "Int", dh
        , "Ptr", hdcScreen, "Int", sx, "Int", sy, "Int", sw, "Int", sh
        , "UInt", 0x00CC0020)  ; SRCCOPY

    ; 绘制中心十字线
    DrawCrosshair(hdcMem, dw, dh)

    ; 保存为 BMP
    SaveHBitmapToFile(hBitmap, dw, dh, filePath)

    ; 清理
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
}

; -------------------------------------------------
; DrawCrosshair - 绘制十字准星
; -------------------------------------------------
DrawCrosshair(hdc, w, h) {
    cx := w // 2
    cy := h // 2

    ; 创建画笔 - 白色
    hPenWhite := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0xFFFFFF, "Ptr")
    ; 创建画笔 - 黑色
    hPenBlack := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x000000, "Ptr")

    ; 绘制黑色外框
    hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenBlack, "Ptr")

    ; 水平线
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx - 10, "Int", cy, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx + 11, "Int", cy)
    ; 垂直线
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx, "Int", cy - 10, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx, "Int", cy + 11)

    ; 绘制白色内线
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenWhite, "Ptr")
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx - 9, "Int", cy, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx - 2, "Int", cy)
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx + 3, "Int", cy, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx + 10, "Int", cy)
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx, "Int", cy - 9, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx, "Int", cy - 2)
    DllCall("MoveToEx", "Ptr", hdc, "Int", cx, "Int", cy + 3, "Ptr", 0)
    DllCall("LineTo", "Ptr", hdc, "Int", cx, "Int", cy + 10)

    ; 清理
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
    DllCall("DeleteObject", "Ptr", hPenWhite)
    DllCall("DeleteObject", "Ptr", hPenBlack)
}

; -------------------------------------------------
; SaveHBitmapToFile - 保存位图到文件
; -------------------------------------------------
SaveHBitmapToFile(hBitmap, w, h, filePath) {
    ; BITMAPINFOHEADER
    biSize := 40
    bi := Buffer(biSize, 0)
    NumPut("UInt", biSize, bi, 0)
    NumPut("Int", w, bi, 4)
    NumPut("Int", -h, bi, 8)  ; 负数表示从上到下
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 24, bi, 14)  ; 24位色

    ; 计算数据大小
    stride := ((w * 3 + 3) & ~3)
    dataSize := stride * h

    ; 获取位图数据
    bits := Buffer(dataSize)
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", h, "Ptr", bits, "Ptr", bi, "UInt", 0)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    ; BITMAPFILEHEADER
    fh := Buffer(14, 0)
    NumPut("UShort", 0x4D42, fh, 0)  ; "BM"
    NumPut("UInt", 54 + dataSize, fh, 2)
    NumPut("UInt", 54, fh, 10)

    ; 写入文件
    file := FileOpen(filePath, "w")
    file.RawWrite(fh, 14)
    file.RawWrite(bi, 40)
    file.RawWrite(bits, dataSize)
    file.Close()
}

; -------------------------------------------------
; UpdateColorInfo - 更新颜色信息显示
; -------------------------------------------------
UpdateColorInfo(color) {
    global PickerGui, CurrentFormat

    if !IsObject(PickerGui)
        return

    ; 解析颜色
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF

    ; HEX 格式
    hexColor := Format("#{:02X}{:02X}{:02X}", r, g, b)

    ; RGB 格式
    rgbColor := Format("RGB({}, {}, {})", r, g, b)

    ; HSL 格式
    hslColor := RGBtoHSL(r, g, b)

    ; 更新显示
    try {
        ; 更新预览块颜色 - Progress 控件使用 c 选项设置颜色
        colorHex := SubStr(hexColor, 2)  ; 去掉 # 号
        PickerGui["ColorPreview"].Opt("c" colorHex " Background" colorHex)

        ; 更新文本
        PickerGui["ColorValue"].Text := hexColor
        PickerGui["ColorRGB"].Text := rgbColor
        PickerGui["ColorHSL"].Text := hslColor
    }
}

; -------------------------------------------------
; PositionGuis - 定位GUI窗口
; -------------------------------------------------
PositionGuis(mx, my) {
    global PickerGui, MagnifierGui, MagnifierSize

    ; 确保GUI对象有效
    if !IsObject(MagnifierGui) || !IsObject(PickerGui)
        return

    ; 获取屏幕尺寸
    screenWidth := SysGet(78)
    screenHeight := SysGet(79)
    screenLeft := SysGet(76)
    screenTop := SysGet(77)

    ; 放大镜位置 (在鼠标右下方)
    magX := mx + 20
    magY := my + 20

    ; 信息面板位置 (在放大镜下方)
    infoX := magX
    infoY := magY + MagnifierSize + 5

    ; 边界检测 - 放大镜
    if (magX + MagnifierSize > screenLeft + screenWidth)
        magX := mx - MagnifierSize - 20
    if (magY + MagnifierSize > screenTop + screenHeight)
        magY := my - MagnifierSize - 20

    ; 边界检测 - 信息面板
    if (magX + 220 > screenLeft + screenWidth)
        infoX := mx - 240
    if (infoY + 100 > screenTop + screenHeight)
        infoY := magY - 105

    ; 显示/移动窗口
    MagnifierGui.Show("x" magX " y" magY " w" MagnifierSize " h" MagnifierSize " NA")
    PickerGui.Show("x" infoX " y" infoY " NA")

    ; 更新坐标显示
    try PickerGui["Coords"].Text := Format("X: {}  Y: {}", mx, my)
}

; -------------------------------------------------
; GetPixelColor - 获取像素颜色
; -------------------------------------------------
GetPixelColor(x, y) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    color := DllCall("GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

    ; Windows 返回 BGR，转换为 RGB
    r := color & 0xFF
    g := (color >> 8) & 0xFF
    b := (color >> 16) & 0xFF

    return (r << 16) | (g << 8) | b
}

; -------------------------------------------------
; RGBtoHSL - RGB 转 HSL
; -------------------------------------------------
RGBtoHSL(r, g, b) {
    r := r / 255
    g := g / 255
    b := b / 255

    maxVal := Max(r, g, b)
    minVal := Min(r, g, b)
    l := (maxVal + minVal) / 2

    if (maxVal = minVal) {
        h := 0
        s := 0
    } else {
        d := maxVal - minVal
        s := l > 0.5 ? d / (2 - maxVal - minVal) : d / (maxVal + minVal)

        if (maxVal = r)
            h := (g - b) / d + (g < b ? 6 : 0)
        else if (maxVal = g)
            h := (b - r) / d + 2
        else
            h := (r - g) / d + 4

        h := h / 6
    }

    return Format("HSL({}°, {}%, {}%)", Round(h * 360), Round(s * 100), Round(l * 100))
}

; =================================================
; 事件处理
; =================================================

; -------------------------------------------------
; OnPickerLButtonDown - 鼠标左键按下
; -------------------------------------------------
OnPickerLButtonDown(wParam, lParam, msg, hwnd) {
    global IsPicking

    if !IsPicking
        return

    ; 延迟执行，避免在消息处理中执行复杂操作
    SetTimer(DoPickerClick, -10)
    return 0  ; 阻止消息继续传递
}

; -------------------------------------------------
; OnPickerRButtonDown - 鼠标右键按下
; -------------------------------------------------
OnPickerRButtonDown(wParam, lParam, msg, hwnd) {
    global IsPicking

    if !IsPicking
        return

    SetTimer(DoFormatSwitch, -10)
    return 0
}

; -------------------------------------------------
; OnPickerMouseWheel - 鼠标滚轮
; -------------------------------------------------
OnPickerMouseWheel(wParam, lParam, msg, hwnd) {
    global IsPicking, CurrentZoom, MinZoom, MaxZoom

    if !IsPicking
        return

    ; 获取滚动方向
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 0x7FFF)
        delta := delta - 0x10000

    if (delta > 0) {
        ; 向上滚 - 放大
        if (CurrentZoom < MaxZoom) {
            CurrentZoom += 2
            ShowNotification("🔍 放大", CurrentZoom "x")
        }
    } else {
        ; 向下滚 - 缩小
        if (CurrentZoom > MinZoom) {
            CurrentZoom -= 2
            ShowNotification("🔍 缩小", CurrentZoom "x")
        }
    }

    return 0
}

; -------------------------------------------------
; DoPickerClick - 执行点击复制颜色
; -------------------------------------------------
DoPickerClick() {
    global IsPicking, LastColor, CurrentFormat, ColorHistory

    if !IsPicking
        return

    ; 获取要复制的颜色格式
    color := LastColor
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF

    hexColor := Format("#{:02X}{:02X}{:02X}", r, g, b)

    switch CurrentFormat {
        case "HEX":
            copyText := hexColor
        case "RGB":
            copyText := Format("rgb({}, {}, {})", r, g, b)
        case "HSL":
            copyText := RGBtoHSL(r, g, b)
        default:
            copyText := hexColor
    }

    ; 复制到剪贴板
    A_Clipboard := copyText

    ; 添加到历史记录
    AddToHistory(hexColor)

    ; 结束取色
    StopColorPicker()

    ShowNotification("🎨 已复制", copyText)
}

; -------------------------------------------------
; DoFormatSwitch - 执行切换颜色格式
; -------------------------------------------------
DoFormatSwitch() {
    global IsPicking, CurrentFormat

    if !IsPicking
        return

    ; 循环切换格式
    switch CurrentFormat {
        case "HEX":
            CurrentFormat := "RGB"
        case "RGB":
            CurrentFormat := "HSL"
        case "HSL":
            CurrentFormat := "HEX"
    }

    ShowNotification("🎨 格式", CurrentFormat)
}

; -------------------------------------------------
; OnPickerClick - 点击复制颜色 (旧函数保留兼容)
; -------------------------------------------------
OnPickerClick(*) {
    DoPickerClick()
}

; -------------------------------------------------
; OnFormatSwitch - 切换颜色格式
; -------------------------------------------------
OnFormatSwitch(*) {
    global IsPicking, CurrentFormat

    if !IsPicking
        return

    ; 循环切换格式
    switch CurrentFormat {
        case "HEX":
            CurrentFormat := "RGB"
        case "RGB":
            CurrentFormat := "HSL"
        case "HSL":
            CurrentFormat := "HEX"
    }

    ShowNotification("🎨 格式", CurrentFormat)
}

; -------------------------------------------------
; OnPickerCancel - 取消取色
; -------------------------------------------------
OnPickerCancel(*) {
    global IsPicking

    if !IsPicking
        return

    StopColorPicker()
    ShowNotification("🎨 取消", "取色已取消")
}

; -------------------------------------------------
; OnZoomIn - 放大
; -------------------------------------------------
OnZoomIn(*) {
    global IsPicking, CurrentZoom, MaxZoom

    if !IsPicking
        return

    if (CurrentZoom < MaxZoom) {
        CurrentZoom += 2
        ShowNotification("🔍 放大", CurrentZoom "x")
    }
}

; -------------------------------------------------
; OnZoomOut - 缩小
; -------------------------------------------------
OnZoomOut(*) {
    global IsPicking, CurrentZoom, MinZoom

    if !IsPicking
        return

    if (CurrentZoom > MinZoom) {
        CurrentZoom -= 2
        ShowNotification("🔍 缩小", CurrentZoom "x")
    }
}

; -------------------------------------------------
; StopColorPicker - 停止取色
; -------------------------------------------------
StopColorPicker() {
    global IsPicking, PickerGui, MagnifierGui

    IsPicking := false

    ; 停止定时器
    SetTimer(UpdatePicker, 0)

    ; 解除热键
    try {
        Hotkey("*Escape", "Off")
        Hotkey("*WheelUp", "Off")
        Hotkey("*WheelDown", "Off")
    }

    ; 恢复鼠标
    RestoreSystemCursor()

    ; 销毁GUI
    if IsObject(MagnifierGui) {
        MagnifierGui.Destroy()
        MagnifierGui := ""
    }
    if IsObject(PickerGui) {
        PickerGui.Destroy()
        PickerGui := ""
    }
}

; -------------------------------------------------
; AddToHistory - 添加到历史记录
; -------------------------------------------------
AddToHistory(color) {
    global ColorHistory, MaxHistory, HistoryGui

    ; 检查是否已存在
    for i, c in ColorHistory {
        if (c = color) {
            ColorHistory.RemoveAt(i)
            break
        }
    }

    ; 添加到开头
    ColorHistory.InsertAt(1, color)

    ; 限制数量
    while (ColorHistory.Length > MaxHistory)
        ColorHistory.Pop()

    ; 如果历史窗口正在显示，刷新它
    if IsObject(HistoryGui) {
        try {
            if WinExist(HistoryGui.Hwnd) {
                RefreshHistoryGui()
            }
        }
    }
}

; -------------------------------------------------
; ShowColorHistory - 显示颜色历史
; -------------------------------------------------
ShowColorHistory() {
    global ColorHistory, HistoryGui

    if (ColorHistory.Length = 0) {
        ShowNotification("🎨 历史", "暂无颜色记录")
        return
    }

    ; 如果窗口已存在，先关闭它
    if IsObject(HistoryGui) {
        try HistoryGui.Destroy()
    }

    ; 创建历史窗口
    HistoryGui := Gui("+AlwaysOnTop -MinimizeBox", "🎨 颜色历史")
    HistoryGui.BackColor := "1a1a1a"
    HistoryGui.OnEvent("Close", OnHistoryGuiClose)

    ; 构建内容
    BuildHistoryContent()

    ; 计算窗口高度
    guiHeight := 50 + ColorHistory.Length * 40 + 50
    HistoryGui.Show("w220 h" guiHeight)
}

; -------------------------------------------------
; OnHistoryGuiClose - 历史窗口关闭事件
; -------------------------------------------------
OnHistoryGuiClose(guiObj) {
    global HistoryGui
    HistoryGui := ""
}

; -------------------------------------------------
; RefreshHistoryGui - 刷新历史窗口内容
; -------------------------------------------------
RefreshHistoryGui() {
    global HistoryGui, ColorHistory

    if !IsObject(HistoryGui)
        return

    ; 记住当前位置
    try {
        WinGetPos(&winX, &winY, , , HistoryGui.Hwnd)
    } catch {
        winX := ""
        winY := ""
    }

    ; 清空并重建内容
    try {
        ; 销毁旧窗口，创建新窗口
        HistoryGui.Destroy()

        HistoryGui := Gui("+AlwaysOnTop -MinimizeBox", "🎨 颜色历史")
        HistoryGui.BackColor := "1a1a1a"
        HistoryGui.OnEvent("Close", OnHistoryGuiClose)

        BuildHistoryContent()

        ; 计算窗口高度
        guiHeight := 50 + ColorHistory.Length * 40 + 50

        ; 在原位置显示
        if (winX != "" && winY != "")
            HistoryGui.Show("x" winX " y" winY " w220 h" guiHeight)
        else
            HistoryGui.Show("w220 h" guiHeight)
    }
}

; -------------------------------------------------
; BuildHistoryContent - 构建历史窗口内容
; -------------------------------------------------
BuildHistoryContent() {
    global HistoryGui, ColorHistory

    HistoryGui.SetFont("s10 cWhite", "Segoe UI")
    HistoryGui.AddText("x10 y10 w280", "点击颜色复制到剪贴板：")

    y := 40
    for i, color in ColorHistory {
        ; 颜色块 - 创建纯色位图文件并显示
        colorHex := SubStr(color, 2)
        bmpPath := CreateColorBitmap(colorHex, 30, 30)
        if (bmpPath != "") {
            HistoryGui.AddPicture("x10 y" y " w30 h30 +Border", bmpPath)
        }

        ; 颜色值按钮
        btn := HistoryGui.AddButton("x50 y" (y - 2) " w150 h30", color)
        btn.OnEvent("Click", CopyHistoryColor.Bind(color))

        y += 40
    }

    HistoryGui.AddButton("x10 y" y " w100 h30", "清空历史").OnEvent("Click", ClearHistory)
    HistoryGui.AddButton("x120 y" y " w80 h30", "关闭").OnEvent("Click", (*) => (HistoryGui.Destroy(), HistoryGui := ""))
}

; -------------------------------------------------
; CreateColorBitmap - 创建纯色位图文件
; -------------------------------------------------
CreateColorBitmap(hexColor, width, height) {
    ; 解析颜色
    r := Integer("0x" SubStr(hexColor, 1, 2))
    g := Integer("0x" SubStr(hexColor, 3, 2))
    b := Integer("0x" SubStr(hexColor, 5, 2))

    ; 创建临时文件路径
    bmpPath := A_Temp "\color_" hexColor ".bmp"

    ; 如果文件已存在，直接返回
    if FileExist(bmpPath)
        return bmpPath

    ; BMP 文件头 (14 bytes)
    fileSize := 54 + width * height * 3 + (width * 3 + 3) // 4 * 4 * height - width * height * 3
    rowSize := ((width * 3 + 3) // 4) * 4  ; 每行字节数（4字节对齐）
    pixelDataSize := rowSize * height

    file := FileOpen(bmpPath, "w")
    if !file
        return ""

    ; BITMAPFILEHEADER
    file.WriteUChar(0x42)  ; 'B'
    file.WriteUChar(0x4D)  ; 'M'
    file.WriteUInt(54 + pixelDataSize)  ; 文件大小
    file.WriteUShort(0)    ; 保留
    file.WriteUShort(0)    ; 保留
    file.WriteUInt(54)     ; 像素数据偏移

    ; BITMAPINFOHEADER
    file.WriteUInt(40)     ; 头大小
    file.WriteInt(width)   ; 宽度
    file.WriteInt(height)  ; 高度
    file.WriteUShort(1)    ; 色彩平面数
    file.WriteUShort(24)   ; 每像素位数
    file.WriteUInt(0)      ; 压缩方式
    file.WriteUInt(pixelDataSize)  ; 像素数据大小
    file.WriteInt(2835)    ; 水平分辨率
    file.WriteInt(2835)    ; 垂直分辨率
    file.WriteUInt(0)      ; 调色板颜色数
    file.WriteUInt(0)      ; 重要颜色数

    ; 写入像素数据 (BGR 格式，从下到上)
    padding := rowSize - width * 3
    loop height {
        loop width {
            file.WriteUChar(b)  ; Blue
            file.WriteUChar(g)  ; Green
            file.WriteUChar(r)  ; Red
        }
        ; 写入填充字节
        loop padding
            file.WriteUChar(0)
    }

    file.Close()
    return bmpPath
}

; -------------------------------------------------
; ClearHistory - 清空历史记录
; -------------------------------------------------
ClearHistory(*) {
    global ColorHistory, HistoryGui
    ColorHistory := []
    if IsObject(HistoryGui) {
        HistoryGui.Destroy()
        HistoryGui := ""
    }
    ShowNotification("🎨 已清空", "颜色历史已清空")
}

CopyHistoryColor(color, *) {
    A_Clipboard := color
    ShowNotification("🎨 已复制", color)
}

; =================================================
; 辅助函数
; =================================================

TryDeleteFile(path) {
    try FileDelete(path)
}

InitGDIPlus() {
    global pToken, hGdip

    hGdip := DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")

    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
}

SetSystemCursor(cursorName) {
    cursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr")  ; IDC_CROSS

    cursorIDs := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651]
    for id in cursorIDs {
        cursorCopy := DllCall("CopyImage", "Ptr", cursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
        DllCall("SetSystemCursor", "Ptr", cursorCopy, "UInt", id)
    }
}

RestoreSystemCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)
}

ShowNotification(title, text) {
    ToolTip(title "`n" text)
    SetTimer(() => ToolTip(), -1500)
}

; =================================================
; 清理
; =================================================

OnExit(ExitFunc)

ExitFunc(reason, code) {
    global pToken

    try RestoreSystemCursor()

    if (pToken != 0) {
        try DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
        pToken := 0
    }
}

; =================================================
; 初始化完成
; =================================================
ShowNotification("🎨 屏幕取色工具", "已启动！按 Win+Shift+C 取色")