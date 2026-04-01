# Convert & Compress v1.4.0 开发方案文档

> 基于竞品调研报告 | 2026-04-01 | 范围：P0 + P1

---

## 一、版本目标

v1.4.0 聚焦两个方向：

1. **P0 — 核心体验优化**：巩固批量处理稳定性，增强压缩质量预览
2. **P1 — 自动化能力建设**：文件夹监控、Apple Shortcuts 集成、批量重命名

预期成果：缩小与 Zipic/Picmal 在自动化能力上的差距，同时保持 AI 去背景、前后对比、目录结构保持等差异化优势。

---

## 二、P0 — 核心体验优化

### 2.1 批量处理稳定性优化

**用户价值**：竞品（XnConvert、Preview）在数百张图片时崩溃/卡顿，这是用户信任的基础。

**现状分析**：
- 已有自适应并发（`recommendedConcurrency()`，基于 CPU/内存/温度）
- 已有流式导入（`streamURLs` 64 张一批）
- 缺少：内存峰值控制、处理失败的单张跳过与重试机制、进度恢复

**技术设计**：

#### 2.1.1 内存压力监控与自动降级

- **涉及文件**：`ImageToolsViewModel+Processing.swift`
- **方案**：接入 `os/proc.h` 的 `os_proc_available_memory()` 或 `ProcessInfo.processInfo.physicalMemory` 结合 `mach_task_basic_info` 监控运行时内存
- **实现**：
  - 新增 `MemoryPressureMonitor` 类（`Services/Processing/`）
  - 使用 `DispatchSource.makeMemoryPressureSource()` 监听系统内存压力事件
  - 收到 `.warning` 时自动将并发数减半
  - 收到 `.critical` 时暂停队列，等待内存释放后恢复
- **与现有代码集成**：在 `executeExport()` 的 TaskGroup 中，每批次处理前检查内存压力状态

#### 2.1.2 单张失败跳过与错误汇总

- **涉及文件**：`Processing/Pipeline.swift`、`ImageToolsViewModel+Processing.swift`
- **现状**：`Pipeline.run(on:)` 抛出异常时整个批次中断
- **方案**：
  - `run(on:)` 返回 `Result<ImageAsset, ProcessingError>` 替代直接 throw
  - ViewModel 收集所有 `.failure`，处理结束后弹窗展示失败清单（文件名 + 错误原因）
  - 新增 `ProcessingError` 枚举：`.loadFailed`、`.encodeFailed`、`.writeFailed`、`.insufficientDisk`
- **UI**：处理完成后若有失败项，显示 Alert 包含失败数量和"查看详情"按钮

### 2.2 压缩质量预览增强

**用户价值**：用户需要在压缩率和画质间有精细控制，实时看到结果。

**现状分析**：
- 已有 `PreviewEstimator` 估算文件大小
- 已有 `ComparisonView` 前后分屏对比（带缩放/平移）
- 缺少：压缩率百分比显示、批量预估汇总

**技术设计**：

#### 2.2.1 压缩率与节省空间显示

- **涉及文件**：`ViewModels/ImageToolsViewModel+Estimation.swift`、`Views/BottomBar/`
- **方案**：
  - 在现有 `estimatedFileSize` 基础上，计算 `compressionRatio = 1 - (estimated / original)`
  - BottomBar 显示：`已选 N 张 | 原始 12.3 MB → 预估 3.4 MB (节省 72%)`
  - 使用已有的 `originalFileSizeBytes` 和估算值计算

#### 2.2.2 批量预估汇总

- **涉及文件**：`ImageToolsViewModel+Estimation.swift`
- **方案**：
  - 对所有已加载图片（或选中图片）汇总原始大小和预估大小
  - 使用后台 Task 异步计算，避免阻塞 UI
  - 设置 debounce（复用现有 250ms 机制），参数变更时重新估算

---

## 三、P1-a — 文件夹监控

**用户价值**：截图自动压缩、下载目录新图片自动转格式——竞品 Zipic/Picmal/Compresto 均已支持。

**技术设计**：

### 3.1 架构概览

