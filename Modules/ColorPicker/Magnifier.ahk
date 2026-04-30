; =================================================
; 🔍 ColorPicker/Magnifier.ahk - 放大镜模块
; =================================================

class Magnifier {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(size := 150, zoom := 8, showGrid := true, showCrosshair := true) {
        ; 配置
        this.Size := size
        this.Zoom := zoom
        this.MinZoom := 2
        this.MaxZoom := 20

        this.ShowGrid := showGrid
        this.ShowCrosshair := showCrosshair

        ; GUI
        this._gui := ""
        this._tempFiles := []
    }

    ; -------------------------------------------------
    ; Create - 创建放大镜窗口
    ; -------------------------------------------------
    Create() {
        this._gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
        this._gui.BackColor := "000000"
        this._gui.MarginX := 0
        this._gui.MarginY := 0
        this._gui.AddPicture("vMagView x0 y0 w" this.Size " h" this.Size, "")
        return this
    }

    ; -------------------------------------------------
    ; Update - 更新放大镜内容
    ; -------------------------------------------------
    Update(mx, my) {
        if !this._gui
            return

        captureSize := this.Size // this.Zoom
        halfCapture := captureSize // 2

        sx := mx - halfCapture
        sy := my - halfCapture

        tempFile := A_Temp "\ahk_mag_" A_TickCount ".bmp"
        this._tempFiles.Push(tempFile)

        this._CaptureAndScale(sx, sy, captureSize, captureSize, this.Size, this.Size, tempFile)

        try {
            this._gui["MagView"].Value := tempFile
        }

        ; 延迟清理临时文件
        SetTimer(() => this._CleanupOldFiles(), -500)
    }

    ; -------------------------------------------------
    ; Show - 显示放大镜
    ; -------------------------------------------------
    Show(x, y) {
        if this._gui
            this._gui.Show("x" x " y" y " w" this.Size " h" this.Size " NA")
    }

    ; -------------------------------------------------
    ; Hide - 隐藏放大镜
    ; -------------------------------------------------
    Hide() {
        if this._gui
            this._gui.Hide()
    }

    ; -------------------------------------------------
    ; Destroy - 销毁放大镜
    ; -------------------------------------------------
    Destroy() {
        if this._gui {
            this._gui.Destroy()
            this._gui := ""
        }
        this._CleanupAllFiles()
    }

    ; -------------------------------------------------
    ; ZoomIn - 放大
    ; -------------------------------------------------
    ZoomIn(step := 2) {
        if (this.Zoom < this.MaxZoom)
            this.Zoom += step
        return this.Zoom
    }

    ; -------------------------------------------------
    ; ZoomOut - 缩小
    ; -------------------------------------------------
    ZoomOut(step := 2) {
        if (this.Zoom > this.MinZoom)
            this.Zoom -= step
        return this.Zoom
    }

    ; -------------------------------------------------
    ; 私有方法：截取并缩放
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

        ; 绘制辅助线（根据设置）
        if this.ShowGrid {
            cell := sw > 0 ? Floor(dw / sw) : 0
            if (cell >= 2)
                this._DrawCenterGrid(hdcMem, dw, dh, cell)
        }
        if this.ShowCrosshair
            this._DrawCrosshair(hdcMem, dw, dh)
        this._SaveBitmap(hBitmap, dw, dh, filePath)

        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteObject", "Ptr", hBitmap)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    }

    ; -------------------------------------------------
    ; 私有方法：绘制十字准星
    ; -------------------------------------------------
    _DrawCrosshair(hdc, w, h) {
        cx := w // 2
        cy := h // 2

        hPenWhite := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0xFFFFFF, "Ptr")
        hPenBlack := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x000000, "Ptr")

        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenBlack, "Ptr")

        ; 黑色外框
        DllCall("MoveToEx", "Ptr", hdc, "Int", cx - 10, "Int", cy, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", cx + 11, "Int", cy)
        DllCall("MoveToEx", "Ptr", hdc, "Int", cx, "Int", cy - 10, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", cx, "Int", cy + 11)

        ; 白色内线
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
    ; 私有方法：绘制中心像素网格（仅绘制中心格边框，避免过重绘制）
    ; -------------------------------------------------
    _DrawCenterGrid(hdc, w, h, cell) {
        cx := w // 2
        cy := h // 2

        half := cell // 2
        x1 := cx - half
        y1 := cy - half
        x2 := x1 + cell
        y2 := y1 + cell

        hPenBlack := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x000000, "Ptr")
        hPenWhite := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0xFFFFFF, "Ptr")

        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenBlack, "Ptr")

        ; 黑色外框
        DllCall("MoveToEx", "Ptr", hdc, "Int", x1, "Int", y1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x2, "Int", y1)
        DllCall("LineTo", "Ptr", hdc, "Int", x2, "Int", y2)
        DllCall("LineTo", "Ptr", hdc, "Int", x1, "Int", y2)
        DllCall("LineTo", "Ptr", hdc, "Int", x1, "Int", y1)

        ; 白色内框（向内 1px）
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hPenWhite, "Ptr")
        DllCall("MoveToEx", "Ptr", hdc, "Int", x1 + 1, "Int", y1 + 1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x2 - 1, "Int", y1 + 1)
        DllCall("LineTo", "Ptr", hdc, "Int", x2 - 1, "Int", y2 - 1)
        DllCall("LineTo", "Ptr", hdc, "Int", x1 + 1, "Int", y2 - 1)
        DllCall("LineTo", "Ptr", hdc, "Int", x1 + 1, "Int", y1 + 1)

        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
        DllCall("DeleteObject", "Ptr", hPenBlack)
        DllCall("DeleteObject", "Ptr", hPenWhite)
    }

    ; -------------------------------------------------
    ; 私有方法：保存位图
    ; -------------------------------------------------
    _SaveBitmap(hBitmap, w, h, filePath) {
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
    ; 私有方法：清理旧临时文件
    ; -------------------------------------------------
    _CleanupOldFiles() {
        while (this._tempFiles.Length > 3) {
            try FileDelete(this._tempFiles.RemoveAt(1))
        }
    }

    ; -------------------------------------------------
    ; 私有方法：清理所有临时文件
    ; -------------------------------------------------
    _CleanupAllFiles() {
        for file in this._tempFiles {
            try FileDelete(file)
        }
        this._tempFiles := []
    }
}
