; =================================================
; 📸 截图悬浮工具 (AutoHotkey v2)
;
; 功能说明：
;   - 框选屏幕区域进行截图
;   - 截图自动悬浮置顶显示
;   - 支持拖动、缩放、调节透明度
;   - 支持复制到剪贴板、保存到文件
;   - 可同时显示多个悬浮截图
;
; 快捷键：
;   Win + Shift + S : 开始截图
;   ESC            : 取消截图 / 关闭悬浮窗
;
; 悬浮窗操作：
;   左键拖动      : 移动窗口
;   滚轮          : 缩放大小
;   Ctrl+滚轮     : 调节透明度
;   右键          : 关闭当前悬浮窗
;   Ctrl+C        : 复制到剪贴板
;   Ctrl+S        : 保存到文件
;   Ctrl+A        : 关闭所有悬浮窗
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ---------- 🖥️ 托盘设置 ----------
; 隐藏托盘图标，由脚本管理器统一管理
#NoTrayIcon

; ---------- 🎨 配置区域 ----------
global ScreenshotFolder := A_ScriptDir "\Screenshots"  ; 截图保存目录
global SelectionColor := "00AAFF"                       ; 选框颜色（蓝色）
global SelectionBorderWidth := 3                        ; 选框边框宽度（加粗更明显）
global MinFloatSize := 50                               ; 悬浮窗最小尺寸
global MaxFloatSize := 2000                             ; 悬浮窗最大尺寸
global DefaultOpacity := 255                            ; 默认不透明度 (0-255)
global OpacityStep := 15                                ; 透明度调节步进
global ZoomStep := 0.1                                  ; 缩放步进

; ---------- 核心数据 ----------
global FloatingWindows := Map()    ; 存储所有悬浮窗 {hwnd: {gui, pic, originalW, originalH, scale, opacity}}
global IsSelecting := false        ; 是否正在选择区域
global OverlayGui := ""            ; 半透明遮罩层
global BorderTop := ""             ; 选择框-上边框
global BorderBottom := ""          ; 选择框-下边框
global BorderLeft := ""            ; 选择框-左边框
global BorderRight := ""           ; 选择框-右边框
global SelectionFill := ""         ; 选择区域填充（清除遮罩效果）
global SizeTooltip := ""           ; 尺寸提示框
global StartX := 0, StartY := 0    ; 选择起点
global EndX := 0, EndY := 0        ; 选择终点

; ---------- GDI+ 初始化 ----------
global pToken := 0
InitGDIPlus()

; 确保截图目录存在
if !DirExist(ScreenshotFolder)
    DirCreate(ScreenshotFolder)

; ---------- 保持悬浮窗置顶的定时器 ----------
; 每秒检查一次，确保所有悬浮窗保持 AlwaysOnTop 状态
SetTimer(EnsureFloatOnTop, 1000)

EnsureFloatOnTop() {
    global FloatingWindows

    for hwnd, info in FloatingWindows {
        if WinExist(hwnd) {
            try {
                ; 检查窗口是否仍然置顶，如果不是则重新设置
                exStyle := WinGetExStyle(hwnd)
                if !(exStyle & 0x8) {  ; WS_EX_TOPMOST = 0x8
                    WinSetAlwaysOnTop(true, hwnd)
                }
            }
        }
    }
}

; =================================================
; 快捷键定义
; =================================================

; Win + Shift + S: 开始截图
#+s:: {
    StartScreenshot()
}

; ESC: 取消截图 / 关闭当前悬浮窗
~*Escape:: {
    if IsSelecting {
        CancelSelection()
        return
    }
    ; 关闭当前激活的悬浮窗
    activeHwnd := WinGetID("A")
    for hwnd, floatWin in FloatingWindows {
        if (hwnd = activeHwnd) {
            CloseFloatingWindow(hwnd)
            return
        }
    }
}

; Win + Shift + Q: 关闭所有悬浮窗
#+q:: {
    CloseAllFloatingWindows()
}

; =================================================
; 截图流程函数
; =================================================

