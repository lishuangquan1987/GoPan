class FileNode {
  final String id;
  final String name;
  final bool isFolder;
  final int size;
  final String? parentId;
  final String? mimeType;
  final String? hash;
  final DateTime updatedAt;
  final bool isDeleted;

  FileNode({
    required this.id,
    required this.name,
    required this.isFolder,
    required this.size,
    this.parentId,
    this.mimeType,
    this.hash,
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory FileNode.fromJson(Map<String, dynamic> j) => FileNode(
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? '',
        isFolder: j['is_folder'] ?? false,
        size: j['size'] ?? 0,
        parentId: j['parent_id']?.toString(),
        mimeType: j['mime_type'],
        hash: j['hash'],
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at']) ?? DateTime.now()
            : DateTime.now(),
        isDeleted: j['is_deleted'] ?? false,
      );
}

class FileListResponse {
  final List<FileNode> files;
  final int total;
  final int page;
  final int pageSize;

  FileListResponse({
    required this.files,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory FileListResponse.fromJson(Map<String, dynamic> j) => FileListResponse(
        files: (j['files'] as List? ?? []).map((e) => FileNode.fromJson(e)).toList(),
        total: j['total'] ?? 0,
        page: j['page'] ?? 1,
        pageSize: j['page_size'] ?? 50,
      );
}
