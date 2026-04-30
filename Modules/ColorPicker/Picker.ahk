; =================================================
; 🎨 ColorPicker/Picker.ahk - 取色器主逻辑
; =================================================

#Include ..\..\Lib\GDIPlus.ahk
#Include ..\..\Lib\Constants.ahk
#Include ..\..\Lib\ConfigManager.ahk
#Include Converter.ahk
#Include Magnifier.ahk
#Include History.ahk

class ColorPicker {
    ; 状态常量
    static STATE_IDLE := "IDLE"
    static STATE_PICKING := "PICKING"
    static STATE_COPYING := "COPYING"

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(config := "") {
        ; 配置
        this.Config := {
            MagnifierSize: 150,
            MagnifierZoom: 8,
            PreviewSize: 50,
            MaxHistory: 10,
            DefaultFormat: "HEX",
            ShowGrid: true,
            ShowCrosshair: true
        }

        ; 状态
        this._state := "IDLE"
        this._currentFormat := "HEX"
        this._lastColor := ""
        this._lButtonDown := false
        this._rButtonDown := false

        ; 组件
        this._magnifier := ""
        this._history := ""
        this._infoGui := ""
        this._overlay := ""  ; 全屏透明覆盖层，阻止点击穿透

        ; 回调
        this.OnColorPicked := ""
        this.OnCancel := ""
        this.OnNotify := ""

        ; 运行时热键（用于解绑）
        this._boundHotkeys := []

        ; 应用配置
        if config {
            for key, val in config.OwnProps() {
                if this.Config.HasOwnProp(key)
                    this.Config.%key% := val
            }
        }

        ; 定时器回调（必须复用同一个引用，才能可靠停止）
        this._updateTimerFn := ObjBindMethod(this, "_Update")

        this._currentFormat := this.Config.DefaultFormat
        this._magnifier := Magnifier(this.Config.MagnifierSize, this.Config.MagnifierZoom, this.Config.ShowGrid, this.Config.ShowCrosshair)
        this._history := ColorHistory(this.Config.MaxHistory)
    }

    ; -------------------------------------------------
    ; Start - 开始取色
    ; -------------------------------------------------
    Start() {
        if (this._state != ColorPicker.STATE_IDLE)
            return false

        this._state := ColorPicker.STATE_PICKING
        this._lButtonDown := false
        this._rButtonDown := false

        ; 创建全屏透明覆盖层（阻止鼠标点击穿透到其他窗口）
        this._CreateOverlay()

        ; 创建 GUI
        this._magnifier.Create()
        this._CreateInfoGui()

        ; 设置鼠标
        Cursor.SetCross()

        ; 绑定热键
        this._boundHotkeys := []

        cancelHk := ConfigManager.GetHotkey("ColorPicker.Cancel")
        copyHk := ConfigManager.GetHotkey("ColorPicker.Copy")
        zoomInHk := ConfigManager.GetHotkey("ColorPicker.ZoomIn")
        zoomOutHk := ConfigManager.GetHotkey("ColorPicker.ZoomOut")
        switchHk := ConfigManager.GetHotkey("ColorPicker.SwitchFormat")

        bind := (hk, fn) => (
            (hk && hk != "" && hk != "None")
                ? (Hotkey("*" hk, fn, "On"), this._boundHotkeys.Push("*" hk), true)
                : false
        )

        bind(cancelHk, (*) => this.Cancel())
        bind(copyHk, (*) => this._CopyColorFromCursor())
        bind(zoomInHk, (*) => this._OnZoom(1))
        bind(zoomOutHk, (*) => this._OnZoom(-1))
        bind(switchHk, (*) => this._SwitchFormat())

        ; 开始更新
        SetTimer(this._updateTimerFn, 16)

        return true
    }

    ; -------------------------------------------------
    ; Stop - 停止取色
    ; -------------------------------------------------
    Stop() {
        ; 先设置状态，阻止定时器继续处理
        this._state := ColorPicker.STATE_IDLE

        ; 停止定时器
        SetTimer(this._updateTimerFn, 0)

        ; 解除热键
        try {
            if IsObject(this._boundHotkeys) {
                for hkStr in this._boundHotkeys
                    try Hotkey(hkStr, "Off")
            }
        }
        this._boundHotkeys := []

        ; 恢复鼠标
        Cursor.Restore()

        ; 销毁 GUI（先销毁 infoGui，防止定时器残留访问）
        this._DestroyInfoGui()
        this._magnifier.Destroy()
        this._DestroyOverlay()
    }

