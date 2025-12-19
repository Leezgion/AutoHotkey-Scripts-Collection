; =================================================
; 🌐 Lang/en-US.ahk - English Language Pack
; =================================================

class Lang_en_US {
    static Code := "en-US"
    static Name := "English (US)"

    ; -------------------------------------------------
    ; Common Text
    ; -------------------------------------------------
    static Common := {
        AppName: "Script Manager",
        OK: "OK",
        Cancel: "Cancel",
        Close: "Close",
        Save: "Save",
        Delete: "Delete",
        Copy: "Copy",
        Copied: "Copied",
        Error: "Error",
        Warning: "Warning",
        Info: "Information",
        Success: "Success",
        Enabled: "Enabled",
        Disabled: "Disabled"
    }

    ; -------------------------------------------------
    ; Tray Menu
    ; -------------------------------------------------
    static TrayMenu := {
        ColorPicker: "🎨 Color Picker",
        Screenshot: "📷 Screenshot Float",
        PinWindow: "📌 Pin Window",
        Settings: "⚙️ Settings",
        About: "💡 About",
        Exit: "❌ Exit",
        Pause: "⏸️ Pause",
        Reload: "🔄 Reload",
        AutoStart: "🚀 Auto Start",
        ; Submenus
        ColorPickerMenu: "Color Picker",
        PinWindowMenu: "Pin Window Operations",
        ModuleManagement: "🔧 Module Management",
        ; Color picker submenu
        StartPicking: "🎨 Start Picking (Alt+C)",
        ColorHistory: "📋 Color History",
        ; Pin window submenu
        UnpinAll: "Unpin All (Alt+Shift+T)",
        SwitchFocus: "Switch Focus",
        ChangeBorderColor: "Change Border Color (Alt+Shift+C)"
    }

    ; -------------------------------------------------
    ; Color Picker
    ; -------------------------------------------------
    static ColorPicker := {
        Starting: "Starting color picker...",
        Stopping: "Color picker stopped",
        ColorCopied: "Color copied",
        NoColor: "No color selected",
        History: "History",
        ClearHistory: "Clear History",
        HistoryCleared: "History cleared",
        ZoomIn: "Zoom In",
        ZoomOut: "Zoom Out",
        Tip: "Press Esc to cancel, scroll to zoom",
        Format_Hex: "HEX",
        Format_RGB: "RGB",
        Format_HSL: "HSL",
        ; Short alias keys
        title: "Color Picker",
        started: "Color picker started",
        copied: "Copied",
        tips: "Press Esc to cancel, scroll to zoom",
        noHistory: "No history",
        history: "Color History",
        format: {
            hex: "HEX format",
            rgb: "RGB format",
            hsl: "HSL format"
        }
    }

    ; -------------------------------------------------
    ; Screenshot Float
    ; -------------------------------------------------
    static Screenshot := {
        Starting: "Starting screenshot...",
        Stopping: "Screenshot cancelled",
        Capturing: "Capturing...",
        SelectArea: "Select area",
        AreaSelected: "Area selected",
        Saved: "Saved",
        SaveFailed: "Save failed",
        Copied: "Copied to clipboard",
        CopyFailed: "Copy failed",
        FloatCreated: "Float window created",
        FloatClosed: "Float window closed",
        AllClosed: "All float windows closed",
        Tip: "Drag to select area, Esc to cancel",
        ContextMenu_Copy: "Copy Image",
        ContextMenu_Save: "Save As...",
        ContextMenu_Close: "Close",
        ContextMenu_CloseAll: "Close All",
        ZoomIn: "Zoom In",
        ZoomOut: "Zoom Out",
        OpacityUp: "Increase Opacity",
        OpacityDown: "Decrease Opacity",
        ; Short alias keys
        title: "Screenshot Float",
        started: "Screenshot mode started",
        done: "Screenshot done",
        tooSmall: "Selection too small",
        allClosed: "All float windows closed",
        copied: "Copied to clipboard",
        saved: "Saved",
        saveFailed: "Save failed"
    }

    ; -------------------------------------------------
    ; Pin Window
    ; -------------------------------------------------
    static PinWindow := {
        Pinned: "Pinned",
        Unpinned: "Unpinned",
        NoPinnedWindows: "No pinned windows",
        NoActiveWindow: "No active window",
        NotPinned: "Window not pinned",
        ColorChanged: "Border color changed",
        AllUnpinned: "All windows unpinned",
        Tip: "Click window to toggle pin",
        SwitchFocus: "Switch Focus",
        UnpinAll: "Unpin All",
        ; Short alias keys
        title: "Pin Window",
        started: "Pin function started",
        pinned: "Pinned",
        unpinned: "Unpinned",
        allUnpinned: "All windows unpinned",
        noWindow: "No active window",
        colorChanged: "Border color changed"
    }

