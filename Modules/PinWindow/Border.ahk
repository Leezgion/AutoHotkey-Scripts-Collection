; =================================================
; 🔲 PinWindow/Border.ahk - 边框绘制模块
; =================================================

class WindowBorder {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(targetHwnd, color, thickness := 4) {
        ; 配置
        this.Hwnd := targetHwnd
        this.Color := color
        this.Thickness := thickness
        this.Title := ""

        ; GUI
        this._top := ""
        this._bottom := ""
        this._left := ""
        this._right := ""
        this._lastCoords := ""

        ; State
        this._destroyed := false
        this._flashTimer := ""

        try {
            this.Title := WinGetTitle(targetHwnd)
            if (this.Title = "")
                this.Title := "无标题窗口"
        } catch {
            this.Title := "未知窗口"
        }

        this._CreateBorders()
    }

    ; -------------------------------------------------
    ; 私有方法：判断 GUI 是否有窗口
    ; -------------------------------------------------
    _HasGuiWindow(guiObj) {
        try {
            return IsObject(guiObj) && guiObj.Hwnd
        } catch {
            return false
        }
    }

    ; -------------------------------------------------
    ; 私有方法：确保边框 GUI 可用
    ; -------------------------------------------------
    _EnsureBorders() {
        if this._destroyed
            return false

        if (this._HasGuiWindow(this._top)
            && this._HasGuiWindow(this._bottom)
            && this._HasGuiWindow(this._left)
            && this._HasGuiWindow(this._right)) {
            return true
        }

        ; 可能已被 Destroy()，或创建失败；重建一套
        try {
            this._SafeDestroyBorders()
        }
        try {
            this._CreateBorders()
            return true
        } catch {
            return false
        }
    }

    ; -------------------------------------------------
    ; 私有方法：安全销毁边框 GUI（不改变 _destroyed）
    ; -------------------------------------------------
    _SafeDestroyBorders() {
        try this._top.Destroy()
        try this._bottom.Destroy()
        try this._left.Destroy()
        try this._right.Destroy()
    }

    ; -------------------------------------------------
    ; 私有方法：创建边框 GUI
    ; -------------------------------------------------
    _CreateBorders() {
        guiOpts := "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner" this.Hwnd

        this._top := Gui(guiOpts)
        this._bottom := Gui(guiOpts)
        this._left := Gui(guiOpts)
        this._right := Gui(guiOpts)

        this._top.BackColor := this.Color
        this._bottom.BackColor := this.Color
        this._left.BackColor := this.Color
        this._right.BackColor := this.Color
    }

    ; -------------------------------------------------
    ; Update - 更新边框位置
    ; -------------------------------------------------
    Update(force := false) {
        if this._destroyed
            return false

        if !WinExist(this.Hwnd)
            return false

        if !this._EnsureBorders()
            return false

        try {
            WinGetPos(&x, &y, &w, &h, this.Hwnd)
            minMax := WinGetMinMax(this.Hwnd)
        } catch {
            return false
        }

        ; 最小化时隐藏
        if (minMax = -1) {
            if (this._lastCoords != "Min") {
                this.Hide()
                this._lastCoords := "Min"
            }
            return true
        }

        ; 位置未变化则跳过
        currentCoords := x "," y "," w "," h
        if (!force && this._lastCoords = currentCoords)
            return true

        this._lastCoords := currentCoords
        bt := this.Thickness

        ; 显示四条边框
        try this._top.Show("NA x" x " y" y " w" w " h" bt)
        try this._bottom.Show("NA x" x " y" (y + h - bt) " w" w " h" bt)
        try this._left.Show("NA x" x " y" y " w" bt " h" h)
        try this._right.Show("NA x" (x + w - bt) " y" y " w" bt " h" h)

        return true
    }

    ; -------------------------------------------------
    ; Hide - 隐藏边框
    ; -------------------------------------------------
    Hide() {
        if this._destroyed
            return

        try this._top.Hide()
        try this._bottom.Hide()
        try this._left.Hide()
        try this._right.Hide()
    }

    ; -------------------------------------------------
    ; Show - 显示边框
    ; -------------------------------------------------
    Show() {
        if this._destroyed
            return false
        return this.Update(true)
    }

    ; -------------------------------------------------
    ; SetColor - 设置颜色
    ; -------------------------------------------------
    SetColor(color) {
        if this._destroyed
            return

        this.Color := color
        if this._EnsureBorders() {
            try this._top.BackColor := color
            try this._bottom.BackColor := color
            try this._left.BackColor := color
            try this._right.BackColor := color
        }
    }

    ; -------------------------------------------------
    ; Flash - 闪烁动画
    ; -------------------------------------------------
    Flash(count := 3, interval := 100) {
        if this._destroyed
            return

        ; 取消之前尚未完成的闪烁计时器
        if IsObject(this._flashTimer)
            SetTimer(this._flashTimer, 0)

        flashNum := 0

        this._flashTimer := (*) => (
            this._destroyed ? 0 : (
                flashNum++,
                (Mod(flashNum, 2) = 1) ? this.Hide() : this.Show(),
                (flashNum < count * 2) ? SetTimer(this._flashTimer, -interval) : 0
            )
        )

        SetTimer(this._flashTimer, -interval)
    }

    ; -------------------------------------------------
    ; Destroy - 销毁边框
    ; -------------------------------------------------
    Destroy() {
        ; 先标记销毁，避免定时器再次触发 Show/Hide
        this._destroyed := true

        ; 停止尚未完成的闪烁
        if IsObject(this._flashTimer)
            SetTimer(this._flashTimer, 0)

        try this._SafeDestroyBorders()
    }
}
