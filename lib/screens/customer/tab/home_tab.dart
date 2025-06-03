import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cart/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:argri_chain_app/data/store_data.dart';
import 'package:argri_chain_app/screens/customer/tab/product_detail_screen.dart';
import 'package:intl/intl.dart';
import 'store_provider.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final Color themeColor = const Color(0xFF388E3C);
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filtered = [];
  List<Map<String, dynamic>> recommendedProducts = [];

  String? selectedStoreId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<StoreProvider>(context, listen: false);
      if (provider.selectedStoreId == null) {
        _initLocationAndStore();
      } else {
        selectedStoreId = provider.selectedStoreId;
        _loadProductsForStore(selectedStoreId!);
        await _loadPersonalizedRecommendations(); 
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _initLocationAndStore() async {
    Position position = await _determinePosition();

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestStore;

    for (var store in storeLocations) {
      double dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        store['lat'],
        store['lng'],
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestStore = store;
      }
    }

    selectedStoreId = nearestStore?['id'];
    Provider.of<StoreProvider>(context, listen: false).setStore(selectedStoreId!);
    await _loadProductsForStore(selectedStoreId!);
    await _loadPersonalizedRecommendations(); 
    setState(() => isLoading = false);
  }

  Future<void> _loadProductsForStore(String storeId) async {
    final productsSnap = await FirebaseFirestore.instance.collection('products').get();
    final stockSnap = await FirebaseFirestore.instance
        .collection('branch_products')
        .where('branchId', isEqualTo: storeId)
        .get();

    final quantityMap = <String, int>{
      for (var doc in stockSnap.docs)
        (doc['productId'] as String): (doc['quantity'] as int? ?? 0),
    };

    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.setBranchStock(quantityMap);

    final merged = productsSnap.docs.map((doc) {
      final data = doc.data();
      final id = doc.id;
      final quantity = quantityMap[id] ?? 0;
      return {
        ...data,
        'id': id,
        'quantity': quantity,
      };
    }).toList();

    merged.sort((a, b) => (b['quantity'] > 0 ? 1 : 0) - (a['quantity'] > 0 ? 1 : 0));

    setState(() {
      products = merged;
      filtered = merged;
    });
  }

  void _filterProducts(String query) {
    final filteredResults = products
        .where((product) =>
            product['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();

    filteredResults.sort((a, b) {
      final quantityA = a['quantity'] ?? 0;
      final quantityB = b['quantity'] ?? 0;
      if (quantityA > 0 && quantityB <= 0) return -1;
      if (quantityA <= 0 && quantityB > 0) return 1;
      return 0;
    });

    setState(() => filtered = filteredResults);
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _trackUserBehavior(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('user_behavior').add({
      'productname': name,
      'userId': user?.uid ?? 'anonymous',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
Future<void> _loadPersonalizedRecommendations() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || selectedStoreId == null) return;

  final profileDoc = await FirebaseFirestore.instance
      .collection('user_product_click_profiles')
      .doc(user.uid)
      .get();

  if (!profileDoc.exists) {
    return;
  }

  final summary = profileDoc.data()?['products_clicked_summary'];
  if (summary == null || summary is! List) {
    return;
  }

  final topClicks = List<Map<String, dynamic>>.from(summary)
    .take(4) 
    .where((e) => e['productname'] != null)
    .toList();
 //final topClicks = List<Map<String, dynamic>>.from(summary)
    //..sort((a, b) => (b['click_count'] ?? 0).compareTo(a['click_count'] ?? 0));
  final topProductNames = topClicks
    .map((e) => e['productname'])
    .where((name) => name != null)
    .cast<String>()
    .toList();

  if (topProductNames.isEmpty) {
    return;
  }

  final productSnap = await FirebaseFirestore.instance
      .collection('products')
      .where('name', whereIn: topProductNames)
      .get();


  final stockSnap = await FirebaseFirestore.instance
      .collection('branch_products')
      .where('branchId', isEqualTo: selectedStoreId)
      .get();

  final stockMap = {
    for (var doc in stockSnap.docs)
      doc['productId']: doc['quantity'] ?? 0,
  };

  final result = productSnap.docs.map((doc) {
    final data = doc.data();
    final id = doc.id;
    return {
      ...data,
      'id': id,
      'quantity': stockMap[id] ?? 0,
    };
  }).toList();

  setState(() => recommendedProducts = result);
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: Text(
          'Danh sách sản phẩm',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          if (selectedStoreId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStoreId,
                  icon: const Icon(Icons.store, color: Colors.white),
                  dropdownColor: Colors.white,
                  style: GoogleFonts.quicksand(
                    color: themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                  items: storeLocations.map((store) {
                    return DropdownMenuItem<String>(
                      value: store['id'],
                      child: Row(
                        children: [
                          Icon(Icons.storefront, color: themeColor, size: 18),
                          const SizedBox(width: 6),
                          Text(store['name']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() => isLoading = true);
                    selectedStoreId = value!;
                    Provider.of<StoreProvider>(context, listen: false).setStore(value);
                    await _loadProductsForStore(value);
                    await _loadPersonalizedRecommendations();
                    setState(() => isLoading = false);
                  },
                ),
              ),
            ),
        ],
      ),

body: isLoading
  ? const Center(child: CircularProgressIndicator())
  : ListView(
    padding: EdgeInsets.zero,
    children: [
      // Search box
      Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: TextField(
        controller: _searchController,
        onChanged: _filterProducts,
        style: GoogleFonts.quicksand(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm sản phẩm...',
          hintStyle: GoogleFonts.quicksand(color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF388E3C)),
          filled: true,
          fillColor: const Color(0xFFF6FFF7),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 18),
          border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
          ),
        ),
        ),
      ),
      ),
      // Gợi ý cho bạn
      if (recommendedProducts.isNotEmpty) ...[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        alignment: Alignment.centerLeft,
        child: Text(
        "Gợi ý cho bạn",
        style: GoogleFonts.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: themeColor,
        ),
        ),
      ),
      SizedBox(
        height: 280,
        child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12, right: 12),
        itemCount: recommendedProducts.length,
        itemBuilder: (context, index) {
          final product = recommendedProducts[index];
          return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 160,
            child: _AnimatedProductCard(
            product: product,
            themeColor: themeColor,
            onViewDetail: () {
              _trackUserBehavior(product['name']);
              Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
              );
            },
            ),
          ),
          );
        },
        ),
      ),
      ],
      // Danh sách sản phẩm
      if (filtered.isEmpty)
      SizedBox(
        height: 300,
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(Icons.sentiment_dissatisfied, color: Colors.grey[400], size: 60),
          const SizedBox(height: 10),
          Text(
            "Không có sản phẩm",
            style: GoogleFonts.quicksand(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            ),
          ),
          ],
        ),
        ),
      )
      else
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
        final product = filtered[index];
        return _AnimatedProductCard(
          product: product,
          themeColor: themeColor,
          onViewDetail: () {
          _trackUserBehavior(product['name']);
          Navigator.push(
            context,
            MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
            ),
          );
          },
        );
        },
      ),
    ],
    ),
    );
  }
}

