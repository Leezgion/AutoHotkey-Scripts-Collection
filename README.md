# 🎛️ AutoHotkey Scripts Collection

<div align="center">

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-green?logo=autohotkey)
![Platform](https://img.shields.io/badge/Platform-Windows-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-yellow)

**[English](#english)** | **[中文](#中文)**

</div>

---

<a name="english"></a>

## 🌐 English

A collection of useful AutoHotkey v2 scripts to enhance your Windows productivity, featuring a centralized script manager.

### 📁 Project Structure

```
AutoHotkey/
├── 📜 ScriptManager.ahk       # Central script manager
├── 📌 置顶窗口.ahk            # Window pin tool with colored borders
├── 📸 截图悬浮.ahk            # Screenshot floating tool
├── 📁 Lib/                    # Modular library
│   ├── Utils.ahk              # Utility functions
│   ├── ScriptCore.ahk         # Script control core
│   ├── AutoStart.ahk          # Auto-start management
│   └── TrayMenu.ahk           # Tray menu module
└── 📄 README.md
```

### 📋 Scripts

#### 1. 🎛️ Script Manager (ScriptManager.ahk)

A centralized management tool for all your AutoHotkey scripts.

**Features:**

- 📜 Start/Stop/Reload individual scripts via tray menu
- 🚀 Manage auto-start settings for each script
- 🖥️ Manager auto-start option (start manager on Windows boot)
- 📌 Integrated window pin controls (when pin script is running)
- 📸 Integrated screenshot controls (when screenshot script is running)
- 🔄 Batch operations: Start All / Stop All / Reload All
- 📊 Real-time status display in tray menu
- 🎯 Single tray icon for all managed scripts

**Hotkeys:**

| Hotkey | Function |
|--------|----------|
| `Win + Alt + A` | Start all scripts |
| `Win + Alt + S` | Stop all scripts |
| `Win + Alt + R` | Reload all scripts |

---

#### 2. 📌 Window Pin Tool (置顶窗口.ahk)

Pin any window to stay always on top with a colorful visual border indicator.

**Features:**

- 📌 Pin any window to stay always on top
- 🌈 10 different border colors, auto-assigned per window
- ✨ Flash animation when pinning
- 🔊 Sound feedback (can be disabled)
- 🖥️ Support for multiple pinned windows
- ⚡ Ultra-low latency border tracking (10ms refresh)
- 🪟 Smart handling of minimized windows
- 🎯 No tray icon (managed by Script Manager)

**Hotkeys:**

| Hotkey | Function |
|--------|----------|
| `CapsLock + Space` | Toggle pin for current window |
| `CapsLock + Esc` | Unpin ALL windows |
| `CapsLock + Tab` | Cycle through pinned windows |
| `CapsLock + C` | Change border color of current window |

**Available Border Colors:**
🟢 Green · 🔴 Coral Red · 🔵 Cyan · 🟡 Gold · 🟢 Mint · 🩷 Pink · 🟣 Lavender · 🔵 Teal · 🟠 Orange · 🔵 Sky Blue

---

#### 3. 📸 Screenshot Floating Tool (截图悬浮.ahk)

Capture screen regions and display as floating windows, similar to Snipaste.

**Features:**

- 📸 Region selection with crosshair cursor
- 🖼️ Auto-floating display after capture
- 🔝 Always on top floating windows
- 🖱️ Drag to move floating screenshots
- 🔍 Scroll wheel to zoom in/out
- 🌫️ Ctrl + scroll to adjust transparency
- 📋 Copy screenshot to clipboard
- 💾 Save screenshot to file
- 🪟 Support multiple floating windows simultaneously
- 🎯 No tray icon (managed by Script Manager)

**Hotkeys:**

| Hotkey | Function |
|--------|----------|
| `Win + Shift + S` | Start screenshot (region selection) |
| `Escape` | Cancel screenshot / Close focused floating window |
| `Win + Shift + Q` | Close ALL floating windows |

**Floating Window Controls (when window is focused):**

| Action | Function |
|--------|----------|
| Left-click drag | Move window |
| Scroll wheel | Zoom in/out |
| `Ctrl` + Scroll | Adjust transparency |
| Right-click | Close current floating window |
| `Ctrl + C` | Copy to clipboard |
| `Ctrl + S` | Save to file |

---

### 🚀 Getting Started

1. **Install AutoHotkey v2.0**
   - Download from [AutoHotkey.com](https://www.autohotkey.com/)
   - Choose **v2.0** (required)

2. **Download Scripts**

   ```bash
   git clone https://github.com/yourusername/AutoHotkey.git
   ```

3. **Run Script Manager**
   - Double-click `ScriptManager.ahk`
   - Right-click tray icon to manage all scripts

4. **Set Auto-Start (Optional)**
   - Right-click tray icon → "开机自启动" → Enable desired scripts
   - Right-click tray icon → "管理器开机自启" → Enable manager auto-start

### 📝 Requirements

- Windows 10/11
- AutoHotkey **v2.0** or later

---

<a name="中文"></a>

## 🌐 中文

一个实用的 AutoHotkey v2 脚本合集，提升你的 Windows 使用效率，配备集中式脚本管理器。

### 📁 项目结构

```
AutoHotkey/
├── 📜 ScriptManager.ahk       # 集中管理工具
├── 📌 置顶窗口.ahk            # 窗口置顶工具（彩色边框）
├── 📸 截图悬浮.ahk            # 截图悬浮工具
├── 📁 Lib/                    # 模块化代码库
│   ├── Utils.ahk              # 通用工具函数
│   ├── ScriptCore.ahk         # 脚本控制核心
│   ├── AutoStart.ahk          # 开机自启管理
│   └── TrayMenu.ahk           # 托盘菜单模块
└── 📄 README.md
```

### 📋 脚本列表

#### 1. 🎛️ 脚本管理器 (ScriptManager.ahk)

统一管理所有 AutoHotkey 脚本的集中控制工具。

**功能特点：**

- 📜 通过托盘菜单启动/停止/重载单个脚本
- 🚀 管理每个脚本的开机自启动设置
- 🖥️ 管理器开机自启选项（Windows 启动时自动运行管理器）
- 📌 集成置顶窗口控制（当置顶脚本运行时显示）
- 📸 集成截图悬浮控制（当截图脚本运行时显示）
- 🔄 批量操作：全部启动 / 全部停止 / 全部重载
- 📊 托盘菜单实时显示运行状态
- 🎯 所有脚本共用一个托盘图标

**快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `Win + Alt + A` | 启动所有脚本 |
| `Win + Alt + S` | 停止所有脚本 |
| `Win + Alt + R` | 重载所有脚本 |

---

#### 2. 📌 置顶窗口工具 (置顶窗口.ahk)

将任意窗口置顶显示，并用彩色边框标识。

**功能特点：**

- 📌 将任意窗口置顶显示
- 🌈 10种不同边框颜色，每个窗口自动分配
- ✨ 置顶时边框闪烁动画
- 🔊 声音反馈（可关闭）
- 🖥️ 支持同时置顶多个窗口
- ⚡ 超低延迟边框跟踪（10ms 刷新率）
- 🪟 智能处理最小化窗口
- 🎯 无托盘图标（由脚本管理器统一管理）

**快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `CapsLock + Space` | 切换当前窗口置顶状态 |
| `CapsLock + Esc` | 取消所有窗口置顶 |
| `CapsLock + Tab` | 在置顶窗口间循环切换 |
| `CapsLock + C` | 更换当前窗口边框颜色 |

**可用边框颜色：**
🟢 绿色 · 🔴 珊瑚红 · 🔵 青色 · 🟡 金黄 · 🟢 薄荷绿 · 🩷 粉红 · 🟣 淡紫 · 🔵 蓝绿 · 🟠 橙色 · 🔵 天蓝

---

#### 3. 📸 截图悬浮工具 (截图悬浮.ahk)

框选屏幕区域截图并悬浮显示，类似 Snipaste 功能。

**功能特点：**

- 📸 十字准星区域选择
- 🖼️ 截图后自动悬浮显示
- 🔝 悬浮窗始终置顶
- 🖱️ 拖动移动悬浮窗位置
- 🔍 滚轮缩放截图大小
- 🌫️ Ctrl+滚轮调节透明度
- 📋 复制截图到剪贴板
- 💾 保存截图到文件
- 🪟 支持同时显示多个悬浮截图
- 🎯 无托盘图标（由脚本管理器统一管理）

**快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `Win + Shift + S` | 开始截图（区域选择）|
| `Escape` | 取消截图 / 关闭当前悬浮窗 |
| `Win + Shift + Q` | 关闭所有悬浮窗 |

**悬浮窗操作（窗口激活时）：**

| 操作 | 功能 |
|------|------|
| 左键拖动 | 移动窗口 |
| 滚轮 | 缩放大小 |
| `Ctrl` + 滚轮 | 调节透明度 |
| 右键 | 关闭当前悬浮窗 |
| `Ctrl + C` | 复制到剪贴板 |
| `Ctrl + S` | 保存到文件 |

---

### 🚀 快速开始

1. **安装 AutoHotkey v2.0**
   - 从 [AutoHotkey.com](https://www.autohotkey.com/) 下载
   - 选择 **v2.0** 版本（必需）

2. **下载脚本**

   ```bash
   git clone https://github.com/yourusername/AutoHotkey.git
   ```

3. **运行脚本管理器**
   - 双击 `ScriptManager.ahk`
   - 右键托盘图标管理所有脚本

4. **设置开机自启（可选）**
   - 右键托盘图标 → "开机自启动" → 启用需要的脚本
   - 右键托盘图标 → "管理器开机自启" → 启用管理器自启动

### 📝 系统要求

- Windows 10/11
- AutoHotkey **v2.0** 或更高版本

---

## 🔧 Adding New Scripts / 添加新脚本

To add a new script to be managed:

1. Place your `.ahk` file in the root directory
2. Add `#NoTrayIcon` at the top to hide its tray icon
3. Restart Script Manager to detect the new script

添加新脚本到管理器：

1. 将 `.ahk` 文件放到根目录
2. 在脚本开头添加 `#NoTrayIcon` 隐藏托盘图标
3. 重启脚本管理器以检测新脚本

---

## 📄 License / 许可证

MIT License

## 🤝 Contributing / 贡献

Feel free to submit issues and pull requests!

欢迎提交 Issue 和 Pull Request！
