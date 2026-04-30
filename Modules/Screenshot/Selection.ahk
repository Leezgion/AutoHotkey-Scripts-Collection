; =================================================
; 📸 Screenshot/Selection.ahk - 选区绘制模块
; =================================================

class Selection {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(borderColor := "00AAFF", borderWidth := 3) {
        ; 配置
        this.BorderColor := borderColor
        this.BorderWidth := borderWidth
        this.OverlayOpacity := 120

        ; GUI
        this._overlayGui := ""
        this._borderTop := ""
        this._borderBottom := ""
        this._borderLeft := ""
        this._borderRight := ""
        this._selectionFill := ""
        this._sizeTooltip := ""

        ; 状态
        this._startX := 0
        this._startY := 0
        this._endX := 0
        this._endY := 0
        this._isSelecting := false

        ; 虚拟屏幕范围（用于多显示器边界判断）
        this._screenLeft := 0
        this._screenTop := 0
        this._screenWidth := 0
        this._screenHeight := 0
    }

    ; -------------------------------------------------
    ; Start - 开始选择
    ; -------------------------------------------------
    Start() {
        this._startX := 0
        this._startY := 0
        this._isSelecting := false

        ; 获取虚拟屏幕尺寸
        this._screenLeft := SysGet(76)
        this._screenTop := SysGet(77)
        this._screenWidth := SysGet(78)
        this._screenHeight := SysGet(79)

        ; 创建半透明遮罩层
        this._overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")
        this._overlayGui.BackColor := "000000"
        this._overlayGui.Show("x" this._screenLeft " y" this._screenTop " w" this._screenWidth " h" this._screenHeight " NA")
        WinSetTransparent(this.OverlayOpacity, this._overlayGui.Hwnd)

        ; 创建选择区域填充
        this._selectionFill := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this._selectionFill.BackColor := "000000"

        ; 创建4条边框线
        this._borderTop := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this._borderTop.BackColor := this.BorderColor

        this._borderBottom := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this._borderBottom.BackColor := this.BorderColor

        this._borderLeft := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this._borderLeft.BackColor := this.BorderColor

        this._borderRight := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this._borderRight.BackColor := this.BorderColor

        ; 创建尺寸提示框
        this._sizeTooltip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this._sizeTooltip.BackColor := "222222"
        this._sizeTooltip.SetFont("s10 cWhite", "Consolas")
        this._sizeTooltip.MarginX := 8
        this._sizeTooltip.MarginY := 4
        this._sizeTooltip.AddText("vSizeText cWhite", "0 x 0")
    }

    ; -------------------------------------------------
    ; OnMouseDown - 鼠标按下
    ; -------------------------------------------------
    OnMouseDown(x, y) {
        this._startX := x
        this._startY := y
        this._isSelecting := true
    }

    ; -------------------------------------------------
    ; OnMouseMove - 鼠标移动
    ; -------------------------------------------------
    OnMouseMove(x, y) {
        if !this._isSelecting
            return

        ; 选择过程中可能被其他线程（取消/结束）销毁 GUI。
        ; 这里先快照引用，避免在 .Show() 与 .Hwnd 之间被置空为字符串。
        selectionFill := this._selectionFill
        borderTop := this._borderTop
        borderBottom := this._borderBottom
        borderLeft := this._borderLeft
        borderRight := this._borderRight
        sizeTooltip := this._sizeTooltip

        ; 选择过程中如果 GUI 已被销毁/未初始化，直接终止本次选择
        if Type(selectionFill) != "Gui"
            || Type(borderTop) != "Gui"
            || Type(borderBottom) != "Gui"
            || Type(borderLeft) != "Gui"
            || Type(borderRight) != "Gui"
            || Type(sizeTooltip) != "Gui" {
            this._isSelecting := false
            return
        }

        if (this._startX = 0 && this._startY = 0)
            return

        this._endX := x
        this._endY := y

        ; 计算选择框
        rx := Min(this._startX, x)
        ry := Min(this._startY, y)
        rw := Abs(x - this._startX)
        rh := Abs(y - this._startY)
        bw := this.BorderWidth

        if (rw > 3 && rh > 3) {
            selectionFill.Show("x" rx " y" ry " w" rw " h" rh " NA")
            try WinSetTransparent(1, selectionFill.Hwnd)

            borderTop.Show("x" rx " y" (ry - bw) " w" rw " h" bw " NA")
            borderBottom.Show("x" rx " y" (ry + rh) " w" rw " h" bw " NA")
            borderLeft.Show("x" (rx - bw) " y" (ry - bw) " w" bw " h" (rh + bw * 2) " NA")
            borderRight.Show("x" (rx + rw) " y" (ry - bw) " w" bw " h" (rh + bw * 2) " NA")

            try {
                sizeTooltip["SizeText"].Text := rw " x " rh
                tipY := ry - 30
                if (tipY < this._screenTop)
                    tipY := ry + rh + 5
                sizeTooltip.Show("x" rx " y" tipY " NA")
            }
        }
    }

    ; -------------------------------------------------
    ; OnMouseUp - 鼠标释放
    ; -------------------------------------------------
    OnMouseUp(x, y) {
        this._endX := x
        this._endY := y
        this._isSelecting := false
    }

    ; -------------------------------------------------
    ; GetRect - 获取选择区域
    ; -------------------------------------------------
    GetRect() {
        return {
            x: Min(this._startX, this._endX),
            y: Min(this._startY, this._endY),
            w: Abs(this._endX - this._startX),
            h: Abs(this._endY - this._startY)
        }
    }

    ; -------------------------------------------------
    ; IsValidSelection - 是否为有效选择
    ; -------------------------------------------------
    IsValidSelection(minSize := 10) {
        rect := this.GetRect()
        return rect.w >= minSize && rect.h >= minSize
    }

    ; -------------------------------------------------
    ; Destroy - 销毁所有GUI
    ; -------------------------------------------------
    Destroy() {
        ; 防止外部仍在派发鼠标移动事件导致对已销毁 GUI 调用 .Show()
        this._isSelecting := false
        this._startX := 0
        this._startY := 0
        this._endX := 0
        this._endY := 0

        for gui in [this._overlayGui, this._selectionFill,
            this._borderTop, this._borderBottom,
            this._borderLeft, this._borderRight,
            this._sizeTooltip] {
            if gui {
                try gui.Destroy()
            }
        }

        this._overlayGui := ""
        this._selectionFill := ""
        this._borderTop := ""
        this._borderBottom := ""
        this._borderLeft := ""
        this._borderRight := ""
        this._sizeTooltip := ""
    }
}