    ; -------------------------------------------------
    ; Cancel - 取消取色
    ; -------------------------------------------------
    Cancel() {
        this.Stop()
        if this.OnCancel
            this.OnCancel()
    }

    ; -------------------------------------------------
    ; GetHistory - 获取历史记录组件
    ; -------------------------------------------------
    GetHistory() {
        return this._history
    }

    ; -------------------------------------------------
    ; ShowHistory - 显示历史记录
    ; -------------------------------------------------
    ShowHistory() {
        this._history.OnColorClick := (color) => this._Notify("已复制: " color)
        return this._history.ShowGUI()
    }

    ; -------------------------------------------------
    ; GetState - 获取当前状态
    ; -------------------------------------------------
    GetState() {
        return this._state
    }

    ; -------------------------------------------------
    ; IsActive - 是否正在取色
    ; -------------------------------------------------
    IsActive() {
        return this._state = ColorPicker.STATE_PICKING
    }

    ; -------------------------------------------------
    ; 私有方法：创建信息面板
    ; -------------------------------------------------
    _CreateInfoGui() {
        this._infoGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        this._infoGui.BackColor := "1a1a2e"
        this._infoGui.MarginX := 10
        this._infoGui.MarginY := 8

        ps := this.Config.PreviewSize

        ; 颜色预览块
        this._infoGui.AddProgress("vColorPreview x10 y8 w" ps " h" ps " Background000000", 100)

        ; 颜色值显示
        this._infoGui.SetFont("s11 cWhite Bold", "Consolas")
        this._infoGui.AddText("vColorValue x" (ps + 20) " y10 w150 h24", "#000000")

        this._infoGui.SetFont("s9 cA0A0A0", "Segoe UI")
        this._infoGui.AddText("vColorRGB x" (ps + 20) " y36 w150 h18", "RGB(0, 0, 0)")
        this._infoGui.AddText("vColorHSL x" (ps + 20) " y54 w150 h18", "HSL(0°, 0%, 0%)")

        ; 坐标显示
        this._infoGui.SetFont("s8 c666666", "Consolas")
        this._infoGui.AddText("vCoords x10 y" (ps + 15) " w200 h16", "X: 0  Y: 0")

        ; 操作提示
        this._infoGui.SetFont("s8 c666666", "Segoe UI")
        this._infoGui.AddText("vTips x10 y" (ps + 33) " w200 h32", "左键复制 | 右键切换格式 | 滚轮缩放")
    }

    ; -------------------------------------------------
    ; 私有方法：创建全屏透明覆盖层
    ; -------------------------------------------------
    _CreateOverlay() {
        ; 获取虚拟屏幕尺寸（支持多显示器）
        x := SysGet(76)  ; SM_XVIRTUALSCREEN
        y := SysGet(77)  ; SM_YVIRTUALSCREEN
        w := SysGet(78)  ; SM_CXVIRTUALSCREEN
        h := SysGet(79)  ; SM_CYVIRTUALSCREEN

        ; 创建透明窗口覆盖整个屏幕
        ; 不使用 E0x20 (WS_EX_TRANSPARENT)，这样窗口会拦截鼠标点击
        this._overlay := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this._overlay.BackColor := "000000"

        ; 使窗口几乎完全透明（透明度1），但仍能接收点击
        WinSetTransparent(1, this._overlay)

        this._overlay.Show("x" x " y" y " w" w " h" h " NA")
    }

    ; -------------------------------------------------
    ; 私有方法：销毁覆盖层
    ; -------------------------------------------------
    _DestroyOverlay() {
        if this._overlay {
            this._overlay.Destroy()
            this._overlay := ""
        }
    }

    ; -------------------------------------------------
    ; 私有方法：销毁信息面板
    ; -------------------------------------------------
    _DestroyInfoGui() {
        if this._infoGui {
            this._infoGui.Destroy()
            this._infoGui := ""
        }
    }

    ; -------------------------------------------------
    ; 私有方法：更新循环
    ; -------------------------------------------------
    _Update() {
        if (this._state != ColorPicker.STATE_PICKING)
            return

        ; 确保 _infoGui 是有效的 Gui 对象
        if !this._infoGui || Type(this._infoGui) != "Gui"
            return

        ; 获取鼠标位置
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)

        ; 获取颜色
        color := this._GetPixelColor(mx, my)
        if (color = -1)
            return

        ; 更新放大镜
        this._magnifier.Update(mx, my)

        ; 更新颜色信息
        if (color != this._lastColor) {
            this._lastColor := color
            this._UpdateColorInfo(color)
        }