    ; -------------------------------------------------
    ; Settings Panel
    ; -------------------------------------------------
    static Settings := {
        Title: "Settings",
        General: "General",
        Hotkeys: "Hotkeys",
        ColorPicker: "Color Picker",
        Screenshot: "Screenshot",
        PinWindow: "Pin Window",
        Language: "Language",
        Theme: "Theme",
        AutoStart: "Start with Windows",
        ShowTrayTip: "Show tray tips",
        SoundEnabled: "Enable sounds",
        SavePath: "Save path",
        Browse: "Browse...",
        DefaultFormat: "Default format",
        ZoomLevel: "Zoom level",
        BorderThickness: "Border thickness",
        FlashAnimation: "Flash animation",
        RestartRequired: "Restart required",
        Saved: "Settings saved",
        SaveSuccess: "Settings saved",
        LanguageChangeRestart: "Language has been changed. Restart now to apply the new language?",
        ; Module management
        ModuleManagement: "🔧 Module Management",
        GeneralSettings: "⚙️ General Settings",
        ModuleHint: "Hint: Disabled modules won't appear in tray menu and hotkeys will be inactive",
        ; Additional settings
        MagnifierSize: "Magnifier size",
        Pixels: "pixels",
        ShowGrid: "Show grid lines",
        ShowCrosshair: "Show crosshair",
        CheckUpdate: "🔄 Check for Updates",
        OpenConfigDir: "📂 Open Config Folder",
        ; Screenshot
        MaxFloats: "Max float windows",
        AutoCopyToClipboard: "Auto copy to clipboard after capture",
        ; Pin window
        SelectColor: "Select Color...",
        FlashCount: "Flash count on pin",
        Times: "times",
        EnablePinSound: "Enable pin/unpin sound"
    }

    ; -------------------------------------------------
    ; Hotkey Editor
    ; -------------------------------------------------
    static HotkeyEditor := {
        Title: "Edit Hotkey",
        Action: "Action",
        CurrentHotkey: "Current Hotkey",
        NewHotkey: "New Hotkey",
        PressKey: "Press new hotkey...",
        Conflict: "Hotkey already in use",
        Clear: "Clear",
        Reset: "Reset Default",
        Apply: "Apply"
    }

    ; -------------------------------------------------
    ; About Dialog
    ; -------------------------------------------------
    static About := {
        Title: "About",
        Version: "Version",
        Author: "Author",
        Website: "Website",
        Description: "A practical AutoHotkey script manager with color picker, screenshot float, and window pinning features.",
        License: "License",
        CheckUpdate: "Check for Updates"
    }

    ; -------------------------------------------------
    ; Error Messages
    ; -------------------------------------------------
    static Errors := {
        FileNotFound: "File not found",
        AccessDenied: "Access denied",
        InvalidPath: "Invalid path",
        GDIPlusFailed: "GDI+ initialization failed",
        WindowNotFound: "Window not found",
        HotkeyFailed: "Hotkey registration failed",
        Unknown: "Unknown error",
        ; Short alias keys
        gdipInit: "GDI+ initialization failed",
        unknown: "Unknown error"
    }

    ; -------------------------------------------------
    ; Dialog Text
    ; -------------------------------------------------
    static Dialog := {
        cancel: "Cancel",
        ok: "OK",
        close: "Close"
    }

    ; -------------------------------------------------
    ; Hotkey Text
    ; -------------------------------------------------
    static Hotkey := {
        clear: "Clear",
        reset: "Reset"
    }

    ; -------------------------------------------------
    ; Get - Get translated text (supports nested properties)
    ; -------------------------------------------------
    static Get(category, key, default := "") {
        if !this.HasOwnProp(category)
            return (default != "") ? default : key

        cat := this.%category%

        ; Support nested keys, e.g. "format.hex"
        if InStr(key, ".") {
            parts := StrSplit(key, ".")
            result := cat
            for part in parts {
                if IsObject(result) && result.HasOwnProp(part)
                    result := result.%part%
                else
                    return (default != "") ? default : key
            }
            return result
        }

        ; Normal key
        if cat.HasOwnProp(key)
            return cat.%key%

        return (default != "") ? default : key
    }
}
