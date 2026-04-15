class CapacityModel {
  final int usedQuota;
  final int totalQuota;

  CapacityModel({required this.usedQuota, required this.totalQuota});

  factory CapacityModel.fromJson(Map<String, dynamic> j) => CapacityModel(
        usedQuota: j['used_quota'] ?? 0,
        totalQuota: j['total_quota'] ?? 1,
      );

  double get ratio => totalQuota > 0 ? usedQuota / totalQuota : 0;
}