; -------------------------------------------------
; StartScreenshot - 开始截图流程
; -------------------------------------------------
StartScreenshot() {
    global IsSelecting, OverlayGui, StartX, StartY
    global BorderTop, BorderBottom, BorderLeft, BorderRight, SelectionFill, SizeTooltip
    global SelectionColor, SelectionBorderWidth

    if IsSelecting
        return

    IsSelecting := true
    StartX := 0
    StartY := 0

    ; 获取虚拟屏幕尺寸（支持多显示器）
    screenLeft := SysGet(76)    ; SM_XVIRTUALSCREEN
    screenTop := SysGet(77)     ; SM_YVIRTUALSCREEN
    screenWidth := SysGet(78)   ; SM_CXVIRTUALSCREEN
    screenHeight := SysGet(79)  ; SM_CYVIRTUALSCREEN

    ; 创建半透明遮罩层
    OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")  ; WS_EX_LAYERED
    OverlayGui.BackColor := "000000"
    OverlayGui.Show("x" screenLeft " y" screenTop " w" screenWidth " h" screenHeight " NA")
    WinSetTransparent(120, OverlayGui.Hwnd)  ; 稍微深一点的遮罩

    ; 创建选择区域填充（用于"挖空"遮罩层显示原始屏幕）
    SelectionFill := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")  ; 鼠标穿透
    SelectionFill.BackColor := "000000"

    ; 创建4条边框线 - 亮蓝色边框（不使用鼠标穿透，确保可见）
    BorderTop := Gui("+AlwaysOnTop -Caption +ToolWindow")
    BorderTop.BackColor := SelectionColor

    BorderBottom := Gui("+AlwaysOnTop -Caption +ToolWindow")
    BorderBottom.BackColor := SelectionColor

    BorderLeft := Gui("+AlwaysOnTop -Caption +ToolWindow")
    BorderLeft.BackColor := SelectionColor

    BorderRight := Gui("+AlwaysOnTop -Caption +ToolWindow")
    BorderRight.BackColor := SelectionColor

    ; 创建尺寸提示框
    SizeTooltip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    SizeTooltip.BackColor := "222222"
    SizeTooltip.SetFont("s10 cWhite", "Consolas")
    SizeTooltip.MarginX := 8
    SizeTooltip.MarginY := 4
    SizeTooltip.AddText("vSizeText cWhite", "0 x 0")

    ; 设置鼠标为十字准星
    SetSystemCursor("cross")

    ; 监听鼠标事件
    OnMessage(0x201, OnLButtonDown)   ; WM_LBUTTONDOWN
    OnMessage(0x200, OnMouseMove)     ; WM_MOUSEMOVE
    OnMessage(0x202, OnLButtonUp)     ; WM_LBUTTONUP
}

; -------------------------------------------------
; OnLButtonDown - 鼠标左键按下
; -------------------------------------------------
OnLButtonDown(wParam, lParam, msg, hwnd) {
    global IsSelecting, StartX, StartY

    if !IsSelecting
        return

    ; 记录起点
    CoordMode("Mouse", "Screen")
    MouseGetPos(&StartX, &StartY)
}

; -------------------------------------------------
; OnMouseMove - 鼠标移动
; -------------------------------------------------
OnMouseMove(wParam, lParam, msg, hwnd) {
    global IsSelecting, StartX, StartY, EndX, EndY
    global BorderTop, BorderBottom, BorderLeft, BorderRight, SelectionFill, SizeTooltip
    global SelectionBorderWidth

    if !IsSelecting
        return

    ; 检查左键是否按下
    if !(wParam & 1)  ; MK_LBUTTON
        return

    ; 如果还没开始选择（StartX为0），不显示
    if (StartX = 0 && StartY = 0)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&EndX, &EndY)

    ; 计算选择框位置和大小
    x := Min(StartX, EndX)
    y := Min(StartY, EndY)
    w := Abs(EndX - StartX)
    h := Abs(EndY - StartY)
    bw := SelectionBorderWidth  ; 边框宽度

    if (w > 3 && h > 3) {
        ; 显示选择区域填充（让选中区域变亮/透明）
        SelectionFill.Show("x" x " y" y " w" w " h" h " NA")
        WinSetTransparent(1, SelectionFill.Hwnd)  ; 几乎完全透明，只是为了层级

        ; 显示4条边框线 - 形成矩形选择框
        ; 上边框 - 在选择区域顶部
        BorderTop.Show("x" x " y" (y - bw) " w" w " h" bw " NA")
        ; 下边框 - 在选择区域底部
        BorderBottom.Show("x" x " y" (y + h) " w" w " h" bw " NA")
        ; 左边框 - 在选择区域左侧（包含角落）
        BorderLeft.Show("x" (x - bw) " y" (y - bw) " w" bw " h" (h + bw * 2) " NA")
        ; 右边框 - 在选择区域右侧（包含角落）
        BorderRight.Show("x" (x + w) " y" (y - bw) " w" bw " h" (h + bw * 2) " NA")

        ; 更新尺寸提示
        try {
            SizeTooltip["SizeText"].Text := w " x " h
            ; 显示在选择框左上角上方
            tipY := y - 30
            if (tipY < 0)
                tipY := y + h + 5  ; 如果上方空间不足，显示在下方
            SizeTooltip.Show("x" x " y" tipY " NA")
        }
    }
}

