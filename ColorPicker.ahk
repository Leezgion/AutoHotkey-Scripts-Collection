; =================================================
; 🎨 屏幕取色工具 v2 (重构版)
; =================================================
; 使用模块: StateMachine, GDIPlus, i18n, Constants
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ---------- 🖥️ 托盘设置 ----------
#NoTrayIcon

; ---------- 📦 加载模块 ----------
#Include Lib\Constants.ahk
#Include Lib\GDIPlus.ahk
#Include Lib\StateMachine.ahk
#Include Lib\i18n.ahk

; ---------- 🎨 配置区域 ----------
global Config := {
    MagnifierSize: Defaults.PickerMagnifierSize,
    MagnifierZoom: Defaults.PickerMagnifierZoom,
    MinZoom: Defaults.PickerMinZoom,
    MaxZoom: Defaults.PickerMaxZoom,
    PreviewSize: 50,
    MaxHistory: Defaults.PickerMaxHistory,
    DefaultFormat: Defaults.PickerColorFormat
}

; ---------- 核心数据 ----------
global PickerGui := ""
global MagnifierGui := ""
global HistoryGui := ""
global CurrentFormat := Config.DefaultFormat
global CurrentZoom := Config.MagnifierZoom
global ColorHistory := []
global LastColor := ""
global LButtonWasDown := false
global RButtonWasDown := false

; ---------- 🔄 状态机初始化 ----------
global FSM := ColorPickerStateMachine()

; ---------- 📦 模块初始化 ----------
Initialize()

Initialize() {
    ; 初始化多语言
    I18n.Init("auto")

    ; 初始化 GDI+
    if !GDIPlus.Startup() {
        MsgBox(T("error.gdipInit"), "Error", "Icon!")
        ExitApp()
    }

    ; 确保截图目录存在
    if !DirExist(Paths.Screenshots)
        DirCreate(Paths.Screenshots)
}

; =================================================
; 🔄 取色器状态机
; =================================================
class ColorPickerStateMachine extends StateMachine {
    __New() {
        super.__New("ColorPicker", PickerState.Idle)

        ; 定义状态
        this.DefineStates([
            PickerState.Idle,
            PickerState.Initializing,
            PickerState.Picking,
            PickerState.Copying,
            PickerState.Cleanup
        ])

        ; 定义转换
        this.AddTransition(PickerState.Idle, "START", PickerState.Initializing)
        this.AddTransition(PickerState.Initializing, "READY", PickerState.Picking)
        this.AddTransition(PickerState.Picking, "CLICK", PickerState.Copying)
        this.AddTransition(PickerState.Picking, "CANCEL", PickerState.Cleanup)
        this.AddTransition(PickerState.Copying, "DONE", PickerState.Cleanup)
        this.AddTransition(PickerState.Cleanup, "COMPLETE", PickerState.Idle)

        ; 注册回调
        this.OnEnter(PickerState.Initializing, (old, new, data) => this._OnEnterInit())
        this.OnEnter(PickerState.Picking, (old, new, data) => this._OnEnterPicking())
        this.OnEnter(PickerState.Copying, (old, new, data) => this._OnEnterCopying(data))
        this.OnEnter(PickerState.Cleanup, (old, new, data) => this._OnEnterCleanup(data))

        this.EnableDebug(false)
    }

    ; -------------------------------------------------
    ; 状态回调: 初始化
    ; -------------------------------------------------
    _OnEnterInit() {
        global PickerGui, MagnifierGui, CurrentZoom, LButtonWasDown, RButtonWasDown

        CurrentZoom := Config.MagnifierZoom
        LButtonWasDown := false
        RButtonWasDown := false

        ; 创建GUI
        this._CreateMagnifierGui()
        this._CreatePickerGui()

        ; 设置鼠标为十字准星
        Cursor.SetCross()

        ; 绑定快捷键
        Hotkey("*Escape", (*) => this.Trigger("CANCEL"), "On")
        Hotkey("*WheelUp", (*) => this._OnZoom(1), "On")
        Hotkey("*WheelDown", (*) => this._OnZoom(-1), "On")

        ; 触发就绪
        this.Trigger("READY")
    }

