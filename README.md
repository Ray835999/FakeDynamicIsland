# Fake Dynamic Island (A9 / iOS 15)

一个**自绘式假灵动岛**越狱插件，专门给 **iPhone 6s（A9）/ iOS 15.x（rootless palera1n）** 用。
在锁屏 / 主屏 / App 上方画一个黑色药丸，模拟灵动岛的几个核心事件，并可在「设置」里调参数。

## 为什么不是 DynamicCow

DynamicCow 是 **MacDirtyCow 漏洞应用**，它通过改写系统文件
`com.apple.MobileGestalt.plist` 的 `deviceSubType`，让 **iOS 16 本来就有的** 灵动岛渲染层
（`SBDynamicIsland` 等）以为自己跑在 iPhone 14 Pro 上。它的仓库明确写明：

> iOS 15/14/13 are NOT and will never be supported ... it can bootloop your device.

也就是说：

- iOS 16 能用，是因为系统里**本来就有**灵动岛渲染代码，只是被能力位关掉；DynamicCow 把能力位打开。
- **iOS 15 系统里根本没有这套渲染代码**，打开能力位也没东西可画。
- 它改的是系统文件 —— 这正是 **白苹果（开机卡苹果标）** 的成因。在 iOS 15 上跑 DynamicCow 既无效又危险。

所以「让 DynamicCow 兼容 iOS 15」这条路**走不通且危险**。本插件改用「自己画一个药丸」的方案
（和越狱界的 Island / DynamicPeninsula 同一思路），这是 iOS 15 上唯一安全可行的办法。

## 为什么说它「不会白苹果」

- 只往 **SpringBoard** 注入（`filter: com.apple.springboard`）。
- 只创建一个 **UIWindow**（顶层、纯绘制、`userInteractionEnabled = NO`）—— 不接收任何触摸，
  因此绝不会挡住操作或搞坏 UI。
- **不修改任何系统文件、不碰 MobileGestalt、不在开机路径上 hook 任何东西**。
- 最坏情况只是 SpringBoard 运行时崩溃 → 进 palera1n **安全模式**（重启用音量下键），
  在 Sileo/Filza 里卸载即可。**不会卡开机**。

## 功能

- 顶部居中的黑色药丸（尺寸 / 圆角 / 顶部偏移可调）。
- 事件（均可在设置里开关）：
  - **App 启动**：打开 App 时药丸短暂展开（"Opening <App>"）。
  - **正在播放**：音乐 / 音频播放时显示曲目 — 艺人（♪）。
  - **充电**：充电时显示 "Charging NN%"。
  - **低电量模式**：开启时提示。
- 设置（设置 → Fake Dynamic Island）里可调：开关、药丸宽/高/圆角/顶部偏移、各事件开关、动画开关。

## 已知限制

- iPhone 6s 没有刘海，药丸画在**顶部居中**（可借 Top Offset 微调位置）。
- 假岛是纯视觉模拟，不像 iOS 16 原生岛那样能随 App 深度适配 / 长按展开交互（那是系统级渲染）。
  本版药丸**不接收触摸**，避免破坏操作；可交互展开留待后续版本。
- 若发现药丸在 App 内不显示（极个别系统窗口层级差异），告诉我，我可以抬高层级或换实现。

## 安装

**首次安装 / 重装必须注销（respring）一次** 才能让 dylib 加载进 SpringBoard：

```bash
dpkg -i com.you.fakedi_1.0.1-1_iphoneos-arm64.deb
killall -9 SpringBoard
```

> 注意：「设置里改外观参数即时生效、不用注销」指的是**已加载后的外观微调**；
> 但插件本体（dylib）要进 SpringBoard 必须注销一次。Sileo 装完若没自动注销，请手动 killall SpringBoard。

或卸载：

```bash
dpkg -r com.you.fakedi
killall -9 SpringBoard
```

需要先装 **PreferenceLoader**（设置面板依赖它）。

## 如果注销后卡死（v1.0.0 的已知问题，v1.0.1 已修）

v1.0.0 在 `%ctor`（SpringBoard 启动最脆弱阶段）就同步创建并显示顶层 UIWindow，
在 iOS 15 上会死锁导致**注销后卡死/冻屏**。v1.0.1 已把窗口创建推迟到
`UIApplicationDidFinishLaunchingNotification`（SpringBoard 真正启动完成）之后再执行，
并加了 3 秒兜底定时器，不会再卡。

若你正卡着：Home+电源键强制重启 → 重新 palera1n 引导时**按住音量下**进安全模式 →
Sileo 卸载 `com.you.fakedi` → 正常重启，再用上面的 v1.0.1 命令重装。

## 怎么验证（不用终端）

用 **Filza** 打开 `/var/mobile/Documents/FakeDynamicIsland.log`，应能看到：

- `[FakeDI] ctor SpringBoard iOS 15.8.8`
- `[FakeDI] init done enabled=1`
- `[FakeDI] window created level=1010`
- 调节设置 / 触发事件时会有 `prefs ...` / `media/charging` 相关刷新记录

## 安全模式恢复（万一崩了）

1. 重启设备 → 用电脑重新引导 palera1n 时**按住音量下键**直到出现锁屏 = 安全模式（不加载插件）。
2. 在 Sileo / Filza 里卸载 `com.you.fakedi`。
3. 正常引导即可。

## 构建

GitHub Actions（theos + iOS 15.6 SDK + L1ghtmann 工具链，rootless，arm64）。
产物为 `com.you.fakedi_1.0.0-1_iphoneos-arm64.deb`，dylib 位于
`/var/jb/Library/MobileSubstrate/DynamicLibraries/FakeDynamicIsland.dylib`。
