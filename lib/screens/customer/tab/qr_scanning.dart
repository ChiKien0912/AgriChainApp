import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'qr_scanner.dart';
import '../../../data/store_data.dart';

class ProductTabScreen extends StatefulWidget {
  const ProductTabScreen({super.key});

  @override
  State<ProductTabScreen> createState() => _ProductTabScreenState();
}

class _ProductTabScreenState extends State<ProductTabScreen>
    with SingleTickerProviderStateMixin {
  String? scannedProductId;
  Map<String, dynamic>? productData;
  Map<String, dynamic>? orderData;
  Map<String, dynamic>? scannedOrder;

  final Duration _animDuration = const Duration(milliseconds: 400);

  Future<void> _startScanning() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result == null) return;

    try {
      final decoded = jsonDecode(result);

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('productId')) {
          final id = decoded['productId'];
          setState(() {
            scannedProductId = id;
            productData = decoded;
            scannedOrder = null;
          });

          final orderQuery = await FirebaseFirestore.instance
              .collection('orders')
              .where('items.productId', isEqualTo: id)
              .limit(1)
              .get();

          if (orderQuery.docs.isNotEmpty) {
            setState(() => orderData = orderQuery.docs.first.data());
          }
        }

        if (decoded.containsKey('orderId')) {
          setState(() {
            scannedOrder = decoded;
            scannedProductId = null;
            productData = null;
            orderData = null;
          });
        }
      }
    } catch (_) {
      Fluttertoast.showToast(msg: "QR không hợp lệ hoặc không đọc được");
    }
  }

  void restart() {
    setState(() {
      scannedProductId = null;
      productData = null;
      orderData = null;
      scannedOrder = null;
    });
  }

  Widget buildSection(String title, Color color, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProductInfo(Color themeColor) {
    if (scannedProductId == null) return const SizedBox.shrink();
    return buildSection("Thông tin sản phẩm", themeColor, [
      _infoTile("ID", scannedProductId!),
      _infoTile("Tên", productData?['productName'] ?? '-'),
      _infoTile("Thu hoạch", productData?['harvestDate'] ?? '-'),
      _infoTile("Canh tác", productData?['organicType'] ?? '-'),
      _infoTile("Phân/thuốc", productData?['fertilizer'] ?? '-'),
      _infoTile("Ghi chú", productData?['note'] ?? '-'),
      _infoTile("Chứng nhận", productData?['cert'] ?? '-'),
      _infoTile("Trang trại", productData?['farm'] ?? '-'),
    ]);
  }

  String getStoreNameById(String id) {
    final store = storeLocations.firstWhere(
      (store) => store['id'] == id,
      orElse: () => {'name': 'Không rõ cửa hàng'},
    );
    return store['name'];
  }

  Widget buildOrderInfo(Color themeColor) {
    if (scannedOrder != null) {
      final items = List<Map<String, dynamic>>.from(scannedOrder!['items']);
      return buildSection("Thông tin đơn hàng", themeColor, [
        _infoTile("Mã đơn", scannedOrder?['orderId'] ?? ''),
        _infoTile("Cửa hàng", getStoreNameById(scannedOrder?['storeId'] ?? '')),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: Text("Sản phẩm:",
              style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
        ),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("${e['name']}: ${e['quantity']}"),
                ],
              ),
            )),
      ]);
    }

    if (orderData != null) {
      return buildSection("Thông tin đơn hàng", themeColor, [
        _infoTile("Khách", orderData?['email'] ?? ''),
        _infoTile("Tổng", "${orderData?['total']}đ"),
        _infoTile("Thanh toán", orderData?['payment'] ?? ''),
        _infoTile(
            "Thời gian",
            (orderData?['timestamp'] is Timestamp)
                ? (orderData?['timestamp'] as Timestamp)
                    .toDate()
                    .toString()
                : '-'),
      ]);
    }

    return const SizedBox.shrink();
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      title: Text(value, style: const TextStyle(fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);
    final hasResult = scannedProductId != null || scannedOrder != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text('Tra cứu sản phẩm / đơn hàng'),
        backgroundColor: themeColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            onPressed: _startScanning,
            tooltip: "Quét QR",
          )
        ],
      ),
      body: AnimatedSwitcher(
        duration: _animDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: hasResult
            ? Column(
                key: const ValueKey('result'),
                children: [
                  const SizedBox(height: 18),
                  AnimatedScale(
                    scale: 1,
                    duration: _animDuration,
                    curve: Curves.elasticOut,
                    child: Icon(Icons.verified, color: themeColor, size: 60),
                  ),
                  buildProductInfo(themeColor),
                  buildOrderInfo(themeColor),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Xóa kết quả"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 24),
                ],
              )
            : Center(
                key: const ValueKey('empty'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),
                    AnimatedOpacity(
                      opacity: 1,
                      duration: _animDuration,
                      child: Icon(Icons.qr_code_2,
                          color: themeColor.withOpacity(0.7), size: 90),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Bấm biểu tượng QR để quét và tra cứu",
                      style: TextStyle(
                          fontSize: 17,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
