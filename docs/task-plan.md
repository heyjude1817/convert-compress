# Convert & Compress v1.4.0 任务规划文档

> 基于开发方案文档 | 2026-04-01

---

## 工作流规范

每个任务严格遵循以下流程：

```
1. 编码实现
2. 构建验证：xcodebuild -scheme convert-compress -configuration Debug build
3. 测试验证：xcodebuild -scheme convert-compress test（若有新增/修改测试）
4. Git 提交：git add <具体文件> && git commit -m "<type>: <描述>"
5. 进入下一个任务
```

**提交类型规范**：`feat`（新功能）、`fix`（修复）、`refactor`（重构）、`test`（测试）、`chore`（配置/杂项）

---

## 阶段一：P0 — 核心体验优化

### Task 1.1 — 内存压力监控器

| 项目 | 内容 |
|---|---|
| **描述** | 新增 `MemoryPressureMonitor`，使用 `DispatchSource.makeMemoryPressureSource()` 监听系统内存压力，提供响应式并发调节能力 |
| **新增文件** | `Services/Processing/MemoryPressureMonitor.swift` |
| **实现要点** | 1. 监听 `.warning` / `.critical` 事件<br>2. 提供 `@Published var pressureLevel` 属性<br>3. 提供 `recommendedConcurrencyReduction() -> Int` 方法 |
| **验证标准** | 构建通过；单元测试验证状态变更回调 |
| **测试文件** | `convert-compress-tests/MemoryPressureMonitorTests.swift` |
| **提交信息** | `feat: add MemoryPressureMonitor for system memory pressure detection` |

### Task 1.2 — 集成内存监控到导出流程

| 项目 | 内容 |
|---|---|
| **描述** | 将 `MemoryPressureMonitor` 集成到 `ImageToolsViewModel+Processing.swift` 的导出 TaskGroup 中，内存压力时自动降低并发 |
| **修改文件** | `ViewModels/ImageToolsViewModel+Processing.swift` |
| **实现要点** | 1. 在 `executeExport()` 启动时创建监控<br>2. `.warning` 时并发减半<br>3. `.critical` 时暂停新任务提交，等待已有任务完成 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: integrate memory pressure monitoring into export pipeline` |

### Task 1.3 — 单张失败跳过与错误汇总

| 项目 | 内容 |
|---|---|
| **描述** | 重构 Pipeline 的错误处理，单张失败不中断批次；收集错误后统一展示 |
| **新增文件** | `Core/Models/ProcessingError.swift` |
| **修改文件** | `Processing/Pipeline.swift`、`ViewModels/ImageToolsViewModel+Processing.swift` |
| **实现要点** | 1. 新增 `ProcessingError` 枚举（`.loadFailed`、`.encodeFailed`、`.writeFailed`、`.insufficientDisk`）<br>2. `Pipeline.run(on:)` 内部 catch 异常，返回 `Result<ImageAsset, ProcessingError>`<br>3. ViewModel 收集失败结果，处理结束后通过 `@Published var processingErrors` 暴露 |
| **验证标准** | 构建通过；单元测试验证 Pipeline 对异常输入的 Result 返回 |
| **测试文件** | `convert-compress-tests/PipelineErrorHandlingTests.swift` |
| **提交信息** | `feat: add per-image error handling with skip and summary` |

### Task 1.4 — 错误汇总 UI

| 项目 | 内容 |
|---|---|
| **描述** | 批量处理完成后，若有失败项，弹窗展示失败清单 |
| **新增文件** | `Views/Processing/ProcessingErrorAlert.swift` |
| **修改文件** | `Views/BottomBar/`（相关导出完成回调处） |
| **实现要点** | 1. Alert 显示失败数量<br>2. "查看详情" 展开 Sheet，列出每张失败图的文件名和错误原因<br>3. 复用 Theme 层的组件风格 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add processing error summary alert UI` |

### Task 1.5 — 压缩率与节省空间显示

