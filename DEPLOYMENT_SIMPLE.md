# GoPan 简化部署方案

## 方案说明

本方案通过 Go 后端代理 MinIO 和 kkFileView，前端只通过 GoPan API 访问，无需在 Caddy 中配置子域名。

### 优势

1. **配置简单**：Caddyfile 只需代理 GoPan 和 Blog，无需配置 MinIO 和 kkFileView 的子域名
2. **安全性好**：MinIO 和 kkFileView 不对外暴露，只通过 GoPan 后端访问
3. **解决混合内容问题**：所有文件访问都通过 HTTPS 的 GoPan API，避免混合内容错误
4. **无需 DNS 配置**：不需要为 MinIO 和 kkFileView 配置额外的 DNS 记录

## 架构说明

```
用户浏览器 (HTTPS)
    ↓
Caddy (pan.lishq.cn)
    ↓
GoPan 后端 (175.24.234.161:8080)
    ├─→ MinIO (内部 HTTP: 175.24.234.161:9000)
    └─→ kkFileView (内部 HTTP: 175.24.234.161:8012)
```

## 配置步骤

### 1. 使用简化的 Caddyfile

使用 `Caddyfile.simple` 文件：

```caddy
# GoPan 网盘服务
pan.lishq.cn {
    reverse_proxy 175.24.234.161:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
        transport http {
            dial_timeout 60s
            response_header_timeout 60s
        }
    }
}

# Blog 服务
blog.lishq.cn {
    reverse_proxy 8.134.114.124:8090 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

### 2. Config.json 保持不变

MinIO 和 kkFileView 配置保持使用内部 HTTP 地址：

```json
{
  "minio": {
    "endpoint": "175.24.234.161:9000",
    "use_ssl": false,
    ...
  },
  "preview": {
    "kkfileview": {
      "enabled": true,
      "base_url": "http://175.24.234.161:8012"
    }
  }
}
```

### 3. 重新加载配置

```bash
# 重新加载 Caddy
caddy reload --config /path/to/Caddyfile.simple

# 重启 GoPan（如果已运行）
systemctl restart gopan
```

## API 变更说明

### 新增接口

1. **文件代理接口**：`GET /api/files/:id/proxy`
   - 用于预览文件（不触发下载）
   - 返回文件流，设置正确的 Content-Type
   - 不设置 Content-Disposition，浏览器可以内联显示

2. **kkFileView 代理接口**：`GET /api/preview/kkfileview/:id` 和 `GET /api/preview/kkfileview/:id/*path`
   - 代理所有 kkFileView 请求
   - 自动将文件 URL 转换为 GoPan 代理 URL
   - 支持 kkFileView 的所有路径和参数

### 预览 URL 变化

**之前**（直接使用 MinIO presigned URL）：
- Office: `https://view.officeapps.live.com/op/view.aspx?src=http://175.24.234.161:9000/...` ❌ 混合内容错误
- PDF: `/pdfjs/web/viewer.html?file=http://175.24.234.161:9000/...` ❌ 混合内容错误
- kkFileView: `http://175.24.234.161:8012/onlinePreview?url=...` ❌ 外部无法访问

**现在**（使用 GoPan 代理 URL）：
- Office: `https://view.officeapps.live.com/op/view.aspx?src=https://pan.lishq.cn/api/files/123/proxy` ✅
- PDF: `/pdfjs/web/viewer.html?file=https://pan.lishq.cn/api/files/123/proxy` ✅
- kkFileView: `https://pan.lishq.cn/api/preview/kkfileview/123/onlinePreview` ✅

## 工作原理

### 文件预览流程

1. 前端调用 `GET /api/preview/:id`
2. 后端返回预览信息，URL 使用 `https://pan.lishq.cn/api/files/:id/proxy`
3. 前端加载预览时，请求通过 Caddy → GoPan → MinIO（内部 HTTP）
4. 所有请求都是 HTTPS，避免混合内容问题

### kkFileView 预览流程

1. 前端调用 `GET /api/preview/:id`，返回 kkFileView URL
2. kkFileView URL 为 `https://pan.lishq.cn/api/preview/kkfileview/:id/onlinePreview`
3. 前端加载 iframe，请求通过 Caddy → GoPan → kkFileView（内部 HTTP）
4. GoPan 后端将文件 URL 转换为代理 URL 后转发给 kkFileView

## 验证

1. **检查文件预览**：
   - 打开浏览器开发者工具
   - 查看 Network 标签
   - 确认所有请求都是 HTTPS
   - 确认没有混合内容错误

2. **检查 kkFileView**：
   - 预览一个支持的文件（如 CAD、压缩包等）
   - 确认 iframe 可以正常加载
   - 查看 Network，确认请求路径为 `/api/preview/kkfileview/...`

## 注意事项

1. **性能**：文件通过 GoPan 后端代理，会有一定的性能开销，但对于预览场景可以接受

2. **大文件**：如果预览大文件，确保 GoPan 的超时设置足够长

3. **缓存**：代理接口设置了 `Cache-Control: public, max-age=3600`，浏览器会缓存 1 小时

4. **安全性**：所有文件访问都经过 GoPan 的认证中间件，确保用户只能访问自己的文件

## 故障排查

### 预览无法加载

1. 检查 Caddy 是否正确传递了 `X-Forwarded-Proto` 和 `X-Forwarded-Host`
2. 检查浏览器控制台是否有错误
3. 检查 GoPan 日志，确认后端可以访问 MinIO 和 kkFileView

### kkFileView 无法工作

1. 确认 kkFileView 服务正常运行（`http://175.24.234.161:8012`）
2. 检查 GoPan 日志，查看代理请求是否成功
3. 确认 Config.json 中的 `base_url` 配置正确