        ; 定位 GUI
        this._PositionGuis(mx, my)
    }

    ; -------------------------------------------------
    ; 私有方法：获取像素颜色
    ; -------------------------------------------------
    _GetPixelColor(x, y) {
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        if !hdc
            return -1

        bgr := DllCall("GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

        if (bgr = 0xFFFFFFFF)
            return -1

        return ColorConverter.BGRToRGB(bgr)
    }

    ; -------------------------------------------------
    ; 私有方法：更新颜色信息
    ; -------------------------------------------------
    _UpdateColorInfo(color) {
        ; 确保 _infoGui 是有效的 Gui 对象
        if !this._infoGui || Type(this._infoGui) != "Gui"
            return

        hexColor := ColorConverter.ToHex(color)
        rgbColor := ColorConverter.ToRGBString(color)
        hslColor := ColorConverter.ToHSLString(color)

        try {
            colorHex := SubStr(hexColor, 2)
            this._infoGui["ColorPreview"].Opt("c" colorHex " Background" colorHex)

            ; 根据当前格式高亮显示主颜色值
            switch this._currentFormat {
                case "HEX":
                    this._infoGui["ColorValue"].Text := hexColor
                case "RGB":
                    this._infoGui["ColorValue"].Text := rgbColor
                case "HSL":
                    this._infoGui["ColorValue"].Text := hslColor
            }

            this._infoGui["ColorRGB"].Text := rgbColor
            this._infoGui["ColorHSL"].Text := hslColor
        }
    }

    ; -------------------------------------------------
    ; 私有方法：定位 GUI
    ; -------------------------------------------------
    _PositionGuis(mx, my) {
        ; 确保状态正确且 _infoGui 是有效的 Gui 对象
        if (this._state != ColorPicker.STATE_PICKING)
            return
        if !this._infoGui || Type(this._infoGui) != "Gui"
            return

        screenW := SysGet(78)
        screenH := SysGet(79)
        screenL := SysGet(76)
        screenT := SysGet(77)

        magSize := this._magnifier.Size

        magX := mx + 20
        magY := my + 20
        infoX := magX
        infoY := magY + magSize + 5

        if (magX + magSize > screenL + screenW)
            magX := mx - magSize - 20
        if (magY + magSize > screenT + screenH)
            magY := my - magSize - 20

        if (magX + 220 > screenL + screenW)
            infoX := mx - 240
        if (infoY + 100 > screenT + screenH)
            infoY := magY - 105

        ; 使用 try 包裹，防止状态转换时的竞态条件
        try {
            this._magnifier.Show(magX, magY)
            if this._infoGui && Type(this._infoGui) = "Gui"
                this._infoGui.Show("x" infoX " y" infoY " NA")
        }

        try this._infoGui["Coords"].Text := Format("X: {}  Y: {}", mx, my)
    }

    ; -------------------------------------------------
    ; 私有方法：复制颜色
    ; -------------------------------------------------
    _CopyColor() {
        color := this._lastColor
        copyText := ColorConverter.GetFormatted(color, this._currentFormat)

        A_Clipboard := copyText
        this._history.Add(ColorConverter.ToHex(color))

        this.Stop()

        if this.OnColorPicked {
            callback := this.OnColorPicked
            callback(copyText, color)
        }

        this._Notify("已复制: " copyText)
    }

    ; -------------------------------------------------
    ; 私有方法：从当前鼠标位置复制颜色
    ; -------------------------------------------------
    _CopyColorFromCursor() {
        if (this._state != ColorPicker.STATE_PICKING)
            return

        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        color := this._GetPixelColor(mx, my)
        if (color = -1)
            return

        this._lastColor := color
        this._CopyColor()
    }

    ; -------------------------------------------------
    ; 私有方法：切换格式
    ; -------------------------------------------------
    _SwitchFormat() {
        switch this._currentFormat {
            case "HEX": this._currentFormat := "RGB"
            case "RGB": this._currentFormat := "HSL"
            case "HSL": this._currentFormat := "HEX"
        }

        ; 立即更新颜色信息显示
        if (this._lastColor != -1)
            this._UpdateColorInfo(this._lastColor)

        this._Notify("格式: " this._currentFormat)
    }

    ; -------------------------------------------------
    ; 私有方法：缩放
    ; -------------------------------------------------
    _OnZoom(direction) {
        if (this._state != ColorPicker.STATE_PICKING)
            return

        zoom := direction > 0
            ? this._magnifier.ZoomIn()
                : this._magnifier.ZoomOut()

        this._Notify("缩放: " zoom "x")
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
            SetTimer(() => ToolTip(), -1500)
        }
    }
}
