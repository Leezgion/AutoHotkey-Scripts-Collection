; =================================================
; 🖼️ Screenshot/FloatWindow.ahk - 悬浮窗管理
; =================================================

class FloatWindow {
    ; 类常量
    static MinSize := 50
    static MaxSize := 2000
    static DefaultOpacity := 255
    static OpacityStep := 15
    static ZoomStep := 0.1

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(tempFile, w, h, showX, showY) {
        ; 实例数据
        this.Hwnd := 0
        this.TempFile := tempFile
        this.OriginalW := w
        this.OriginalH := h
        this.CurrentW := w
        this.CurrentH := h
        this.Scale := 1.0
        this.Opacity := FloatWindow.DefaultOpacity

        ; GUI
        this._gui := ""
        this._pic := ""

        ; 回调
        this.OnClose := ""
        this.OnCopy := ""
        this.OnSave := ""

        ; 创建窗口
        this._gui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        this._gui.BackColor := "FFFFFF"
        this._gui.MarginX := 0
        this._gui.MarginY := 0

        ; 添加图片
        this._pic := this._gui.AddPicture("x0 y0 w" w " h" h, tempFile)

        ; 显示
        this._gui.Show("x" showX " y" showY " w" w " h" h " NA")
        WinSetTransparent(this.Opacity, this._gui.Hwnd)

        this.Hwnd := this._gui.Hwnd

        ; 绑定事件
        this._gui.OnEvent("Close", (*) => this.Close())
        this._BindHotkeys()
        this._EnableDrag()
    }

    ; -------------------------------------------------
    ; Zoom - 缩放
    ; -------------------------------------------------
    Zoom(direction) {
        newScale := this.Scale + (direction > 0 ? FloatWindow.ZoomStep : -FloatWindow.ZoomStep)

        newW := this.OriginalW * newScale
        newH := this.OriginalH * newScale

        if (newW < FloatWindow.MinSize || newH < FloatWindow.MinSize)
            return
        if (newW > FloatWindow.MaxSize || newH > FloatWindow.MaxSize)
            return

        this.Scale := newScale
        this.CurrentW := Round(newW)
        this.CurrentH := Round(newH)

        this._pic.Value := "*w" this.CurrentW " *h" this.CurrentH " " this.TempFile
        this._gui.Move(, , this.CurrentW, this.CurrentH)
    }

    ; -------------------------------------------------
    ; AdjustOpacity - 调节透明度
    ; -------------------------------------------------
    AdjustOpacity(direction) {
        newOpacity := this.Opacity + (direction > 0 ? FloatWindow.OpacityStep : -FloatWindow.OpacityStep)
        newOpacity := Max(30, Min(255, newOpacity))

        this.Opacity := newOpacity
        WinSetTransparent(newOpacity, this.Hwnd)
    }

    ; -------------------------------------------------
    ; CopyToClipboard - 复制到剪贴板
    ; -------------------------------------------------
    CopyToClipboard() {
        if this.OnCopy {
            callback := this.OnCopy
            callback(this)
        }
    }

    ; -------------------------------------------------
    ; SaveToFile - 保存到文件
    ; -------------------------------------------------
    SaveToFile() {
        if this.OnSave {
            callback := this.OnSave
            callback(this)
        }
    }

    ; -------------------------------------------------
    ; Close - 关闭窗口
    ; -------------------------------------------------
    Close() {
        this._UnbindHotkeys()

        try FileDelete(this.TempFile)

        if this._gui {
            this._gui.Destroy()
            this._gui := ""
        }

        if this.OnClose {
            callback := this.OnClose
            callback(this)
        }
    }

    ; -------------------------------------------------
    ; EnsureOnTop - 确保置顶
    ; -------------------------------------------------
    EnsureOnTop() {
        if WinExist(this.Hwnd) {
            try {
                exStyle := WinGetExStyle(this.Hwnd)
                if !(exStyle & 0x8) {
                    WinSetAlwaysOnTop(true, this.Hwnd)
                }
            }
        }
    }

