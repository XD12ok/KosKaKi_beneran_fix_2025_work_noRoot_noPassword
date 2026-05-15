class RatingKos {
  static Map<String, List<int>> data = {};

  static void addRating(String kosName, int rating) {
    data.putIfAbsent(kosName, () => []);
    data[kosName]!.add(rating);
  }

  static double getAverage(String kosName) {
    final list = data[kosName] ?? [];
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }


  static int getTotal(String kosName) {
    return data[kosName]?.length ?? 0;
  }
}