| 项目 | 内容 |
|---|---|
| **描述** | 在 BottomBar 显示批量预估汇总：原始大小 → 预估大小（节省百分比） |
| **修改文件** | `ViewModels/ImageToolsViewModel+Estimation.swift`、`Views/BottomBar/`（相关视图） |
| **实现要点** | 1. 汇总所有图片的 `originalFileSizeBytes` 和 `estimatedFileSize`<br>2. 计算 `compressionRatio = 1 - (totalEstimated / totalOriginal)`<br>3. BottomBar 文案：`N 张 · 12.3 MB → 3.4 MB (节省 72%)`<br>4. 复用现有 debounce 机制（250ms） |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: show compression ratio and space savings in bottom bar` |

---

## 阶段二：P1-a — 文件夹监控

### Task 2.1 — FolderWatcher 核心类

| 项目 | 内容 |
|---|---|
| **描述** | 实现单个目录的文件系统监控，检测新增图片文件 |
| **新增文件** | `Services/Monitor/FolderWatcher.swift` |
| **实现要点** | 1. 使用 `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:.write)`<br>2. 维护已知文件集合，通过差集检测新增文件<br>3. 1 秒 debounce 防止频繁触发<br>4. 文件稳定性检测：连续两次扫描文件大小一致才视为写入完成<br>5. 通过 `IngestionCoordinator.expandToSupportedImageURLs()` 过滤非图片文件 |
| **验证标准** | 构建通过；单元测试验证新文件检测和 debounce 逻辑 |
| **测试文件** | `convert-compress-tests/FolderWatcherTests.swift` |
| **提交信息** | `feat: add FolderWatcher for file system monitoring` |

### Task 2.2 — MonitoredFolder 模型与持久化

| 项目 | 内容 |
|---|---|
| **描述** | 定义监控目录数据模型，支持序列化和 Security-Scoped Bookmark 持久化 |
| **新增文件** | `Core/Models/MonitoredFolder.swift`、`Services/Monitor/FolderMonitorStore.swift` |
| **实现要点** | 1. `MonitoredFolder` 模型：id, bookmarkData, presetID, outputDirectoryBookmarkData, isActive<br>2. `FolderMonitorStore` 使用 UserDefaults 持久化（键：`bundleIdentifier.monitored_folders`）<br>3. Bookmark data 编解码用于沙盒目录访问恢复 |
| **验证标准** | 构建通过；单元测试验证序列化/反序列化 |
| **测试文件** | `convert-compress-tests/MonitoredFolderTests.swift` |
| **提交信息** | `feat: add MonitoredFolder model and persistence store` |

### Task 2.3 — FolderMonitorManager 管理器

| 项目 | 内容 |
|---|---|
| **描述** | 单例管理器，协调多个 FolderWatcher，处理生命周期和自动处理流程 |
| **新增文件** | `Services/Monitor/FolderMonitorManager.swift` |
| **实现要点** | 1. 管理 `[UUID: FolderWatcher]` 字典<br>2. `start(folder:)` — 恢复 bookmark 权限 → 创建 FolderWatcher → 注册回调<br>3. 回调中：加载关联 Preset → 构建 ProcessingConfiguration → PipelineBuilder.build() → Pipeline.run()<br>4. `restoreAndStart()` — App 启动时从 Store 恢复所有活跃监控<br>5. `stopAll()` — App 退出时清理<br>6. `@Published var activeFolders: [MonitoredFolder]` 供 UI 绑定 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add FolderMonitorManager for coordinating folder watchers` |

### Task 2.4 — 文件夹监控设置 UI

