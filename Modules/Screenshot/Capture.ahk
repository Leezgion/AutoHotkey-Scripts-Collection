; =================================================
; 📷 Screenshot/Capture.ahk - 截图主逻辑
; =================================================

#Include ..\..\Lib\GDIPlus.ahk
#Include ..\..\Lib\Constants.ahk
#Include Selection.ahk
#Include FloatWindow.ahk

class ScreenCapture {
    ; 状态常量
    static STATE_IDLE := "IDLE"
    static STATE_SELECTING := "SELECTING"
    static STATE_CAPTURING := "CAPTURING"

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(config := "") {
        ; 配置
        this.Config := {
            ScreenshotFolder: A_ScriptDir "\Screenshots",
            SelectionColor: "00AAFF",
            BorderWidth: 3,
            MaxFloats: 20,
            DefaultOpacity: 255
        }

        ; 状态
        this._state := "IDLE"

        ; 组件
        this._selection := ""
        this._windowManager := ""

        ; GDI+ Token
        this._gdipToken := 0

        ; 回调
        this.OnCapture := ""
        this.OnCancel := ""
        this.OnNotify := ""

        ; 应用配置
        if config {
            for key, val in config.OwnProps() {
                if this.Config.HasOwnProp(key)
                    this.Config.%key% := val
            }
        }

        ; 初始化 GDI+
        this._InitGDIPlus()

        ; 创建窗口管理器
        this._windowManager := FloatWindowManager(this.Config.MaxFloats)
        this._windowManager.OnNotify := ObjBindMethod(this, "_Notify")

        ; 确保截图目录存在
        if !DirExist(this.Config.ScreenshotFolder)
            DirCreate(this.Config.ScreenshotFolder)
    }

    ; -------------------------------------------------
    ; Start - 开始截图
    ; -------------------------------------------------
    Start() {
        if (this._state != ScreenCapture.STATE_IDLE)
            return false

        this._state := ScreenCapture.STATE_SELECTING

        ; 创建选区
        this._selection := Selection(this.Config.SelectionColor, this.Config.BorderWidth)
        this._selection.Start()

        ; 设置鼠标
        Cursor.SetCross()

        ; 监听鼠标事件
        OnMessage(0x201, ObjBindMethod(this, "_OnLButtonDown"))
        OnMessage(0x200, ObjBindMethod(this, "_OnMouseMove"))
        OnMessage(0x202, ObjBindMethod(this, "_OnLButtonUp"))

        ; 绑定 ESC
        Hotkey("*Escape", (*) => this.Cancel(), "On")

        return true
    }

    ; -------------------------------------------------
    ; Cancel - 取消截图
    ; -------------------------------------------------
    Cancel() {
        this._Cleanup()
        this._state := ScreenCapture.STATE_IDLE

        if this.OnCancel
            this.OnCancel()

        this._Notify("截图已取消")
    }

    ; -------------------------------------------------
    ; CloseAllFloats - 关闭所有悬浮窗
    ; -------------------------------------------------
    CloseAllFloats() {
        this._windowManager.CloseAll()
        this._Notify("所有悬浮窗已关闭")
    }

    ; -------------------------------------------------
    ; GetFloatCount - 获取悬浮窗数量
    ; -------------------------------------------------
    GetFloatCount() {
        return this._windowManager.GetCount()
    }

    ; -------------------------------------------------
    ; GetState - 获取当前状态
    ; -------------------------------------------------
    GetState() {
        return this._state
    }

    ; -------------------------------------------------
    ; IsActive - 是否正在截图
    ; -------------------------------------------------
    IsActive() {
        return this._state != ScreenCapture.STATE_IDLE
    }

    ; -------------------------------------------------
    ; Destroy - 销毁
    ; -------------------------------------------------
    Destroy() {
        this._Cleanup()
        this._windowManager.Destroy()
        this._ShutdownGDIPlus()
    }

    ; -------------------------------------------------
    ; 私有方法：鼠标按下
    ; -------------------------------------------------
    _OnLButtonDown(wParam, lParam, msg, hwnd) {
        if (this._state != ScreenCapture.STATE_SELECTING)
            return

        CoordMode("Mouse", "Screen")
        MouseGetPos(&x, &y)
        this._selection.OnMouseDown(x, y)
    }

    ; -------------------------------------------------
    ; 私有方法：鼠标移动
    ; -------------------------------------------------
    _OnMouseMove(wParam, lParam, msg, hwnd) {
        if (this._state != ScreenCapture.STATE_SELECTING)
            return

        if !(wParam & 1)  ; MK_LBUTTON
            return

        CoordMode("Mouse", "Screen")
        MouseGetPos(&x, &y)
        this._selection.OnMouseMove(x, y)
    }

    ; -------------------------------------------------
    ; 私有方法：鼠标释放
    ; -------------------------------------------------
    _OnLButtonUp(wParam, lParam, msg, hwnd) {
        if (this._state != ScreenCapture.STATE_SELECTING)
            return

        CoordMode("Mouse", "Screen")
        MouseGetPos(&x, &y)
        this._selection.OnMouseUp(x, y)

        ; 检查选区
        if !this._selection.IsValidSelection() {
            this._Notify("选择区域太小")
            this._Cleanup()
            this._state := ScreenCapture.STATE_IDLE
            return
        }

        ; 执行截图
        this._state := ScreenCapture.STATE_CAPTURING
        rect := this._selection.GetRect()
        this._Cleanup()

        this._CaptureAndFloat(rect.x, rect.y, rect.w, rect.h)
        this._state := ScreenCapture.STATE_IDLE
    }

