// lib/services/delivery_logic.dart

class DeliveryLogic {
  static String getDeliveryMethod(double distance, String? material) {
    material = material?.toLowerCase() ?? "";

    bool fragile = material.contains("glass") ||
        material.contains("pottery") ||
        material.contains("ceramic") ||
        material.contains("clay");

    if (fragile) {
      if (distance > 500) return "Special Fragile Courier";
      if (distance > 100) return "Premium Courier";
      return "Hand Delivery / Local Courier";
    }

    if (distance > 1000) return "Economy Truck Service";
    if (distance > 300) return "Courier";
    return "Standard Delivery";
  }

  static double calculateDeliveryCost(double distance, String? material) {
    material = material?.toLowerCase() ?? "";

    double baseRate = 5.0;

    bool fragile = material.contains("glass") ||
        material.contains("pottery") ||
        material.contains("ceramic") ||
        material.contains("clay");

    if (fragile) baseRate += 3;

    double cost = distance * baseRate;

    if (cost < 50) cost = 50;

    return cost;
  }
}
