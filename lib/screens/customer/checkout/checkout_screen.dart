import 'package:argri_chain_app/screens/customer/checkout/ethereum_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../cart/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../data/store_data.dart';
import 'dart:math';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:intl/intl.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  CheckoutScreenState createState() => CheckoutScreenState();
}

class CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  final addressController = TextEditingController();
  final voucherController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  PhoneNumber phoneNumber = PhoneNumber(isoCode: 'VN');
  String paymentMethod = 'transfer';
  double shippingFee = 20000;
  double discount = 0;
  Map<String, dynamic>? selectedStore;
  bool isLoadingLocation = false;
  bool isSubmitting = false;
  bool voucherSuccess = false;
  late AnimationController _voucherAnimController;
  late Animation<double> _voucherAnim;

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<Map<String, dynamic>?> findNearestStoreWithStock(List<Map<String, dynamic>> cartItems) async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    double shortestDistance = double.infinity;
    Map<String, dynamic>? nearestStore;

    for (var store in storeLocations) {
      final stockSnap = await FirebaseFirestore.instance
          .collection('branch_products')
          .where('branchId', isEqualTo: store['id'])
          .get();

      final inventory = {
        for (var doc in stockSnap.docs)
          doc['productId']: doc['quantity'] ?? 0
      };

      final hasAllItems = cartItems.every((item) =>
        inventory[item['id']] != null && inventory[item['id']] >= item['quantity']
      );

      if (hasAllItems) {
        double dist = calculateDistance(
          position.latitude, position.longitude, store['lat'], store['lng'],
        );
        if (dist < shortestDistance) {
          shortestDistance = dist;
          nearestStore = store;
        }
      }
    }

    setState(() => selectedStore = nearestStore);
    return nearestStore;
  }

  @override
  void initState() {
    super.initState();
    final cart = Provider.of<CartProvider>(context, listen: false);
    findNearestStoreWithStock(cart.items); 
    _voucherAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _voucherAnim = CurvedAnimation(
      parent: _voucherAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _voucherAnimController.dispose();
    super.dispose();
  }

  String formatCurrency(num value) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final themeColor = const Color(0xFF388E3C);
    final accentColor = const Color(0xFFB2FF59);
    final bgColor = const Color(0xFFF6F8F6);
    shippingFee = cart.total >= 300000 ? 0 : 15000;
    final totalBefore = cart.total + shippingFee - discount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Xác nhận đơn hàng",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: themeColor,
        elevation: 4,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          children: [
                            if (selectedStore != null) ...[
                              _AnimatedCard(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: TextField(
                                    controller: nameController,
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Tên khách hàng",
                                      labelStyle: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        color: themeColor,
                                      ),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(Icons.person_outline, color: themeColor),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _AnimatedCard(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Số điện thoại",
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: themeColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InternationalPhoneNumberInput(
                                        onInputChanged: (PhoneNumber number) {
                                          phoneNumber = number;
                                          phoneController.text = number.phoneNumber ?? '';
                                        },
                                        initialValue: phoneNumber,
                                        selectorConfig: const SelectorConfig(
                                          selectorType: PhoneInputSelectorType.DROPDOWN,
                                        ),
                                        inputDecoration: InputDecoration(
                                          hintText: "Nhập số điện thoại",
                                          prefixIcon: const Icon(Icons.phone),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(width: 0.8),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        ),
                                        keyboardType: TextInputType.phone,
                                        formatInput: true,
                                        textStyle: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _AnimatedCard(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: DropdownButtonFormField<Map<String, dynamic>>(
                                    value: selectedStore,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    decoration: InputDecoration(
                                      labelText: "Chọn chi nhánh",
                                      labelStyle: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        color: themeColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      prefixIcon: Icon(Icons.storefront, color: themeColor),
                                    ),
                                    items: storeLocations.map((store) {
                                      return DropdownMenuItem<Map<String, dynamic>>(
                                        value: store,
                                        child: Text(store['name'], style: TextStyle(fontFamily: 'Montserrat')),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedStore = value!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _AnimatedCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: TextField(
                                  controller: addressController,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Địa chỉ giao hàng",
                                    labelStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                      color: themeColor,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.location_on_outlined, color: themeColor),
                                    suffixIcon: isLoadingLocation
                                        ? Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: themeColor)),
                                          )
                                        : IconButton(
                                            icon: Icon(Icons.my_location, color: themeColor),
                                            onPressed: getCurrentLocation,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AnimatedCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: DropdownButtonFormField<String>(
                                  value: paymentMethod,
                                  decoration: InputDecoration(
                                    labelText: "Hình thức thanh toán",
                                    labelStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                      color: themeColor,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.payment_outlined, color: themeColor),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'transfer',  
                                        child: Row(
                                          children: [
                                            const Icon(Icons.account_balance_wallet_outlined, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text("Chuyển khoản ngân hàng", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Color.fromARGB(255, 31, 31, 31))),
                                          ],
                                        )),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => paymentMethod = val!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AnimatedCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: voucherController,
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 15,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: "Mã giảm giá (nếu có)",
                                          labelStyle: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(Icons.card_giftcard_outlined),
                                        ),
                                      ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _voucherAnim,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: voucherSuccess
                                              ? 1 + 0.25 * _voucherAnim.value
                                              : 1,
                                          child: child,
                                        );
                                      },
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () {
                                          final code = voucherController.text.trim().toUpperCase();
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user == null) return;

                                          if (vouchers.containsKey(code)) {
                                            final voucher = vouchers[code];
                                            final usedUsers = (voucher['usedUsers'] ?? <String>{}) as Set<String>;
                                            final minTotal = voucher['minTotal'] ?? 0;
                                            final userLimit = voucher['userLimit'] ?? 1;

                                            if (voucher['used'] >= voucher['limit']) {
                                              Fluttertoast.showToast(
                                                msg: "Mã giảm giá đã hết lượt sử dụng",
                                                backgroundColor: Colors.red[600],
                                                textColor: Colors.white,
                                              );
                                            } else if (DateTime.now().isAfter(voucher['expiry'])) {
                                              Fluttertoast.showToast(
                                                msg: "Mã giảm giá đã hết hạn",
                                                backgroundColor: Colors.red[600],
                                                textColor: Colors.white,
                                              );
                                            } else if (cart.total < minTotal) {
                                              Fluttertoast.showToast(
                                                msg: "Đơn hàng phải trên ${formatCurrency(minTotal)} để sử dụng mã này",
                                                backgroundColor: Colors.red[600],
                                                textColor: Colors.white,
                                              );
                                            } else if (usedUsers.contains(user.uid)) {
                                              Fluttertoast.showToast(
                                                msg: "Bạn đã sử dụng mã này rồi",
                                                backgroundColor: Colors.orange[600],
                                                textColor: Colors.white,
                                              );
                                            } else {
                                              setState(() {
                                                discount = (voucher['discount'] as num).toDouble();
                                                voucherSuccess = true;
                                                voucher['used'] += 1;
                                                usedUsers.add(user.uid);
                                              });
                                              _voucherAnimController
                                                ..reset()
                                                ..forward();
                                              Fluttertoast.showToast(
                                                msg: "Áp dụng mã thành công!",
                                                backgroundColor: Colors.green[600],
                                                textColor: Colors.white,
                                              );
                                            }
                                          } else {
                                            setState(() {
                                              discount = 0;
                                              voucherSuccess = false;
                                            });
                                            Fluttertoast.showToast(
                                              msg: "Mã không hợp lệ",
                                              backgroundColor: Colors.red[600],
                                              textColor: Colors.white,
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeOut,
                                          decoration: BoxDecoration(
                                            color: voucherSuccess ? accentColor.withAlpha((0.7 * 255).toInt()) : Colors.grey[200],
                                            shape: BoxShape.circle,
                                            boxShadow: voucherSuccess
                                                ? [
                                                    BoxShadow(
                                                      color: accentColor.withAlpha((0.5 * 255).toInt()),
                                                      blurRadius: 12,
                                                      spreadRadius: 2,
                                                    )
                                                  ]
                                                : [],
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: voucherSuccess ? Colors.green : Colors.grey,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _AnimatedCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  children: [
                                    _buildSummaryRow("Tạm tính", cart.total, themeColor),
                                    _buildSummaryRow("Phí ship", shippingFee, themeColor),
                                    _buildSummaryRow("Giảm giá", -discount, themeColor),
                                    const Divider(height: 18, thickness: 1.2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Tổng cộng",
                                            style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17)),
                                        Text(
                                          formatCurrency(totalBefore),
                                          style: TextStyle(
                                              color: themeColor,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Montserrat'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              child: SizedBox(
                                key: ValueKey(isSubmitting),
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isSubmitting ? null : () => submitOrder(context, cart, totalBefore),
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.check_circle_outline, size: 24),
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      isSubmitting ? "Đang xử lý..." : "Xác nhận đơn hàng",
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor: themeColor.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  fontSize: 15)),
          Text(
            "${value >= 0 ? '' : '-'}${formatCurrency(value.abs())}",
            style: TextStyle(
                color: label == "Tổng cộng" ? color : Colors.black87,
                fontWeight: label == "Tổng cộng" ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Montserrat',
                fontSize: 15),
          ),
        ],
      ),
    );
  }

  Future<void> getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: "Hãy bật dịch vụ vị trí (GPS)");
        setState(() => isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(msg: "Quyền vị trí bị từ chối");
          setState(() => isLoadingLocation = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      Placemark place = placemarks[0];
      setState(() {
        addressController.text =
            "${place.street}, ${place.subLocality}, ${place.locality}";
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Không lấy được vị trí");
    }
    setState(() => isLoadingLocation = false);
  }

  Future<void> submitOrder(
      BuildContext context, CartProvider cart, double total) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final address = addressController.text.trim();
    if (address.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập địa chỉ");
      return;
    }
    final phone = phoneController.text.trim();
    final phoneRegex = RegExp(r'^\+84(3|5|7|8|9)[0-9]{8}$');

    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập số điện thoại");
      return;
    }
    if (!phoneRegex.hasMatch(phone)) {
      Fluttertoast.showToast(msg: "Số điện thoại không hợp lệ");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() => isSubmitting = true);

    try {
      final nearestStore = selectedStore ?? await findNearestStoreWithStock(cart.items);
      final orderId = "${user.uid}_${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'userId': user.uid,
        'email': user.email,
        'name': nameController.text.trim(), 
        'phone': phoneController.text.trim(),
        'address': address,
        'items': cart.items.map((e) => {
              'productId': e['id'],
              'name': e['name'],
              'price': e['price'],
              'quantity': e['quantity'],
            }).toList(),
        'total': total,
        'status': 'Đang xử lý',
        'payment': paymentMethod,
        'voucher': voucherController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'storeId': nearestStore != null ? nearestStore['id'] : null,
        'storeName': nearestStore != null ? nearestStore['name'] : null,
        'destination': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
      });
      
if (paymentMethod == 'transfer') {
  double ethAmount = total / 24000000;  // giả sử 1 ETH = 24 triệu VND
  await payOrderToSmartContract(orderId, ethAmount);
}
      cart.clearCart();
      Fluttertoast.showToast(
        msg: "Đặt hàng thành công!",
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi: ${e.toString()}",
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
    setState(() => isSubmitting = false);
  }
}

/// Animated card for smooth appearance
class _AnimatedCard extends StatelessWidget {
  final Widget child;
  const _AnimatedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.95, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black12,
        child: child,
      ),
    );
  }
}

final Map<String, dynamic> vouchers = {
  "HNX10": {
    "discount": 10000,
    "limit": 100,
    "used": 0,
    "minTotal": 100000, 
    "userLimit": 1,     
    "usedUsers": <String>{}, 
    "expiry": DateTime(2025, 12, 31),
  },
  "HNX50": {
    "discount": 50000,
    "limit": 50,
    "used": 0,
    "minTotal": 300000,
    "userLimit": 1,
    "usedUsers": <String>{},
    "expiry": DateTime(2025, 6, 30),
  },
};