    ; -------------------------------------------------
    ; 私有方法：截图并悬浮
    ; -------------------------------------------------
    _CaptureAndFloat(x, y, w, h) {
        ; 截图
        pBitmap := this._CaptureScreen(x, y, w, h)
        if !pBitmap {
            this._Notify("截图失败")
            return
        }

        ; 保存临时文件
        tempFile := A_Temp "\ahk_screenshot_" A_TickCount ".png"
        this._SaveBitmap(pBitmap, tempFile)
        this._DisposeBitmap(pBitmap)

        ; 计算显示位置
        screenW := SysGet(78)
        screenH := SysGet(79)
        showX := x + 20
        showY := y + 20
        if (showX + w > screenW)
            showX := screenW - w - 20
        if (showY + h > screenH)
            showY := screenH - h - 20

        ; 创建悬浮窗
        floatWin := FloatWindow(tempFile, w, h, showX, showY)
        floatWin.OnCopy := ObjBindMethod(this, "_OnFloatCopy")
        floatWin.OnSave := ObjBindMethod(this, "_OnFloatSave")

        this._windowManager.Add(floatWin)

        if this.OnCapture {
            callback := this.OnCapture
            callback(floatWin)
        }

        this._Notify("截图完成 (" w "x" h ")")
    }

    ; -------------------------------------------------
    ; 私有方法：悬浮窗复制回调
    ; -------------------------------------------------
    _OnFloatCopy(floatWin) {
        pBitmap := this._LoadBitmap(floatWin.TempFile)
        if pBitmap {
            this._CopyBitmapToClipboard(pBitmap)
            this._DisposeBitmap(pBitmap)
            this._Notify("已复制到剪贴板")
        }
    }

    ; -------------------------------------------------
    ; 私有方法：悬浮窗保存回调
    ; -------------------------------------------------
    _OnFloatSave(floatWin) {
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        savePath := this.Config.ScreenshotFolder "\Screenshot_" timestamp ".png"

        try {
            FileCopy(floatWin.TempFile, savePath)
            this._Notify("已保存: " savePath)
            Run("explorer.exe /select,`"" savePath "`"")
        } catch as e {
            this._Notify("保存失败: " e.Message)
        }
    }

    ; -------------------------------------------------
    ; 私有方法：清理
    ; -------------------------------------------------
    _Cleanup() {
        ; 移除消息监听
        OnMessage(0x201, ObjBindMethod(this, "_OnLButtonDown"), 0)
        OnMessage(0x200, ObjBindMethod(this, "_OnMouseMove"), 0)
        OnMessage(0x202, ObjBindMethod(this, "_OnLButtonUp"), 0)

        ; 解除热键
        try Hotkey("*Escape", "Off")

        ; 恢复鼠标
        Cursor.Restore()

        ; 销毁选区
        if this._selection {
            this._selection.Destroy()
            this._selection := ""
        }
    }

    ; -------------------------------------------------
    ; 私有方法：通知
    ; -------------------------------------------------
    _Notify(text) {
        if this.OnNotify {
            callback := this.OnNotify
            callback(text)
        } else {
            ToolTip(text)
            SetTimer(() => ToolTip(), -2000)
        }
    }

    ; -------------------------------------------------
    ; GDI+ 方法
    ; -------------------------------------------------
    _InitGDIPlus() {
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")

        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
        this._gdipToken := token
    }

    _ShutdownGDIPlus() {
        if this._gdipToken {
            try DllCall("gdiplus\GdiplusShutdown", "Ptr", this._gdipToken)
            this._gdipToken := 0
        }
    }

    _CaptureScreen(x, y, w, h) {
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
        hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

        DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h
            , "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)

        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)

        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteObject", "Ptr", hBitmap)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

        return pBitmap
    }

    _SaveBitmap(pBitmap, filePath) {
        CLSID := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", CLSID)
        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filePath, "Ptr", CLSID, "Ptr", 0)
    }

    _LoadBitmap(filePath) {
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", filePath, "Ptr*", &pBitmap)
        return pBitmap
    }

    _DisposeBitmap(pBitmap) {
        if pBitmap
            DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    }

    _CopyBitmapToClipboard(pBitmap) {
        width := 0, height := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &width)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &height)

        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
        hOldBmp := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

        pGraphics := 0
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
        DllCall("gdiplus\GdipDrawImageI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", 0, "Int", 0)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)

        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBmp)

        if DllCall("OpenClipboard", "Ptr", 0) {
            DllCall("EmptyClipboard")
            DllCall("SetClipboardData", "UInt", 2, "Ptr", hBitmap)
            DllCall("CloseClipboard")
        } else {
            DllCall("DeleteObject", "Ptr", hBitmap)
        }

        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    }
}