| 项目 | 内容 |
|---|---|
| **描述** | 监控设置界面：管理监控目录、关联预设、输出目录 |
| **新增文件** | `Views/Monitor/FolderMonitorSettingsView.swift` |
| **修改文件** | `App/Commands/AppCommands.swift`（添加菜单项） |
| **实现要点** | 1. 列表展示已配置的监控目录<br>2. 每行：目录路径 / 关联预设下拉 / 输出目录 / 启用开关<br>3. 添加按钮 → NSOpenPanel 选择目录<br>4. 删除按钮（滑动或按钮）<br>5. 菜单栏 → "文件夹监控..." (⌘⇧M) 打开 Sheet |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add folder monitor settings UI and menu entry` |

### Task 2.5 — AppDelegate 集成与启动恢复

| 项目 | 内容 |
|---|---|
| **描述** | 在 App 生命周期中集成文件夹监控的启动和停止 |
| **修改文件** | `App/ConvertCompressApp.swift` |
| **实现要点** | 1. `applicationDidFinishLaunching` 中调用 `FolderMonitorManager.shared.restoreAndStart()`<br>2. 添加 `applicationWillTerminate` 调用 `FolderMonitorManager.shared.stopAll()` |
| **验证标准** | 构建通过；手动验证：启动 App → 向监控目录添加图片 → 确认自动处理 |
| **提交信息** | `feat: integrate folder monitoring into app lifecycle` |

---

## 阶段三：P1-b — Apple Shortcuts 集成

### Task 3.1 — ImageFormatEntity（AppEnum）

| 项目 | 内容 |
|---|---|
| **描述** | 定义图片格式的 AppEnum，供 Shortcuts 参数选择器使用 |
| **新增文件** | `App/Intents/ImageFormatEntity.swift` |
| **实现要点** | 1. 枚举 `jpeg, png, heic, webp, avif`<br>2. 实现 `AppEnum` 协议：`typeDisplayRepresentation`、`caseDisplayRepresentations`<br>3. 提供 `toImageFormat()` 方法映射到现有 `ImageFormat` 类型 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add ImageFormatEntity AppEnum for Shortcuts integration` |

### Task 3.2 — IntentsPipeline 无 UI 处理桥接

| 项目 | 内容 |
|---|---|
| **描述** | 封装从 IntentFile 到 Pipeline 处理再到 IntentFile 输出的完整流程，不依赖 ViewModel |
| **新增文件** | `Services/Processing/IntentsPipeline.swift` |
| **实现要点** | 1. `static func process(files:format:quality:operations:) async throws -> [IntentFile]`<br>2. 将 IntentFile.data 写入临时文件<br>3. 构建 ProcessingConfiguration → PipelineBuilder.build() → Pipeline.renderEncodedData()<br>4. 将结果 Data 包装为 IntentFile 返回<br>5. 清理临时文件 |
| **验证标准** | 构建通过；单元测试验证处理流程（用测试图片） |
| **测试文件** | `convert-compress-tests/IntentsPipelineTests.swift` |
| **提交信息** | `feat: add IntentsPipeline for headless image processing` |

### Task 3.3 — ConvertImageIntent

| 项目 | 内容 |
|---|---|
| **描述** | 实现"转换图片"Shortcuts Action：支持格式转换 + 质量设置 |
| **新增文件** | `App/Intents/ConvertImageIntent.swift` |
| **实现要点** | 1. 参数：`@Parameter images: [IntentFile]`、`format: ImageFormatEntity`、`quality: Int`<br>2. `perform()` 调用 `IntentsPipeline.process()`<br>3. 返回 `ReturnsValue<[IntentFile]>` |
| **验证标准** | 构建通过；手动在 Shortcuts app 中验证 Action 可见并可执行 |
| **提交信息** | `feat: add ConvertImageIntent Shortcuts action` |

### Task 3.4 — ResizeImageIntent

| 项目 | 内容 |
|---|---|
| **描述** | 实现"缩放图片"Shortcuts Action |
| **新增文件** | `App/Intents/ResizeImageIntent.swift` |
| **实现要点** | 1. 参数：images、width（可选）、height（可选）、percentage（可选）<br>2. 根据参数构建 ResizeOperation<br>3. 通过 IntentsPipeline 处理 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add ResizeImageIntent Shortcuts action` |

### Task 3.5 — RemoveBackgroundIntent

| 项目 | 内容 |
|---|---|
| **描述** | 实现"去除背景"Shortcuts Action |
| **新增文件** | `App/Intents/RemoveBackgroundIntent.swift` |
| **实现要点** | 1. 参数：images<br>2. 构建 RemoveBackgroundOperation<br>3. 输出格式默认 PNG（保留透明度） |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add RemoveBackgroundIntent Shortcuts action` |

