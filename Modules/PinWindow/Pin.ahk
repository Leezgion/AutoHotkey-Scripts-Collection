; =================================================
; 📌 PinWindow/Pin.ahk - 置顶窗口主逻辑
; =================================================

#Include ..\..\Lib\Constants.ahk
#Include Border.ahk

class WindowPinner {
    ; 颜色池 - 使用 Constants.ahk 定义
    static ColorPool := BorderColors.Pool

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(config := "") {
        ; 配置
        this.Config := {
            BorderThickness: Defaults.PinBorderThickness,
            SoundEnabled: Defaults.PinSoundEnabled,
            FlashCount: Defaults.PinFlashCount,
            FlashInterval: Defaults.PinFlashInterval,
            UpdateInterval: Defaults.PinUpdateInterval
        }

        ; 数据
        this._pinnedWindows := Map()
        this._colorIndex := 0
        this._updateTimer := 0

        ; 回调
        this.OnPin := ""
        this.OnUnpin := ""
        this.OnNotify := ""

        ; 应用配置
        if config {
            for key, val in config.OwnProps() {
                if this.Config.HasOwnProp(key)
                    this.Config.%key% := val
            }
        }

        this._updateTimer := ObjBindMethod(this, "_UpdateAllBorders")
    }

    ; -------------------------------------------------
    ; Pin - 置顶窗口
    ; -------------------------------------------------
    Pin(hwnd) {
        if this._pinnedWindows.Has(hwnd)
            return false

        ; 设置窗口置顶
        try WinSetAlwaysOnTop(true, hwnd)

        ; 获取下一个颜色
        this._colorIndex := Mod(this._colorIndex, WindowPinner.ColorPool.Length) + 1
        color := WindowPinner.ColorPool[this._colorIndex]

        ; 创建边框
        border := WindowBorder(hwnd, color, this.Config.BorderThickness)
        this._pinnedWindows[hwnd] := border

        ; 显示边框
        border.Update(true)

        ; 启动定时器
        SetTimer(this._updateTimer, this.Config.UpdateInterval)

        ; 闪烁动画
        border.Flash(this.Config.FlashCount, this.Config.FlashInterval)

        ; 播放声音
        this._PlaySound("ON")

        if this.OnPin {
            callback := this.OnPin
            callback(hwnd, border.Title)
        }

        return true
    }

    ; -------------------------------------------------
    ; Unpin - 取消置顶
    ; -------------------------------------------------
    Unpin(hwnd) {
        if !this._pinnedWindows.Has(hwnd)
            return false

        border := this._pinnedWindows[hwnd]
        title := border.Title

        ; 取消窗口置顶（排除截图悬浮窗）
        if WinExist(hwnd) {
            if !this._IsScreenshotFloat(hwnd)
                try WinSetAlwaysOnTop(false, hwnd)
        }

        ; 销毁边框
        border.Destroy()
        this._pinnedWindows.Delete(hwnd)

        ; 如果没有置顶窗口，停止定时器
        if (this._pinnedWindows.Count = 0)
            SetTimer(this._updateTimer, 0)

        ; 播放声音
        this._PlaySound("OFF")

        if this.OnUnpin {
            callback := this.OnUnpin
            callback(hwnd, title)
        }

        return true
    }

    ; -------------------------------------------------
    ; Toggle - 切换置顶状态
    ; -------------------------------------------------
    Toggle(hwnd) {
        if this._pinnedWindows.Has(hwnd)
            return this.Unpin(hwnd)
        else
            return this.Pin(hwnd)
    }

    ; -------------------------------------------------
    ; ToggleCurrent - 切换当前窗口
    ; -------------------------------------------------
    ToggleCurrent() {
        try {
            hwnd := WinGetID("A")
            return this.Toggle(hwnd)
        } catch {
            this._Notify("没有活动窗口")
            return false
        }
    }

    ; -------------------------------------------------
    ; UnpinAll - 取消所有置顶
    ; -------------------------------------------------
    UnpinAll() {
        count := this._pinnedWindows.Count
        if (count = 0)
            return 0

        hwnds := []
        for hwnd in this._pinnedWindows
            hwnds.Push(hwnd)

        for hwnd in hwnds
            this.Unpin(hwnd)

        return count
    }

