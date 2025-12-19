; =================================================
; 📦 GDIPlus.ahk - 统一的 GDI+ 图形库封装
; =================================================
; 功能：
;   - GDI+ 初始化与关闭
;   - 屏幕截图
;   - 图片加载与保存
;   - 剪贴板操作
;   - 颜色获取与转换
;   - 资源自动管理
; =================================================

; -------------------------------------------------
; 🎨 GDI+ 管理器类
; -------------------------------------------------
class GDIPlus {
    static _token := 0
    static _initialized := false
    static _refCount := 0

    ; -------------------------------------------------
    ; Startup - 初始化 GDI+
    ; 返回: true=成功, false=失败
    ; -------------------------------------------------
    static Startup() {
        ; 引用计数，支持多模块共享
        this._refCount++

        if this._initialized
            return true

        ; 加载 GDI+ DLL
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")

        ; 初始化结构
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)  ; GdiplusVersion = 1

        token := 0
        result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)

        if (result != 0) {
            this._token := 0
            this._initialized := false
            return false
        }

        this._token := token
        this._initialized := true
        return true
    }

    ; -------------------------------------------------
    ; Shutdown - 关闭 GDI+
    ; -------------------------------------------------
    static Shutdown() {
        this._refCount--

        ; 只有当引用计数归零时才真正关闭
        if (this._refCount > 0)
            return

        if this._initialized && this._token {
            try DllCall("gdiplus\GdiplusShutdown", "Ptr", this._token)
            this._token := 0
            this._initialized := false
        }
    }

    ; -------------------------------------------------
    ; IsInitialized - 检查是否已初始化
    ; -------------------------------------------------
    static IsInitialized() {
        return this._initialized && this._token != 0
    }

    ; -------------------------------------------------
    ; GetPixelColor - 获取屏幕指定位置的颜色
    ; 返回: BGR 格式颜色值，失败返回 -1
    ; -------------------------------------------------
    static GetPixelColor(x, y) {
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        if !hdc
            return -1

        color := DllCall("GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

        ; GetPixel 失败返回 CLR_INVALID (0xFFFFFFFF)
        if (color = 0xFFFFFFFF)
            return -1

        return color
    }

    ; -------------------------------------------------
    ; CaptureScreen - 截取屏幕区域
    ; 参数: x, y, w, h - 截取区域
    ; 返回: pBitmap 指针，失败返回 0
    ; -------------------------------------------------
    static CaptureScreen(x, y, w, h) {
        if !this.IsInitialized()
            return 0

        ; 创建兼容 DC 和位图
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        if !hdcScreen
            return 0

        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")

        if (!hdcMem || !hBitmap) {
            if hdcMem
                DllCall("DeleteDC", "Ptr", hdcMem)
            if hBitmap
                DllCall("DeleteObject", "Ptr", hBitmap)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
            return 0
        }

        hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

        ; 复制屏幕内容 (SRCCOPY = 0x00CC0020)
        DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h
            , "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)

        ; 创建 GDI+ Bitmap
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap)

        ; 清理
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteObject", "Ptr", hBitmap)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

        return pBitmap
    }

    ; -------------------------------------------------
    ; CaptureScreenFromCoords - 从坐标字符串截图
    ; 参数: coords - "x|y|w|h" 格式的坐标字符串
    ; -------------------------------------------------
    static CaptureScreenFromCoords(coords) {
        parts := StrSplit(coords, "|")
        if parts.Length < 4
            return 0
        return this.CaptureScreen(parts[1], parts[2], parts[3], parts[4])
    }

    ; -------------------------------------------------
    ; LoadFromFile - 从文件加载图片
    ; 返回: pBitmap 指针
    ; -------------------------------------------------
    static LoadFromFile(filePath) {
        if !this.IsInitialized() || !FileExist(filePath)
            return 0

        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", filePath, "Ptr*", &pBitmap)
        return pBitmap
    }

    ; -------------------------------------------------
    ; SaveToFile - 保存图片到文件
    ; 参数: pBitmap - 位图指针
    ;       filePath - 保存路径
    ;       format - 格式 (PNG, JPEG, BMP, GIF)
    ;       quality - JPEG质量 (0-100)
    ; -------------------------------------------------
    static SaveToFile(pBitmap, filePath, format := "PNG", quality := 100) {
        if !pBitmap
            return false

        ; 编码器 CLSID
        static encoders := Map(
            "PNG", "{557CF406-1A04-11D3-9A73-0000F81EF32E}",
            "JPEG", "{557CF401-1A04-11D3-9A73-0000F81EF32E}",
            "JPG", "{557CF401-1A04-11D3-9A73-0000F81EF32E}",
            "BMP", "{557CF400-1A04-11D3-9A73-0000F81EF32E}",
            "GIF", "{557CF402-1A04-11D3-9A73-0000F81EF32E}"
        )

        format := StrUpper(format)
        if !encoders.Has(format)
            format := "PNG"

        CLSID := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", encoders[format], "Ptr", CLSID)

        ; 对于 JPEG，可以设置质量参数
        if (format = "JPEG" || format = "JPG") {
            ; 创建编码参数
            ; 这里简化处理，不设置质量参数
        }

        result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filePath, "Ptr", CLSID, "Ptr", 0)
        return result = 0
    }

    ; -------------------------------------------------
    ; CopyToClipboard - 复制位图到剪贴板
    ; -------------------------------------------------
    static CopyToClipboard(pBitmap) {
        if !pBitmap
            return false

        ; 获取图片尺寸
        width := 0, height := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &width)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &height)

        if (!width || !height)
            return false

        ; 创建兼容 DC
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
        hOldBmp := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

        ; 创建 GDI+ Graphics 并绘制
        pGraphics := 0
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
        DllCall("gdiplus\GdipDrawImageI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", 0, "Int", 0)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)

        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBmp)

        ; 复制到剪贴板
        success := false
        if DllCall("OpenClipboard", "Ptr", 0) {
            DllCall("EmptyClipboard")
            if DllCall("SetClipboardData", "UInt", 2, "Ptr", hBitmap)  ; CF_BITMAP = 2
                success := true
            else
                DllCall("DeleteObject", "Ptr", hBitmap)
            DllCall("CloseClipboard")
        } else {
            DllCall("DeleteObject", "Ptr", hBitmap)
        }

        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

        return success
    }

    ; -------------------------------------------------
    ; DisposeImage - 释放图片资源
    ; -------------------------------------------------
    static DisposeImage(pBitmap) {
        if pBitmap
            DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    }

    ; -------------------------------------------------
    ; GetImageSize - 获取图片尺寸
    ; 返回: {width, height}
    ; -------------------------------------------------
    static GetImageSize(pBitmap) {
        if !pBitmap
            return { width: 0, height: 0 }

        width := 0, height := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &width)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &height)

        return { width: width, height: height }
    }

    ; -------------------------------------------------
    ; CreateGraphics - 从 HDC 创建 Graphics
    ; -------------------------------------------------
    static CreateGraphics(hdc) {
        pGraphics := 0
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &pGraphics)
        return pGraphics
    }

    ; -------------------------------------------------
    ; DeleteGraphics - 删除 Graphics
    ; -------------------------------------------------
    static DeleteGraphics(pGraphics) {
        if pGraphics
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    }

    ; -------------------------------------------------
    ; DrawImage - 绘制图片
    ; -------------------------------------------------
    static DrawImage(pGraphics, pBitmap, x, y, w := 0, h := 0) {
        if (!pGraphics || !pBitmap)
            return false

        if (w = 0 || h = 0)
            DllCall("gdiplus\GdipDrawImageI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", x, "Int", y)
        else
            DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", x, "Int", y, "Int", w, "Int",
                h)

        return true
    }
}