; -------------------------------------------------
; OnLButtonUp - 鼠标左键释放
; -------------------------------------------------
OnLButtonUp(wParam, lParam, msg, hwnd) {
    global IsSelecting, StartX, StartY, EndX, EndY

    if !IsSelecting
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&EndX, &EndY)

    ; 计算选择区域
    x := Min(StartX, EndX)
    y := Min(StartY, EndY)
    w := Abs(EndX - StartX)
    h := Abs(EndY - StartY)

    ; 清理选择界面
    CleanupSelection()

    ; 如果选择区域太小，忽略
    if (w < 10 || h < 10) {
        ShowNotification("📸 提示", "选择区域太小")
        return
    }

    ; 执行截图
    CaptureAndFloat(x, y, w, h)
}

; -------------------------------------------------
; CancelSelection - 取消选择
; -------------------------------------------------
CancelSelection() {
    CleanupSelection()
    ShowNotification("📸 已取消", "截图已取消")
}

; -------------------------------------------------
; CleanupSelection - 清理选择界面
; -------------------------------------------------
CleanupSelection() {
    global IsSelecting, OverlayGui
    global BorderTop, BorderBottom, BorderLeft, BorderRight, SelectionFill, SizeTooltip

    IsSelecting := false

    ; 移除消息监听
    OnMessage(0x201, OnLButtonDown, 0)
    OnMessage(0x200, OnMouseMove, 0)
    OnMessage(0x202, OnLButtonUp, 0)

    ; 恢复鼠标指针
    RestoreSystemCursor()

    ; 销毁所有 GUI
    if OverlayGui {
        OverlayGui.Destroy()
        OverlayGui := ""
    }
    if SelectionFill {
        SelectionFill.Destroy()
        SelectionFill := ""
    }
    if BorderTop {
        BorderTop.Destroy()
        BorderTop := ""
    }
    if BorderBottom {
        BorderBottom.Destroy()
        BorderBottom := ""
    }
    if BorderLeft {
        BorderLeft.Destroy()
        BorderLeft := ""
    }
    if BorderRight {
        BorderRight.Destroy()
        BorderRight := ""
    }
    if SizeTooltip {
        SizeTooltip.Destroy()
        SizeTooltip := ""
    }
}

; =================================================
; 截图与悬浮显示函数
; =================================================

; -------------------------------------------------
; CaptureAndFloat - 截图并悬浮显示
; -------------------------------------------------
CaptureAndFloat(x, y, w, h) {
    global FloatingWindows, pToken, DefaultOpacity

    ; 使用 GDI+ 截图
    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
    if !pBitmap {
        ShowNotification("❌ 错误", "截图失败")
        return
    }

    ; 生成临时文件路径
    tempFile := A_Temp "\ahk_screenshot_" A_TickCount ".png"

    ; 保存为 PNG
    Gdip_SaveBitmapToFile(pBitmap, tempFile)
    Gdip_DisposeImage(pBitmap)

    ; 创建悬浮窗口
    floatGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    floatGui.BackColor := "FFFFFF"
    floatGui.MarginX := 0
    floatGui.MarginY := 0

    ; 添加图片
    pic := floatGui.AddPicture("x0 y0 w" w " h" h, tempFile)

    ; 计算显示位置（在截图位置稍微偏移）
    showX := x + 20
    showY := y + 20

    ; 确保不超出屏幕
    screenWidth := SysGet(78)
    screenHeight := SysGet(79)
    if (showX + w > screenWidth)
        showX := screenWidth - w - 20
    if (showY + h > screenHeight)
        showY := screenHeight - h - 20

    floatGui.Show("x" showX " y" showY " w" w " h" h " NA")
    WinSetTransparent(DefaultOpacity, floatGui.Hwnd)

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
        opacity: DefaultOpacity
    }

    ; 绑定事件
    floatGui.OnEvent("Close", OnFloatClose)

    ; 为图片控件绑定鼠标事件
    BindFloatEvents(floatGui.Hwnd)

    ShowNotification("📸 截图完成", "悬浮窗已创建 (" w "x" h ")")
}