    ; -------------------------------------------------
    ; SwitchFocus - 切换焦点到下一个置顶窗口
    ; -------------------------------------------------
    SwitchFocus() {
        if (this._pinnedWindows.Count = 0) {
            this._Notify("没有置顶的窗口")
            return false
        }

        hwnds := []
        for hwnd in this._pinnedWindows
            hwnds.Push(hwnd)

        currentHwnd := 0
        try currentHwnd := WinGetID("A")

        currentIndex := 0
        for i, h in hwnds {
            if (h = currentHwnd) {
                currentIndex := i
                break
            }
        }

        nextIndex := Mod(currentIndex, hwnds.Length) + 1
        try WinActivate(hwnds[nextIndex])

        return true
    }

    ; -------------------------------------------------
    ; ChangeColor - 更改当前窗口边框颜色
    ; -------------------------------------------------
    ChangeColor(hwnd := "") {
        if (hwnd = "") {
            try hwnd := WinGetID("A")
            catch {
                this._Notify("没有活动窗口")
                return false
            }
        }

        if !this._pinnedWindows.Has(hwnd) {
            this._Notify("当前窗口未置顶")
            return false
        }

        border := this._pinnedWindows[hwnd]
        currentColor := border.Color

        ; 找下一个颜色
        newColor := WindowPinner.ColorPool[1]
        for i, c in WindowPinner.ColorPool {
            if (c = currentColor) {
                nextIndex := Mod(i, WindowPinner.ColorPool.Length) + 1
                newColor := WindowPinner.ColorPool[nextIndex]
                break
            }
        }

        border.SetColor(newColor)
        this._Notify("边框颜色: #" newColor)

        return true
    }

    ; -------------------------------------------------
    ; IsPinned - 检查窗口是否已置顶
    ; -------------------------------------------------
    IsPinned(hwnd) {
        return this._pinnedWindows.Has(hwnd)
    }

    ; -------------------------------------------------
    ; GetPinnedCount - 获取置顶窗口数量
    ; -------------------------------------------------
    GetPinnedCount() {
        return this._pinnedWindows.Count
    }

    ; -------------------------------------------------
    ; GetPinnedList - 获取置顶窗口列表
    ; -------------------------------------------------
    GetPinnedList() {
        list := []
        for hwnd, border in this._pinnedWindows {
            list.Push({
                hwnd: hwnd,
                title: border.Title,
                color: border.Color
            })
        }
        return list
    }

    ; -------------------------------------------------
    ; Destroy - 销毁
    ; -------------------------------------------------
    Destroy() {
        SetTimer(this._updateTimer, 0)
        this.UnpinAll()
    }

    ; -------------------------------------------------
    ; 私有方法：更新所有边框
    ; -------------------------------------------------
    _UpdateAllBorders() {
        toRemove := []

        for hwnd, border in this._pinnedWindows {
            if !WinExist(hwnd) {
                toRemove.Push(hwnd)
                continue
            }
            border.Update()
        }

        for hwnd in toRemove
            this.Unpin(hwnd)
    }

    ; -------------------------------------------------
    ; 私有方法：检查是否为截图悬浮窗
    ; -------------------------------------------------
    _IsScreenshotFloat(hwnd) {
        try {
            winClass := WinGetClass(hwnd)
            winPID := WinGetPID(hwnd)
            procName := ProcessGetName(winPID)

            if (winClass = "AutoHotkeyGUI" && InStr(procName, "AutoHotkey")) {
                winTitle := WinGetTitle(hwnd)
                if (StrLen(winTitle) = 0 || winTitle = "")
                    return true
            }
        }
        return false
    }

    ; -------------------------------------------------
    ; 私有方法：播放声音
    ; -------------------------------------------------
    _PlaySound(type) {
        if !this.Config.SoundEnabled
            return

        if (type = "ON")
            SoundBeep(750, 50)
        else
            SoundBeep(500, 50)
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
}
