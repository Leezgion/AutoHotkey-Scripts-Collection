; =================================================
; 📦 Constants.ahk - 全局常量定义
; =================================================
; 统一管理所有常量，避免硬编码和冲突
; =================================================

; -------------------------------------------------
; 📌 版本信息
; -------------------------------------------------
class AppInfo {
    static Name := "AHK Script Manager"
    static Version := "2.0.0"
    static Author := "AutoHotkey User"
    static Website := "https://github.com/user/ahk-script-manager"
}

; -------------------------------------------------
; 📡 脚本间消息ID
; -------------------------------------------------
; 使用 0x8000-0xBFFF 范围（WM_APP 区域，确保不与系统消息冲突）
class MSG {
    ; 置顶窗口脚本 (0x8001 - 0x800F)
    static PIN_TOGGLE := 0x8001         ; 切换置顶
    static PIN_UNPIN_ALL := 0x8002      ; 取消全部置顶
    static PIN_SWITCH := 0x8003         ; 切换焦点
    static PIN_CHANGE_COLOR := 0x8004   ; 更换颜色

    ; 截图悬浮脚本 (0x8010 - 0x801F)
    static SCREENSHOT_START := 0x8010   ; 开始截图
    static SCREENSHOT_CLOSE_ALL := 0x8011  ; 关闭所有悬浮窗

    ; 屏幕取色脚本 (0x8020 - 0x802F)
    static PICKER_START := 0x8020       ; 开始取色
    static PICKER_SHOW_HISTORY := 0x8021  ; 显示历史

    ; 管理器广播 (0x8100 - 0x810F)
    static MANAGER_RELOAD := 0x8100     ; 请求重载
    static MANAGER_SHUTDOWN := 0x8101   ; 请求关闭
    static MANAGER_STATUS := 0x8102     ; 状态查询
}

; -------------------------------------------------
; 🎨 主题颜色 (现代深色主题)
; -------------------------------------------------
class Theme {
    ; 背景色
    static BgPrimary := "1a1a2e"        ; 主背景 - 深蓝黑
    static BgSecondary := "16213e"      ; 次背景 - 深蓝
    static BgTertiary := "0f3460"       ; 第三背景 - 蓝色
    static BgHover := "1f4068"          ; 悬停背景
    static BgSelected := "e94560"       ; 选中背景 - 红色强调

    ; 前景色
    static FgPrimary := "eaeaea"        ; 主文字 - 浅灰白
    static FgSecondary := "a0a0a0"      ; 次文字 - 灰色
    static FgMuted := "666666"          ; 弱化文字
    static FgAccent := "e94560"         ; 强调色 - 红色

    ; 状态色
    static Success := "00d26a"          ; 成功 - 绿色
    static Warning := "ffc107"          ; 警告 - 黄色
    static Error := "ff4757"            ; 错误 - 红色
    static Info := "3498db"             ; 信息 - 蓝色

    ; 边框色
    static Border := "2d2d44"           ; 默认边框
    static BorderHover := "e94560"      ; 悬停边框
    static BorderFocus := "e94560"      ; 焦点边框

    ; 按钮色
    static BtnPrimary := "e94560"       ; 主按钮背景
    static BtnPrimaryHover := "ff6b81"  ; 主按钮悬停
    static BtnSecondary := "16213e"     ; 次按钮背景
    static BtnSecondaryHover := "1f4068"  ; 次按钮悬停
}

; -------------------------------------------------
; 🌈 置顶窗口边框颜色池
; -------------------------------------------------
class BorderColors {
    static Pool := [
        "00FF00",  ; 绿色
        "FF6B6B",  ; 珊瑚红
        "4ECDC4",  ; 青色
        "FFE66D",  ; 金黄
        "95E1D3",  ; 薄荷绿
        "F38181",  ; 粉红
        "AA96DA",  ; 淡紫
        "00ADB5",  ; 蓝绿
        "FF9F43",  ; 橙色
        "74B9FF"   ; 天蓝
    ]
}

