; =================================================
; 📸 截图悬浮工具 v2 (重构版)
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
    ScreenshotFolder: Paths.Screenshots,
    SelectionColor: Defaults.ScreenshotSelectionColor,
    SelectionBorderWidth: Defaults.ScreenshotBorderWidth,
    MinFloatSize: 50,
    MaxFloatSize: 2000,
    DefaultOpacity: Defaults.ScreenshotDefaultOpacity,
    OpacityStep: 15,
    ZoomStep: 0.1,
    MaxFloats: Defaults.ScreenshotMaxFloats
}

; ---------- 核心数据 ----------
global FloatingWindows := Map()
global OverlayGui := ""
global BorderTop := ""
global BorderBottom := ""
global BorderLeft := ""
global BorderRight := ""
global SelectionFill := ""
global SizeTooltip := ""
global StartX := 0, StartY := 0
global EndX := 0, EndY := 0

; ---------- 🔄 状态机初始化 ----------
global FSM := ScreenshotStateMachine()

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
    if !DirExist(Config.ScreenshotFolder)
        DirCreate(Config.ScreenshotFolder)

    ; 启动置顶检查定时器
    SetTimer(EnsureFloatOnTop, 1000)
}

; =================================================
; 🔄 截图状态机
; =================================================
class ScreenshotStateMachine extends StateMachine {
    __New() {
        super.__New("Screenshot", ScreenshotState.Idle)

        ; 定义状态
        this.DefineStates([
            ScreenshotState.Idle,
            ScreenshotState.Overlay,
            ScreenshotState.Selecting,
            ScreenshotState.Capturing,
            ScreenshotState.Floating
        ])

        ; 定义转换
        this.AddTransition(ScreenshotState.Idle, "START", ScreenshotState.Overlay)
        this.AddTransition(ScreenshotState.Overlay, "MOUSE_DOWN", ScreenshotState.Selecting)
        this.AddTransition(ScreenshotState.Selecting, "MOUSE_UP", ScreenshotState.Capturing)
        this.AddTransition(ScreenshotState.Selecting, "CANCEL", ScreenshotState.Idle)
        this.AddTransition(ScreenshotState.Overlay, "CANCEL", ScreenshotState.Idle)
        this.AddTransition(ScreenshotState.Capturing, "DONE", ScreenshotState.Floating)
        this.AddTransition(ScreenshotState.Capturing, "FAILED", ScreenshotState.Idle)
        this.AddTransition(ScreenshotState.Floating, "COMPLETE", ScreenshotState.Idle)

        ; 注册回调
        this.OnEnter(ScreenshotState.Overlay, (old, new, data) => this._OnEnterOverlay())
        this.OnEnter(ScreenshotState.Selecting, (old, new, data) => this._OnEnterSelecting())
        this.OnEnter(ScreenshotState.Capturing, (old, new, data) => this._OnEnterCapturing())
        this.OnExit(ScreenshotState.Overlay, (old, new, data) => this._OnExitOverlay())
        this.OnExit(ScreenshotState.Selecting, (old, new, data) => this._OnExitSelecting())

        this.EnableDebug(false)
    }

    ; -------------------------------------------------
    ; 状态回调: 进入覆盖层
    ; -------------------------------------------------
    _OnEnterOverlay() {
        global OverlayGui, BorderTop, BorderBottom, BorderLeft, BorderRight
        global SelectionFill, SizeTooltip, StartX, StartY

        StartX := 0
        StartY := 0

        ; 获取虚拟屏幕尺寸
        screenLeft := SysGet(76)
        screenTop := SysGet(77)
        screenWidth := SysGet(78)
        screenHeight := SysGet(79)

        ; 创建半透明遮罩层
        OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")
        OverlayGui.BackColor := "000000"
        OverlayGui.Show("x" screenLeft " y" screenTop " w" screenWidth " h" screenHeight " NA")
        WinSetTransparent(120, OverlayGui.Hwnd)

        ; 创建选择区域填充
        SelectionFill := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        SelectionFill.BackColor := "000000"

        ; 创建4条边框线
        BorderTop := Gui("+AlwaysOnTop -Caption +ToolWindow")
        BorderTop.BackColor := Config.SelectionColor

        BorderBottom := Gui("+AlwaysOnTop -Caption +ToolWindow")
        BorderBottom.BackColor := Config.SelectionColor

        BorderLeft := Gui("+AlwaysOnTop -Caption +ToolWindow")
        BorderLeft.BackColor := Config.SelectionColor

        BorderRight := Gui("+AlwaysOnTop -Caption +ToolWindow")
        BorderRight.BackColor := Config.SelectionColor

        ; 创建尺寸提示框
        SizeTooltip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        SizeTooltip.BackColor := Theme.BgSecondary
        SizeTooltip.SetFont("s10 c" Theme.FgPrimary, "Consolas")
        SizeTooltip.MarginX := 8
        SizeTooltip.MarginY := 4
        SizeTooltip.AddText("vSizeText c" Theme.FgPrimary, "0 x 0")

        ; 设置鼠标为十字准星
        Cursor.SetCross()

        ; 监听鼠标事件
        OnMessage(0x201, OnLButtonDown)
        OnMessage(0x200, OnMouseMove)
        OnMessage(0x202, OnLButtonUp)

        ; 绑定ESC取消
        Hotkey("*Escape", (*) => this.Trigger("CANCEL"), "On")
    }

