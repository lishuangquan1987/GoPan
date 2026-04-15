import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:dio/dio.dart';
import '../controllers/preview_controller.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/storage/local_storage.dart';

class PreviewView extends GetView<PreviewController> {
  const PreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.node.value?.name ?? '预览')),
        backgroundColor: const Color(0xFF0078D4),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: controller.downloadAndOpen,
            tooltip: '下载',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final n = controller.node.value;
        if (n == null) return const Center(child: Text('无法预览'));

        if (FileUtils.isImage(n.name)) return _ImagePreview(url: controller.localPath.value);
        if (FileUtils.isPdf(n.name)) return _PdfPreview(path: controller.localPath.value);
        if (FileUtils.isVideo(n.name)) return _VideoPreview(path: controller.localPath.value);
        if (FileUtils.isText(n.name)) return _TextPreview(url: controller.localPath.value, name: n.name);
        return _UnsupportedPreview(onDownload: controller.downloadAndOpen);
      }),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String url;
  const _ImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return PhotoView(
      imageProvider: NetworkImage(url,
          headers: {'Authorization': 'Bearer ${LocalStorage.token}'}),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  final String path;
  const _PdfPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const Center(child: CircularProgressIndicator());
    return PDFView(filePath: path, enableSwipe: true, swipeHorizontal: false);
  }
}

class _VideoPreview extends StatefulWidget {
  final String path;
  const _VideoPreview({required this.path});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _vpc;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // localPath is a local file path (downloaded to temp) for video
    _vpc = VideoPlayerController.file(File(widget.path));
    _vpc.initialize().then((_) {
      setState(() => _initialized = true);
      _vpc.play();
    });
  }

  @override
  void dispose() {
    _vpc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Center(child: CircularProgressIndicator());
    return Center(
      child: AspectRatio(
        aspectRatio: _vpc.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_vpc),
            VideoProgressIndicator(_vpc, allowScrubbing: true),
            Positioned(
              bottom: 20,
              child: IconButton(
                icon: Icon(_vpc.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 32),
                onPressed: () => setState(() =>
                    _vpc.value.isPlaying ? _vpc.pause() : _vpc.play()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextPreview extends StatefulWidget {
  final String url;
  final String name;
  const _TextPreview({required this.url, required this.name});

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Dio().get(widget.url,
          options: Options(headers: {'Authorization': 'Bearer ${LocalStorage.token}'},
              responseType: ResponseType.plain));
      setState(() {
        _content = res.data.toString();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ext = FileUtils.ext(widget.name);
    return SingleChildScrollView(
      child: HighlightView(
        _content,
        language: ext.isEmpty ? 'plaintext' : ext,
        theme: githubTheme,
        padding: const EdgeInsets.all(16),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  final VoidCallback onDownload;
  const _UnsupportedPreview({required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 64, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text('此文件类型暂不支持预览', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download),
            label: const Text('下载文件'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0078D4),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
