; =================================================
; 📋 ColorPicker/History.ahk - 颜色历史记录
; =================================================

class ColorHistory {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(maxItems := 10) {
        ; 配置
        this.MaxItems := maxItems

        ; 数据
        this._items := []
        this._gui := ""

        ; 回调
        this.OnColorClick := ""
    }

    ; -------------------------------------------------
    ; Add - 添加颜色
    ; -------------------------------------------------
    Add(color) {
        ; 移除已存在的相同颜色
        for i, c in this._items {
            if (c = color) {
                this._items.RemoveAt(i)
                break
            }
        }

        ; 添加到开头
        this._items.InsertAt(1, color)

        ; 限制数量
        while (this._items.Length > this.MaxItems)
            this._items.Pop()

        ; 如果 GUI 已打开，刷新显示
        if this._gui
            this._RefreshGUI()

        return this
    }

    ; -------------------------------------------------
    ; GetAll - 获取所有颜色
    ; -------------------------------------------------
    GetAll() {
        return this._items.Clone()
    }

    ; -------------------------------------------------
    ; GetCount - 获取数量
    ; -------------------------------------------------
    GetCount() {
        return this._items.Length
    }

    ; -------------------------------------------------
    ; Clear - 清空历史
    ; -------------------------------------------------
    Clear() {
        this._items := []
        return this
    }

    ; -------------------------------------------------
    ; ShowGUI - 显示历史记录窗口
    ; -------------------------------------------------
    ShowGUI(title := "🎨 颜色历史", bgColor := "1a1a2e", fgColor := "eaeaea") {
        if (this._items.Length = 0) {
            return false
        }

        ; 关闭已有窗口
        this.CloseGUI()

        this._gui := Gui("+AlwaysOnTop -MinimizeBox", title)
        this._gui.BackColor := bgColor
        this._gui.OnEvent("Close", (*) => this.CloseGUI())

        this._gui.SetFont("s10 c" fgColor, "Segoe UI")
        this._gui.AddText("x10 y10 w200", "点击颜色复制到剪贴板：")

        y := 40
        for i, color in this._items {
            colorHex := SubStr(color, 2)
            bmpPath := this._CreateColorBitmap(colorHex, 30, 30)

            if (bmpPath != "")
                this._gui.AddPicture("x10 y" y " w30 h30 +Border", bmpPath)

            btn := this._gui.AddButton("x50 y" (y - 2) " w150 h30", color)
            btn.OnEvent("Click", this._OnColorClick.Bind(this, color))

            y += 40
        }

        this._gui.AddButton("x10 y" y " w100 h30", "清空历史").OnEvent("Click", (*) => (this.Clear(), this.CloseGUI()))
        this._gui.AddButton("x120 y" y " w80 h30", "关闭").OnEvent("Click", (*) => this.CloseGUI())

        guiHeight := 50 + this._items.Length * 40 + 50
        this._gui.Show("w220 h" guiHeight)

        return true
    }

    ; -------------------------------------------------
    ; CloseGUI - 关闭窗口
    ; -------------------------------------------------
    CloseGUI() {
        if this._gui {
            this._gui.Destroy()
            this._gui := ""
        }
    }

    ; -------------------------------------------------
    ; _RefreshGUI - 刷新窗口内容
    ; -------------------------------------------------
    _RefreshGUI() {
        if !this._gui
            return

        ; 获取当前窗口位置
        try {
            WinGetPos(&x, &y, , , this._gui.Hwnd)
        } catch {
            x := "", y := ""
        }

        ; 重新创建窗口
        this._gui.Destroy()
        this._gui := ""

        if (this._items.Length = 0)
            return

        this._gui := Gui("+AlwaysOnTop -MinimizeBox", "🎨 颜色历史")
        this._gui.BackColor := "1a1a2e"
        this._gui.OnEvent("Close", (*) => this.CloseGUI())

        this._gui.SetFont("s10 ceaeaea", "Segoe UI")
        this._gui.AddText("x10 y10 w200", "点击颜色复制到剪贴板：")

        yPos := 40
        for i, color in this._items {
            colorHex := SubStr(color, 2)
            bmpPath := this._CreateColorBitmap(colorHex, 30, 30)

            if (bmpPath != "")
                this._gui.AddPicture("x10 y" yPos " w30 h30 +Border", bmpPath)

            btn := this._gui.AddButton("x50 y" (yPos - 2) " w150 h30", color)
            btn.OnEvent("Click", this._OnColorClick.Bind(this, color))

            yPos += 40
        }

        this._gui.AddButton("x10 y" yPos " w100 h30", "清空历史").OnEvent("Click", (*) => (this.Clear(), this.CloseGUI()))
        this._gui.AddButton("x120 y" yPos " w80 h30", "关闭").OnEvent("Click", (*) => this.CloseGUI())

        guiHeight := 50 + this._items.Length * 40 + 50

        ; 在原位置显示，或默认位置
        if (x != "" && y != "")
            this._gui.Show("x" x " y" y " w220 h" guiHeight)
        else
            this._gui.Show("w220 h" guiHeight)
    }

    ; -------------------------------------------------
    ; 私有方法：颜色点击处理
    ; -------------------------------------------------
    _OnColorClick(color, *) {
        A_Clipboard := color
        if this.OnColorClick {
            callback := this.OnColorClick
            callback(color)
        }
    }

    ; -------------------------------------------------
    ; 私有方法：创建颜色位图
    ; -------------------------------------------------
    _CreateColorBitmap(hexColor, width, height) {
        r := Integer("0x" SubStr(hexColor, 1, 2))
        g := Integer("0x" SubStr(hexColor, 3, 2))
        b := Integer("0x" SubStr(hexColor, 5, 2))

        bmpPath := A_Temp "\color_" hexColor ".bmp"

        if FileExist(bmpPath)
            return bmpPath

        rowSize := ((width * 3 + 3) // 4) * 4
        pixelDataSize := rowSize * height

        file := FileOpen(bmpPath, "w")
        if !file
            return ""

        ; BITMAPFILEHEADER
        file.WriteUChar(0x42)
        file.WriteUChar(0x4D)
        file.WriteUInt(54 + pixelDataSize)
        file.WriteUShort(0)
        file.WriteUShort(0)
        file.WriteUInt(54)

        ; BITMAPINFOHEADER
        file.WriteUInt(40)
        file.WriteInt(width)
        file.WriteInt(height)
        file.WriteUShort(1)
        file.WriteUShort(24)
        file.WriteUInt(0)
        file.WriteUInt(pixelDataSize)
        file.WriteInt(2835)
        file.WriteInt(2835)
        file.WriteUInt(0)
        file.WriteUInt(0)

        padding := rowSize - width * 3
        loop height {
            loop width {
                file.WriteUChar(b)
                file.WriteUChar(g)
                file.WriteUChar(r)
            }
            loop padding
                file.WriteUChar(0)
        }

        file.Close()
        return bmpPath
    }

    ; -------------------------------------------------
    ; Save - 保存到文件
    ; -------------------------------------------------
    Save(filePath) {
        content := ""
        for color in this._items {
            content .= color "`n"
        }
        try {
            FileDelete(filePath)
            FileAppend(content, filePath)
            return true
        }
        return false
    }

    ; -------------------------------------------------
    ; Load - 从文件加载
    ; -------------------------------------------------
    Load(filePath) {
        if !FileExist(filePath)
            return false

        this._items := []
        loop read filePath {
            if (A_LoopReadLine != "")
                this._items.Push(A_LoopReadLine)
        }
        return true
    }
}