    ; -------------------------------------------------
    ; 状态回调: 取色中
    ; -------------------------------------------------
    _OnEnterPicking() {
        ; 开始跟踪鼠标
        SetTimer(ObjBindMethod(this, "_UpdatePicker"), 16)  ; ~60 FPS
    }

    ; -------------------------------------------------
    ; 状态回调: 复制
    ; -------------------------------------------------
    _OnEnterCopying(data) {
        global LastColor, CurrentFormat, ColorHistory

        ; 停止定时器
        SetTimer(ObjBindMethod(this, "_UpdatePicker"), 0)

        ; 获取颜色信息
        color := LastColor
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        hexColor := Format("#{:02X}{:02X}{:02X}", r, g, b)

        ; 根据格式生成复制文本
        switch CurrentFormat {
            case "HEX":
                copyText := hexColor
            case "RGB":
                copyText := Format("rgb({}, {}, {})", r, g, b)
            case "HSL":
                copyText := ColorUtils.RGBToHSLString(r, g, b)
            default:
                copyText := hexColor
        }

        ; 复制到剪贴板
        A_Clipboard := copyText

        ; 添加到历史
        this._AddToHistory(hexColor)

        ; 显示通知
        ShowNotify(T("picker.copied", copyText))

        ; 完成
        this.Trigger("DONE")
    }

    ; -------------------------------------------------
    ; 状态回调: 清理
    ; -------------------------------------------------
    _OnEnterCleanup(data) {
        global PickerGui, MagnifierGui

        ; 停止定时器
        SetTimer(ObjBindMethod(this, "_UpdatePicker"), 0)

        ; 解除热键
        try {
            Hotkey("*Escape", "Off")
            Hotkey("*WheelUp", "Off")
            Hotkey("*WheelDown", "Off")
        }

        ; 恢复鼠标
        Cursor.Restore()

        ; 销毁GUI
        if IsObject(MagnifierGui) {
            MagnifierGui.Destroy()
            MagnifierGui := ""
        }
        if IsObject(PickerGui) {
            PickerGui.Destroy()
            PickerGui := ""
        }

        ; 完成清理
        this.Trigger("COMPLETE")
    }

    ; -------------------------------------------------
    ; 创建放大镜GUI
    ; -------------------------------------------------
    _CreateMagnifierGui() {
        global MagnifierGui

        MagnifierGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
        MagnifierGui.BackColor := "000000"
        MagnifierGui.MarginX := 0
        MagnifierGui.MarginY := 0
        MagnifierGui.AddPicture("vMagView x0 y0 w" Config.MagnifierSize " h" Config.MagnifierSize, "")
    }

    ; -------------------------------------------------
    ; 创建信息面板GUI
    ; -------------------------------------------------
    _CreatePickerGui() {
        global PickerGui

        PickerGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        PickerGui.BackColor := Theme.BgPrimary
        PickerGui.MarginX := 10
        PickerGui.MarginY := 8

        ; 颜色预览块
        PickerGui.AddProgress("vColorPreview x10 y8 w" Config.PreviewSize " h" Config.PreviewSize " Background000000",
            100)

        ; 颜色值显示
        PickerGui.SetFont("s11 cWhite Bold", "Consolas")
        PickerGui.AddText("vColorValue x" (Config.PreviewSize + 20) " y10 w150 h24", "#000000")

        PickerGui.SetFont("s9 c" Theme.FgSecondary, "Segoe UI")
        PickerGui.AddText("vColorRGB x" (Config.PreviewSize + 20) " y36 w150 h18", "RGB(0, 0, 0)")
        PickerGui.AddText("vColorHSL x" (Config.PreviewSize + 20) " y54 w150 h18", "HSL(0°, 0%, 0%)")

        ; 坐标显示
        PickerGui.SetFont("s8 c" Theme.FgMuted, "Consolas")
        PickerGui.AddText("vCoords x10 y" (Config.PreviewSize + 15) " w200 h16", "X: 0  Y: 0")

        ; 操作提示
        PickerGui.SetFont("s8 c" Theme.FgMuted, "Segoe UI")
        PickerGui.AddText("vTips x10 y" (Config.PreviewSize + 33) " w200 h32", T("picker.tips"))
    }

