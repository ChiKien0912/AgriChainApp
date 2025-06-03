import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class ReceiveFarmGoodsScreen extends StatefulWidget {
  const ReceiveFarmGoodsScreen({super.key});

  @override
  State<ReceiveFarmGoodsScreen> createState() => _ReceiveFarmGoodsScreenState();
}

class _ReceiveFarmGoodsScreenState extends State<ReceiveFarmGoodsScreen>
    with SingleTickerProviderStateMixin {
  String batchId = '';
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _farmController = TextEditingController();
  final TextEditingController _organicMethodController = TextEditingController();
  final TextEditingController _fertilizerController = TextEditingController();
  final TextEditingController _certificateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _harvestDate;

  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final MobileScannerController controller = MobileScannerController();

  List<Map<String, dynamic>> _items = [];
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _generateBatchId();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generateBatchId() async {
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final snapshot = await FirebaseFirestore.instance
        .collection('warehouse_batches')
        .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 1)))
        .get();
    final count = snapshot.docs.length + 1;
    setState(() {
      batchId = 'FARM-$today-${count.toString().padLeft(3, '0')}';
    });
  }

  void _scanQR() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Quét QR sản phẩm")),
          body: MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code == null || !mounted) return;

              controller.stop();
              await Future.delayed(const Duration(milliseconds: 200));

              try {
                final data = jsonDecode(code);
                if (!mounted) return;

                setState(() {
                  _productIdController.text = data['productId'] ?? '';
                  _productNameController.text = data['productName'] ?? '';
                  _harvestDate = data['harvestDate'] != null
                      ? DateTime.tryParse(data['harvestDate'])
                      : null;
                  _organicMethodController.text = data['organicType'] ?? '';
                  _fertilizerController.text = data['fertilizer'] ?? '';
                  _noteController.text = data['note'] ?? '';
                  _certificateController.text = data['cert'] ?? '';
                  _farmController.text = data['farm'] ?? '';
                });

                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('QR lỗi: ${e.toString()}')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _addItem() {
    if (_productIdController.text.isEmpty ||
        _productNameController.text.isEmpty ||
        _quantityController.text.isEmpty) return;
    setState(() {
      _items.add({
        'productId': _productIdController.text.trim(),
        'name': _productNameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text) ?? 0,
      });
      _productIdController.clear();
      _productNameController.clear();
      _quantityController.clear();
    });
    _animationController.forward(from: 0);
  }

  Future<void> _submitBatch() async {
    if (batchId.isEmpty || _items.isEmpty) return;
    setState(() => _isSaving = true);

    final batchData = {
      'batchId': batchId,
      'items': {
        'unallocated': _items,
        'allocated': [],
      },
      'driver': _driverController.text.trim(),
      'farm': _farmController.text.trim(),
      'organicMethod': _organicMethodController.text.trim(),
      'fertilizer': _fertilizerController.text.trim(),
      'certificate': _certificateController.text.trim(),
      'note': _noteController.text.trim(),
      'harvestDate': _harvestDate,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('warehouse_batches')
        .add(batchData);

    setState(() {
      _items.clear();
      _driverController.clear();
      _farmController.clear();
      _organicMethodController.clear();
      _fertilizerController.clear();
      _certificateController.clear();
      _noteController.clear();
      _harvestDate = null;
      _isSaving = false;
    });
    _generateBatchId();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Đã lưu lô hàng'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade50,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.green) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Colors.green.shade50.withOpacity(0.25),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      floatingLabelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, double? elevation, EdgeInsets? padding}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Nhập hàng từ nông trại'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQR,
            tooltip: "Quét QR sản phẩm",
          )
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassCard(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.inventory_2, color: Colors.green, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                            fontSize: 18,
                          ),
                          child: Text('Mã lô hàng: $batchId'),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const SizedBox(width: 24, height: 24),
                      ),
                    ],
                  ),
                ),
                _buildSectionTitle("Thông tin chung"),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _driverController,
                          decoration: _inputDecoration('Tên tài xế', icon: Icons.person),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _farmController,
                          decoration: _inputDecoration('Tên nông trại', icon: Icons.agriculture),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _organicMethodController,
                          decoration: _inputDecoration('Phương pháp canh tác', icon: Icons.eco),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _fertilizerController,
                          decoration: _inputDecoration('Phân bón / thuốc BVTV', icon: Icons.science),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _certificateController,
                          decoration: _inputDecoration('Mã chứng nhận', icon: Icons.verified),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassCard(
                        child: TextField(
                          controller: _noteController,
                          decoration: _inputDecoration('Ghi chú', icon: Icons.note_alt),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGlassCard(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Ngày thu hoạch: ',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _harvestDate != null
                              ? DateFormat('dd/MM/yyyy').format(_harvestDate!)
                              : 'Chưa chọn',
                          key: ValueKey(_harvestDate),
                          style: TextStyle(
                            color: _harvestDate != null ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _harvestDate = picked);
                          }
                        },
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Chọn'),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("Thêm sản phẩm"),
                _buildGlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _productIdController,
                          decoration: _inputDecoration('Mã SP', icon: Icons.qr_code),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _productNameController,
                          decoration: _inputDecoration('Tên SP', icon: Icons.shopping_bag),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('SL', icon: Icons.numbers),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: "Thêm sản phẩm",
                        child: AnimatedScale(
                          scale: 1.1,
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                            onPressed: _addItem,
                          ),
                        ),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                ),
                const SizedBox(height: 12),
                _buildSectionTitle("Danh sách sản phẩm"),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'Chưa có sản phẩm nào',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (_, index) {
                            final item = _items[index];
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    0.0,
                                    1.0,
                                    curve: Curves.easeOutBack,
                                  ),
                                ),
                              ),
                              child: Dismissible(
                                key: ValueKey(item['productId'] + item['name'] + item['quantity'].toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  color: Colors.red.shade100,
                                  child: const Icon(Icons.delete, color: Colors.red),
                                ),
                                onDismissed: (direction) {
                                  setState(() => _items.removeAt(index));
                                },
                                child: _buildGlassCard(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        item['quantity'].toString(),
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(item['name']),
                                    subtitle: Text('Mã: ${item['productId']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => setState(() => _items.removeAt(index)),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: _isSaving ? 180 : 220,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shadowColor: Colors.green.shade100,
                      ),
                      onPressed: _isSaving ? null : _submitBatch,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(_isSaving ? "Đang lưu..." : "Lưu lô hàng"),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