; -------------------------------------------------
; BindFloatEvents - 绑定悬浮窗事件
; -------------------------------------------------
BindFloatEvents(hwnd) {
    ; 使用热键监听当窗口激活时的操作
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

    ; 拖动功能 - 监听窗口的鼠标按下事件
    OnMessage(0x84, OnNcHitTest)  ; WM_NCHITTEST - 允许拖动
}

; -------------------------------------------------
; OnNcHitTest - 处理窗口拖动
; -------------------------------------------------
OnNcHitTest(wParam, lParam, msg, hwnd) {
    global FloatingWindows

    if FloatingWindows.Has(hwnd) {
        ; 返回 HTCAPTION (2) 让窗口可拖动
        return 2
    }
}

; -------------------------------------------------
; OnFloatClose - 悬浮窗关闭事件
; -------------------------------------------------
OnFloatClose(guiObj) {
    CloseFloatingWindow(guiObj.Hwnd)
}

; -------------------------------------------------
; CloseFloatingWindow - 关闭单个悬浮窗
; -------------------------------------------------
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
    info.gui.Destroy()
    FloatingWindows.Delete(hwnd)
}

; -------------------------------------------------
; CloseAllFloatingWindows - 关闭所有悬浮窗
; -------------------------------------------------
CloseAllFloatingWindows() {
    global FloatingWindows

    if FloatingWindows.Count = 0 {
        return
    }

    ; 收集所有 hwnd
    hwnds := []
    for hwnd in FloatingWindows
        hwnds.Push(hwnd)

    ; 逐个关闭
    for hwnd in hwnds
        CloseFloatingWindow(hwnd)

    ShowNotification("📸 已关闭", "所有悬浮窗已关闭")
}

; -------------------------------------------------
; ZoomFloat - 缩放悬浮窗
; -------------------------------------------------
ZoomFloat(hwnd, direction) {
    global FloatingWindows, ZoomStep, MinFloatSize, MaxFloatSize

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    ; 计算新缩放比例
    newScale := info.scale + (direction > 0 ? ZoomStep : -ZoomStep)

    ; 限制缩放范围
    newW := info.originalW * newScale
    newH := info.originalH * newScale

    if (newW < MinFloatSize || newH < MinFloatSize || newW > MaxFloatSize || newH > MaxFloatSize)
        return

    info.scale := newScale
    info.currentW := Round(newW)
    info.currentH := Round(newH)

    ; 重新设置图片以正确缩放（关键修复！）
    ; 使用 *wH 格式指定宽高，让图片重新渲染
    info.pic.Value := "*w" info.currentW " *h" info.currentH " " info.tempFile

    ; 更新窗口大小
    info.gui.Move(, , info.currentW, info.currentH)

    FloatingWindows[hwnd] := info
}

; -------------------------------------------------
; AdjustOpacity - 调节透明度
; -------------------------------------------------
AdjustOpacity(hwnd, direction) {
    global FloatingWindows, OpacityStep

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    ; 计算新透明度
    newOpacity := info.opacity + (direction > 0 ? OpacityStep : -OpacityStep)
    newOpacity := Max(30, Min(255, newOpacity))  ; 限制范围 30-255

    info.opacity := newOpacity
    WinSetTransparent(newOpacity, hwnd)

    FloatingWindows[hwnd] := info
}

; -------------------------------------------------
; CopyFloatToClipboard - 复制截图到剪贴板
; -------------------------------------------------
CopyFloatToClipboard(hwnd) {
    global FloatingWindows, pToken

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    ; 从文件加载位图
    pBitmap := Gdip_CreateBitmapFromFile(info.tempFile)
    if pBitmap {
        Gdip_SetBitmapToClipboard(pBitmap)
        Gdip_DisposeImage(pBitmap)
        ShowNotification("📋 已复制", "截图已复制到剪贴板")
    }
}

