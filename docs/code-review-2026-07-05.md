# PiliPala TV 分支代码审查与修复记录（2026-07-05）

本次针对 `tv` 分支做了一轮完整审查（`lib/` 共 487 个 Dart 文件，其中 TV 专属 28 个），
并修复了一批确认的 bug。核心目标是解决 **TV 原生手机号登录“请求错误”**，
同时顺带修掉审查中发现的其它真实问题。

## 审查方法

- `dart analyze lib`（Flutter 3.19.6 SDK）：0 error，89 条均为既有 warning/info（未处理，避免噪音）。
- 分三路并行深读：TV 控制器、TV 页面/组件、共享层改动 + 更新流程。
- 登录问题对照反编译的官方云视听 TV（`com.xiaodianshi.tv.yst`，
  `C:\Users\Lan\Documents\Playground\魔改云视听`）逐字段核对接口。
- 每处修复后对改动文件复跑 `dart analyze`；`pubspec.lock` 全程未变（md5 校验一致）。

> 说明：`tv_home_controller.dart`、`tv_player_*`、`tv_left_nav.dart`、`README.md`、`docs/tv-build-and-test.md`、
> `pubspec.yaml` 里的改动是本次审查**之前就已存在的未提交 WIP**，不是本次改动。
> 本次实际修改的文件见下方每条记录的“文件”。

---

## 一、已修复的问题

### 1.【重点】TV 原生手机号登录“请求错误”

**文件**：`lib/http/login.dart`

**现象**：TV 原生手机号登录（发送验证码 / 验证码登录）请求官方 `passport-tv-login` 接口时，
服务端返回 `-400 请求错误`。

**根因**（对照官方 app 定位到两点）：

1. **缺少 `ts` 时间戳**。Bilibili 的 app 签名要求带秒级 `ts`，官方 TV 端由 native `signQuery`
   自动补上并纳入签名，缺失会被服务端判为 `-400 请求错误`。本仓库自己的 `lib/http/member.dart`
   里其它 app 签名请求（`getTVCode` / `qrcodePoll`，即能用的扫码登录）**都带 `ts`**，唯独
   TV 手机号登录的 `signedTvParams` 漏了。
2. **空格编码不一致**。原来用 `Utils.appSign` → `Uri(queryParameters:)` 计算签名，Dart 会把空格
   编成 `+`；而官方 okhttp `FormBody`（及服务端校验）用 `%20`。很多电视盒子的机型名
   （`model` / `device_platform`，如 “SHIELD Android TV”、“BRAVIA 4K”）带空格，会导致签名与
   请求体不一致而报错。

**修复**：在 `signedTvParams` 里签名前补 `ts`，并改用统一的 `%20` 编码同时计算签名与拼接
请求体（`_tvEncodedQuery`，按 key 排序）：GET `/key` 把 query 直接拼进 URL，POST `sms/send`、
`login/sms` 用 `%20` 编码后的字符串作 body。这样签名与实际发送完全一致，且与官方 okhttp 对齐。

**已核对无误的字段**（与官方 `BiliAuthService` / `LoginHandler` 逐一比对）：
接口路径、`cid=86`、`tel_encrypt=RSA(hash+tel).base64`、`token=16位设备号`、`code`、
`captcha_key`、`login_session_id`、以及 `appkey/appsec` 均正确。

> ⚠️ 此修复基于官方 app 与本仓库既有签名约定，逻辑与编码已离线验证一致；
> 因涉及真实短信下发，**最终是否成功需真机 + 真实手机号验证**。

### 2.【严重】TV 首页内容区 Obx 空转崩溃

**文件**：`lib/tv/pages/shell/tv_shell_page.dart`

**根因**：首页内容用 `Obx(() => _HomeStage(...))` 包裹，但闭包里只是构造 `_HomeStage`，
真正读取 `currentTab` / 当前列表 / `selectedIndex` 等 Rx 的动作发生在 `_HomeStage.build`（子 widget）里，
不在该 Obx 闭包内。GetX 4.6.6 的 `Obx` 在闭包**未读取任何可观察对象时会直接抛
“improper use of a GetX”异常**（已核对 GetX 源码 `rx_interface.dart`），导致首页内容区渲染即崩，
而且即便不崩这些 Rx 变化也不会触发重建。

**修复**：让该 `Obx` 闭包显式订阅 `_controller.currentVideos` 与 `_controller.selectedVideo`
（二者覆盖 `currentTab`、当前 Tab 的列表、`selectedIndex`）。既消除抛错，也让首页在
切 Tab / 数据刷新 / 选中项变化时正确重建。（已确认 shell 内其余 4 处 `Obx` 闭包都读了 Rx，无同类问题。）

### 3. 登录页验证码浮层每帧无限重建

**文件**：`lib/tv/pages/login/tv_login_page.dart`