    ; -------------------------------------------------
    ; 状态回调: 退出覆盖层
    ; -------------------------------------------------
    _OnExitOverlay() {
        try Hotkey("*Escape", "Off")
    }

    ; -------------------------------------------------
    ; 状态回调: 进入选择中
    ; -------------------------------------------------
    _OnEnterSelecting() {
        ; 选择已开始
    }

    ; -------------------------------------------------
    ; 状态回调: 退出选择中
    ; -------------------------------------------------
    _OnExitSelecting() {
        ; 清理选择界面
        this._CleanupSelectionUI()
    }

    ; -------------------------------------------------
    ; 状态回调: 进入截取中
    ; -------------------------------------------------
    _OnEnterCapturing() {
        global StartX, StartY, EndX, EndY

        ; 计算选择区域
        x := Min(StartX, EndX)
        y := Min(StartY, EndY)
        w := Abs(EndX - StartX)
        h := Abs(EndY - StartY)

        ; 如果选择区域太小，取消
        if (w < 10 || h < 10) {
            ShowNotify(T("screenshot.tooSmall"))
            this.Trigger("FAILED")
            return
        }

        ; 执行截图
        this._CaptureAndFloat(x, y, w, h)
        this.Trigger("DONE")
    }

    ; -------------------------------------------------
    ; 清理选择界面
    ; -------------------------------------------------
    _CleanupSelectionUI() {
        global OverlayGui, BorderTop, BorderBottom, BorderLeft, BorderRight
        global SelectionFill, SizeTooltip

        ; 移除消息监听
        OnMessage(0x201, OnLButtonDown, 0)
        OnMessage(0x200, OnMouseMove, 0)
        OnMessage(0x202, OnLButtonUp, 0)

        ; 恢复鼠标指针
        Cursor.Restore()

        ; 销毁所有 GUI
        for guiVar in [OverlayGui, SelectionFill, BorderTop, BorderBottom, BorderLeft, BorderRight, SizeTooltip] {
            if guiVar {
                try guiVar.Destroy()
            }
        }

        OverlayGui := ""
        SelectionFill := ""
        BorderTop := ""
        BorderBottom := ""
        BorderLeft := ""
        BorderRight := ""
        SizeTooltip := ""
    }

    ; -------------------------------------------------
    ; 截图并悬浮显示
    ; -------------------------------------------------
    _CaptureAndFloat(x, y, w, h) {
        global FloatingWindows

        ; 检查悬浮窗数量限制
        if (FloatingWindows.Count >= Config.MaxFloats) {
            ; 关闭最早的悬浮窗
            for hwnd, info in FloatingWindows {
                CloseFloatingWindow(hwnd)
                break
            }
        }

        ; 使用 GDI+ 截图
        pBitmap := GDIPlus.CaptureScreen(x, y, w, h)
        if !pBitmap {
            ShowNotify("❌ " T("error.unknown"))
            return
        }

        ; 生成临时文件路径
        tempFile := A_Temp "\ahk_screenshot_" A_TickCount ".png"

        ; 保存为 PNG
        GDIPlus.SaveToFile(pBitmap, tempFile, "PNG")
        GDIPlus.DisposeImage(pBitmap)

        ; 创建悬浮窗口
        floatGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        floatGui.BackColor := "FFFFFF"
        floatGui.MarginX := 0
        floatGui.MarginY := 0

        ; 添加图片
        pic := floatGui.AddPicture("x0 y0 w" w " h" h, tempFile)

        ; 计算显示位置
        showX := x + 20
        showY := y + 20

        screenWidth := SysGet(78)
        screenHeight := SysGet(79)
        if (showX + w > screenWidth)
            showX := screenWidth - w - 20
        if (showY + h > screenHeight)
            showY := screenHeight - h - 20

        floatGui.Show("x" showX " y" showY " w" w " h" h " NA")
        WinSetTransparent(Config.DefaultOpacity, floatGui.Hwnd)

        ; 存储悬浮窗信息
        FloatingWindows[floatGui.Hwnd] := {
            gui: floatGui,
            pic: pic,
            tempFile: tempFile,
            originalW: w,
            originalH: h,
            currentW: w,
            currentH: h,
            scale: 1.0,
            opacity: Config.DefaultOpacity
        }

        ; 绑定事件
        floatGui.OnEvent("Close", OnFloatClose)
        BindFloatEvents(floatGui.Hwnd)

        ShowNotify("📸 " T("screenshot.done") " (" w "x" h ")")

        ; 返回到空闲状态
        this.Trigger("COMPLETE")
    }
}