; -------------------------------------------------
; ⌨️ 默认快捷键
; -------------------------------------------------
class DefaultHotkeys {
    ; 屏幕取色
    static PickerStart := "#+c"          ; Win+Shift+C
    static PickerCancel := "Escape"

    ; 截图悬浮
    static ScreenshotStart := "#+s"      ; Win+Shift+S
    static ScreenshotCloseAll := "#+q"   ; Win+Shift+Q

    ; 置顶窗口
    static PinToggle := "CapsLock & Space"
    static PinUnpinAll := "CapsLock & Escape"
    static PinSwitch := "CapsLock & Tab"
    static PinChangeColor := "CapsLock & c"

    ; 管理器
    static ManagerReloadAll := "#!r"     ; Win+Alt+R
    static ManagerStopAll := "#!s"       ; Win+Alt+S
    static ManagerStartAll := "#!a"      ; Win+Alt+A
    static ManagerShowGUI := "#!m"       ; Win+Alt+M
}

; -------------------------------------------------
; ⚙️ 默认配置值
; -------------------------------------------------
class Defaults {
    ; 通用
    static Language := "auto"            ; auto=跟随系统
    static CheckUpdateOnStart := true
    static MinimizeToTray := true
    static ShowNotifications := true
    static NotificationDuration := 2000  ; 毫秒

    ; 屏幕取色
    static PickerColorFormat := "HEX"    ; HEX, RGB, HSL
    static PickerMagnifierSize := 150
    static PickerMagnifierZoom := 8
    static PickerMinZoom := 2
    static PickerMaxZoom := 20
    static PickerMaxHistory := 10

    ; 截图悬浮
    static ScreenshotFolder := "Screenshots"
    static ScreenshotMaxFloats := 20     ; 最大悬浮窗数量
    static ScreenshotDefaultOpacity := 255
    static ScreenshotSelectionColor := "00AAFF"
    static ScreenshotBorderWidth := 3

    ; 置顶窗口
    static PinBorderThickness := 4
    static PinSoundEnabled := true
    static PinFlashCount := 3
    static PinFlashInterval := 100
    static PinUpdateInterval := 30       ; 边框更新间隔(ms)

    ; 日志
    static LogLevel := "INFO"            ; DEBUG, INFO, WARN, ERROR
    static LogToFile := false
    static LogMaxSize := 1048576         ; 1MB
}

; -------------------------------------------------
; 🗂️ 文件路径
; -------------------------------------------------
class Paths {
    static Config := A_ScriptDir "\Config"
    static Settings := A_ScriptDir "\Config\settings.json"
    static Hotkeys := A_ScriptDir "\Config\hotkeys.json"
    static Log := A_ScriptDir "\Config\app.log"
    static Lang := A_ScriptDir "\Lang"
    static Screenshots := A_ScriptDir "\Screenshots"
}

; -------------------------------------------------
; 🔧 脚本信息
; -------------------------------------------------
class Scripts {
    static ColorPicker := {
        Name: "Color Picker",
        File: "ColorPicker.ahk",
        Icon: "🎨",
        MsgBase: 0x8020
    }
    static Screenshot := {
        Name: "Screenshot Float",
        File: "ScreenshotFloat.ahk",
        Icon: "📸",
        MsgBase: 0x8010
    }
    static PinWindow := {
        Name: "Window Pin",
        File: "WindowPin.ahk",
        Icon: "📌",
        MsgBase: 0x8001
    }
}

; -------------------------------------------------
; 📊 状态枚举
; -------------------------------------------------
class ScriptState {
    static Stopped := 0
    static Running := 1
    static Starting := 2
    static Stopping := 3
    static Error := -1
}

class PickerState {
    static Idle := "IDLE"
    static Initializing := "INIT"
    static Picking := "PICKING"
    static Copying := "COPYING"
    static Cleanup := "CLEANUP"
}

class ScreenshotState {
    static Idle := "IDLE"
    static Overlay := "OVERLAY"
    static Selecting := "SELECTING"
    static Capturing := "CAPTURING"
    static Floating := "FLOATING"
}
