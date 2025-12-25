# GoPan 文件预览问题解决方案

## 问题原因

当通过 `https://pan.lishq.cn` 访问 GoPan 时，文件预览无法工作的主要原因：

### 1. 混合内容（Mixed Content）问题 ⚠️
- MinIO 生成的 presigned URL 是 `http://175.24.234.161:9000/...`
- 前端通过 `https://pan.lishq.cn` 访问
- **浏览器会阻止 HTTPS 页面加载 HTTP 资源**（安全策略）

### 2. 外部无法访问内网 IP
- presigned URL 使用内网 IP `175.24.234.161:9000`
- 外部用户无法直接访问

### 3. Office Online Viewer 要求
- Microsoft Office Online Viewer **只接受 HTTPS URL**
- HTTP URL 会被拒绝

## 解决方案

### ✅ 方案一：通过子域名代理 MinIO（强烈推荐）

#### 步骤 1：配置 DNS
在 DNS 服务商添加以下 A 记录：
```
minio.pan.lishq.cn    -> 175.24.234.161
kkfileview.pan.lishq.cn -> 175.24.234.161  (如果使用 kkFileView)
```

#### 步骤 2：使用完整的 Caddyfile
使用 `Caddyfile.gopan` 文件，包含三个服务配置。

#### 步骤 3：修改 Config.json
```json
{
  "minio": {
    "endpoint": "minio.pan.lishq.cn",  // 改为子域名
    "access_key_id": "tony",
    "secret_access_key": "tony123456",
    "use_ssl": true,  // 改为 true（重要！）
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

#### 步骤 4：重启服务
```bash
# 重新加载 Caddy
caddy reload --config /path/to/Caddyfile.gopan

# 重启 GoPan
systemctl restart gopan  # 或你的启动方式
```

### ⚠️ 方案二：临时方案（不推荐，仅部分解决）

如果暂时无法配置子域名，可以使用 `Caddyfile.simple`，但需要：

1. **修改 GoPan 代码**：让 presigned URL 使用 `https://pan.lishq.cn/minio/...` 格式
2. **在 Caddyfile 中添加路径代理**（见下方）

这需要修改源代码，比较复杂。

## 推荐的 Caddyfile 配置

使用 `Caddyfile.gopan`，包含：

1. **pan.lishq.cn** - GoPan 主服务
2. **minio.pan.lishq.cn** - MinIO 对象存储（HTTPS）
3. **kkfileview.pan.lishq.cn** - kkFileView 预览服务（HTTPS）

## 验证

配置完成后，检查：

1. **DNS 解析**：
```bash
nslookup minio.pan.lishq.cn
```

2. **HTTPS 访问**：
```bash
curl -I https://minio.pan.lishq.cn
```

3. **浏览器控制台**：
   - 打开开发者工具
   - 查看 Network 标签
   - 确认没有混合内容错误

## 关键配置说明

### Caddyfile 中的关键项：

1. **请求头传递**：
   ```
   header_up X-Forwarded-Proto {scheme}  # 传递协议（HTTP/HTTPS）
   header_up X-Forwarded-Host {host}      # 传递域名
   ```

2. **MinIO 认证**：
   ```
   header_up Authorization {>Authorization}  # 传递认证头
   ```

3. **超时设置**：
   ```
   dial_timeout 120s  # 大文件传输需要更长超时
   ```

## 常见问题

**Q: 配置后预览仍然无法工作？**
- 检查 DNS 是否解析正确
- 检查 Config.json 中的 `use_ssl` 是否为 `true`
- 检查 endpoint 是否已改为 HTTPS 域名
- 查看浏览器控制台的错误信息

**Q: MinIO 认证失败？**
- 确保 Caddyfile 中包含 `header_up Authorization {>Authorization}`

**Q: 不想使用子域名？**
- 需要修改 GoPan 源代码，让 presigned URL 使用路径格式
- 这需要更多开发工作，不推荐

