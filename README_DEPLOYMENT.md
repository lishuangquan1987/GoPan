# GoPan 部署方案总结

## 简化方案（推荐）✅

**特点**：通过 Go 后端代理 MinIO 和 kkFileView，Caddy 只代理 GoPan 和 Blog

### 优势
- ✅ 配置简单，无需 DNS 配置
- ✅ 安全性好，内部服务不对外暴露
- ✅ 解决混合内容问题
- ✅ 无需修改 Config.json（保持内部 HTTP 地址）

### 使用文件
- `Caddyfile.simple` - 简化的 Caddy 配置
- `DEPLOYMENT_SIMPLE.md` - 详细部署说明

### 快速开始

1. **使用 Caddyfile.simple**：
```bash
caddy reload --config /path/to/Caddyfile.simple
```

2. **重启 GoPan**（如果已运行）：
```bash
systemctl restart gopan
```

3. **验证**：访问 `https://pan.lishq.cn`，测试文件预览功能

### 工作原理

- 文件预览：`https://pan.lishq.cn/api/files/:id/proxy` → GoPan 后端 → MinIO（内部 HTTP）
- kkFileView：`https://pan.lishq.cn/api/preview/kkfileview/:id` → GoPan 后端 → kkFileView（内部 HTTP）

所有请求都通过 HTTPS，避免混合内容错误。

---

## 复杂方案（不推荐）

**特点**：通过 Caddy 子域名代理所有服务

### 缺点
- ❌ 需要配置多个 DNS 记录
- ❌ 配置复杂
- ❌ 需要修改 Config.json

### 使用文件
- `Caddyfile.gopan` - 完整的 Caddy 配置（包含子域名）
- `DEPLOYMENT_GUIDE.md` - 详细部署说明

---

## 代码变更

### 新增功能

1. **文件代理接口** (`src/internal/api/file.go`)
   - `GET /api/files/:id/proxy` - 代理文件访问（用于预览）

2. **kkFileView 代理接口** (`src/internal/preview/preview.go`)
   - `GET /api/preview/kkfileview/:id` - 代理 kkFileView 请求
   - `GET /api/preview/kkfileview/:id/*path` - 代理 kkFileView 所有路径

3. **预览 URL 生成** (`src/internal/preview/preview.go`)
   - 使用 GoPan 代理 URL 替代 MinIO presigned URL
   - 自动检测协议（HTTP/HTTPS）和域名

### 路由变更

在 `src/internal/api/router.go` 中新增：
- `/api/files/:id/proxy`
- `/api/preview/kkfileview/:id`
- `/api/preview/kkfileview/:id/*path`

---

## 配置对比

### Config.json（两种方案相同）

```json
{
  "minio": {
    "endpoint": "175.24.234.161:9000",
    "use_ssl": false
  },
  "preview": {
    "kkfileview": {
      "enabled": true,
      "base_url": "http://175.24.234.161:8012"
    }
  }
}
```

### Caddyfile 对比

**简化方案**（推荐）：
```caddy
pan.lishq.cn {
    reverse_proxy 175.24.234.161:8080 { ... }
}
blog.lishq.cn {
    reverse_proxy 8.134.114.124:8090 { ... }
}
```

**复杂方案**：
```caddy
pan.lishq.cn { ... }
minio.pan.lishq.cn { ... }      # 需要 DNS
kkfileview.pan.lishq.cn { ... } # 需要 DNS
blog.lishq.cn { ... }
```

---

## 推荐使用简化方案

简化方案更符合你的需求：
- ✅ 只通过 Caddy 代理 GoPan 和 Blog
- ✅ MinIO 和 kkFileView 保持内部 HTTP 访问
- ✅ 通过 Go 后端包装，前端不直接调用内部服务