    ; -------------------------------------------------
    ; 更新取色器显示
    ; -------------------------------------------------
    _UpdatePicker() {
        global PickerGui, MagnifierGui, CurrentZoom, LastColor, LButtonWasDown, RButtonWasDown

        if !this.IsState(PickerState.Picking)
            return

        if !IsObject(PickerGui) || !IsObject(MagnifierGui)
            return

        ; 检测鼠标状态
        lButtonDown := DllCall("GetAsyncKeyState", "Int", 0x01, "Short") & 0x8000
        rButtonDown := DllCall("GetAsyncKeyState", "Int", 0x02, "Short") & 0x8000

        ; 左键点击 - 复制颜色
        if (LButtonWasDown && !lButtonDown) {
            LButtonWasDown := false
            this.Trigger("CLICK")
            return
        }
        LButtonWasDown := lButtonDown

        ; 右键点击 - 切换格式
        if (RButtonWasDown && !rButtonDown) {
            RButtonWasDown := false
            this._SwitchFormat()
        }
        RButtonWasDown := rButtonDown

        ; 获取鼠标位置和颜色
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)

        color := GDIPlus.GetPixelColor(mx, my)
        if (color = -1)
            return

        ; BGR 转 RGB
        color := ColorUtils.BGRToRGB(color)

        ; 更新放大镜
        this._UpdateMagnifier(mx, my)

        ; 更新颜色信息
        if (color != LastColor) {
            LastColor := color
            this._UpdateColorInfo(color)
        }

