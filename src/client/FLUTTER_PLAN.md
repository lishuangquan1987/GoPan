# GoPan Flutter 客户端开发计划

## 概述

基于现有 GoPan 后端 REST API，使用 Flutter + GetX 开发跨平台客户端，严格遵循 MVVM 架构模式。

- 目标平台：Windows / Linux / macOS / Android / iOS / Web
- 状态管理：GetX（Controller = ViewModel）
- UI 风格：Desktop/Web 与现有前端保持一致（Windows 资源管理器风格，主色 `#0078d4`）
- 移动端：适配触控交互，保持视觉一致性

---

## 技术选型

| 类别 | 选型 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | 跨平台 |
| 状态管理 | GetX | Controller 充当 ViewModel |
| 网络 | Dio | HTTP 客户端，支持拦截器 |
| 本地存储 | get_storage | Token/配置持久化 |
| 文件选择 | file_picker | 跨平台文件选择 |
| 文件下载 | dio + path_provider | 下载到本地 |
| 图片预览 | photo_view | 图片缩放预览 |
| PDF 预览 | flutter_pdfview | PDF 预览 |
| 视频预览 | video_player | 视频播放 |
| 代码高亮 | flutter_highlight | 代码文件预览 |
| 图标 | flutter_svg / Material Icons | 文件类型图标 |
| 国际化 | GetX i18n | 中英文 |

---

## 项目结构（MVVM）

```
client/gopan_flutter/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── routes/          # GetX 路由定义
│   │   │   ├── app_pages.dart
│   │   │   └── app_routes.dart
│   │   └── bindings/        # GetX 依赖注入绑定
│   │       └── initial_binding.dart
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart        # Dio 封装，JWT 拦截器
│   │   │   └── api_endpoints.dart     # 所有接口路径常量
│   │   ├── storage/
│   │   │   └── local_storage.dart     # GetStorage 封装
│   │   └── utils/
│   │       ├── file_utils.dart        # 文件大小格式化、图标映射
│   │       └── platform_utils.dart    # 平台判断工具
│   ├── data/
│   │   ├── models/                    # 数据模型（Model 层）
│   │   │   ├── user_model.dart
│   │   │   ├── file_node_model.dart
│   │   │   ├── share_model.dart
│   │   │   └── capacity_model.dart
│   │   └── repositories/              # 数据仓库（对接 API）
│   │       ├── auth_repository.dart
│   │       ├── file_repository.dart
│   │       └── share_repository.dart
│   └── presentation/
│       ├── auth/                      # 登录/注册
│       │   ├── views/
│       │   │   └── login_view.dart
│       │   ├── controllers/           # ViewModel
│       │   │   └── auth_controller.dart
│       │   └── bindings/
│       │       └── auth_binding.dart
│       ├── dashboard/                 # 主界面（文件管理器）
│       │   ├── views/
│       │   │   ├── dashboard_view.dart        # 主布局（左侧树+右侧列表）
│       │   │   ├── file_list_view.dart        # 文件列表/网格
│       │   │   └── file_tree_view.dart        # 左侧目录树
│       │   ├── controllers/
│       │   │   ├── dashboard_controller.dart  # 主 ViewModel
│       │   │   └── upload_controller.dart     # 上传 ViewModel
│       │   ├── widgets/
│       │   │   ├── file_item_widget.dart      # 文件行/格子
│       │   │   ├── breadcrumb_widget.dart     # 面包屑导航
│       │   │   ├── toolbar_widget.dart        # 工具栏
│       │   │   ├── context_menu_widget.dart   # 右键菜单
│       │   │   ├── upload_progress_widget.dart
│       │   │   └── capacity_bar_widget.dart   # 容量进度条
│       │   └── bindings/
│       │       └── dashboard_binding.dart
│       ├── share/                     # 分享页
│       │   ├── views/
│       │   │   ├── share_list_view.dart       # 我的分享
│       │   │   └── share_access_view.dart     # 访问分享链接
│       │   ├── controllers/
│       │   │   └── share_controller.dart
│       │   └── bindings/
│       │       └── share_binding.dart
│       ├── trash/                     # 回收站
│       │   ├── views/
│       │   │   └── trash_view.dart
│       │   ├── controllers/
│       │   │   └── trash_controller.dart
│       │   └── bindings/
│       │       └── trash_binding.dart
│       ├── preview/                   # 文件预览
│       │   ├── views/
│       │   │   └── preview_view.dart
│       │   ├── controllers/
│       │   │   └── preview_controller.dart
│       │   └── bindings/
│       │       └── preview_binding.dart
│       └── settings/                  # 设置（服务器地址等）
│           ├── views/
│           │   └── settings_view.dart
│           └── controllers/
│               └── settings_controller.dart
├── pubspec.yaml
└── README.md
```

