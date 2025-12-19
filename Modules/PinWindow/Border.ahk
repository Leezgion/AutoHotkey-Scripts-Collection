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
        if !WinExist(this.Hwnd)
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
        this._top.Show("NA x" x " y" y " w" w " h" bt)
        this._bottom.Show("NA x" x " y" (y + h - bt) " w" w " h" bt)
        this._left.Show("NA x" x " y" y " w" bt " h" h)
        this._right.Show("NA x" (x + w - bt) " y" y " w" bt " h" h)

        return true
    }

    ; -------------------------------------------------
    ; Hide - 隐藏边框
    ; -------------------------------------------------
    Hide() {
        this._top.Hide()
        this._bottom.Hide()
        this._left.Hide()
        this._right.Hide()
    }

    ; -------------------------------------------------
    ; Show - 显示边框
    ; -------------------------------------------------
    Show() {
        this.Update(true)
    }

    ; -------------------------------------------------
    ; SetColor - 设置颜色
    ; -------------------------------------------------
    SetColor(color) {
        this.Color := color
        this._top.BackColor := color
        this._bottom.BackColor := color
        this._left.BackColor := color
        this._right.BackColor := color
    }

    ; -------------------------------------------------
    ; Flash - 闪烁动画
    ; -------------------------------------------------
    Flash(count := 3, interval := 100) {
        flashNum := 0

        FlashStep() {
            flashNum++

            if (Mod(flashNum, 2) = 1)
                this.Hide()
            else
                this.Show()

            if (flashNum < count * 2)
                SetTimer(FlashStep, -interval)
        }

        SetTimer(FlashStep, -interval)
    }

    ; -------------------------------------------------
    ; Destroy - 销毁边框
    ; -------------------------------------------------
    Destroy() {
        try {
            this._top.Destroy()
            this._bottom.Destroy()
            this._left.Destroy()
            this._right.Destroy()
        }
    }
}