        ; 定位GUI
        this._PositionGuis(mx, my)
    }

    ; -------------------------------------------------
    ; 更新放大镜内容
    ; -------------------------------------------------
    _UpdateMagnifier(mx, my) {
        global MagnifierGui, CurrentZoom

        if !IsObject(MagnifierGui)
            return

        captureSize := Config.MagnifierSize // CurrentZoom
        halfCapture := captureSize // 2

        sx := mx - halfCapture
        sy := my - halfCapture

        tempFile := A_Temp "\ahk_mag_" A_TickCount ".bmp"

        this._CaptureAndScale(sx, sy, captureSize, captureSize, Config.MagnifierSize, Config.MagnifierSize, tempFile)

        try {
            MagnifierGui["MagView"].Value := tempFile
        }

        SetTimer(() => TryDeleteFile(tempFile), -500)
    }

    ; -------------------------------------------------
    ; 截取并缩放屏幕区域
    ; -------------------------------------------------
    _CaptureAndScale(sx, sy, sw, sh, dw, dh, filePath) {
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", dw, "Int", dh, "Ptr")
        hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

        DllCall("SetStretchBltMode", "Ptr", hdcMem, "Int", 4)  ; HALFTONE
        DllCall("StretchBlt"
            , "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", dw, "Int", dh
            , "Ptr", hdcScreen, "Int", sx, "Int", sy, "Int", sw, "Int", sh
            , "UInt", 0x00CC0020)

        ; 绘制十字准星
        this._DrawCrosshair(hdcMem, dw, dh)

        ; 保存为 BMP
        this._SaveHBitmapToFile(hBitmap, dw, dh, filePath)

        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteObject", "Ptr", hBitmap)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    }

    ; -------------------------------------------------
    ; 绘制十字准星
    ; -------------------------------------------------
    _DrawCrosshair(hdc, w, h) {
        cx := w // 2
        cy := h // 2

        hPenWhite := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0xFFFFFF, "Ptr")
        hPenBlack := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x000000, "Ptr")

        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenBlack, "Ptr")

        ; 绘制黑色外框
        DllCall("MoveToEx", "Ptr", hdc, "Int", cx - 10, "Int", cy, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", cx + 11, "Int", cy)
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

        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
        DllCall("DeleteObject", "Ptr", hPenWhite)
        DllCall("DeleteObject", "Ptr", hPenBlack)
    }

    ; -------------------------------------------------
    ; 保存位图到文件
    ; -------------------------------------------------
    _SaveHBitmapToFile(hBitmap, w, h, filePath) {
        biSize := 40
        bi := Buffer(biSize, 0)
        NumPut("UInt", biSize, bi, 0)
        NumPut("Int", w, bi, 4)
        NumPut("Int", -h, bi, 8)
        NumPut("UShort", 1, bi, 12)
        NumPut("UShort", 24, bi, 14)

        stride := ((w * 3 + 3) & ~3)
        dataSize := stride * h

        bits := Buffer(dataSize)
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", h, "Ptr", bits, "Ptr", bi, "UInt", 0)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

        fh := Buffer(14, 0)
        NumPut("UShort", 0x4D42, fh, 0)
        NumPut("UInt", 54 + dataSize, fh, 2)
        NumPut("UInt", 54, fh, 10)

        file := FileOpen(filePath, "w")
        file.RawWrite(fh, 14)
        file.RawWrite(bi, 40)
        file.RawWrite(bits, dataSize)
        file.Close()
    }

    ; -------------------------------------------------
    ; 更新颜色信息显示
    ; -------------------------------------------------
    _UpdateColorInfo(color) {
        global PickerGui, CurrentFormat

        if !IsObject(PickerGui)
            return

        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        hexColor := Format("#{:02X}{:02X}{:02X}", r, g, b)
        rgbColor := Format("RGB({}, {}, {})", r, g, b)
        hslColor := ColorUtils.RGBToHSLString(r, g, b)

        try {
            colorHex := SubStr(hexColor, 2)
            PickerGui["ColorPreview"].Opt("c" colorHex " Background" colorHex)
            PickerGui["ColorValue"].Text := hexColor
            PickerGui["ColorRGB"].Text := rgbColor
            PickerGui["ColorHSL"].Text := hslColor
        }
    }

    ; -------------------------------------------------
    ; 定位GUI窗口
    ; -------------------------------------------------
    _PositionGuis(mx, my) {
        global PickerGui, MagnifierGui

        if !IsObject(MagnifierGui) || !IsObject(PickerGui)
            return

        screenWidth := SysGet(78)
        screenHeight := SysGet(79)
        screenLeft := SysGet(76)
        screenTop := SysGet(77)

        magX := mx + 20
        magY := my + 20

        infoX := magX
        infoY := magY + Config.MagnifierSize + 5

        if (magX + Config.MagnifierSize > screenLeft + screenWidth)
            magX := mx - Config.MagnifierSize - 20
        if (magY + Config.MagnifierSize > screenTop + screenHeight)
            magY := my - Config.MagnifierSize - 20

        if (magX + 220 > screenLeft + screenWidth)
            infoX := mx - 240
        if (infoY + 100 > screenTop + screenHeight)
            infoY := magY - 105

        MagnifierGui.Show("x" magX " y" magY " w" Config.MagnifierSize " h" Config.MagnifierSize " NA")
        PickerGui.Show("x" infoX " y" infoY " NA")

        try PickerGui["Coords"].Text := Format("X: {}  Y: {}", mx, my)
    }

    ; -------------------------------------------------
    ; 切换颜色格式
    ; -------------------------------------------------
    _SwitchFormat() {
        global CurrentFormat

        switch CurrentFormat {
            case "HEX":
                CurrentFormat := "RGB"
            case "RGB":
                CurrentFormat := "HSL"
            case "HSL":
                CurrentFormat := "HEX"
        }

        ShowNotify("🎨 " T("picker.format." StrLower(CurrentFormat)))
    }

    ; -------------------------------------------------
    ; 缩放处理
    ; -------------------------------------------------
    _OnZoom(direction) {
        global CurrentZoom

        if !this.IsState(PickerState.Picking)
            return

        if (direction > 0 && CurrentZoom < Config.MaxZoom) {
            CurrentZoom += 2
            ShowNotify("🔍 " CurrentZoom "x")
        } else if (direction < 0 && CurrentZoom > Config.MinZoom) {
            CurrentZoom -= 2
            ShowNotify("🔍 " CurrentZoom "x")
        }
    }

    ; -------------------------------------------------
    ; 添加到历史记录
    ; -------------------------------------------------
    _AddToHistory(color) {
        global ColorHistory

        ; 移除已存在的相同颜色
        for i, c in ColorHistory {
            if (c = color) {
                ColorHistory.RemoveAt(i)
                break
            }
        }

        ; 添加到开头
        ColorHistory.InsertAt(1, color)

        ; 限制数量
        while (ColorHistory.Length > Config.MaxHistory)
            ColorHistory.Pop()
    }
}

; =================================================
; 快捷键定义
; =================================================
#+c:: {
    StartColorPicker()
}

; =================================================
; 公共函数
; =================================================

