/// Districts where egg prices are tracked.
/// Maps district name → state name.
class DistrictData {
  static const Map<String, String> districtStateMap = {
    'Chittoor': 'Andhra Pradesh',
    'East Godavari': 'Andhra Pradesh',
    'Vijayawada': 'Andhra Pradesh',
    'Vizag': 'Andhra Pradesh',
    'West Godavari': 'Andhra Pradesh',
    'Hyderabad': 'Telangana',
    'Warangal': 'Telangana',
  };

  static List<String> get allDistricts => districtStateMap.keys.toList();

  static String getState(String district) =>
      districtStateMap[district] ?? 'Andhra Pradesh';

  /// Returns list of { district, state, label } for dropdown display
  static List<Map<String, String>> get dropdownItems {
    return districtStateMap.entries.map((e) => <String, String>{
        'district': e.key,
        'state': e.value,
        'label': '${e.key}, ${e.value}',
      }).toList();
  }
}
