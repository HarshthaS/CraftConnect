import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  static Future<bool> makePayment({
    required int amount,
  }) async {
    try {

      final response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        headers: {
          "Authorization": "Bearer pk_test_51Sc7OrFJLOKa0qdlncv2zIGzoxPUaCKAdMqsncGxYkqbAjz9l8HE20N4mDDQYDpshhqZz2LbF2XwM5LSvC2CdX8v00U5D3FF13",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "amount": (amount * 100).toString(),
          "currency": "inr",
          "payment_method_types[]": "card",
        },
      );

      final json = jsonDecode(response.body);
      final clientSecret = json["client_secret"];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: "CraftConnect",
          paymentIntentClientSecret: clientSecret,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      print("Stripe error: $e");
      return false;
    }
  }
}
