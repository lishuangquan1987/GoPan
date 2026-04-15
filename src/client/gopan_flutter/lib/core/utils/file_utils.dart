import 'package:flutter/material.dart';

class FileUtils {
  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String ext(String name) {
    final idx = name.lastIndexOf('.');
    return idx == -1 ? '' : name.substring(idx + 1).toLowerCase();
  }

  static IconData iconData(String name, bool isFolder) {
    if (isFolder) return Icons.folder;
    switch (ext(name)) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'bmp': case 'webp': case 'svg':
        return Icons.image;
      case 'mp4': case 'avi': case 'mov': case 'mkv': case 'flv': case 'wmv':
        return Icons.video_file;
      case 'mp3': case 'wav': case 'flac': case 'aac': case 'ogg':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc': case 'docx': case 'xls': case 'xlsx': case 'ppt': case 'pptx':
        return Icons.description;
      case 'zip': case 'rar': case '7z': case 'tar': case 'gz':
        return Icons.folder_zip;
      case 'dart': case 'js': case 'ts': case 'py': case 'go': case 'java':
      case 'c': case 'cpp': case 'h': case 'cs': case 'html': case 'css':
      case 'json': case 'yaml': case 'yml': case 'xml': case 'sh':
        return Icons.code;
      case 'txt': case 'md': case 'log':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color iconColor(String name, bool isFolder) {
    if (isFolder) return const Color(0xFFFBBF24);
    switch (ext(name)) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'bmp': case 'webp': case 'svg':
        return const Color(0xFF10B981);
      case 'mp4': case 'avi': case 'mov': case 'mkv': case 'flv': case 'wmv':
        return const Color(0xFFEF4444);
      case 'mp3': case 'wav': case 'flac': case 'aac': case 'ogg':
        return const Color(0xFF8B5CF6);
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'doc': case 'docx': case 'xls': case 'xlsx': case 'ppt': case 'pptx':
        return const Color(0xFF3B82F6);
      case 'zip': case 'rar': case '7z': case 'tar': case 'gz':
        return const Color(0xFFF59E0B);
      case 'dart': case 'js': case 'ts': case 'py': case 'go': case 'java':
      case 'c': case 'cpp': case 'h': case 'cs': case 'html': case 'css':
      case 'json': case 'yaml': case 'yml': case 'xml': case 'sh':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static bool isImage(String name) =>
      ['jpg','jpeg','png','gif','bmp','webp'].contains(ext(name));
  static bool isVideo(String name) =>
      ['mp4','avi','mov','mkv','flv','wmv'].contains(ext(name));
  static bool isPdf(String name) => ext(name) == 'pdf';
  static bool isText(String name) =>
      ['txt','md','log','json','yaml','yml','xml','html','css','js','ts',
       'dart','py','go','java','c','cpp','h','cs','sh'].contains(ext(name));
}
