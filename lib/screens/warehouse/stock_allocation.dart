import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockAllocationScreen extends StatefulWidget {
  const StockAllocationScreen({super.key});

  @override
  State<StockAllocationScreen> createState() => _StockAllocationScreenState();
}

class BatchItem {
  final String productId;
  final String productName;
  final int quantity;
  final String batchId;

  BatchItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.batchId,
  });

  BatchItem copyWith({int? quantity}) => BatchItem(
        productId: productId,
        productName: productName,
        quantity: quantity ?? this.quantity,
        batchId: batchId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchItem &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          batchId == other.batchId;

  @override
  int get hashCode => productId.hashCode ^ batchId.hashCode;
}

class _StockAllocationScreenState extends State<StockAllocationScreen>
    with SingleTickerProviderStateMixin {
  int currentFloor = 1;
  final int totalFloors = 4;
  List<BatchItem> availableBatches = [];
  BatchItem? selectedItem;
  bool isLoadingBatches = true;
  String? suggestedSlotId;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _loadAvailableBatches();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBatches() async {
    final batchSnap = await FirebaseFirestore.instance
        .collection('warehouse_batches')
        .where('status', whereIn: ['waiting', 'partial'])
        .get();

    List<BatchItem> batchItems = [];
    for (var doc in batchSnap.docs) {
      final data = doc.data();
      final List unallocated = data['items']['unallocated'] ?? [];

      for (var item in unallocated) {
        batchItems.add(BatchItem(
          productId: item['productId'],
          productName: item['name'],
          quantity: item['quantity'],
          batchId: doc.id,
        ));
      }
    }
    if (selectedItem != null &&
        availableBatches.where((b) =>
                b.productId == selectedItem!.productId &&
                b.batchId == selectedItem!.batchId)
            .length != 1) {
      selectedItem = null;
    }

    setState(() {
      final uniqueBatches = <BatchItem>{};
      for (var item in batchItems) {
        uniqueBatches.add(item);
      }
      availableBatches = uniqueBatches.toList();
      if (selectedItem != null && !availableBatches.contains(selectedItem)) {
        selectedItem = null;
      }
      isLoadingBatches = false;
    });
  }

  void _updateBatchItemQuantity(BatchItem item, int newQty) {
    setState(() {
      final index = availableBatches.indexWhere(
          (e) => e.productId == item.productId && e.batchId == item.batchId);
      if (index != -1) {
        availableBatches[index] =
            availableBatches[index].copyWith(quantity: newQty);
      }
    });
  }

  Future<void> allocateToSlot(
      DocumentReference slotRef, Map<String, dynamic> slotData) async {
    if (selectedItem == null) return;

    final currentQty = slotData['quantity'] ?? 0;
    final maxQty = slotData['maxQuantity'] ?? 50;
    final remainQty = maxQty - currentQty;
    final itemQty = selectedItem!.quantity;

    if (remainQty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot đã đầy, không thể thêm.')),
      );
      return;
    }

    final toAllocate = itemQty <= remainQty ? itemQty : remainQty;

    await slotRef.update({
      'productId': selectedItem!.productId,
      'productName': selectedItem!.productName,
      'quantity': currentQty + toAllocate,
      'batchId': selectedItem!.batchId
    });

    final batchRef = FirebaseFirestore.instance
        .collection('warehouse_batches')
        .doc(selectedItem!.batchId);
    final batchSnap = await batchRef.get();
    final data = batchSnap.data()!;
    final unallocated =
        List<Map<String, dynamic>>.from(data['items']['unallocated'] ?? []);
    final allocated =
        List<Map<String, dynamic>>.from(data['items']['allocated'] ?? []);

    final index = unallocated.indexWhere(
      (item) => item['productId'] == selectedItem!.productId,
    );

    if (index == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy sản phẩm trong batch!')),
      );
      return;
    }

    final item = unallocated[index];
    final remainingQty = item['quantity'] - toAllocate;

    if (item['quantity'] is! int) {
      throw Exception("Lỗi dữ liệu: 'quantity' không phải kiểu int");
    }

    if (remainingQty <= 0) {
      unallocated.removeAt(index);
    } else {
      unallocated[index]['quantity'] = remainingQty;
    }

    allocated.add({
      'productId': selectedItem!.productId,
      'name': selectedItem!.productName,
      'quantity': toAllocate,
      'slotId': slotRef.id,
    });

    final newStatus = unallocated.isEmpty ? 'allocated' : 'partial';

    await batchRef.update({
      'items': {
        'unallocated': unallocated,
        'allocated': allocated,
      },
      'status': newStatus,
    });

    if (itemQty > toAllocate) {
      final newItem =
          selectedItem!.copyWith(quantity: (itemQty - toAllocate).toInt());
      _updateBatchItemQuantity(selectedItem!, (itemQty - toAllocate).toInt());
      final newSlots = await FirebaseFirestore.instance
          .collection('warehouse_slots')
          .where('floor', isEqualTo: currentFloor)
          .get();

      if (!mounted) return;
      setState(() {
        selectedItem = newItem;
        suggestSlotForItem(newSlots.docs);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Đã phân $toAllocate thùng. Còn lại ${itemQty - toAllocate} thùng'),
        ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        selectedItem = null;
        suggestedSlotId = null;
        _loadAvailableBatches();
      });
      setState(() {
        availableBatches.removeWhere((b) =>
            b.productId == selectedItem!.productId &&
            b.batchId == selectedItem!.batchId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã phân bổ hết sản phẩm vào kệ')),
      );
    }
  }

  void suggestSlotForItem(List<QueryDocumentSnapshot> slots) {
    if (selectedItem == null) return;
    String targetProductId = selectedItem!.productId;
    String? bestSlot;
    int maxRemaining = 0;

    for (var doc in slots) {
      final data = doc.data() as Map<String, dynamic>;
      final slotQty = data['quantity'] ?? 0;
      final slotMax = data['maxQuantity'] ?? 50;
      final slotProduct = data['productId'];
      final remaining = slotMax - slotQty;

      if (slotProduct == targetProductId &&
          remaining > 0 &&
          remaining >= maxRemaining) {
        bestSlot = data['slotId'];
        maxRemaining = remaining;
      }
    }

    if (bestSlot == null) {
      for (var doc in slots) {
        final data = doc.data() as Map<String, dynamic>;
        final slotQty = data['quantity'] ?? 0;
        final slotMax = data['maxQuantity'] ?? 50;
        final remaining = slotMax - slotQty;

        if ((data['productId'] == null || data['productId'] == '') &&
            remaining >= maxRemaining) {
          bestSlot = data['slotId'];
          maxRemaining = remaining;
        }
      }
    }

    setState(() => suggestedSlotId = bestSlot);
  }

  void showSlotDetails(DocumentSnapshot slot) {
    final data = slot.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text('Chi tiết vị trí ${data['slotId']}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              infoRow('Mặt hàng:', data['productName'] ?? 'Trống'),
              infoRow('Mã sản phẩm:', data['productId'] ?? '-'),
              infoRow('Số lượng:', '${data['quantity'] ?? 0}'),
              infoRow('Thuộc lô hàng:', data['batchId'] ?? '-'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  elevation: 2,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final destinationSlotId = await showSlotSelectionDialog(slot);
                  if (destinationSlotId != null) {
                    final destRef = FirebaseFirestore.instance
                        .collection('warehouse_slots')
                        .doc(destinationSlotId);
                    await destRef.update({
                      'productId': data['productId'],
                      'productName': data['productName'],
                      'quantity': data['quantity'],
                      'batchId': data['batchId'],
                    });
                    await slot.reference.update({
                      'productId': null,
                      'productName': null,
                      'quantity': 0,
                      'batchId': null,
                    });
                    if (!mounted) return;
                    _loadAvailableBatches();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã chuyển vị trí hàng')),
                    );
                  }
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Chuyển sang vị trí khác'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Future<String?> showSlotSelectionDialog(DocumentSnapshot currentSlot) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('warehouse_slots').get();
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn vị trí mới',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...snapshot.docs
                  .where((s) => s.id != currentSlot.id)
                  .map((doc) {
                final data = doc.data();
                return ListTile(
                  onTap: () => Navigator.pop(ctx, doc.id),
                  leading: Icon(Icons.inventory_2, color: Colors.blue[400]),
                  title: Text(
                    '${data['slotId']} (còn ${data['maxQuantity'] - data['quantity']})',
                    style: const TextStyle(fontSize: 15),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget floorSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: currentFloor < totalFloors ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 250),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 32),
              color: Colors.blueAccent,
              onPressed: currentFloor < totalFloors
                  ? () => setState(() => currentFloor++)
                  : null,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              'Tầng $currentFloor',
              key: ValueKey(currentFloor),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent),
            ),
          ),
          AnimatedScale(
            scale: currentFloor > 1 ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 250),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 32),
              color: Colors.blueAccent,
              onPressed: currentFloor > 1
                  ? () => setState(() => currentFloor--)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget warehouseLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          legendDot(Colors.green[300]!, 'Trống'),
          const SizedBox(width: 16),
          legendDot(Colors.orange[300]!, 'Đang chứa'),
          const SizedBox(width: 16),
          legendDot(Colors.red[300]!, 'Gần đầy'),
          const SizedBox(width: 16),
          legendDot(Colors.blueAccent, 'Gợi ý', border: true),
        ],
      ),
    );
  }

  Widget legendDot(Color color, String label, {bool border = false}) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            border: border ? Border.all(color: Colors.blueAccent, width: 3) : null,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget productDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.blueGrey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: DropdownButtonFormField<BatchItem>(
          decoration: InputDecoration(
            labelText: 'Chọn sản phẩm từ lô hàng',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          value: selectedItem,
          isExpanded: true,
          items: availableBatches.map((item) {
            return DropdownMenuItem<BatchItem>(
              value: item,
              child: Text(
                '${item.productName} (${item.quantity} thùng)',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            setState(() => selectedItem = value);
            final slotsSnap = await FirebaseFirestore.instance
                .collection('warehouse_slots')
                .where('floor', isEqualTo: currentFloor)
                .get();
            suggestSlotForItem(slotsSnap.docs);
          },
        ),
      ),
    );
  }

  Widget warehouseGrid(List<QueryDocumentSnapshot> slots) {
    int crossAxisCount = 4;
    if (slots.length >= 16) crossAxisCount = 6;
    if (slots.length >= 30) crossAxisCount = 8;

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnim,
        child: GridView.builder(
          padding: const EdgeInsets.all(18),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final data = slot.data() as Map<String, dynamic>;
            final currentQty = data['quantity'] ?? 0;
            final maxQty = data['maxQuantity'] ?? 50;
            final percent = currentQty / maxQty;

            Color color;
            if (percent >= 0.8) {
              color = Colors.red[300]!;
            } else if (percent >= 0.5) {
              color = Colors.orange[300]!;
            } else {
              color = Colors.green[300]!;
            }

            final isSuggested =
                suggestedSlotId != null && data['slotId'] == suggestedSlotId;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: isSuggested
                    ? Border.all(color: Colors.blueAccent, width: 4)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.blueAccent.withOpacity(0.18),
                  highlightColor: Colors.blueAccent.withOpacity(0.08),
                  onTap: () => showSlotDetails(slot),
                  onLongPress: selectedItem == null
                      ? null
                      : () => allocateToSlot(slot.reference, data),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSuggested ? 1.18 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              data['slotId'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSuggested
                                    ? Colors.blueAccent
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: Text(
                              '$currentQty/$maxQty thùng',
                              key: ValueKey(currentQty),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (data['productName'] != null &&
                              data['productName'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                data['productName'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('Sơ đồ kho hàng'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          floorSelector(),
          warehouseLegend(),
          if (isLoadingBatches)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: CircularProgressIndicator(),
            )
          else
            productDropdown(),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('warehouse_slots')
                  .where('floor', isEqualTo: currentFloor)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Không có dữ liệu kệ hàng'));
                }
                final slots = snapshot.data!.docs;
                return warehouseGrid(slots);
              },
            ),
          ),
        ],
      ),
    );
  }
}