# GoPan Flutter 客户端

GoPan 网盘的跨平台 Flutter 客户端，支持 Windows / Linux / macOS / Android / iOS / Web。

## 技术栈

- Flutter 3.32+ / Dart 3.8+
- 状态管理：GetX（MVVM，Controller = ViewModel）
- 网络：Dio（JWT 拦截器）
- 本地存储：get_storage
- 拖拽上传：desktop_drop
- 窗口管理：window_manager（Desktop）

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 运行

```bash
# Windows
flutter run -d windows

# Web
flutter run -d chrome

# Android
flutter run -d android

# macOS
flutter run -d macos
```

### 3. 配置服务器地址

首次启动后，在登录页点击「服务器设置」，填入 GoPan 后端地址（默认 `http://localhost:8080`）。

## 项目结构

```
lib/
├── main.dart                  # 入口，初始化 window_manager
├── app/
│   ├── routes/                # GetX 路由
│   └── bindings/              # 全局依赖注入
├── core/
│   ├── network/               # ApiClient (Dio + JWT)、接口常量
│   ├── storage/               # LocalStorage (token/serverUrl)
│   └── utils/                 # 文件工具、平台工具
├── data/
│   ├── models/                # UserModel, FileNode, ShareModel, CapacityModel
│   └── repositories/          # AuthRepo, FileRepo, ShareRepo
└── presentation/
    ├── auth/                  # 登录/注册
    ├── dashboard/             # 主界面（文件管理器）
    ├── preview/               # 文件预览（图片/PDF/视频/文本）
    ├── share/                 # 分享管理
    ├── trash/                 # 回收站
    └── settings/              # 设置
```

## 功能

- 文件浏览（列表/网格视图，排序，面包屑导航）
- 文件上传（普通上传 / 分片上传 / 秒传）
- 拖拽上传（Desktop / Web）
- 文件下载（下载后用系统应用打开）
- 文件预览（图片、PDF、视频、文本/代码）
- 文件操作（重命名、删除、移动、复制）
- 分享（永久/限时，可设密码，生成 Web 可访问链接）
- 回收站（恢复 / 永久删除）
- 容量显示
- 自定义标题栏（Desktop，可拖动，最小化/最大化/关闭）

## 构建

```bash
# Windows 发布包
flutter build windows --release

# Web
flutter build web --release

# Android APK
flutter build apk --release
```