```
┌─────────────────────────┐
│   FolderMonitorManager  │ ← 单例，管理多个监控目录
│   (Services/Monitor/)   │
├─────────────────────────┤
│ - monitoredFolders: [MonitoredFolder]
│ - start(folder:preset:) │
│ - stop(folder:)         │
│ - stopAll()             │
└────────┬────────────────┘
         │ 使用
┌────────▼────────────────┐
│   FolderWatcher         │ ← 每个目录一个实例
│   (DispatchSource)      │
├─────────────────────────┤
│ - url: URL              │
│ - preset: Preset        │
│ - onNewFiles: ([URL])   │
│ - debounce: 1s          │
└────────┬────────────────┘
         │ 检测到新文件
┌────────▼────────────────┐
│   ProcessingPipeline    │ ← 复用现有管道
│   (已有)                │
└─────────────────────────┘
```

### 3.2 关键实现

#### 3.2.1 FolderWatcher

- **新增文件**：`Services/Monitor/FolderWatcher.swift`
- **技术选型**：`DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:)` 监听 `.write` 事件
- **工作流程**：
  1. 用 `open()` 获取目录的 file descriptor
  2. 创建 DispatchSource 监听 `.write`（目录内容变更）
  3. 触发时，扫描目录获取新增文件（对比上次已知文件集合）
  4. 1 秒 debounce 防止频繁触发（截图工具可能分步写入）
  5. 新文件通过 `IngestionCoordinator.expandToSupportedImageURLs()` 过滤
  6. 交给 `ProcessingPipeline` 按关联 Preset 处理
- **输出策略**：处理后的文件写入源目录的 `_converted/` 子目录，或用户指定的输出目录

#### 3.2.2 FolderMonitorManager

- **新增文件**：`Services/Monitor/FolderMonitorManager.swift`
- **职责**：
  - 管理多个 FolderWatcher 实例
  - 持久化监控配置（使用 `UserDefaults`，键值存储监控目录路径 + 关联 Preset ID + 输出目录）
  - App 启动时自动恢复监控
  - 提供 `@Published` 属性供 UI 绑定
- **模型**：
  ```swift
  struct MonitoredFolder: Codable, Identifiable {
      let id: UUID
      var url: URL                    // 监控目录（bookmark data）
      var presetID: UUID?             // 关联预设（nil = 使用当前设置）
      var outputDirectoryURL: URL?    // 输出目录（nil = 源目录/_converted/）
      var isActive: Bool              // 是否激活
  }
  ```
- **沙盒处理**：使用 Security-Scoped Bookmark 持久化目录访问权限，复用 `SandboxAccessManager`

#### 3.2.3 监控设置 UI

- **新增文件**：`Views/Monitor/FolderMonitorSettingsView.swift`
- **入口**：在 `AppCommands` 菜单中添加"文件夹监控..."菜单项，打开设置 Sheet
- **UI 元素**：
  - 监控目录列表（添加/移除）
  - 每行显示：目录路径 | 关联预设（下拉选择）| 输出目录 | 启用/禁用开关
  - "添加目录"按钮 → NSOpenPanel 选择目录
  - 状态指示器（监控中 / 已暂停）

#### 3.2.4 与 AppDelegate 集成

- **修改文件**：`App/ConvertCompressApp.swift`
- `applicationDidFinishLaunching` 中调用 `FolderMonitorManager.shared.restoreAndStart()`
- `applicationWillTerminate` 中调用 `FolderMonitorManager.shared.stopAll()`

### 3.3 依赖与风险

- **沙盒权限**：需要在 entitlements 中确保有 `com.apple.security.files.bookmarks.app-scope` 权限（已有，因为当前已使用 Security-Scoped Bookmarks）
- **性能风险**：高频写入目录（如下载大量图片）可能触发过多事件 → 用 debounce + 批量处理缓解
- **文件锁定**：浏览器下载中的文件可能未写入完成 → 检测文件大小稳定后再处理（连续两次扫描文件大小一致）

---

## 四、P1-b — Apple Shortcuts 集成

**用户价值**：打通 macOS 自动化生态，用户可在 Shortcuts 中串联 Convert & Compress 的能力。

**技术设计**：

### 4.1 AppIntents 框架概览

```
┌──────────────────────────────┐
│   AppIntents (macOS 13+)     │
├──────────────────────────────┤
│ ConvertImageIntent           │ ← 核心：转换格式+压缩
│ ResizeImageIntent            │ ← 缩放图片
│ RemoveBackgroundIntent       │ ← AI 去背景
│ CompressImageIntent          │ ← 仅压缩不转格式
└──────────────────────────────┘
```