; -------------------------------------------------
; 🖱️ 光标操作类
; -------------------------------------------------
class Cursor {
    static _savedCursors := Map()

    ; 光标 ID 常量
    static IDC_ARROW := 32512
    static IDC_IBEAM := 32513
    static IDC_WAIT := 32514
    static IDC_CROSS := 32515
    static IDC_UPARROW := 32516
    static IDC_SIZE := 32640
    static IDC_ICON := 32641
    static IDC_SIZENWSE := 32642
    static IDC_SIZENESW := 32643
    static IDC_SIZEWE := 32644
    static IDC_SIZENS := 32645
    static IDC_SIZEALL := 32646
    static IDC_NO := 32648
    static IDC_HAND := 32649
    static IDC_APPSTARTING := 32650
    static IDC_HELP := 32651

    ; 需要设置的系统光标列表
    static _allCursors := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650,
        32651]

    ; -------------------------------------------------
    ; SetCross - 设置十字准星光标
    ; -------------------------------------------------
    static SetCross() {
        this._SetAll(this.IDC_CROSS)
    }

    ; -------------------------------------------------
    ; SetWait - 设置等待光标
    ; -------------------------------------------------
    static SetWait() {
        this._SetAll(this.IDC_WAIT)
    }

    ; -------------------------------------------------
    ; SetHand - 设置手形光标
    ; -------------------------------------------------
    static SetHand() {
        this._SetAll(this.IDC_HAND)
    }

    ; -------------------------------------------------
    ; Restore - 恢复系统默认光标
    ; -------------------------------------------------
    static Restore() {
        ; SPI_SETCURSORS = 0x57
        DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)
    }

    ; -------------------------------------------------
    ; 私有方法：设置所有系统光标
    ; -------------------------------------------------
    static _SetAll(cursorId) {
        cursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", cursorId, "Ptr")
        if !cursor
            return

        for id in this._allCursors {
            cursorCopy := DllCall("CopyImage", "Ptr", cursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
            if cursorCopy
                DllCall("SetSystemCursor", "Ptr", cursorCopy, "UInt", id)
        }
    }
}

