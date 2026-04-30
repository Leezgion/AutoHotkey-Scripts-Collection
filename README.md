# 🎛️ AutoHotkey Script Manager

<div align="center">

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-green?logo=autohotkey)
![Platform](https://img.shields.io/badge/Platform-Windows-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-yellow)

**[English](#english)** | **[中文](#中文)**

</div>

---

<a name="english"></a>

## 🌐 English

A modular AutoHotkey v2 script management system with centralized control, featuring color picker, screenshot floating, and window pinning tools.

### ✨ Features

- 🎨 **Color Picker** - Screen color picking with magnifier, multiple formats (HEX/RGB/HSL), color history
- 📸 **Screenshot Float** - Region capture with draggable floating windows, zoom, transparency control
- 📌 **Window Pin** - Pin any window always-on-top with colorful border indicators
- 🌍 **i18n Support** - Multi-language interface (English/Chinese)
- ⚙️ **Settings Panel** - GUI-based configuration management
- 🔧 **Module System** - Enable/disable individual features as needed

### 📁 Project Structure

```
AutoHotkey/
├── ScriptManager.ahk           # 🚀 Main entry point
├── ColorPicker.ahk             # 🎨 Standalone color picker
├── ScreenshotFloat.ahk         # 📸 Standalone screenshot tool
├── WindowPin.ahk               # 📌 Standalone window pin tool
│
├── Modules/                    # 📦 Core modules
│   ├── ColorPicker/
│   │   ├── Picker.ahk          # Main color picker logic
│   │   ├── Magnifier.ahk       # Magnifier component
│   │   ├── History.ahk         # Color history panel
│   │   └── Converter.ahk       # Color format converter
│   ├── Screenshot/
│   │   ├── Capture.ahk         # Screen capture logic
│   │   ├── Selection.ahk       # Region selection UI
│   │   └── FloatWindow.ahk     # Floating window manager
│   └── PinWindow/
│       ├── Pin.ahk             # Window pinning logic
│       └── Border.ahk          # Border drawing component
│
├── GUI/                        # 🖼️ GUI components
│   ├── SettingsWindow.ahk      # Settings dialog
│   └── AboutDialog.ahk         # About dialog
│
├── Lib/                        # 📚 Shared libraries
│   ├── Constants.ahk           # Global constants & defaults
│   ├── ConfigManager.ahk       # INI configuration handler
│   ├── I18n.ahk                # Internationalization system
│   ├── Logger.ahk              # Logging utility
│   ├── GDIPlus.ahk             # GDI+ wrapper
│   ├── StateMachine.ahk        # State machine base class
│   ├── Theme.ahk               # UI theme definitions
│   ├── Utils.ahk               # Common utilities
│   └── ...
│
├── Lang/                       # 🌍 Language files
│   ├── en-US.ahk               # English translations
│   └── zh-CN.ahk               # Chinese translations
│
├── Config/                     # ⚙️ Configuration files
│   ├── settings.ini            # Application settings
│   └── hotkeys.ini             # Hotkey mappings
│
└── Screenshots/                # 📷 Screenshot output folder
```

### 🚀 Quick Start

1. **Requirements**
   - Windows 10/11
   - [AutoHotkey v2.0+](https://www.autohotkey.com/)

2. **Run**

   ```
   Double-click ScriptManager.ahk
   ```

3. **Access via Tray**
   - Right-click tray icon for quick actions
   - Double-click to start color picker (default)

### ⌨️ Hotkeys

Hotkeys are configured in `Config/hotkeys.ini` (source of truth). Defaults below come from that file and can be changed.

| Hotkey | Function |
|--------|----------|
| `Alt + C` | 🎨 Start color picker |
| `Alt + S` | 📸 Start screenshot |
| `Alt + T` | 📌 Toggle pin current window |
| `Alt + Shift + T` | Unpin all windows |
| `Alt + Shift + C` | Change border color |
| `Ctrl + Alt + A` | Close all floating screenshots |
| `Alt + ,` | Open settings |
| `Alt + Q` | Exit |

### 🎨 Color Picker Usage

- **Left Click** - Copy color to clipboard
- **Right Click** - Switch color format (HEX → RGB → HSL)
- **Scroll Wheel** - Adjust magnification (2x - 20x)
- **ESC** - Cancel picking

### 📸 Screenshot Usage

- **Drag** - Select region to capture
- **ESC** - Cancel selection
- On floating window:
  - **Drag** - Move window
  - **Scroll** - Zoom in/out
  - **Ctrl + Scroll** - Adjust transparency
  - **Ctrl + C** - Copy to clipboard
  - **Ctrl + S** - Save to file
  - **Right Click / ESC** - Close window

### 📌 Window Pin Usage

- Pinned windows get colorful borders (10 colors available)
- Hotkeys can be customized in `Config/hotkeys.ini`

---

<a name="中文"></a>

## 🌐 中文

一个模块化的 AutoHotkey v2 脚本管理系统，集成屏幕取色、截图悬浮、窗口置顶等实用工具。

### ✨ 功能特点

- 🎨 **屏幕取色** - 放大镜取色，支持 HEX/RGB/HSL 多格式，颜色历史记录
- 📸 **截图悬浮** - 区域截图，可拖动悬浮窗，支持缩放与透明度调节
- 📌 **窗口置顶** - 任意窗口置顶，彩色边框标识
- 🌍 **多语言** - 支持中英文界面切换
- ⚙️ **设置面板** - 图形化配置管理
- 🔧 **模块系统** - 按需启用/禁用功能模块

### 📁 项目结构

```
AutoHotkey/
├── ScriptManager.ahk           # 🚀 主入口
├── ColorPicker.ahk             # 🎨 独立取色工具
├── ScreenshotFloat.ahk         # 📸 独立截图工具  
├── WindowPin.ahk               # 📌 独立置顶工具
│
├── Modules/                    # 📦 核心模块
│   ├── ColorPicker/            # 取色器模块
│   ├── Screenshot/             # 截图模块
│   └── PinWindow/              # 置顶模块
│
├── GUI/                        # 🖼️ GUI 组件
│   ├── SettingsWindow.ahk      # 设置窗口
│   └── AboutDialog.ahk         # 关于对话框
│
├── Lib/                        # 📚 公共库
│   ├── Constants.ahk           # 全局常量
│   ├── ConfigManager.ahk       # 配置管理器
│   ├── I18n.ahk                # 国际化系统
│   └── ...                     # 其他工具库
│
├── Lang/                       # 🌍 语言文件
│   ├── en-US.ahk               # 英文
│   └── zh-CN.ahk               # 中文
│
├── Config/                     # ⚙️ 配置文件
│   ├── settings.ini            # 应用设置
│   └── hotkeys.ini             # 快捷键配置
│
└── Screenshots/                # 📷 截图保存目录
```

### 🚀 快速开始

1. **系统要求**
   - Windows 10/11
   - [AutoHotkey v2.0+](https://www.autohotkey.com/)

2. **运行**

   ```
   双击 ScriptManager.ahk
   ```

3. **托盘菜单**
   - 右键点击托盘图标访问快捷功能
   - 双击托盘图标启动取色器（默认）

### ⌨️ 快捷键

快捷键以 `Config/hotkeys.ini` 为准（唯一配置来源）。下表默认值来自该文件，均可修改。

| 快捷键 | 功能 |
|--------|------|
| `Alt + C` | 🎨 开始取色 |
| `Alt + S` | 📸 开始截图 |
| `Alt + T` | 📌 切换当前窗口置顶 |
| `Alt + Shift + T` | 取消所有置顶 |
| `Alt + Shift + C` | 更改边框颜色 |
| `Ctrl + Alt + A` | 关闭所有悬浮截图 |
| `Alt + ,` | 打开设置 |
| `Alt + Q` | 退出 |

### 🎨 取色器操作

- **左键点击** - 复制颜色到剪贴板
- **右键点击** - 切换颜色格式（HEX → RGB → HSL）
- **滚轮** - 调整放大倍数（2x - 20x）
- **ESC** - 取消取色

### 📸 截图操作

- **拖动** - 选择截图区域
- **ESC** - 取消选择
- 悬浮窗内：
  - **拖动** - 移动窗口
  - **滚轮** - 缩放大小
  - **Ctrl + 滚轮** - 调整透明度
  - **Ctrl + C** - 复制到剪贴板
  - **Ctrl + S** - 保存到文件
  - **右键 / ESC** - 关闭窗口

### 📌 置顶操作

- 置顶窗口会显示彩色边框（10种颜色自动分配）
- 可在 `Config/hotkeys.ini` 自定义快捷键

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Issues and Pull Requests are welcome!

---

<div align="center">
Made with ❤️ using AutoHotkey v2
</div>