### Task 3.6 — AppShortcutsProvider 注册

| 项目 | 内容 |
|---|---|
| **描述** | 注册所有 Intent 到 Shortcuts app，提供推荐短语 |
| **新增文件** | `App/Intents/AppShortcutsProvider.swift` |
| **实现要点** | 1. 实现 `AppShortcutsProvider` 协议<br>2. 定义 `appShortcuts` 包含所有 Intent 的 `AppShortcut`<br>3. 添加推荐短语（中英文） |
| **验证标准** | 构建通过；Shortcuts app 中可搜索到 Convert & Compress 的 Actions |
| **提交信息** | `feat: register app shortcuts provider with all intents` |

---

## 阶段四：P1-c — 批量重命名

### Task 4.1 — NamingTemplate 模型

| 项目 | 内容 |
|---|---|
| **描述** | 定义重命名模板数据模型，支持占位符系统 |
| **新增文件** | `Core/Models/NamingTemplate.swift` |
| **实现要点** | 1. 属性：`isEnabled: Bool`、`pattern: String`<br>2. `Codable` 实现（兼容 Preset 序列化）<br>3. 支持占位符文档注释：`{name}`、`{n}`、`{n:03}`、`{date}`、`{datetime}`、`{w}`、`{h}` |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add NamingTemplate model for batch rename patterns` |

### Task 4.2 — NamingTemplateResolver

| 项目 | 内容 |
|---|---|
| **描述** | 模板解析引擎，将模板 + 上下文解析为最终文件名 |
| **新增文件** | `Services/Processing/NamingTemplateResolver.swift` |
| **实现要点** | 1. 正则匹配 `\{(\w+)(?::(\w+))?\}` 提取占位符<br>2. 逐一替换为上下文值<br>3. 过滤非法文件名字符（`/`、`:`、`\0`）<br>4. 同批次冲突检测：追加 `_1`、`_2` 后缀 |
| **验证标准** | 构建通过；单元测试覆盖所有占位符和边界情况 |
| **测试文件** | `convert-compress-tests/NamingTemplateResolverTests.swift` |
| **提交信息** | `feat: add NamingTemplateResolver with placeholder support` |

### Task 4.3 — 集成重命名到 Pipeline

| 项目 | 内容 |
|---|---|
| **描述** | 将 NamingTemplate 集成到处理管道的输出路径计算中 |
| **修改文件** | `Core/Models/ProcessingConfiguration.swift`、`Processing/Pipeline.swift`、`Services/Processing/PipelineBuilder.swift` |
| **实现要点** | 1. `ProcessingConfiguration` 新增 `namingTemplate: NamingTemplate?`（可选，Codable 兼容）<br>2. `Pipeline.destinationPlan()` 中：若 template.isEnabled，用 Resolver 结果替换 base filename<br>3. `PipelineBuilder.build()` 传递 namingTemplate 到 Pipeline |
| **验证标准** | 构建通过；单元测试验证带模板的导出路径生成 |
| **测试文件** | `convert-compress-tests/PipelineNamingTests.swift` |
| **提交信息** | `feat: integrate naming template into processing pipeline` |

### Task 4.4 — ViewModel 集成

| 项目 | 内容 |
|---|---|
| **描述** | 在 ViewModel 中暴露重命名配置属性 |
| **修改文件** | `ViewModels/ImageToolsViewModel.swift`、`ViewModels/ImageToolsViewModel+Processing.swift` |
| **实现要点** | 1. 新增 `@Published var namingTemplate = NamingTemplate()`<br>2. `buildConfiguration()` 中将 namingTemplate 传入 ProcessingConfiguration<br>3. 预设保存/加载时包含 namingTemplate |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: expose naming template in ViewModel` |