---

## API 对接清单

后端 Base URL 可配置，默认 `http://localhost:8080`。

### 认证
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/register` | 注册 |
| POST | `/api/auth/login` | 登录，返回 JWT token |
| POST | `/api/auth/logout` | 登出 |
| GET  | `/api/auth/me` | 获取当前用户信息 |

### 文件管理
| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/files?parent_id=&page=&sort_by=` | 获取文件列表 |
| GET  | `/api/files/tree` | 获取目录树 |
| GET  | `/api/files/search?keyword=` | 搜索文件 |
| POST | `/api/files/upload` | 普通上传 |
| POST | `/api/files/upload/status` | 检查分片上传状态 |
| POST | `/api/files/upload/chunk` | 分片上传 |
| POST | `/api/files/upload/cancel` | 取消上传 |
| POST | `/api/files/quick-upload` | 秒传（hash 匹配） |
| POST | `/api/files/folder` | 创建文件夹 |
| GET  | `/api/files/:id/download` | 下载文件 |
| GET  | `/api/files/:id/proxy` | 代理访问（预览用） |
| PUT  | `/api/files/:id` | 重命名 |
| PUT  | `/api/files/move` | 移动 |
| PUT  | `/api/files/copy` | 复制 |
| DELETE | `/api/files/:id` | 删除（移入回收站） |

### 回收站
| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/files/trash` | 获取回收站列表 |
| POST | `/api/files/restore` | 恢复文件 |
| DELETE | `/api/files/trash/:id` | 永久删除 |

### 分享
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/shares` | 创建分享 |
| GET  | `/api/shares` | 我的分享列表 |
| DELETE | `/api/shares/:id` | 删除分享 |
| GET  | `/api/shares/:code` | 访问分享（公开） |
| GET  | `/api/shares/:code/download` | 下载分享文件 |
| GET  | `/api/shares/:code/folder/:id` | 浏览分享文件夹 |
| POST | `/api/shares/:code/save` | 保存到我的网盘 |

### 容量
| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/user/capacity` | 获取容量信息 |

### 预览
| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/preview/:id` | 获取预览信息 |

---

## MVVM 架构说明

```
View  ←→  Controller (GetX)  ←→  Repository  ←→  ApiClient (Dio)
           (ViewModel)                              ↕
                                              Model (dart class)
```

- **Model**：纯数据类，`fromJson` / `toJson`，无业务逻辑
- **Repository**：封装所有 API 调用，返回 Model 对象，处理异常
- **Controller**：继承 `GetxController`，持有 `RxList`/`RxBool` 等响应式状态，调用 Repository，不直接操作 UI
- **View**：继承 `GetView<XxxController>`，通过 `Obx` 响应状态变化，不含业务逻辑
- **Binding**：每个路由对应一个 Binding，负责 `Get.lazyPut` 注入 Controller 和 Repository

---

## UI 设计规范

### 颜色
- 主色：`#0078d4`（Windows 蓝）
- 选中背景：`#0078d4`，选中文字：白色
- Hover 背景：`#f3f4f6`
- 文件夹图标：`#fbbf24`（黄色）
- 工具栏背景：`#f9fafb`
- 边框：`#e5e7eb`