; =================================================
; 鼠标消息处理
; =================================================

OnLButtonDown(wParam, lParam, msg, hwnd) {
    global FSM, StartX, StartY

    if !FSM.IsState(ScreenshotState.Overlay)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&StartX, &StartY)

    FSM.Trigger("MOUSE_DOWN")
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    global FSM, StartX, StartY, EndX, EndY
    global BorderTop, BorderBottom, BorderLeft, BorderRight, SelectionFill, SizeTooltip

    if !FSM.IsState(ScreenshotState.Selecting)
        return

    if !(wParam & 1)  ; MK_LBUTTON
        return

    if (StartX = 0 && StartY = 0)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&EndX, &EndY)

    ; 计算选择框
    x := Min(StartX, EndX)
    y := Min(StartY, EndY)
    w := Abs(EndX - StartX)
    h := Abs(EndY - StartY)
    bw := Config.SelectionBorderWidth

    if (w > 3 && h > 3) {
        SelectionFill.Show("x" x " y" y " w" w " h" h " NA")
        WinSetTransparent(1, SelectionFill.Hwnd)

        BorderTop.Show("x" x " y" (y - bw) " w" w " h" bw " NA")
        BorderBottom.Show("x" x " y" (y + h) " w" w " h" bw " NA")
        BorderLeft.Show("x" (x - bw) " y" (y - bw) " w" bw " h" (h + bw * 2) " NA")
        BorderRight.Show("x" (x + w) " y" (y - bw) " w" bw " h" (h + bw * 2) " NA")

        try {
            SizeTooltip["SizeText"].Text := w " x " h
            tipY := y - 30
            if (tipY < 0)
                tipY := y + h + 5
            SizeTooltip.Show("x" x " y" tipY " NA")
        }
    }
}

OnLButtonUp(wParam, lParam, msg, hwnd) {
    global FSM, EndX, EndY

    if !FSM.IsState(ScreenshotState.Selecting)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&EndX, &EndY)

    FSM.Trigger("MOUSE_UP")
}

; =================================================
; 悬浮窗事件处理
; =================================================

BindFloatEvents(hwnd) {
    ; 使用热键监听
    HotIfWinActive("ahk_id " hwnd)
    Hotkey("RButton", (*) => CloseFloatingWindow(hwnd), "On")
    Hotkey("^c", (*) => CopyFloatToClipboard(hwnd), "On")
    Hotkey("^s", (*) => SaveFloatToFile(hwnd), "On")
    Hotkey("WheelUp", (*) => ZoomFloat(hwnd, 1), "On")
    Hotkey("WheelDown", (*) => ZoomFloat(hwnd, -1), "On")
    Hotkey("^WheelUp", (*) => AdjustOpacity(hwnd, 1), "On")
    Hotkey("^WheelDown", (*) => AdjustOpacity(hwnd, -1), "On")
    Hotkey("Escape", (*) => CloseFloatingWindow(hwnd), "On")
    HotIf()

    ; 拖动功能 - 只对悬浮窗启用
    ; 注意: 我们使用自定义的消息处理，而不是全局的 OnNcHitTest
    ; 为每个悬浮窗单独注册
    RegisterFloatDrag(hwnd)
}

RegisterFloatDrag(hwnd) {
    ; 使用子类化实现拖动，避免全局消息干扰其他窗口
    ; 为每个悬浮窗设置可拖动
    ; 通过 WM_NCHITTEST 消息实现
    static floatHwnds := Map()
    floatHwnds[hwnd] := true

    ; 如果还没有注册全局处理器，注册一次
    static registered := false
    if !registered {
        OnMessage(0x84, OnNcHitTestFloat)
        registered := true
    }
}

OnNcHitTestFloat(wParam, lParam, msg, hwnd) {
    global FloatingWindows

    ; 只对悬浮窗返回 HTCAPTION，其他窗口不处理
    if FloatingWindows.Has(hwnd) {
        return 2  ; HTCAPTION
    }
    ; 返回空让系统继续处理
}

OnFloatClose(guiObj) {
    CloseFloatingWindow(guiObj.Hwnd)
}

