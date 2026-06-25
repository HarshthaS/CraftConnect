class RecommendationLogic {

  static List<Map<String, dynamic>> suggestProducts({
    required List<Map<String, dynamic>> allProducts,
    required List<String> viewedMaterials,
    required List<String> purchasedMaterials,
  }) {
    return allProducts.where((product) {
      final material = product["material"]?.toString().toLowerCase() ?? "";

      return viewedMaterials.contains(material) ||
          purchasedMaterials.contains(material);
    }).toList();
  }
}
