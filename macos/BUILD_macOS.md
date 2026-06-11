# macOS 客户端打包指南（M 芯片 / Intel）

> ⚠️ **必须在 macOS 上编译**。Windows/Linux 无法产出 `.app`/`.dmg`（Flutter macOS 构建依赖 Xcode/clang、CocoaPods）。本仓库已把 macOS 平台层（图标、显示名、dmg 标题、版本号）和共享业务逻辑都准备好，到 Mac 上"两条命令出双架构包"。

## 已就绪（无需再改）
- **应用内全部界面** —— SSPanel 登录/订阅/流量/隐藏注册商城余额/智能分流·全局/品牌名，全在共享 `lib/`，macOS 自动复用（同安卓）。
- **品牌外观** —— Dock/访达显示名 `美国华人华侨贸易中心`（Info.plist `CFBundleDisplayName`）、App 图标（`Assets.xcassets/AppIcon.appiconset`，从 logo 生成）、dmg 卷名（`packaging/dmg/make_config.yaml`）。
- **版本号** —— `pubspec.yaml` 已设 `1.0.0`。
- 包标识 `com.follow.clash`、可执行名 `FlClash`（与 dmg 配置里的 `FlClash.app` 对应，勿改）。

## 前置依赖（在 Mac 上装一次）
1. **Xcode** + 命令行工具：`xcode-select --install`
2. **Flutter SDK**（与本项目一致，3.44.x）：`flutter doctor` 全绿
3. **Go**（编译内核 `FlClashCore`，darwin 用 `CGO_ENABLED=0` 纯 Go 交叉编译，无需额外 C 工具链）
4. **CocoaPods**：`sudo gem install cocoapods`
5. **Node + appdmg**（打 dmg）：`npm install -g appdmg`
6. 内核子模块：确保 `core/Clash.Meta` 存在（本仓库已扁平化包含）

> 不需要 Apple 开发者账号也能本地出 dmg；但要**对外分发免"已损坏/无法验证"提示**，需开发者账号做**代码签名 + 公证(notarization)**，见末尾。

## 打包（两条命令，分别出 M / Intel）
在 `source/` 目录：

```bash
flutter pub get

# M 芯片（Apple Silicon, arm64）
dart setup.dart macos --arch arm64 --env pre

# Intel（x86_64 / amd64）
dart setup.dart macos --arch amd64 --env pre
```

每条会：① 用 Go 编译对应架构的 `FlClashCore` → ② `flutter_distributor` 打出 `dmg`。产物在 `source/dist/`。
> 两次会先后生成 dmg，**第二次前先把第一次的 dmg 改名移走**，免得被覆盖（或直接用下面的脚本）。

也可以用便捷脚本（自动改名到 `out/`）：
```bash
bash build_macos.sh
```
产出：
- `out/美国华人华侨贸易中心_v1.0_macOS_AppleSilicon.dmg`（M 芯片）
- `out/美国华人华侨贸易中心_v1.0_macOS_Intel.dmg`（Intel）

> 想要"一个 dmg 通吃两种芯片"（universal）需把两架构 `FlClashCore` 和 .app 用 `lipo` 合并，较繁琐；按用户要求这里是**分架构两个包**。

## 签名 / 公证（对外分发才需要）
```bash
# 用开发者证书签名（含内核与 helper 等所有可执行）
codesign --deep --force --options runtime \
  --sign "Developer ID Application: <你的名字> (TEAMID)" \
  "dist/美国华人华侨贸易中心.app"     # 实际为 FlClash.app
# 公证
xcrun notarytool submit <dmg> --apple-id <id> --team-id <TEAMID> --password <app-专用密码> --wait
xcrun stapler staple <dmg>
```
未签名包本地可用：右键「打开」或 `xattr -dr com.apple.quarantine <App>` 即可绕过 Gatekeeper（自用/内测足够）。

## 资源重生成（改了 logo 时）
```bash
cd installer
python make_macos_icon.py   # 重生成 macOS App 图标
```
