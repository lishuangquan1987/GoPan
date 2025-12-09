# 文件预览集成说明

## 概述

已实现多种文件预览方式的集成，包括kkFileView、Office Online、PDF.js等。

## 配置说明

### Config.json配置

在`Config.json`中添加了`preview`配置项：

```json
{
  "preview": {
    "kkfileview": {
      "enabled": false,
      "base_url": "http://localhost:8012"
    }
  }
}
```

- `enabled`: 是否启用kkFileView（默认false）
- `base_url`: kkFileView服务地址（默认http://localhost:8012）

## 预览策略

### 1. 文本文件（TXT, MD等）
- **预览方式**: 直接返回文件内容
- **编辑支持**: ✅ 支持在线编辑
- **实现**: 从MinIO读取文件内容，返回给前端

### 2. Office文档（Word, Excel, PPT）
- **预览方式**: Microsoft Office Online Viewer
- **编辑支持**: ✅ 支持在线编辑
- **实现**: 使用`https://view.officeapps.live.com/op/view.aspx?src=file_url`
- **支持格式**: .doc, .docx, .xls, .xlsx, .ppt, .pptx

### 3. PDF文件
- **预览方式**: PDF.js
- **编辑支持**: ❌ 仅预览
- **实现**: 使用`/pdfjs/web/viewer.html?file=file_url`
- **注意**: 需要部署PDF.js静态资源

### 4. 其他文件格式
- **预览方式**: 
  - 如果启用kkFileView，使用kkFileView预览
  - 否则使用直接URL下载
- **编辑支持**: ❌ 仅预览/下载

## API响应格式

### 文本文件
```json
{
  "type": "text",
  "content": "文件内容",
  "mime_type": "text/plain",
  "editable": true
}
```

### Office文档
```json
{
  "type": "office",
  "url": "预览URL",
  "mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "file_name": "文件名.docx",
  "editable": true
}
```

### PDF文件
```json
{
  "type": "pdf",
  "url": "预览URL",
  "mime_type": "application/pdf",
  "file_name": "文件名.pdf"
}
```

### kkFileView预览
```json
{
  "type": "kkfileview",
  "url": "kkFileView预览URL",
  "mime_type": "application/octet-stream",
  "file_name": "文件名"
}
```

## 使用说明

### 启用kkFileView

1. 部署kkFileView服务（参考kkFileView官方文档）
2. 在`Config.json`中设置：
   ```json
   "preview": {
     "kkfileview": {
       "enabled": true,
       "base_url": "http://your-kkfileview-server:8012"
     }
   }
   ```
3. 重启应用

### 部署PDF.js

如果需要PDF预览功能，需要部署PDF.js：

1. 下载PDF.js：https://mozilla.github.io/pdf.js/
2. 将PDF.js解压到`web/static/pdfjs/`目录
3. 确保可以通过`/pdfjs/web/viewer.html`访问

## 注意事项

1. **Office Online Viewer限制**:
   - 需要文件URL可公网访问
   - 某些地区可能无法访问Microsoft服务
   - 可以考虑使用LibreOffice Online替代

2. **kkFileView**:
   - 需要单独部署kkFileView服务
   - 支持更多文件格式
   - 适合内网环境使用

3. **文件大小限制**:
   - 文本文件建议不超过10MB
   - Office文档和PDF建议不超过50MB
   - 大文件建议使用下载而非预览

## 后续优化建议

1. [ ] 添加LibreOffice Online支持
2. [ ] 实现文件编辑保存功能
3. [ ] 添加预览缓存机制
4. [ ] 支持更多文件格式
5. [ ] 添加预览水印功能

