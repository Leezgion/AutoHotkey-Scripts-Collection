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
    }

    ; -------------------------------------------------
    ; Start - 开始选择
    ; -------------------------------------------------
    Start() {
        this._startX := 0
        this._startY := 0
        this._isSelecting := false

        ; 获取虚拟屏幕尺寸
        screenLeft := SysGet(76)
        screenTop := SysGet(77)
        screenWidth := SysGet(78)
        screenHeight := SysGet(79)

        ; 创建半透明遮罩层
        this._overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")
        this._overlayGui.BackColor := "000000"
        this._overlayGui.Show("x" screenLeft " y" screenTop " w" screenWidth " h" screenHeight " NA")
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
            this._selectionFill.Show("x" rx " y" ry " w" rw " h" rh " NA")
            WinSetTransparent(1, this._selectionFill.Hwnd)

            this._borderTop.Show("x" rx " y" (ry - bw) " w" rw " h" bw " NA")
            this._borderBottom.Show("x" rx " y" (ry + rh) " w" rw " h" bw " NA")
            this._borderLeft.Show("x" (rx - bw) " y" (ry - bw) " w" bw " h" (rh + bw * 2) " NA")
            this._borderRight.Show("x" (rx + rw) " y" (ry - bw) " w" bw " h" (rh + bw * 2) " NA")

            try {
                this._sizeTooltip["SizeText"].Text := rw " x " rh
                tipY := ry - 30
                if (tipY < 0)
                    tipY := ry + rh + 5
                this._sizeTooltip.Show("x" rx " y" tipY " NA")
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
