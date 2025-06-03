import 'package:argri_chain_app/screens/customer/cart/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  String formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return format.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = const Color(0xFF388E3C);
    final Color accentColor = const Color(0xFF81C784);
    final int quantity = product['quantity'] ?? 0;
    final bool isOutOfStock = quantity <= 0;
    final TextTheme textTheme = Theme.of(context).textTheme.apply(
          fontFamily: 'Montserrat',
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        title: Text(
          "Chi tiết sản phẩm",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: themeColor,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: product['image'],
              child: Material(
                color: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: FadeInImage.assetNetwork(
                        placeholder: 'assets/images/placeholder.png',
                        image: product['image'],
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 600),
                        fadeOutDuration: const Duration(milliseconds: 200),
                        imageErrorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      product['name'],
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        letterSpacing: 0.8,
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOutOfStock ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOutOfStock ? "Hết hàng" : "Còn ${product['quantity']} sp",
                      style: textTheme.bodyMedium?.copyWith(
                        color: isOutOfStock ? Colors.red : Colors.green[800],
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: accentColor, size: 26),
                  const SizedBox(width: 4),
                  Text(
                    formatCurrency(product['price']),
                    style: textTheme.titleLarge?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, color: Colors.grey[700], size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        product['description'] ?? "Không có mô tả",
                        key: ValueKey(product['description']),
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.6,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.blue, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          "Chính hãng",
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 22),
                        const SizedBox(width: 4),
                        Text(
                          "4.8",
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: ElevatedButton.icon(
                  onPressed: isOutOfStock
                      ? null
                      : () {
                          Provider.of<CartProvider>(context, listen: false).addItem({
                            'id': product['id'],
                            'name': product['name'],
                            'image': product['image'],
                            'price': product['price'],
                          });
                          Fluttertoast.showToast(
                            msg: "Đã thêm vào giỏ hàng",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: themeColor,
                            textColor: Colors.white,
                          );
                          Navigator.pop(context);
                        },
                  icon: Icon(
                    isOutOfStock ? Icons.error_outline : Icons.add_shopping_cart,
                    size: 26,
                    color: isOutOfStock ? Colors.grey[400] : Colors.white,
                  ),
                  label: Text(
                    isOutOfStock ? "Hết hàng" : "Thêm vào giỏ hàng",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock ? Colors.grey[300] : themeColor,
                    foregroundColor: isOutOfStock ? Colors.black54 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                    elevation: 8,
                    shadowColor: themeColor.withOpacity(0.30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