### 文件类型图标颜色
| 类型 | 颜色 |
|------|------|
| 文件夹 | `#fbbf24` |
| 图片 | `#10b981` |
| 视频 | `#ef4444` |
| 音频 | `#8b5cf6` |
| 文档 | `#3b82f6` |
| PDF | `#dc2626` |
| 压缩包 | `#f59e0b` |
| 代码 | `#6366f1` |
| 其他 | `#6b7280` |

### 布局（Desktop/Web）
```
┌─────────────────────────────────────────────────────┐
│  工具栏（上传、新建文件夹、下载、删除、分享...）         │
├──────────────┬──────────────────────────────────────┤
│              │  面包屑导航                            │
│  左侧目录树   ├──────────────────────────────────────┤
│  - 我的文件   │  文件列表（表格视图 / 网格视图）         │
│  - 分享      │  支持：单击选中、Ctrl多选、右键菜单       │
│  - 回收站    │  拖拽上传                               │
│              │                                      │
├──────────────┴──────────────────────────────────────┤
│  状态栏：已选 N 项 | 容量进度条                        │
└─────────────────────────────────────────────────────┘
```

### 布局（Mobile）
- 隐藏左侧树，改为底部导航栏（文件 / 分享 / 回收站 / 设置）
- 文件列表默认网格视图
- 长按进入多选模式

---

## 开发阶段

### Phase 1 — 项目初始化与基础架构（约 1 天）
- [ ] `flutter create gopan_flutter` 初始化项目，配置多平台支持
- [ ] 添加依赖：`get`, `dio`, `get_storage`, `file_picker`, `path_provider`
- [ ] 实现 `ApiClient`（Dio + JWT 拦截器 + 错误处理）
- [ ] 实现 `LocalStorage`（token、服务器地址持久化）
- [ ] 定义所有 Model 类
- [ ] 配置 GetX 路由（`AppPages` / `AppRoutes`）
- [ ] 实现 `InitialBinding`（全局依赖注入）

### Phase 2 — 认证模块（约 0.5 天）
- [ ] `AuthRepository`：register / login / logout / me
- [ ] `AuthController`：登录状态、表单验证、错误提示
- [ ] `LoginView`：登录/注册表单，响应式布局（Desktop 居中卡片，Mobile 全屏）
- [ ] 路由守卫：未登录跳转登录页

### Phase 3 — 文件管理核心（约 3 天）
- [ ] `FileRepository`：getFiles / createFolder / rename / delete / move / copy / search
- [ ] `DashboardController`：
  - 当前目录、面包屑路径、文件列表
  - 多选状态（selectedIds）
  - 视图模式切换（列表/网格）
  - 排序（名称/大小/时间）
- [ ] `DashboardView`（Desktop/Web）：左侧树 + 右侧列表双栏布局
- [ ] `DashboardView`（Mobile）：单栏 + 底部导航
- [ ] `FileListView`：表格视图 + 网格视图，支持点击/多选
- [ ] `FileTreeView`：可折叠目录树
- [ ] `BreadcrumbWidget`：面包屑导航，可点击跳转
- [ ] `ToolbarWidget`：操作按钮（根据选中状态动态显示）
- [ ] `ContextMenuWidget`：右键菜单（Desktop）/ 长按菜单（Mobile）
- [ ] `CapacityBarWidget`：容量进度条

### Phase 4 — 上传下载（约 1.5 天）
- [ ] `UploadController`：
  - 普通上传（< 10MB）
  - 分片上传（>= 10MB，带进度）
  - 秒传（先计算 SHA256 hash）
  - 上传队列管理
- [ ] `UploadProgressWidget`：上传进度浮层
- [ ] 下载文件（移动端保存到下载目录，Desktop 弹出保存对话框）
- [ ] 拖拽上传（Desktop/Web）