StartColorPicker() {
    global FSM

    if !FSM.IsState(PickerState.Idle)
        return

    FSM.Trigger("START")
}

ShowColorHistory() {
    global ColorHistory, HistoryGui

    if (ColorHistory.Length = 0) {
        ShowNotify(T("picker.noHistory"))
        return
    }

    ; 如果窗口已存在，先关闭
    if IsObject(HistoryGui) {
        try HistoryGui.Destroy()
    }

    HistoryGui := Gui("+AlwaysOnTop -MinimizeBox", "🎨 " T("picker.history"))
    HistoryGui.BackColor := Theme.BgPrimary
    HistoryGui.OnEvent("Close", (*) => (HistoryGui := ""))

    HistoryGui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")
    HistoryGui.AddText("x10 y10 w280", T("picker.history") ":")

    y := 40
    for i, color in ColorHistory {
        colorHex := SubStr(color, 2)
        bmpPath := CreateColorBitmap(colorHex, 30, 30)
        if (bmpPath != "")
            HistoryGui.AddPicture("x10 y" y " w30 h30 +Border", bmpPath)

        btn := HistoryGui.AddButton("x50 y" (y - 2) " w150 h30", color)
        btn.OnEvent("Click", ((c) => (*) => (A_Clipboard := c, ShowNotify(T("picker.copied", c)))).Call(color))

        y += 40
    }

    HistoryGui.AddButton("x10 y" y " w100 h30", T("hotkey.clear")).OnEvent("Click", (*) => (ColorHistory := [],
    HistoryGui.Destroy(), HistoryGui := ""))
    HistoryGui.AddButton("x120 y" y " w80 h30", T("dialog.cancel")).OnEvent("Click", (*) => (HistoryGui.Destroy(),
    HistoryGui := ""))

    guiHeight := 50 + ColorHistory.Length * 40 + 50
    HistoryGui.Show("w220 h" guiHeight)
}

CreateColorBitmap(hexColor, width, height) {
    r := Integer("0x" SubStr(hexColor, 1, 2))
    g := Integer("0x" SubStr(hexColor, 3, 2))
    b := Integer("0x" SubStr(hexColor, 5, 2))

    bmpPath := A_Temp "\color_" hexColor ".bmp"

    if FileExist(bmpPath)
        return bmpPath

    rowSize := ((width * 3 + 3) // 4) * 4
    pixelDataSize := rowSize * height

    file := FileOpen(bmpPath, "w")
    if !file
        return ""

    ; BITMAPFILEHEADER
    file.WriteUChar(0x42)
    file.WriteUChar(0x4D)
    file.WriteUInt(54 + pixelDataSize)
    file.WriteUShort(0)
    file.WriteUShort(0)
    file.WriteUInt(54)

    ; BITMAPINFOHEADER
    file.WriteUInt(40)
    file.WriteInt(width)
    file.WriteInt(height)
    file.WriteUShort(1)
    file.WriteUShort(24)
    file.WriteUInt(0)
    file.WriteUInt(pixelDataSize)
    file.WriteInt(2835)
    file.WriteInt(2835)
    file.WriteUInt(0)
    file.WriteUInt(0)

    padding := rowSize - width * 3
    loop height {
        loop width {
            file.WriteUChar(b)
            file.WriteUChar(g)
            file.WriteUChar(r)
        }
        loop padding
            file.WriteUChar(0)
    }

    file.Close()
    return bmpPath
}

; =================================================
; 消息监听 - 脚本管理器集成
; =================================================
OnMessage(MSG.PICKER_START, OnMsgStartPicker)
OnMessage(MSG.PICKER_SHOW_HISTORY, OnMsgShowHistory)

OnMsgStartPicker(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(StartColorPicker, -100)
    return 1
}

OnMsgShowHistory(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(ShowColorHistory, -100)
    return 1
}

; =================================================
; 辅助函数
; =================================================

TryDeleteFile(path) {
    try FileDelete(path)
}

ShowNotify(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -1500)
}

; =================================================
; 清理
; =================================================
OnExit(ExitFunc)

ExitFunc(reason, code) {
    try Cursor.Restore()
    GDIPlus.Shutdown()
}

; =================================================
; 初始化完成
; =================================================
ShowNotify("🎨 " T("picker.title") " - " T("picker.started"))