; -------------------------------------------------
; 🎨 颜色转换工具类
; -------------------------------------------------
class ColorUtils {
    ; -------------------------------------------------
    ; BGRToRGB - BGR 转 RGB
    ; -------------------------------------------------
    static BGRToRGB(bgr) {
        b := (bgr >> 16) & 0xFF
        g := (bgr >> 8) & 0xFF
        r := bgr & 0xFF
        return (r << 16) | (g << 8) | b
    }

    ; -------------------------------------------------
    ; RGBToBGR - RGB 转 BGR
    ; -------------------------------------------------
    static RGBToBGR(rgb) {
        r := (rgb >> 16) & 0xFF
        g := (rgb >> 8) & 0xFF
        b := rgb & 0xFF
        return (b << 16) | (g << 8) | r
    }

    ; -------------------------------------------------
    ; ToHex - 转换为 HEX 字符串
    ; -------------------------------------------------
    static ToHex(color, includeHash := true) {
        hex := Format("{:06X}", color)
        return includeHash ? "#" hex : hex
    }

    ; -------------------------------------------------
    ; ToRGBString - 转换为 RGB 字符串
    ; -------------------------------------------------
    static ToRGBString(color) {
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF
        return "RGB(" r ", " g ", " b ")"
    }

    ; -------------------------------------------------
    ; ToHSL - 转换为 HSL
    ; 返回: {h, s, l}
    ; -------------------------------------------------
    static ToHSL(color) {
        r := ((color >> 16) & 0xFF) / 255
        g := ((color >> 8) & 0xFF) / 255
        b := (color & 0xFF) / 255

        max := Max(r, g, b)
        min := Min(r, g, b)
        l := (max + min) / 2

        if (max = min) {
            h := s := 0
        } else {
            d := max - min
            s := l > 0.5 ? d / (2 - max - min) : d / (max + min)

            if (max = r)
                h := (g - b) / d + (g < b ? 6 : 0)
            else if (max = g)
                h := (b - r) / d + 2
            else
                h := (r - g) / d + 4

            h /= 6
        }

        return {
            h: Round(h * 360),
            s: Round(s * 100),
            l: Round(l * 100)
        }
    }

    ; -------------------------------------------------
    ; ToHSLString - 转换为 HSL 字符串
    ; -------------------------------------------------
    static ToHSLString(color) {
        hsl := this.ToHSL(color)
        return "HSL(" hsl.h "°, " hsl.s "%, " hsl.l "%)"
    }

    ; -------------------------------------------------
    ; RGBToHSLString - 从 RGB 分量转换为 HSL 字符串
    ; -------------------------------------------------
    static RGBToHSLString(r, g, b) {
        color := (r << 16) | (g << 8) | b
        return this.ToHSLString(color)
    }

    ; -------------------------------------------------
    ; FromHex - 从 HEX 字符串解析
    ; -------------------------------------------------
    static FromHex(hex) {
        hex := StrReplace(hex, "#", "")
        return Integer("0x" hex)
    }

    ; -------------------------------------------------
    ; GetComponents - 获取颜色分量
    ; 返回: {r, g, b}
    ; -------------------------------------------------
    static GetComponents(color) {
        return {
            r: (color >> 16) & 0xFF,
            g: (color >> 8) & 0xFF,
            b: color & 0xFF
        }
    }
}
