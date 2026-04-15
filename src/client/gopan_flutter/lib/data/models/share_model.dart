class ShareModel {
  final String id;
  final String code;
  final String nodeId;
  final String nodeName;
  final bool isFolder;
  final int shareType; // 0: permanent, 1: temporary
  final DateTime? expiresAt;
  final int accessCount;
  final int? maxAccessCount;
  final bool hasPassword;
  final DateTime createdAt;

  ShareModel({
    required this.id,
    required this.code,
    required this.nodeId,
    required this.nodeName,
    required this.isFolder,
    required this.shareType,
    this.expiresAt,
    required this.accessCount,
    this.maxAccessCount,
    required this.hasPassword,
    required this.createdAt,
  });

  factory ShareModel.fromJson(Map<String, dynamic> j) => ShareModel(
        id: j['id']?.toString() ?? '',
        code: j['code'] ?? '',
        nodeId: j['node_id']?.toString() ?? '',
        nodeName: j['node_name'] ?? '',
        isFolder: j['is_folder'] ?? false,
        shareType: j['share_type'] ?? 0,
        expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at']) : null,
        accessCount: j['access_count'] ?? 0,
        maxAccessCount: j['max_access_count'],
        hasPassword: j['has_password'] ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
