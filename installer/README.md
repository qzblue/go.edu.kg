# Windows 安装包打包

用 [Inno Setup 6](https://jrsoftware.org/isdl.php) 把 `flutter build windows` 的产物打成单文件安装程序（简体中文向导、品牌外观、默认装 D 盘可改、自动建桌面+开始菜单快捷方式、带卸载程序）。

## 打包步骤

1. 先构建 Release 产物（在 `source/` 下）：
   ```
   flutter build windows --release --dart-define-from-file=env.json
   ```
   产物在 `source/build/windows/x64/runner/Release/`。

2. 安装 Inno Setup 6（`winget install JRSoftware.InnoSetup`）。

3. 在本目录编译：
   ```
   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" FlClash.iss
   ```
   输出：`dist\美国华人华侨贸易中心_v1.0_安装包.exe`。

> 改版本号：编辑 `FlClash.iss` 顶部的 `MyAppVersion` 与 `VersionInfoVersion`。

## 目录内容

- `FlClash.iss` —— Inno Setup 脚本（UTF-8 BOM，相对路径）。
- `ChineseSimplified.isl` —— 简体中文向导语言包（Inno 官方未内置，需随包）。
- `wizard_large*.bmp` / `wizard_small*.bmp` —— 品牌向导横幅图（深蓝底+logo，含 @2x 高分屏）。
- `make_wizard_images.py` —— 从 `../assets/images/icon.png` 重新生成上面的 bmp。
- `make_tray_icons.py` —— 从 go.edu.kg logo 重新生成系统托盘图标 `../assets/images/icon/status_1/2/3.{ico,png}`。
- `dist/` —— 编译输出（已在 .gitignore 忽略，不入库）。

依赖：`pip install pillow`（两个 py 脚本用）。
