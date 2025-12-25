# GoPan 通过 Caddy 反向代理部署指南

## 问题说明

当 GoPan 通过 Caddy 反向代理使用 HTTPS 访问时，文件预览功能无法工作的原因：

1. **混合内容问题**：MinIO 生成的 presigned URL 是 `http://175.24.234.161:9000/...`，而前端通过 `https://pan.lishq.cn` 访问。浏览器会阻止 HTTPS 页面加载 HTTP 资源（混合内容安全策略）。

2. **外部不可访问**：presigned URL 使用内网 IP，外部用户无法直接访问。

3. **Office Online Viewer 要求**：Microsoft Office Online Viewer 需要 HTTPS URL，不接受 HTTP URL。

## 解决方案

### 方案一：通过子域名代理 MinIO（推荐）

#### 1. 配置 Caddyfile

使用提供的 `Caddyfile.gopan` 配置文件，包含三个服务：
- `pan.lishq.cn` - GoPan 主服务
- `minio.pan.lishq.cn` - MinIO 对象存储（通过 HTTPS）
- `kkfileview.pan.lishq.cn` - kkFileView 预览服务（可选）

#### 2. DNS 配置

在 DNS 服务商处添加以下 A 记录：
```
pan.lishq.cn          -> 服务器IP
minio.pan.lishq.cn    -> 服务器IP
kkfileview.pan.lishq.cn -> 服务器IP（如果使用 kkFileView）
```

#### 3. 修改 GoPan 配置

修改 `Config.json`：

```json
{
  "minio": {
    "endpoint": "minio.pan.lishq.cn",
    "access_key_id": "tony",
    "secret_access_key": "tony123456",
    "use_ssl": true,  // 改为 true，因为现在通过 HTTPS 访问
    "bucket_name": "gopan"
  },
  "preview": {
    "kkfileview": {
      "enabled": true,
      "base_url": "https://kkfileview.pan.lishq.cn"  // 改为 HTTPS
    }
  }
}
```

#### 4. 重启服务

```bash
# 重新加载 Caddy 配置
caddy reload --config /path/to/Caddyfile

# 重启 GoPan 服务
systemctl restart gopan
```

### 方案二：修改代码使用外部域名（备选）

如果不想使用子域名，可以修改代码让 presigned URL 使用外部域名。但这需要修改 GoPan 源代码。

## Caddyfile 配置说明

### 关键配置项

1. **请求头传递**：
   - `header_up Host {host}` - 保持原始 Host
   - `header_up X-Forwarded-Proto {scheme}` - 传递协议（HTTP/HTTPS）
   - `header_up X-Forwarded-Host {host}` - 传递原始域名

2. **WebSocket 支持**：
   - `header_up Connection {>Connection}`
   - `header_up Upgrade {>Upgrade}`

3. **超时设置**：
   - `dial_timeout` - 连接超时
   - `response_header_timeout` - 响应头超时

4. **MinIO 特殊处理**：
   - `header_up Authorization {>Authorization}` - 传递认证头

### 验证配置

1. 检查 Caddy 配置：
```bash
caddy validate --config /path/to/Caddyfile
```

2. 测试连接：
```bash
# 测试主服务
curl -I https://pan.lishq.cn

# 测试 MinIO（需要认证）
curl -I https://minio.pan.lishq.cn
```

## 常见问题

### Q: 预览仍然无法工作？
A: 检查以下几点：
1. DNS 是否正确解析
2. Config.json 中的 endpoint 是否已更新为 HTTPS 域名
3. use_ssl 是否设置为 true
4. 浏览器控制台是否有混合内容错误

### Q: MinIO 认证失败？
A: 确保 Caddyfile 中包含了 `header_up Authorization {>Authorization}`

### Q: 大文件上传/下载超时？
A: 增加 `dial_timeout` 和 `response_header_timeout` 的值

## 注意事项

1. **安全性**：生产环境建议限制 CORS 的 `Access-Control-Allow-Origin`，不要使用 `*`

2. **性能**：大文件传输时适当调整超时时间

3. **日志**：建议启用 Caddy 日志以便排查问题

4. **SSL 证书**：Caddy 会自动申请和管理 Let's Encrypt 证书