**根因**：`_syncCaptchaPointerBounds` 从 `LayoutBuilder` 的 build 中调用，内部无条件
`addPostFrameCallback` → `setState` + 每帧 `requestFocus`，缺少“bounds 未变化就返回”的守卫。
build → postFrame setState → build 形成每帧无限重建，验证码显示期间持续 jank 并每帧抢焦点。
对照同仓库 `lib/pages/webview/view.dart` 的 `_syncTvPointerBounds` 正好有这个守卫，确认是遗漏。

**修复**：加入 `_captchaPointerBounds == bounds` 提前返回；并在验证码关闭时把 bounds 重置为
`Size.zero`，保证下次弹出仍能重新居中并夺焦。

### 4.【严重】防沉迷锁屏一系列问题

**文件**：`lib/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart`

锁屏浮层挂在 `GetMaterialApp.builder` 里、作为 Navigator 的**兄弟**节点（`tv_app.dart`），
由此引出三个问题，全部修复：

- **抢不到焦点 / 拦不住遥控器**：浮层靠 `autofocus: true`，但根 scope 已有焦点子节点时 autofocus
  会被丢弃，锁屏根本拿不到焦点，方向键还能穿透到锁屏背后的控件（甚至 OK 恢复播放且不计时）。
  → 改为 `StatefulWidget`，用 `ever(isLocked)` 在锁定时主动 `requestFocus`；`onKeyEvent` 锁定期间
  吞掉方向键/返回键（禁止焦点遍历逃逸），OK/Enter 触发 PIN 弹窗。
- **PIN 解锁必崩**：`showTvPinDialog(context)` 用的是浮层自身 context，它没有 Navigator 祖先，
  `showDialog` 会抛异常，PIN 解锁根本打不开。→ 改用 `Get.overlayContext ?? Get.context`
  （与 `tv_settings_controller` 一致），并加 `_pinDialogShowing` 防重入。
- **休息倒计时不刷新**：`_LockCountdown` 是独立 `StatelessWidget`，读 `remainingLockSeconds` / `lockReason`
  的位置在外层 Obx 闭包之外，倒计时渲染一次后不再逐秒更新。→ `_LockCountdown.build` 用自己的 `Obx` 包裹。

> ⚠️ 焦点/DPAD 行为**强烈建议在真机或 Google TV 模拟器上用遥控器实测**：开启防沉迷、触发锁屏后，
> 确认方向键无法移动到锁屏背后、OK 能打开 PIN 弹窗、PIN 正确/错误/取消后焦点表现正常。

### 5. 登录方式切换后短信中间态残留

**文件**：`lib/tv/controllers/tv_login_controller.dart`

**根因**：`setLoginMode` 未在切换登录方式时清理 `smsStep` / `captchaKey` / `smsCodeInput`。
在 TV 原生短信（mode 1）发过验证码后切到网页短信（mode 2），会把 TV 端的 `captcha_key` 带去请求
网页接口，必然失败；同时共享的 60s 倒计时还会挡住重新获取。另外从别的方式切回扫码（mode 0）时，
二维码轮询不会重启，扫码静默无效。

**修复**：`setLoginMode` 在方式切换时重置短信中间态（保留手机号方便重发）；切回扫码模式且二维码为空
或轮询已停时，重新生成二维码并恢复轮询。

### 6. 搜索结果竞态

**文件**：`lib/tv/controllers/tv_search_controller.dart`

**根因**：`search()` 无请求时序控制，热词点按与搜索按钮可并发触发；慢的旧请求后到会覆盖新请求的结果，
先返回者还会提前清掉 loading。

**修复**：加自增序号 `_searchSeq`，请求入口捕获序号，写 `results`/`error`/`loadingSearch` 前校验，
过期响应直接丢弃。

### 7. 防沉迷计时与解锁

**文件**：`lib/tv/controllers/tv_anti_addiction_controller.dart`

- **每日上限锁定后跨天不会自动解锁**：`_lock(dailyLimit)` 只把倒计时清零并取消定时器，锁定期间没有任何
  代码会调用 `_rollDailyIfNeeded()`（计时器已停、`_tick`/`startCounting` 在 `isLocked` 时提前返回），
  于是会一直锁到 App 重启或家长 PIN——与“明天再继续观看”的提示矛盾。
  → 每日上限锁定时挂一个每分钟的定时器检查跨天并自动解锁。
- **瞬时失焦后计时永久停止（防沉迷被绕过）**：`didChangeAppLifecycleState` 在 paused/inactive/detached
  时 `stopCounting()` 且清空回调，却没有 `resumed` 分支恢复；播放状态 worker 只在状态变化时触发，
  一次不暂停媒体的瞬时 `inactive`（系统弹窗/语音助手）会让计时永久停止，孩子继续看却不计时。
  → 停表时记 `_pausedByLifecycle` 并保留回调（`stopCounting(keepCallbacks: true)`），
  `resumed` 时若仍在计时条件内则继续计时。