CloseFloatingWindow(hwnd) {
    global FloatingWindows

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    ; 禁用热键
    try {
        HotIfWinActive("ahk_id " hwnd)
        Hotkey("RButton", "Off")
        Hotkey("^c", "Off")
        Hotkey("^s", "Off")
        Hotkey("WheelUp", "Off")
        Hotkey("WheelDown", "Off")
        Hotkey("^WheelUp", "Off")
        Hotkey("^WheelDown", "Off")
        Hotkey("Escape", "Off")
        HotIf()
    }

    ; 删除临时文件
    try FileDelete(info.tempFile)

    ; 销毁窗口
    try info.gui.Destroy()
    FloatingWindows.Delete(hwnd)
}

CloseAllFloatingWindows() {
    global FloatingWindows

    if FloatingWindows.Count = 0
        return

    hwnds := []
    for hwnd in FloatingWindows
        hwnds.Push(hwnd)

    for hwnd in hwnds
        CloseFloatingWindow(hwnd)

    ShowNotify(T("screenshot.allClosed"))
}

ZoomFloat(hwnd, direction) {
    global FloatingWindows

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    newScale := info.scale + (direction > 0 ? Config.ZoomStep : -Config.ZoomStep)

    newW := info.originalW * newScale
    newH := info.originalH * newScale

    if (newW < Config.MinFloatSize || newH < Config.MinFloatSize || newW > Config.MaxFloatSize || newH > Config.MaxFloatSize
    )
        return

    info.scale := newScale
    info.currentW := Round(newW)
    info.currentH := Round(newH)

    info.pic.Value := "*w" info.currentW " *h" info.currentH " " info.tempFile
    info.gui.Move(, , info.currentW, info.currentH)

    FloatingWindows[hwnd] := info
}

AdjustOpacity(hwnd, direction) {
    global FloatingWindows

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    newOpacity := info.opacity + (direction > 0 ? Config.OpacityStep : -Config.OpacityStep)
    newOpacity := Max(30, Min(255, newOpacity))

    info.opacity := newOpacity
    WinSetTransparent(newOpacity, hwnd)

    FloatingWindows[hwnd] := info
}

CopyFloatToClipboard(hwnd) {
    global FloatingWindows

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    pBitmap := GDIPlus.LoadFromFile(info.tempFile)
    if pBitmap {
        GDIPlus.CopyToClipboard(pBitmap)
        GDIPlus.DisposeImage(pBitmap)
        ShowNotify("📋 " T("screenshot.copied"))
    }
}

SaveFloatToFile(hwnd) {
    global FloatingWindows

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    savePath := Config.ScreenshotFolder "\Screenshot_" timestamp ".png"

    try {
        FileCopy(info.tempFile, savePath)
        ShowNotify("💾 " T("screenshot.saved") ": " savePath)
        Run("explorer.exe /select,`"" savePath "`"")
    } catch as e {
        ShowNotify("❌ " T("screenshot.saveFailed") ": " e.Message)
    }
}

EnsureFloatOnTop() {
    global FloatingWindows

    for hwnd, info in FloatingWindows {
        if WinExist(hwnd) {
            try {
                exStyle := WinGetExStyle(hwnd)
                if !(exStyle & 0x8) {  ; WS_EX_TOPMOST
                    WinSetAlwaysOnTop(true, hwnd)
                }
            }
        }
    }
}

; =================================================
; 快捷键定义
; =================================================
#+s:: {
    StartScreenshot()
}

#+q:: {
    CloseAllFloatingWindows()
}

; =================================================
; 公共函数
; =================================================

StartScreenshot() {
    global FSM

    if !FSM.IsState(ScreenshotState.Idle)
        return

    FSM.Trigger("START")
}

; =================================================
; 消息监听 - 脚本管理器集成
; =================================================
OnMessage(MSG.SCREENSHOT_START, OnMsgStartScreenshot)
OnMessage(MSG.SCREENSHOT_CLOSE_ALL, OnMsgCloseAll)

OnMsgStartScreenshot(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(StartScreenshot, -100)
    return 1
}

OnMsgCloseAll(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(CloseAllFloatingWindows, -100)
    return 1
}

; =================================================
; 辅助函数
; =================================================

ShowNotify(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -2000)
}

; =================================================
; 清理
; =================================================
OnExit(ExitFunc)

ExitFunc(reason, code) {
    global FloatingWindows

    ; 关闭所有悬浮窗
    try {
        for hwnd, info in FloatingWindows {
            try FileDelete(info.tempFile)
            try info.gui.Destroy()
        }
    }

    try Cursor.Restore()
    GDIPlus.Shutdown()
}

; =================================================
; 初始化完成
; =================================================
ShowNotify("📸 " T("screenshot.title") " - " T("screenshot.started"))