    ; -------------------------------------------------
    ; 私有方法：绑定热键
    ; -------------------------------------------------
    _BindHotkeys() {
        HotIfWinActive("ahk_id " this.Hwnd)
        Hotkey("RButton", (*) => this.Close(), "On")
        Hotkey("^c", (*) => this.CopyToClipboard(), "On")
        Hotkey("^s", (*) => this.SaveToFile(), "On")
        Hotkey("WheelUp", (*) => this.Zoom(1), "On")
        Hotkey("WheelDown", (*) => this.Zoom(-1), "On")
        Hotkey("^WheelUp", (*) => this.AdjustOpacity(1), "On")
        Hotkey("^WheelDown", (*) => this.AdjustOpacity(-1), "On")
        Hotkey("Escape", (*) => this.Close(), "On")
        HotIf()
    }

    ; -------------------------------------------------
    ; 私有方法：解绑热键
    ; -------------------------------------------------
    _UnbindHotkeys() {
        try {
            HotIfWinActive("ahk_id " this.Hwnd)
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
    }

    ; -------------------------------------------------
    ; 私有方法：启用拖动
    ; -------------------------------------------------
    _EnableDrag() {
        ; 通过消息实现窗口拖动
        ; 在外部通过 FloatWindowManager 统一处理
    }
}

; =================================================
; 🗂️ FloatWindowManager - 悬浮窗管理器
; =================================================

class FloatWindowManager {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(maxWindows := 20) {
        ; 配置
        this.MaxWindows := maxWindows

        ; 数据
        this._windows := Map()
        this._onTopTimer := 0

        ; 回调
        this.OnNotify := ""

        ; 注册 WM_NCHITTEST 消息处理
        OnMessage(0x84, ObjBindMethod(this, "_OnNcHitTest"))

        ; 启动置顶检查定时器
        this._onTopTimer := ObjBindMethod(this, "_EnsureAllOnTop")
        SetTimer(this._onTopTimer, 1000)
    }

    ; -------------------------------------------------
    ; Add - 添加悬浮窗
    ; -------------------------------------------------
    Add(floatWin) {
        ; 检查数量限制
        if (this._windows.Count >= this.MaxWindows) {
            ; 关闭最早的窗口
            for hwnd, win in this._windows {
                win.Close()
                break
            }
        }

        floatWin.OnClose := ObjBindMethod(this, "_OnWindowClose")
        this._windows[floatWin.Hwnd] := floatWin
    }

    ; -------------------------------------------------
    ; Get - 获取悬浮窗
    ; -------------------------------------------------
    Get(hwnd) {
        return this._windows.Has(hwnd) ? this._windows[hwnd] : ""
    }

    ; -------------------------------------------------
    ; GetCount - 获取数量
    ; -------------------------------------------------
    GetCount() {
        return this._windows.Count
    }

    ; -------------------------------------------------
    ; CloseAll - 关闭所有
    ; -------------------------------------------------
    CloseAll() {
        if this._windows.Count = 0
            return

        hwnds := []
        for hwnd in this._windows
            hwnds.Push(hwnd)

        for hwnd in hwnds {
            if this._windows.Has(hwnd)
                this._windows[hwnd].Close()
        }
    }

    ; -------------------------------------------------
    ; Destroy - 销毁管理器
    ; -------------------------------------------------
    Destroy() {
        SetTimer(this._onTopTimer, 0)
        OnMessage(0x84, ObjBindMethod(this, "_OnNcHitTest"), 0)
        this.CloseAll()
    }

    ; -------------------------------------------------
    ; 私有方法：窗口关闭回调
    ; -------------------------------------------------
    _OnWindowClose(floatWin) {
        if this._windows.Has(floatWin.Hwnd)
            this._windows.Delete(floatWin.Hwnd)
    }

    ; -------------------------------------------------
    ; 私有方法：WM_NCHITTEST 处理（只对悬浮窗）
    ; -------------------------------------------------
    _OnNcHitTest(wParam, lParam, msg, hwnd) {
        if this._windows.Has(hwnd)
            return 2  ; HTCAPTION - 允许拖动
    }

    ; -------------------------------------------------
    ; 私有方法：确保所有窗口置顶
    ; -------------------------------------------------
    _EnsureAllOnTop() {
        for hwnd, win in this._windows {
            win.EnsureOnTop()
        }
    }
}
