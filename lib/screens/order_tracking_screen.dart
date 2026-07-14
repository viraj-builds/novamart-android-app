import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order $orderId'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStep('Order Placed', 'Your order has been placed', true, true),
            _buildStep('Packed', 'Your order is being packed', true, true),
            _buildStep('Shipped', 'Your order is on the way', true, false),
            _buildStep('Delivered', 'Expected by 25 Oct', false, false),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String title, String subtitle, bool isCompleted, bool isActive) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: isCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            if (title != 'Delivered')
              Container(
                width: 2,
                height: 50,
                color: isCompleted ? Colors.green : Colors.grey,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey)),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
          ],
        ),
      ],
    );
  }
}