### Task 4.5 — 重命名 UI 控件

| 项目 | 内容 |
|---|---|
| **描述** | 在 ControlsBar 添加重命名按钮和配置 Popover |
| **新增文件** | `Views/Controls/NamingTemplateControl.swift` |
| **修改文件** | ControlsBar 相关视图（添加按钮入口） |
| **实现要点** | 1. 紧凑按钮图标（`textformat.abc`），与现有控件风格一致<br>2. Popover 包含：启用开关、模板输入框、占位符说明、实时预览<br>3. 快捷模板按钮：`{name}_compressed`、`{date}_{n:03}`、`product_{n:03}`<br>4. 预览显示第一张已加载图片的重命名结果 |
| **验证标准** | 构建通过 |
| **提交信息** | `feat: add naming template UI control in controls bar` |

---

## 阶段五：收尾

### Task 5.1 — 版本号更新

| 项目 | 内容 |
|---|---|
| **描述** | 更新版本号为 1.4.0 |
| **修改文件** | 项目配置（Info.plist 或 Xcode 项目设置中的 MARKETING_VERSION） |
| **提交信息** | `chore: update version number to 1.4.0` |

### Task 5.2 — 本地化字符串

| 项目 | 内容 |
|---|---|
| **描述** | 为所有新增 UI 文案添加多语言翻译（15+ 语言） |
| **修改文件** | `Localizable.xcstrings` |
| **实现要点** | 覆盖：文件夹监控设置、重命名控件、错误汇总弹窗、Shortcuts Action 标题/描述、压缩率文案 |
| **提交信息** | `feat: add localization for v1.4.0 features` |

### Task 5.3 — 全量集成测试

| 项目 | 内容 |
|---|---|
| **描述** | 端到端手动测试所有新功能 |
| **验证清单** | 1. 加载 500+ 张图片批量导出，验证内存压力下不崩溃<br>2. 故意混入损坏图片，验证错误跳过和汇总<br>3. BottomBar 压缩率显示正确<br>4. 配置文件夹监控 → 向目录添加图片 → 验证自动处理<br>5. Shortcuts app 中搜索并执行 Convert/Resize/RemoveBackground Action<br>6. 启用重命名模板 → 批量导出 → 验证文件名符合模板<br>7. 保存含重命名的预设 → 重新加载 → 验证预设完整性 |

---

## 任务依赖关系

```
阶段一（P0）— 可独立开发
  Task 1.1 → Task 1.2（内存监控 → 集成到导出）
  Task 1.3 → Task 1.4（错误处理 → 错误 UI）
  Task 1.5（独立）

阶段二（P1-a）— 可与阶段三并行
  Task 2.1 → Task 2.2 → Task 2.3 → Task 2.4 → Task 2.5

阶段三（P1-b）— 可与阶段二并行
  Task 3.1 → Task 3.2 → Task 3.3 / Task 3.4 / Task 3.5（3.3-3.5 可并行）→ Task 3.6

阶段四（P1-c）— 依赖阶段一完成（Pipeline 变更需稳定后再扩展）
  Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4 → Task 4.5

阶段五（收尾）— 依赖所有阶段完成
  Task 5.1 + Task 5.2 → Task 5.3
```

---

## 预估工作量

| 阶段 | 任务数 | 预估复杂度 |
|---|---|---|
| 阶段一：P0 核心优化 | 5 | 中等 |
| 阶段二：文件夹监控 | 5 | 高（涉及文件系统、沙盒、持久化） |
| 阶段三：Shortcuts 集成 | 6 | 中等（AppIntents 框架学习曲线） |
| 阶段四：批量重命名 | 5 | 中低（纯逻辑 + UI） |
| 阶段五：收尾 | 3 | 低 |
| **合计** | **24** | — |