class _AnimatedProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color themeColor;
  final VoidCallback onViewDetail;

  const _AnimatedProductCard({
    required this.product,
    required this.themeColor,
    required this.onViewDetail,
    super.key,
  });

  String _formatCurrency(dynamic value) {
    if (value == null) return '';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final isOutOfStock = product['quantity'] <= 0;
    final priceFormatted = _formatCurrency(product['price']);

    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      shadowColor: themeColor.withOpacity(0.08),
      child: InkWell(
        onTap: onViewDetail,
        borderRadius: BorderRadius.circular(22),
 child: Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Image.network(
        product['image'],
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      ),
    ),
    // Dùng height cố định thay vì Expanded/Flexible
    SizedBox(
      height: 160, // 👈 Chỉnh lại nếu cần theo layout thực tế
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.attach_money, color: themeColor, size: 18),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    priceFormatted,
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: isOutOfStock ? Colors.red : themeColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  isOutOfStock
                      ? 'Hết hàng'
                      : 'Còn: ${product['quantity']}',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: isOutOfStock ? Colors.red : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: isOutOfStock
                  ? null
                  : () {
                      final success = cart.addItem({
                        'id': product['id'],
                        'name': product['name'],
                        'price': product['price'],
                        'image': product['image'],
                        'quantity': 1,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Đã thêm vào giỏ hàng'
                              : 'Vượt quá tồn kho (${product['quantity']} có sẵn)'),
                          backgroundColor:
                              success ? Colors.green : Colors.redAccent,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
              label: Text(
                "Mua ngay",
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
),


      ),
    );
  }
}
