# 手势使用指南

## 触摸模式

驱动支持两种触摸模式，通过 `DriverConfig.gestures.touchMode` 或启动参数切换：

| 模式 | 启动方式 | 主要用途 |
|------|---------|---------|
| 双指滚动模式（默认） | `sudo make run-debug` | 触摸屏当鼠标用，单指控制光标 |
| 单指滚动模式 | `sudo make run-debug-sf` 或 `--single-finger` | 触摸屏当滚动板用，单指直接滚动 |

---

## 双指滚动模式（默认）

### 单指

| 手势 | 操作 | 说明 |
|------|------|------|
| 点击 | 左键单击 | 触摸后快速抬起 |
| 双击 | 左键双击 | 250ms 内连续两次点击 |
| 长按 | 右键菜单 | 按住 0.6s（可配置），移动不超过 15px |
| 拖拽 | 鼠标拖拽 | 按住后移动超过 8px 进入拖拽模式 |

> **延迟 mouseDown（50ms）**：单指触摸时会延迟 50ms 才发出 mouseDown，以避免多指触摸开始时误触发单击。

### 双指

| 手势 | 操作 |
|------|------|
| 上下滑动 | 页面垂直滚动 |
| 左右滑动 | 页面水平滚动 |
| 捏合 / 展开 | 缩小 / 放大（Cmd+滚轮模拟） |

**滚动特性**：
- 支持惯性：快速滑动后松开，内容继续滚动后减速停止
- 加速度：检测到快速滑动时提升初速度（最大 2× boost）
- 自然方向（默认）：手指上移 → 内容上移

**双指分类机制**：`TwoFingerDetector` 通过分析移动向量的方向相似度和距离变化来区分滚动（方向一致）和捏合（方向相反/距离变化大）。

### 4指

| 手势 | 触发动作 | 等效快捷键 |
|------|---------|------------|
| 上滑 | Mission Control | Control + ↑ |
| 下滑 | App Exposé | Control + ↓ |
| 左滑 | 切换到右侧桌面 | Control + → |
| 右滑 | 切换到左侧桌面 | Control + ← |
| 轻拍 | Launchpad | F4 |

---

## 单指滚动模式（`--single-finger`）

适合将触摸屏作为滚动板（trackpad-like）使用的场景。

### 单指

| 手势 | 操作 | 说明 |
|------|------|------|
| 滑动 | 页面滚动 | 移动超过 5px 后进入滚动，光标自动跳到手指位置 |
| 轻拍 | 左键单击 | 快速触摸抬起，延迟 100ms 触发（等待双击判断） |
| 双拍 | 左键双击 | 100ms 内两次轻拍，或第二次拍时上次点击在 doubleClickDelay 内 |
| 长按（~0.6s） | 拖拽模式 | 进入拖拽（mouseDown），移动即选择文字，抬起发出 mouseUp |
| 快速滑动后松手 | 惯性滚动 | 根据抬手速度继续滚动，速度衰减后停止 |

**状态机**：`idle → pending → scrolling / dragging`
- `pending`：手指刚落下，吸收 <5px 抖动，等待意图确认
- `scrolling`：超过 5px 进入，光标跳转到手指所在位置，持续发出滚动事件
- `dragging`：pending 阶段长按 ~0.6s 进入，用于文字选择

### 双指

| 手势 | 操作 | 说明 |
|------|------|------|
| 双指轻拍 | 右键菜单 | 在当前光标位置右键，**不移动光标** |

> **顺序落下处理**：真实硬件上两指往往有先后。驱动通过 `pendingClickFingerId` 识别"A 抬起 → B 才落下"的场景，自动取消 A 的待定点击并触发右键，确保光标不移动。

### 4指

与双指滚动模式相同（见上方4指手势表）。

---

## 默认参数（DriverConfig）

可通过 GUI Gestures 标签页或直接编辑 `config.json` 调整：

