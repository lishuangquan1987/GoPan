# GoPan - 个人网盘系统

一个功能完整的网盘系统，使用 Go + Gin + Ent + MinIO + PostgreSQL 构建，前端使用 HTML + TailwindCSS，最终编译成单个 exe 文件运行。

## 功能特性

- ✅ 用户注册、登录、认证（JWT）
- ✅ 文件上传、下载、删除
- ✅ 文件夹创建和管理
- ✅ 文件快传（基于文件hash）
- ✅ 文件分享（永久分享和时效分享）
- ✅ 回收站功能
- ✅ 文件预览（文本、图片、PDF等）
- ✅ Windows资源管理器风格的界面
- ✅ 前端资源嵌入到exe文件

## 技术栈

- **后端**: Go 1.24.2, Gin, Ent ORM, MinIO客户端, PostgreSQL, JWT
- **前端**: HTML5, TailwindCSS, JavaScript (原生)
- **打包**: Go embed 嵌入前端资源到二进制文件

## 项目结构

```
src/
├── main.go                 # 主程序入口
├── generate.go             # Ent代码生成脚本
├── config/                 # 配置管理
├── internal/
│   ├── api/               # API路由和控制器
│   ├── auth/              # 认证相关
│   ├── database/          # 数据库连接
│   ├── storage/           # MinIO存储
│   ├── middleware/        # 中间件
│   └── preview/           # 预览服务
├── ent/                   # Ent ORM
│   └── schema/            # 数据模型
└── web/                   # 前端资源（将被嵌入）
    ├── index.html
    ├── dashboard.html
    └── share.html
```

## 环境配置

### 配置文件

程序使用 `Config.json` 文件进行配置。配置文件应放在与 `gopan.exe` 相同的目录下，或者在当前工作目录下。

**配置文件示例** (`Config.json.example`):

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080
  },
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",
    "dbname": "gopan",
    "sslmode": "disable"
  },
  "minio": {
    "endpoint": "localhost:9000",
    "access_key_id": "minioadmin",
    "secret_access_key": "minioadmin",
    "use_ssl": false,
    "bucket_name": "gopan"
  },
  "jwt": {
    "secret": "your-secret-key-change-in-production-please-use-a-strong-random-key",
    "expiration": "24h"
  }
}
```

**配置说明**:
- `server.host`: 服务器监听地址（默认: 0.0.0.0）
- `server.port`: 服务器端口（默认: 8080）
- `database.*`: PostgreSQL数据库连接配置
- `minio.*`: MinIO对象存储配置
- `jwt.secret`: JWT密钥（**必须修改为强随机密钥**）
- `jwt.expiration`: JWT过期时间（格式: "24h", "1h30m"等）

**首次使用**:
1. 复制 `Config.json.example` 为 `Config.json`
2. 根据实际情况修改配置项
3. **重要**: 修改 `jwt.secret` 为强随机密钥

## 构建和运行

### 1. 生成Ent代码

有两种方式生成Ent代码：

**方式一（推荐）**：直接运行 generate.go
```bash
cd src
go run generate.go
```

**方式二**：使用 go generate 命令
```bash
cd src
go generate
```

**方式三**：直接运行 ent 命令
```bash
cd src
go run -mod=mod entgo.io/ent/cmd/ent generate ./ent/schema
```

### 2. 编译

```bash
cd src
go build -o gopan.exe
```

编译成功后会生成 `gopan.exe` 文件（约42MB，包含所有前端资源）。

### 3. 配置

复制配置文件示例并修改：

```bash
cp Config.json.example Config.json
# 编辑 Config.json，修改数据库、MinIO和JWT配置
```

**重要**: 必须修改 `jwt.secret` 为强随机密钥！

### 4. 运行

```bash
./gopan.exe
```

程序将在 `http://localhost:8080` 启动（根据Config.json配置）。

### 5. 首次使用

1. 确保PostgreSQL和MinIO服务已启动
2. 访问 `http://localhost:8080`
3. 注册一个新账号
4. 登录后即可开始使用网盘功能

## 当前状态

✅ **项目已编译成功！** 所有核心功能已实现并修复。

### 已完成
- ✅ 所有数据库Schema已实现
- ✅ 所有API接口已实现
- ✅ 前端页面已创建
- ✅ 所有Ent API调用错误已修复
- ✅ 前端资源已嵌入到exe文件
- ✅ 程序可以正常编译运行

### 后续优化建议

1. **前端功能完善**
   - 完善文件树导航
   - 实现完整的搜索功能
   - 优化拖拽操作
   - 添加更多视图模式

2. **文件预览增强**
   - 集成PDF.js用于PDF预览
   - 添加Office文档在线预览
   - 优化代码文件语法高亮

3. **性能优化**
   - 大文件分片上传优化
   - 数据库查询优化
   - 添加缓存机制

4. **安全性增强**
   - 输入验证加强
   - 添加速率限制
   - 文件访问权限细化

5. **用户体验**
   - 添加操作提示
   - 优化错误提示
   - 添加加载动画

## 许可证

MIT License