; -------------------------------------------------
; SaveFloatToFile - 保存截图到文件
; -------------------------------------------------
SaveFloatToFile(hwnd) {
    global FloatingWindows, ScreenshotFolder

    if !FloatingWindows.Has(hwnd)
        return

    info := FloatingWindows[hwnd]

    ; 生成文件名
    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    savePath := ScreenshotFolder "\Screenshot_" timestamp ".png"

    ; 复制文件
    try {
        FileCopy(info.tempFile, savePath)
        ShowNotification("💾 已保存", savePath)
        Run("explorer.exe /select,`"" savePath "`"")
    } catch as e {
        ShowNotification("❌ 保存失败", e.Message)
    }
}

; =================================================
; GDI+ 函数
; =================================================

InitGDIPlus() {
    global pToken

    ; 先加载 GDI+ 库
    if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
        DllCall("LoadLibrary", "Str", "gdiplus")

    si := Buffer(24, 0)  ; GdiplusStartupInput
    NumPut("UInt", 1, si, 0)

    result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
    if (result != 0) {
        pToken := 0
        ShowNotification("❌ 错误", "GDI+ 初始化失败")
    }
}

ShutdownGDIPlus() {
    global pToken
    ; 只有当 pToken 有效时才关闭
    if (pToken != 0) {
        try DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
        pToken := 0
    }
}

Gdip_BitmapFromScreen(coords) {
    ; 解析坐标 "x|y|w|h"
    parts := StrSplit(coords, "|")
    x := parts[1], y := parts[2], w := parts[3], h := parts[4]

    ; 创建兼容 DC 和位图
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
    hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

    ; 复制屏幕内容
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h
        , "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)  ; SRCCOPY

    ; 创建 GDI+ Bitmap
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)

    ; 清理
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    return pBitmap
}

Gdip_SaveBitmapToFile(pBitmap, filePath, quality := 100) {
    ; 获取 PNG 编码器 CLSID
    ; PNG: {557CF406-1A04-11D3-9A73-0000F81EF32E}
    CLSID := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", CLSID)

    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filePath, "Ptr", CLSID, "Ptr", 0)
}

Gdip_CreateBitmapFromFile(filePath) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", filePath, "Ptr*", &pBitmap)
    return pBitmap
}

Gdip_SetBitmapToClipboard(pBitmap) {
    ; 获取图片尺寸
    width := 0, height := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &width)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &height)

    ; 创建兼容 DC
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
    hOldBmp := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

    ; 创建 GDI+ Graphics 并绘制
    pGraphics := 0
    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
    DllCall("gdiplus\GdipDrawImageI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", 0, "Int", 0)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)

    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBmp)

    ; 复制到剪贴板
    if DllCall("OpenClipboard", "Ptr", 0) {
        DllCall("EmptyClipboard")
        DllCall("SetClipboardData", "UInt", 2, "Ptr", hBitmap)  ; CF_BITMAP = 2
        DllCall("CloseClipboard")
    } else {
        DllCall("DeleteObject", "Ptr", hBitmap)
    }

    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
}

Gdip_DisposeImage(pBitmap) {
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}

; =================================================
; 鼠标指针函数
; =================================================

SetSystemCursor(cursorName) {
    ; 十字准星光标
    cursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr")  ; IDC_CROSS

    ; 设置所有系统光标
    cursorIDs := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651]
    for id in cursorIDs {
        cursorCopy := DllCall("CopyImage", "Ptr", cursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
        DllCall("SetSystemCursor", "Ptr", cursorCopy, "UInt", id)
    }
}

RestoreSystemCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)  ; SPI_SETCURSORS
}

; =================================================
; 辅助函数
; =================================================

ShowNotification(title, text) {
    ToolTip(title "`n" text)
    SetTimer(() => ToolTip(), -2000)
}

; =================================================
; 清理
; =================================================

OnExit(ExitFunc)

ExitFunc(reason, code) {
    global FloatingWindows, pToken

    ; 关闭所有悬浮窗
    try {
        for hwnd, info in FloatingWindows {
            try FileDelete(info.tempFile)
            try info.gui.Destroy()
        }
    }

    ; 恢复光标
    try RestoreSystemCursor()

    ; 关闭 GDI+ (只有 pToken 有效时)
    if (pToken != 0) {
        try ShutdownGDIPlus()
    }
}

; =================================================
; 消息监听 - 支持脚本管理器集成
; 消息编号: 0x2001=开始截图, 0x2002=关闭所有悬浮窗
; 注意: 使用自定义消息号避免与系统消息冲突
; =================================================
OnMessage(0x2001, OnMsgStartScreenshot)
OnMessage(0x2002, OnMsgCloseAll)

OnMsgStartScreenshot(wParam, lParam, msg, hwnd) {
    ; 使用 Critical 确保消息处理不被中断
    Critical
    ; 延迟执行，避免在消息处理中启动GUI
    SetTimer(DoStartScreenshot, -100)
    return 1
}

DoStartScreenshot() {
    StartScreenshot()
}

OnMsgCloseAll(wParam, lParam, msg, hwnd) {
    Critical
    SetTimer(DoCloseAll, -100)
    return 1
}

DoCloseAll() {
    CloseAllFloatingWindows()
}

; =================================================
; 初始化完成
; =================================================
ShowNotification("📸 截图悬浮工具", "已启动！按 Win+Shift+S 截图")