import 'package:flutter/material.dart';

String logoForMerchant(String name) {
  final key = name.toLowerCase();
  if (key.contains('netflix'))      return 'assets/images/netflix.png';
  if (key.contains('spotify'))      return 'assets/images/spotify.png';
  if (key.contains('shahid'))       return 'assets/images/shahid.png';
  return 'assets/images/default.png';
}

String logoForIssuer(String issuer) {
  final key = issuer.toLowerCase();
  if (key.contains('arab bank'))    return 'assets/images/arab_bank.png';
  if (key.contains('zain cash'))    return 'assets/images/zain.jpg';
  // …
  return 'assets/images/default.png';
}


IconData iconForFixedExpense(String name) {
  final key = name.toLowerCase();
  if (key.contains('water')) return Icons.water;        // water bill
  if (key.contains('electric')) return Icons.flash_on;     // electricity
  if (key.contains('internet')) return Icons.wifi;         // internet
  if (key.contains('rent')) return Icons.home;         // rent
  if (key.contains('gas')) return Icons.local_gas_station;
  if (key.contains('phone')) return Icons.phone_android;
  // fallback icon:
  return Icons.home;
}

IconData iconForVariableExpense(String category) {
  final key = category.toLowerCase();
  if (key.contains('grocer')) return Icons.local_grocery_store;
  if (key.contains('food')) return Icons.fastfood;
  if (key.contains('transport')) return Icons.directions_car;
  if (key.contains('fuel')) return Icons.local_gas_station;
  if (key.contains('entertain')) return Icons.movie;
  if (key.contains('coffee')) return Icons.local_cafe;
  if (key.contains('shopping')) return Icons.shopping_bag;
  if (key.contains('health')) return Icons.health_and_safety;
  // fallback:
  return Icons.shopping_cart;
}