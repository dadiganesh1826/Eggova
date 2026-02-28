class EggPrice {
  final String district;
  final double pricePerEgg;
  final double pricePerTray;
  final String priceDate;
  final bool isToday;

  EggPrice({
    required this.district,
    required this.pricePerEgg,
    required this.pricePerTray,
    required this.priceDate,
    required this.isToday,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory EggPrice.fromJson(Map<String, dynamic> json) {
    return EggPrice(
      district: json['district'] ?? '',
      pricePerEgg: _parseDouble(json['pricePerEgg'] ?? json['price_per_egg']),
      pricePerTray:
          _parseDouble(json['pricePerTray'] ?? json['price_per_tray']),
      priceDate: json['priceDate'] ?? json['price_date'] ?? '',
      isToday: json['isToday'] ?? false,
    );
  }
}