### 4.2 关键实现

#### 4.2.1 ConvertImageIntent

- **新增文件**：`App/Intents/ConvertImageIntent.swift`
- **定义**：
  ```swift
  struct ConvertImageIntent: AppIntent {
      static var title: LocalizedStringResource = "Convert Images"
      static var description = IntentDescription("Convert images to a different format")

      @Parameter(title: "Images") var images: [IntentFile]
      @Parameter(title: "Format") var format: ImageFormatEntity  // 自定义 AppEnum
      @Parameter(title: "Quality", default: 85) var quality: Int  // 0-100

      func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
          // 1. 将 IntentFile 写入临时目录
          // 2. 构建 ProcessingConfiguration
          // 3. 使用 PipelineBuilder + ProcessingPipeline 处理
          // 4. 返回处理后的 IntentFile 数组
      }
  }
  ```
- **复用**：直接调用 `PipelineBuilder.build()` 和 `Pipeline.renderEncodedData()` — 已有的无副作用处理路径

#### 4.2.2 ResizeImageIntent

- **新增文件**：`App/Intents/ResizeImageIntent.swift`
- **参数**：Images + Width/Height/LongEdge/Percentage（互斥参数组）
- **复用**：`ResizeOperation` 已有完整实现

#### 4.2.3 RemoveBackgroundIntent

- **新增文件**：`App/Intents/RemoveBackgroundIntent.swift`
- **参数**：Images
- **复用**：`RemoveBackgroundOperation` 已有完整实现
- **限制**：需要 macOS 14+ （`VNGenerateForegroundInstanceMaskRequest`）

#### 4.2.4 ImageFormatEntity（AppEnum）

- **新增文件**：`App/Intents/ImageFormatEntity.swift`
- **定义**：将现有 `ImageFormat` 映射为 `AppEnum`，供 Shortcuts 选择器使用
  ```swift
  enum ImageFormatEntity: String, AppEnum {
      case jpeg, png, heic, webp, avif
      static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Image Format")
      static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [...]
  }
  ```

#### 4.2.5 IntentsPipeline（无 UI 处理桥接）

- **新增文件**：`Services/Processing/IntentsPipeline.swift`
- **职责**：封装从 `IntentFile` → 临时文件 → Pipeline 处理 → 返回 `IntentFile` 的完整流程
- **关键**：不依赖 ViewModel 或 UI 状态，纯函数式处理
- **复用**：`Pipeline.renderEncodedData()` 已支持无目录输出的数据流

### 4.3 依赖与风险

- **最低版本**：AppIntents 需要 macOS 13+（Ventura），需确认项目 deployment target
- **沙盒**：Shortcuts 传入的文件在临时 sandbox 中，需用 `IntentFile` 的 data 属性而非 URL
- **测试**：Shortcuts 集成难以自动化测试，需手动在 Shortcuts app 中验证

---

## 五、P1-c — 批量重命名

**用户价值**：电商卖家、摄影师需要在转换时同时重命名文件（前缀、序号、日期）。竞品均未提供此功能，是差异化机会。

**技术设计**：

### 5.1 重命名模板系统

#### 5.1.1 NamingTemplate 模型

- **新增文件**：`Core/Models/NamingTemplate.swift`
- **设计**：
  ```swift
  struct NamingTemplate: Codable {
      var isEnabled: Bool = false
      var pattern: String = "{name}"  // 默认保持原名
      // 支持的占位符：
      // {name}     — 原文件名（不含扩展名）
      // {n}        — 序号（从 1 开始）
      // {n:03}     — 零填充序号（001, 002, ...）
      // {date}     — 当前日期 yyyy-MM-dd
      // {datetime} — 当前日期时间 yyyy-MM-dd_HH-mm-ss
      // {w}        — 图片宽度（像素）
      // {h}        — 图片高度（像素）
      // {ext}      — 目标格式扩展名
  }
  ```

#### 5.1.2 NamingTemplateResolver

