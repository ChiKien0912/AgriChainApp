import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../chat/chatscreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? orderData;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Stream<DocumentSnapshot> _orderStream;

  double? deliveryDistance;
  double? deliveryDuration;

  final String openRouteApiKey = '5b3ce3597851110001cf62480f90ebec2d7846a6ab421cefec6bbb6d';

  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _showCurrentLocation = false;

  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubicEmphasized);
    _orderStream.listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          orderData = data;
        });
        _controller.forward();
        fetchDeliveryEstimate();
      }
    });
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchDeliveryEstimate() async {
    if (orderData == null) return;

    final shipperLat = orderData!['shipperLocation']['lat'];
    final shipperLng = orderData!['shipperLocation']['lng'];
    final destLat = orderData!['destination']['lat'];
    final destLng = orderData!['destination']['lng'];

    try {
      final estimate = await calculateDeliveryEstimate(
          shipperLat, shipperLng, destLat, destLng);
      setState(() {
        deliveryDistance = estimate['distance'];
        deliveryDuration = estimate['duration'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể lấy dự báo thời gian giao hàng")),
        );
      }
    }
  }

  Future<Map<String, dynamic>> calculateDeliveryEstimate(
      double startLat, double startLng, double endLat, double endLng) async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$openRouteApiKey&start=$startLng,$startLat&end=$endLng,$endLat');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final properties = decoded['features'][0]['properties'];
      final distance = properties['segments'][0]['distance'] / 1000;
      final duration = properties['segments'][0]['duration'] / 60;
      return {
        'distance': distance,
        'duration': duration,
      };
    } else {
      throw Exception('Failed to fetch delivery estimate');
    }
  }

  Widget buildShimmer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Đang tải dữ liệu...",
            style: GoogleFonts.montserrat(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMap(BuildContext context) {
    final themeColor = Color(0xFF388E3C);

    if (orderData == null || orderData!['shipperLocation'] == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(Icons.directions_bike, color: Colors.grey[400], size: 28),
            const SizedBox(width: 10),
            Text(
              "Vị trí shipper chưa cập nhật",
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final shipperPosition = LatLng(
      orderData!['shipperLocation']['lat'],
      orderData!['shipperLocation']['lng'],
    );

    final customerPosition = LatLng(
      orderData!['destination']['lat'],
      orderData!['destination']['lng'],
    );

    List<Marker> markers = [
      Marker(
        point: shipperPosition,
        width: 54,
        height: 54,
        child: AnimatedScale(
          scale: 1.0,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 19,
                child: Icon(Icons.directions_bike,
                    color: Colors.green[700], size: 24),
              ),
              const SizedBox(height: 2),
              Text(
                'Shipper',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      ),
      Marker(
        point: customerPosition,
        width: 54,
        height: 54,
        child: AnimatedScale(
          scale: 1.0,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 19,
                child: Icon(Icons.home,
                    color: Colors.red[700], size: 22),
              ),
              const SizedBox(height: 2),
              Text(
                'Khách',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    if (_showCurrentLocation && _currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 54,
          height: 54,
          child: AnimatedScale(
            scale: 1.0,
            duration: Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 19,
                  child: Icon(Icons.my_location,
                      color: Colors.blue[700], size: 24),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    LatLng center = _showCurrentLocation && _currentPosition != null
        ? _currentPosition!
        : LatLng(
            (shipperPosition.latitude + customerPosition.latitude) / 2,
            (shipperPosition.longitude + customerPosition.longitude) / 2,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              border: Border.all(color: themeColor.withOpacity(0.10), width: 1.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.08),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                maxZoom: 19,
                minZoom: 10,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
                onMapReady: () {
                  if (_showCurrentLocation && _currentPosition != null) {
                    _mapController.move(_currentPosition!, 15);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: AnimatedScale(
              scale: 1.0,
              duration: Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: IconButton(
                  icon: Icon(Icons.my_location, color: themeColor, size: 22),
                  tooltip: "Về vị trí của tôi",
                  onPressed: () async {
                    await _getCurrentLocation();
                    if (_currentPosition != null) {
                      setState(() {
                        _showCurrentLocation = true;
                      });
                      _mapController.move(_currentPosition!, 15);
                    }
                  },
                ),
              ),
            ),
          ),
          if (_showCurrentLocation)
            Positioned(
              top: 10,
              left: 10,
              child: AnimatedScale(
                scale: 1.0,
                duration: Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.red[400], size: 22),
                    tooltip: "Ẩn vị trí của tôi",
                    onPressed: () {
                      setState(() {
                        _showCurrentLocation = false;
                      });
                      _mapController.move(
                        LatLng(
                          (shipperPosition.latitude + customerPosition.latitude) / 2,
                          (shipperPosition.longitude + customerPosition.longitude) / 2,
                        ),
                        13,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildProductList(BuildContext context) {
    final themeColor = Color(0xFF388E3C);
    final products = orderData?['items'] as List<dynamic>?;
    if (products == null || products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Không có sản phẩm nào trong đơn hàng.",
          style: GoogleFonts.montserrat(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...products.map((product) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.07),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (product['image'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product['image'] ?? '',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[300]),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[100],
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, size: 28, color: Colors.grey[400]),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Tên sản phẩm',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Số lượng: ${product['quantity'] ?? 1}",
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormatter.format(product['price'] ?? 0),
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget buildOrderInfo(BuildContext context) {
    final themeColor = Color(0xFF388E3C);

    Widget infoTile(
        {required IconData icon,
        required String title,
        required String value,
        Color? iconColor,
        Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          elevation: 2,
          shadowColor: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.06),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: themeColor.withOpacity(0.09),
                child: Icon(icon, color: iconColor ?? themeColor, size: 22),
                radius: 20,
              ),
              title: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: Text(
                value,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: themeColor,
                ),
              ),
              trailing: trailing,
            ),
          ),
        ),
      );
    }

    String statusText(String status) {
      switch (status) {
        case 'Đang giao':
          return 'Đang giao hàng';
        case 'Đã giao':
          return 'Đã giao thành công';
        case 'Đã hủy':
          return 'Đơn đã hủy';
        default:
          return status;
      }
    }

    Color statusColor(String status) {
      switch (status) {
        case 'Đang giao':
          return Colors.blue;
        case 'Đã giao':
          return Colors.green;
        case 'Đã hủy':
          return Colors.red;
        default:
          return themeColor;
      }
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          infoTile(
            icon: Icons.receipt_long,
            title: "Mã đơn hàng",
            value: widget.orderId,
          ),
          infoTile(
            icon: Icons.location_on,
            title: "Địa chỉ nhận hàng",
            value: orderData!['address'],
          ),
          infoTile(
            icon: Icons.attach_money,
            title: "Tổng tiền",
            value: currencyFormatter.format(orderData!['total']),
            iconColor: Colors.orange[700],
          ),
          infoTile(
            icon: Icons.person,
            title: "Tên shipper",
            value: orderData!['shipperName'] ?? "Chưa có",
            iconColor: Colors.blue[700],
          ),
          infoTile(
            icon: Icons.local_shipping,
            title: "Trạng thái",
            value: statusText(orderData!['status']),
            iconColor: statusColor(orderData!['status']),
          ),
          if (deliveryDistance != null && deliveryDuration != null)
            infoTile(
              icon: Icons.timer,
              title: "Thời gian giao hàng dự kiến",
              value:
                  "${deliveryDuration!.toStringAsFixed(0)} phút (${deliveryDistance!.toStringAsFixed(1)} km)",
              iconColor: Colors.orange[700],
            ),
          const SizedBox(height: 16),
         if (orderData!['status'] == 'Đang giao') ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final phone = orderData!['shipperLocation']['shipperPhone'];
                    if (phone != null) {
                      launchUrl(Uri.parse("tel:$phone"));
                    }
                  },
                  icon: Icon(Icons.call, color: Colors.white),
                  label: Text("Gọi shipper"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          orderId: widget.orderId,
                          customerId: orderData?['userId'],
                          shipperId: orderData?['shipperId'],
                          isCustomer: true,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.chat, color: Colors.white),
                  label: Text("Nhắn tin"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
          Text(
            "Danh sách sản phẩm",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 8),
          buildProductList(context),
          const SizedBox(height: 18),
          Text(
            "Vị trí shipper",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 8),
          buildMap(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF388E3C);

    return Scaffold(
      backgroundColor: Color(0xFFF2F6F9),
      appBar: AppBar(
        title: Text(
          "Chi tiết đơn hàng",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return buildShimmer();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          orderData = data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: buildOrderInfo(context),
          );
        },
      ),
    );
  }
}