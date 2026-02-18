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

  factory EggPrice.fromJson(Map<String, dynamic> json) {
    return EggPrice(
      district: json['district'] ?? '',
      pricePerEgg: (json['pricePerEgg'] ?? json['price_per_egg'] ?? 0).toDouble(),
      pricePerTray: (json['pricePerTray'] ?? json['price_per_tray'] ?? 0).toDouble(),
      priceDate: json['priceDate'] ?? json['price_date'] ?? '',
      isToday: json['isToday'] ?? false,
    );
  }
}