- **新增文件**：`Services/Processing/NamingTemplateResolver.swift`
- **职责**：将模板 + 上下文（原文件名、序号、图片尺寸）解析为最终文件名
  ```swift
  struct NamingTemplateResolver {
      func resolve(template: NamingTemplate, context: NamingContext) -> String
  }

  struct NamingContext {
      let originalName: String    // 不含扩展名
      let index: Int              // 批次中的序号
      let width: Int?
      let height: Int?
      let targetExtension: String
  }
  ```
- **实现**：正则匹配 `{key}` 和 `{key:format}` 占位符，逐一替换

#### 5.1.3 集成到 Pipeline

- **修改文件**：`Processing/Pipeline.swift` 的 `destinationPlan()` 方法
- **现有逻辑**：`let base = currentURL.deletingPathExtension().lastPathComponent`
- **变更**：若 `NamingTemplate.isEnabled`，用 `NamingTemplateResolver.resolve()` 的结果替换 `base`
- **ProcessingConfiguration 扩展**：新增 `namingTemplate: NamingTemplate?` 属性

#### 5.1.4 集成到 ViewModel

- **修改文件**：`ViewModels/ImageToolsViewModel.swift`
- 新增 `@Published var namingTemplate = NamingTemplate()`
- `buildConfiguration()` 中将 `namingTemplate` 传入 `ProcessingConfiguration`

#### 5.1.5 重命名 UI

- **新增文件**：`Views/Controls/NamingTemplateControl.swift`
- **入口**：在 ControlsBar 中添加重命名按钮（类似现有 Flip/Metadata 控件的紧凑样式）
- **交互**：点击展开 Popover，包含：
  - 启用/禁用开关
  - 模板输入框（带占位符提示）
  - 实时预览：显示第一张图片按模板重命名后的文件名
  - 常用模板快捷按钮：`{name}_compressed`、`{date}_{n:03}`、`product_{n:03}`

### 5.2 依赖与风险

- **文件名冲突**：同一批次内模板可能生成重名文件 → Resolver 检测冲突时自动追加 `_1`、`_2`
- **非法字符**：模板结果需过滤 `/`、`:`、`\0` 等文件系统非法字符
- **Preset 兼容**：`NamingTemplate` 需加入 `ProcessingConfiguration`（Codable），现有 Preset 反序列化需兼容（默认值处理）

---

## 六、P2-P4 方向概览（本版本不实现）

| 优先级 | 功能 | 方向说明 |
|---|---|---|
| P2 | 剪贴板自动优化 | 监听 `NSPasteboard` 通用剪贴板变化，检测到图片时自动压缩回写 |
| P2 | 选择性元数据保留 | 扩展 `buildDestinationProperties()` 支持白名单/黑名单 EXIF 字段 |
| P3 | JPEG-XL 输出 | 集成 libjxl（SPM），新增 `JXLEncoder`，扩展 `ImageFormat` 枚举 |
| P3 | RAW 格式输入 | 利用 CoreImage 的 `CIRAWFilter` 加载 CR2/NEF/ARW/DNG |
| P4 | 水印功能 | 新增 `WatermarkOperation: ImageOperation`，支持文字/图片水印叠加 |
| P4 | 基础调色 | 新增 `ColorAdjustOperation`，使用 CIFilter（亮度/对比度/饱和度）|
| P4 | CLI 工具 | 新增 Command Line Tool target，复用 Processing 层 |

---

## 七、技术约束与规范

### 7.1 构建与测试

- 每个功能模块完成后必须通过 `xcodebuild -scheme convert-compress build`
- 为核心逻辑（NamingTemplateResolver、MemoryPressureMonitor、FolderWatcher）编写单元测试
- 测试文件放在 `convert-compress-tests/` 目录

### 7.2 代码规范

- 遵循现有 MVVM 分层：新 Service 放 `Services/`，新 Model 放 `Core/Models/`，新 View 放 `Views/`
- 新增的 `@Published` 属性通过 ViewModel 扩展文件管理，避免主文件膨胀
- 使用现有 `AppConstants.bundleIdentifier` 作为 UserDefaults 键前缀
- 本地化字符串使用 `Localizable.xcstrings`

### 7.3 兼容性

- Deployment Target：macOS 14+（Vision 框架的去背景功能已要求此版本）
- Swift Concurrency：使用 async/await + TaskGroup，与现有模式一致
- 沙盒：所有文件访问通过 `SandboxAccessManager`，使用 Security-Scoped Bookmarks
