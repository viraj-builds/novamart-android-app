import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          final orderId = 'SP${1000 + index}';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.shopping_bag, color: Colors.blue),
              title: Text('Order #$orderId'),
              subtitle: const Text('Status: Delivered • 22 Oct 2023'),
              trailing: const Text('\$150.00', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.orderTracking, arguments: orderId);
              },
            ),
          );
        },
      ),
    );
  }
}
