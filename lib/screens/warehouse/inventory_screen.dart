import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  String selectedCategory = 'Tất cả';
  final List<String> categories = ['Tất cả', 'Tầng 1', 'Tầng 2', 'Tầng 3'];
  String searchQuery = '';
  late AnimationController _controller;

  Stream<QuerySnapshot> _streamInventory() {
    final base = FirebaseFirestore.instance
        .collection('warehouse_slots')
        .where('productId', isNotEqualTo: null);
    if (selectedCategory == 'Tất cả') return base.snapshots();
    return base.where('layer', isEqualTo: selectedCategory).snapshots();
  }

  void _exportToPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Báo cáo tồn kho', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return pw.Text(
                    '${data['productName']} - SL: ${data['quantity']} thùng');
              }),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedBarChart(Map<String, int> products) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: products.isNotEmpty
          ? SizedBox(
              key: ValueKey(products.length),
              height: 250,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true, horizontalInterval: 10),
                  borderData: FlBorderData(show: false),
                  backgroundColor: Colors.transparent,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final key = products.keys.toList()[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              key,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 10),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: products.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) => BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.value.toDouble(),
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.teal,
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: 0,
                                  color: Colors.teal.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                        // tooltipBackgroundColor: Colors.teal.shade100, // Không cần dòng này, có thể xóa
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final name = products.keys.toList()[group.x.toInt()];
                        return BarTooltipItem(
                          '$name\n',
                          const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                                text: 'Số lượng: ${rod.toY.toInt()}',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12))
                          ],
                        );
                      },
                    ),
                  ),
                ),
                swapAnimationDuration: const Duration(milliseconds: 600),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.inventory_2, color: Colors.teal.shade700),
            ),
            title: Text(
              data['productName'] ?? 'Không tên',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Số lượng: ${data['quantity']} - Slot ${data['slotId']}',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: (data['quantity'] ?? 0) < 20
                ? Tooltip(
                    message: 'Sắp hết hàng',
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade400))
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: const Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Xuất PDF',
            onPressed: () async {
              final snapshot = await _streamInventory().first;
              _exportToPDF(snapshot.docs);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          onChanged: (val) =>
                              setState(() => selectedCategory = val!),
                          items: categories
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  )))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm sản phẩm...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) =>
                          setState(() => searchQuery = val.toLowerCase()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _streamInventory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                final products = <String, int>{};

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['productName']
                          ?.toString()
                          .toLowerCase()
                          .contains(searchQuery) ??
                      false;
                }).toList();

                for (var doc in filteredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['productName'] ?? 'Không tên';
                  final qty = data['quantity'] ?? 0;
                  products[name] =
                      (products[name] ?? 0) + (qty is int ? qty : (qty as num).toInt());
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: ListView(
                    key: ValueKey(filteredDocs.length),
                    children: [
                      if (products.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: _buildAnimatedBarChart(products),
                        ),
                      ...List.generate(filteredDocs.length, (i) {
                        final data =
                            filteredDocs[i].data() as Map<String, dynamic>;
                        final animation = CurvedAnimation(
                          parent: _controller,
                          curve: Interval(
                              (i / filteredDocs.length).clamp(0.0, 1.0), 1.0,
                              curve: Curves.easeOut),
                        );
                        _controller.forward();
                        return _buildProductCard(data, animation);
                      }),
                      if (filteredDocs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 60, color: Colors.teal.shade100),
                              const SizedBox(height: 12),
                              Text(
                                'Không có sản phẩm phù hợp',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.teal.shade400,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