### 单指（双指滚动模式）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `gestures.contextMenuDelay` | 0.6s | 右键长按时长 |
| `gestures.movementThreshold` | 15px | 长按最大移动量 |
| `gestures.dragThreshold` | 8px | 进入拖拽模式的最小位移 |
| `gestures.mouseDownDelay` | 0.05s | 单指 mouseDown 延迟 |

### 单指（单指滚动模式）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `gestures.touchMode` | `.twoFingerScroll` | 设为 `.singleFingerScroll` 启用单指滚动模式 |
| `gestures.tapTimeout` | 0.1s | 轻拍延迟窗口（等待双指识别） |
| `gestures.doubleClickDelay` | 0.25s | 双击最大间隔 |
| `gestures.contextMenuDelay` | 0.6s | 长按进入拖拽的时长 |
| `scroll.inertialEnabled` | true | 单指惯性滚动开关 |

### 双指滚动

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `scroll.invertY` | true | 自然滚动方向 |
| `scroll.smoothingEnabled` | false | 平滑模式 |
| `scroll.smoothingFactor` | 0.4 | 平滑系数（越大越平滑） |
| `scroll.inertialEnabled` | true | 惯性滚动 |
| `scroll.inertialDecayFactor` | 0.98 | 惯性衰减（越接近1越慢停） |
| `scroll.accelerationEnabled` | true | 速度加速 |
| `scroll.accelerationBoost` | 1.5× | 加速倍率 |
| `scroll.maxBoostFactor` | 2.0× | 最大加速上限 |

### 双指捏合

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `pinch.enabled` | true | 启用捏合 |
| `pinch.threshold` | 3px | 触发缩放的最小距离变化 |
| `pinch.scaleFactor` | 0.8 | 缩放灵敏度 |
| `pinch.minDistance` | 30px | 两指最小距离 |

### 4指手势

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `fourFinger.enabled` | true | 启用4指手势 |
| `fourFinger.minDistance` | 60px | 手指间最小间距 |
| `fourFinger.maxDistance` | 700px | 手指间最大间距 |
| `fourFinger.swipeThreshold` | 60px | 滑动触发最小位移 |
| `fourFinger.swipeMinVelocity` | 100px/s | 滑动触发最小速度 |
| `fourFinger.longPressDuration` | 0.6s | 长按触发（保留扩展） |
| `fourFinger.detectionBuffer` | 0.15s | 等待第4根手指的缓冲时间 |
| `fourFinger.swipeEarlyDetection` | 30px | 提前锁定方向的位移阈值 |

## 使用技巧

### 4指手势
1. 4根手指自然张开同时放上去（不要一根一根放）
2. 手指间距 6–15cm 左右（DriverConfig 默认 60–700px）
3. 滑动时方向清晰，速度适中（不用太快）
4. 如果反复失败：调大 `swipeThreshold` 或调小 `swipeMinVelocity`

### 4指轻拍
1. 4根手指同时触摸
2. 在 0.5s 内抬起（`tapMaxDuration`，由 `FourFingerGesture.swift` 内部定义）
3. 整个过程移动不超过 40px
4. 提示：手指分散（间距 > 60px），否则系统可能识别为单点

### 双指滚动
1. 两指平行放置，均匀发力
2. 快划后松手可享受惯性效果
3. 如果滚动过于灵敏：调小 `accelerationBoost`

## 与 macOS 内置触控板手势对比

| 功能 | ILITEK（本驱动） | macOS 触控板 |
|------|----------------|-------------|
| Mission Control | 4指上滑 | 3指上滑 |
| App Exposé | 4指下滑 | 3指下滑 |
| 切换桌面 | 4指左/右滑 | 3指左/右滑 |
| Launchpad | 4指轻拍 | 拇指+3指捏合 |
| 滚动 | 双指滑动 | 双指滑动 |
| 缩放 | 双指捏合 | 双指捏合 |
