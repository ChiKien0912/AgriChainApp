import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

class CreateFarmProductScreen extends StatefulWidget {
  const CreateFarmProductScreen({super.key});

  @override
  State<CreateFarmProductScreen> createState() => _CreateFarmProductScreenState();
}

class _CreateFarmProductScreenState extends State<CreateFarmProductScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _harvestDateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _fertilizerController = TextEditingController();
  final TextEditingController _certController = TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();

  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedOrganicType;
  String? _generatedProductId;
  String? _qrData;
  GeoPoint? _farmLocation;

  final List<String> _organicTypes = ['Organic', 'Hydroponic', 'Conventional'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Future<List<QueryDocumentSnapshot>> _fetchProducts(String query) async {
    final snapshot = await FirebaseFirestore.instance.collection('products').get();
    return snapshot.docs
        .where((doc) =>
            doc['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<List<QueryDocumentSnapshot>> _fetchFarms(String query) async {
    final snapshot = await FirebaseFirestore.instance.collection('farms').get();
    return snapshot.docs
        .where((doc) =>
            doc['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _getFarmLocation() async {
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _farmLocation = GeoPoint(position.latitude, position.longitude);
    });
  }

  void _generateQRData() {
    final data = {
      'productId': _generatedProductId,
      'productName': _selectedProductName,
      'harvestDate': _harvestDateController.text,
      'organicType': _selectedOrganicType,
      'fertilizer': _fertilizerController.text,
      'note': _noteController.text,
      'cert': _certController.text,
      'farm': _farmNameController.text,
      'location': _farmLocation != null
          ? {
              'lat': _farmLocation!.latitude,
              'lon': _farmLocation!.longitude,
            }
          : null,
    };
    setState(() => _qrData = jsonEncode(data));
    _animationController.forward(from: 0);
  }

  Future<void> _saveToFirestore() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null) return;

    _generateQRData();

    await FirebaseFirestore.instance.collection('farm_products').add({
      'productId': _generatedProductId,
      'productName': _selectedProductName,
      'harvestDate': _harvestDateController.text,
      'organicType': _selectedOrganicType,
      'fertilizer': _fertilizerController.text,
      'note': _noteController.text,
      'cert': _certController.text,
      'farm': _farmNameController.text,
      'location': _farmLocation,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void initState() {
    super.initState();
    _getFarmLocation();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _harvestDateController.dispose();
    _noteController.dispose();
    _fertilizerController.dispose();
    _certController.dispose();
    _farmNameController.dispose();
    super.dispose();
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Tạo sản phẩm từ nông trại'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCard(
                      child: Autocomplete<QueryDocumentSnapshot>(
                        displayStringForOption: (snap) => snap['name'],
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text == '') return const Iterable.empty();
                          return await _fetchProducts(textEditingValue.text);
                        },
                        onSelected: (selection) {
                          setState(() {
                            _selectedProductId = selection.id;
                            _selectedProductName = selection['name'];
                            _generatedProductId = selection.id;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                            TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Chọn sản phẩm',
                            prefixIcon: Icon(Icons.shopping_basket_outlined),
                            border: InputBorder.none,
                          ),
                          validator: (val) =>
                              _selectedProductId == null ? 'Vui lòng chọn sản phẩm' : null,
                        ),
                      ),
                    ),
                    _buildCard(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Phương pháp canh tác',
                          prefixIcon: Icon(Icons.eco_outlined),
                          border: InputBorder.none,
                        ),
                        items: _organicTypes
                            .map((type) =>
                                DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedOrganicType = val),
                        validator: (val) => val == null ? 'Chọn loại canh tác' : null,
                      ),
                    ),
                    _buildCard(
                      child: TextFormField(
                        controller: _harvestDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Ngày thu hoạch',
                          prefixIcon: Icon(Icons.date_range_outlined),
                          border: InputBorder.none,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            _harvestDateController.text =
                                DateFormat('yyyy-MM-dd').format(picked);
                          }
                        },
                      ),
                    ),
                    _buildCard(
                      child: TextFormField(
                        controller: _fertilizerController,
                        decoration: const InputDecoration(
                          labelText: 'Loại phân bón / thuốc BVTV',
                          prefixIcon: Icon(Icons.science_outlined),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    _buildCard(
                      child: TextFormField(
                        controller: _certController,
                        decoration: const InputDecoration(
                          labelText: 'Mã chứng nhận (nếu có)',
                          prefixIcon: Icon(Icons.verified_outlined),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    _buildCard(
                      child: Autocomplete<QueryDocumentSnapshot>(
                        displayStringForOption: (snap) => snap['name'],
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text == '') return const Iterable.empty();
                          return await _fetchFarms(textEditingValue.text);
                        },
                        onSelected: (farm) {
                          setState(() {
                            _farmNameController.text = farm['name'];
                            _farmLocation = GeoPoint(farm['lat'], farm['lon']);
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                            TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Chọn trang trại',
                            prefixIcon: Icon(Icons.agriculture_outlined),
                            border: InputBorder.none,
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Chọn trang trại' : null,
                        ),
                      ),
                    ),
                    _buildCard(
                      child: TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor.withOpacity(0.85),
                            theme.primaryColorDark.withOpacity(0.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code, size: 28),
                        label: const Text('Tạo sản phẩm và QR code'),
                        onPressed: () async {
                          await _saveToFirestore();
                          _generateQRData();
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_qrData != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  QrImageView(data: _qrData!, size: 200),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Quét mã QR để xem thông tin sản phẩm',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.primaryColorDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
