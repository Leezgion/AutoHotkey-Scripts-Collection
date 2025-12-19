; =================================================
; 🎨 ColorPicker/Converter.ahk - 颜色转换工具
; =================================================

class ColorConverter {
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
    ; GetComponents - 获取 RGB 分量
    ; -------------------------------------------------
    static GetComponents(color) {
        return {
            r: (color >> 16) & 0xFF,
            g: (color >> 8) & 0xFF,
            b: color & 0xFF
        }
    }

    ; -------------------------------------------------
    ; ToHex - 转换为 HEX 字符串
    ; -------------------------------------------------
    static ToHex(color, includeHash := true) {
        c := this.GetComponents(color)
        hex := Format("{:02X}{:02X}{:02X}", c.r, c.g, c.b)
        return includeHash ? "#" hex : hex
    }

    ; -------------------------------------------------
    ; ToRGBString - 转换为 RGB 字符串
    ; -------------------------------------------------
    static ToRGBString(color) {
        c := this.GetComponents(color)
        return Format("RGB({}, {}, {})", c.r, c.g, c.b)
    }

    ; -------------------------------------------------
    ; ToHSL - 转换为 HSL 对象
    ; -------------------------------------------------
    static ToHSL(color) {
        c := this.GetComponents(color)
        r := c.r / 255
        g := c.g / 255
        b := c.b / 255

        maxVal := Max(r, g, b)
        minVal := Min(r, g, b)
        l := (maxVal + minVal) / 2

        if (maxVal = minVal) {
            h := s := 0
        } else {
            d := maxVal - minVal
            s := l > 0.5 ? d / (2 - maxVal - minVal) : d / (maxVal + minVal)

            if (maxVal = r)
                h := (g - b) / d + (g < b ? 6 : 0)
            else if (maxVal = g)
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
        return Format("HSL({}°, {}%, {}%)", hsl.h, hsl.s, hsl.l)
    }

    ; -------------------------------------------------
    ; FromHex - 从 HEX 字符串解析
    ; -------------------------------------------------
    static FromHex(hex) {
        hex := StrReplace(hex, "#", "")
        return Integer("0x" hex)
    }

    ; -------------------------------------------------
    ; FromRGB - 从 RGB 分量构建
    ; -------------------------------------------------
    static FromRGB(r, g, b) {
        return (r << 16) | (g << 8) | b
    }

    ; -------------------------------------------------
    ; GetFormatted - 获取指定格式的颜色字符串
    ; -------------------------------------------------
    static GetFormatted(color, format) {
        switch format {
            case "HEX":
                return this.ToHex(color)
            case "RGB":
                return this.ToRGBString(color)
            case "HSL":
                return this.ToHSLString(color)
            default:
                return this.ToHex(color)
        }
    }
}