### 8. 其它

- **播放位置显示 0 秒变 `--:--`**（`lib/tv/utils/tv_formatters.dart`）：`tvFormatDuration` 把
  `seconds <= 0` 当未知时长，但播放器 HUD 也用它显示当前位置，视频开头/拖回 0 秒会显示 `--:--`。
  → 改为仅负数当未知，0 正常显示 `00:00`。
- **GitHub 不可达时启动误报 toast**（`lib/http/interceptor.dart`）：静默更新检查走
  `api.github.com`，大陆网络常不可达，`ApiInterceptor.onError` 会在启动时弹“网络连接超时”。
  → 把 `api.github.com` 加入 toast 排除列表（静默检查失败不再打扰用户；手动检查仍有自己的提示）。

---

## 二、发现但未修复（建议项）

以下为审查中发现、但**涉及移动端 UX 改动或需真机验证、本次未擅自修改**的问题，建议后续处理：

1. **移动端启动仍可能弹更新对话框**（`lib/pages/main/controller.dart:36-38`）：
   `autoUpdate` 开时 `onInit` 调 `Utils.checkUpdata()` 会弹 `AlertDialog`，与 fork“静默更新、不在启动弹窗”
   的设计冲突；且该键默认值在三处不一致（此处 `false`、`update_controller.dart` 与设置页 `true`）。
   建议删掉 `onInit` 里这段（`checkSilently` 已接管）。
2. **手动检查更新崩溃/无反馈**（`lib/utils/utils.dart:279/299/345`、`lib/pages/about/index.dart:233`）：
   GitHub 失败或 release 无对应 ABI 资源时，`data.tagName!` / `data.body!` / `late downloadUrl` 会抛异常。
   建议对 `tagName`/`body` 判空、`downloadUrl` 改可空并兜底跳 releases 页。
3. **设置页“家长 PIN”行状态不刷新**（`lib/tv/pages/settings/tv_settings_page.dart:135`）：
   `hasPin`/`pinStatus` 直接读 Hive 非响应式，设置/修改 PIN 后该行仍显示旧态。
   建议改用 `RxBool` 或保存后触发一次刷新。
4. **网页短信登录验证码丢前导零**（`lib/tv/controllers/tv_login_controller.dart` + `lib/http/login.dart:99`）：
   网页短信路径 `int.parse(smsCodeInput)`，“012345”会变“12345”被拒（约 1/10）；TV 原生路径已用 String，正常。
   源于上游 `int` 类型签名，建议改 String。
5. **`main_tv.dart` 冷启动阻塞**：`Data.init()`（登录时会发网络请求）在 `runApp` 之前 await，
   弱网 TV 上会卡到 12s 超时；建议移进 `TvApp.onReady`。
6. **搜索结果 `cid=0` / 历史非投稿项**（`lib/tv/utils/tv_video_mapper.dart`）：
   `fromSearch` 的 `cid` 恒为 0（详情页会重解析，暂无影响）；`fromHistory` 会把直播/番剧历史也映射成卡片，
   点开必“加载详情失败”，建议按 `business == 'archive'`/非空 bvid 过滤。
7. **计时 ~1s 抖动**（`tv_anti_addiction_controller`）：每次暂停/恢复 `_tick` 向下取整会丢最多约 1s，
   仅约 1Hz 狂按暂停可利用，影响极小。

---

## 三、验证情况

- ✅ `dart analyze lib`：0 error（89 条既有 warning/info，与改动无关）。
- ✅ 每个改动文件单独 `dart analyze`：均 No issues found。
- ✅ `pubspec.lock` 未变动（md5 一致，符合 AGENTS.md 要求）。
- ✅ TV 签名逻辑离线单测：空格→`%20`、base64 的 `+//=`→`%2B/%2F/%3D`、按 key 排序、md5 32 位均正确。
- ⏳ **未做整包构建 / 真机运行**：登录短信下发、锁屏 DPAD 焦点、播放等需真机或 Google TV 模拟器实测（见下）。

## 四、建议的真机/模拟器测试清单

1. **手机号登录**（重点）：真机输入真实手机号 → 获取验证码应成功（不再“请求错误”）→ 输入验证码登录成功。
2. **登录方式切换**：原生短信发码后切到网页短信、再切回扫码，确认无残留、扫码能正常轮询登录。
3. **首页**：进入首页内容区正常渲染（不再报错），切换 推荐/历史/收藏/稍后再看 内容随之刷新。
4. **防沉迷锁屏**：开启防沉迷并触发锁屏后——方向键无法移到锁屏背后；OK 打开 PIN 弹窗；
   PIN 正确解锁、错误/取消后焦点回到锁屏；休息倒计时逐秒刷新；到点自动解锁；跨天后每日上限自动解除。
5. **切后台再回前台**：播放中切后台/触发系统弹窗再返回，确认计时继续累计（防沉迷不被绕过）。
