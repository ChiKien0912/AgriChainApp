import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/store_data.dart';

class ExportToStoreScreen extends StatefulWidget {
  const ExportToStoreScreen({super.key});

  @override
  State<ExportToStoreScreen> createState() => _ExportToStoreScreenState();
}

class _ExportToStoreScreenState extends State<ExportToStoreScreen>
    with SingleTickerProviderStateMixin {
  List<DocumentSnapshot> availableSlots = [];
  DocumentSnapshot? selectedSlot;
  Map<String, dynamic>? selectedStore;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSlots() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('warehouse_slots')
        .where('productName', isNotEqualTo: null)
        .where('quantity', isGreaterThan: 0)
        .get();

    setState(() => availableSlots = snapshot.docs);
  }

  void _submitExport() async {
    if (selectedSlot == null ||
        selectedStore == null ||
        _quantityController.text.isEmpty) return;
    final int qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0 || qty > selectedSlot!['quantity']) return;

    setState(() => isSubmitting = true);

    final batchData = {
      'storeId': selectedStore!['id'],
      'storeName': selectedStore!['name'],
      'lat': selectedStore!['lat'],
      'lng': selectedStore!['lng'],
      'batchId': selectedSlot!['batchId'],
      'note': _noteController.text.trim(),
      'productId': selectedSlot!['productId'],
      'productName': selectedSlot!['productName'],
      'quantity': qty,
      'slotId': selectedSlot!['slotId'],
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    };

    await FirebaseFirestore.instance.collection('pending_batches').add(batchData);

    final slotRef =
        FirebaseFirestore.instance.collection('warehouse_slots').doc(selectedSlot!.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final freshSnap = await transaction.get(slotRef);
      final currentQty = freshSnap['quantity'] ?? 0;
      if (currentQty < qty) throw Exception('Không đủ hàng để xuất');
      transaction.update(slotRef, {'quantity': currentQty - qty});
    });

    setState(() {
      selectedSlot = null;
      selectedStore = null;
      _noteController.clear();
      _quantityController.clear();
      isSubmitting = false;
    });

    _loadAvailableSlots();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã tạo đơn xuất hàng sang cửa hàng'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Xuất hàng cho cửa hàng'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  child: DropdownButtonFormField<DocumentSnapshot>(
                    decoration: const InputDecoration(
                      labelText: 'Chọn hàng trong kho',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    value: selectedSlot,
                    items: availableSlots.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc,
                        child: Text(
                          '${data['productName']} (${data['quantity']} thùng) - Slot ${data['slotId']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedSlot = value),
                    isExpanded: true,
                  ),
                ),
                _buildCard(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng thùng cần xuất',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                _buildCard(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(
                      labelText: 'Chọn cửa hàng nhận hàng',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store_mall_directory),
                    ),
                    value: selectedStore,
                    items: storeLocations.map((store) {
                      return DropdownMenuItem(
                        value: store,
                        child: Text(store['name']),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedStore = value),
                    isExpanded: true,
                  ),
                ),
                _buildCard(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (nếu có)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isSubmitting
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: 220,
                            height: 48,
                            child: ElevatedButton.icon(
                              key: const ValueKey('exportBtn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 4,
                              ),
                              onPressed: _submitExport,
                              icon: const Icon(Icons.local_shipping),
                              label: const Text(
                                'Xuất kho cho cửa hàng',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}