### Phase 5 — 文件预览（约 1 天）
- [ ] `PreviewController`：根据文件类型路由到对应预览器
- [ ] 图片预览：`photo_view`
- [ ] PDF 预览：`flutter_pdfview`
- [ ] 视频预览：`video_player`
- [ ] 文本/代码预览：`flutter_highlight`
- [ ] 不支持的类型：显示文件信息 + 下载按钮

### Phase 6 — 分享模块（约 1 天）
- [ ] `ShareRepository`：createShare / getMyShares / deleteShare / getShare / saveToMyDrive
- [ ] `ShareController`：分享列表、创建分享对话框（设置有效期/密码）
- [ ] `ShareListView`：我的分享列表，显示分享链接、访问次数
- [ ] `ShareAccessView`：通过分享码访问，支持密码验证、浏览文件夹、保存到网盘

### Phase 7 — 回收站（约 0.5 天）
- [ ] `TrashController`：获取回收站、恢复、永久删除
- [ ] `TrashView`：回收站文件列表

### Phase 8 — 设置与收尾（约 0.5 天）
- [ ] `SettingsView`：服务器地址配置、退出登录
- [ ] 适配各平台窗口标题栏（Desktop）
- [ ] 响应式断点：`< 600px` 移动端，`>= 600px` 桌面端
- [ ] 错误处理统一（网络错误、401 自动跳转登录）
- [ ] 基础测试验证

---

## 关键实现细节

### JWT 拦截器
```dart
// 请求拦截：自动附加 Authorization: Bearer <token>
// 响应拦截：401 时清除 token 并跳转登录页
```

### 秒传流程
```
选择文件 → 计算 SHA256 → POST /api/files/quick-upload
  ├─ 200 秒传成功 → 刷新列表
  └─ 404 需要上传 → 走普通/分片上传流程
```

### 分片上传流程
```
POST /api/files/upload/status  (检查已上传分片)
  → 循环 POST /api/files/upload/chunk (每片 5MB)
  → 最后一片服务端自动合并
```

### 响应式布局
```dart
// 使用 GetX + LayoutBuilder 或 MediaQuery
// isDesktop = MediaQuery.of(context).size.width >= 600
```

---

## 依赖清单（pubspec.yaml 关键部分）

```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.7.2
  dio: ^5.7.0
  get_storage: ^2.1.1
  file_picker: ^8.1.4
  path_provider: ^2.1.5
  open_file: ^3.5.10          # 下载后用系统应用打开文件
  share_plus: ^10.1.4         # 分享链接/文件到系统分享面板
  photo_view: ^0.15.0
  flutter_pdfview: ^1.3.2
  video_player: ^2.9.2
  flutter_highlight: ^0.7.0
  intl: ^0.20.1
  crypto: ^3.0.3              # SHA256 计算（秒传）
  url_launcher: ^6.3.1        # 在浏览器打开分享链接
```

---

## 预计总工期

| 阶段 | 工期 |
|------|------|
| Phase 1 基础架构 | 1 天 |
| Phase 2 认证 | 0.5 天 |
| Phase 3 文件管理 | 3 天 |
| Phase 4 上传下载 | 1.5 天 |
| Phase 5 预览 | 1 天 |
| Phase 6 分享 | 1 天 |
| Phase 7 回收站 | 0.5 天 |
| Phase 8 收尾 | 0.5 天 |
| **合计** | **~9 天** |

---

## 已确认事项

1. **服务器地址配置**：单账号单服务器，Settings 页仅配置一个服务器地址即可。
2. **移动端文件下载**：下载完成后调用系统文件管理器/系统分享面板打开文件（使用 `open_file` 或 `share_plus`）。
3. **Web 平台上传**：接受浏览器文件选择器限制，无需访问本地文件系统。
4. **分享链接格式**：生成指向现有 Web 前端的链接（`http://<server>/share.html?code=xxx`），可在浏览器直接打开，移动端通过系统分享面板分享该链接。
5. **Flutter 版本**：使用最新稳定版（Flutter 3.29.x / Dart 3.7.x）。
