// lib/screens/checkout_screen.dart
//
// The complete checkout flow (cart review, address form, and demo payment
// simulation) lives in cart_screen.dart, which already implements all
// requirements from Steps 6–8.
//
// This file is kept as a thin redirect so that any navigation calls to
// CheckoutScreen continue to work without changes to callers.

import 'package:flutter/material.dart';

import 'cart_screen.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Delegate to CartScreen which implements the full checkout flow.
    return const CartScreen();
  }
}
