import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class WarehouseForecastScreen extends StatelessWidget {
  const WarehouseForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);
    final bgColor = const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Dự đoán nhu cầu nhập hàng'),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('predicted_demand_results').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final Map<String, List<Map<String, dynamic>>> groupedData = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final product = data['product_name'];
            final date = data['date'];
            final quantity = data['predicted_quantity'];

            if (!groupedData.containsKey(product)) {
              groupedData[product] = [];
            }
            groupedData[product]!.add({
              'date': date,
              'quantity': quantity,
            });
          }

          if (groupedData.isEmpty) {
            return const Center(child: Text('Không có dữ liệu dự đoán.'));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            children: groupedData.entries.map((entry) {
              final productName = entry.key;
              final entries = entry.value;
              entries.sort((a, b) => a['date'].compareTo(b['date']));

              final total = entries.fold<int>(0, (sum, e) => sum + (e['quantity'] as int));
              final avg = entries.isNotEmpty ? (total / entries.length).toStringAsFixed(1) : '0';
              final trend = entries.length > 1
                  ? ((entries.last['quantity'] as int) - (entries.first['quantity'] as int))
                  : 0;

              final spots = <FlSpot>[];
              for (int i = 0; i < entries.length; i++) {
                spots.add(FlSpot(i.toDouble(), (entries[i]['quantity'] as int).toDouble()));
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: themeColor.withOpacity(0.13),
                              child: Icon(Icons.inventory_2, color: themeColor),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                productName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _InfoChip(
                                icon: Icons.summarize,
                                label: 'Tổng',
                                value: '$total',
                                color: themeColor,
                              ),
                              const SizedBox(width: 10),
                              _InfoChip(
                                icon: Icons.bar_chart,
                                label: 'Trung bình',
                                value: avg,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 10),
                              _InfoChip(
                                icon: trend > 0
                                    ? Icons.trending_up
                                    : trend < 0
                                        ? Icons.trending_down
                                        : Icons.trending_flat,
                                label: 'Xu hướng',
                                value: trend > 0
                                    ? 'Tăng'
                                    : trend < 0
                                        ? 'Giảm'
                                        : 'Ổn định',
                                color: trend > 0
                                    ? Colors.green
                                    : trend < 0
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (spots.length > 1)
                          SizedBox(
                            height: 180,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.13),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 36,
                                      getTitlesWidget: (value, meta) => Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        int idx = value.toInt();
                                        if (idx < 0 || idx >= entries.length) return const SizedBox();
                                        final dateStr = DateFormat('dd/MM').format(DateTime.parse(entries[idx]['date']));
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                        );
                                      },
                                      interval: max(1, (entries.length / 5).floorToDouble()),
                                    ),
                                  ),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: themeColor.withOpacity(0.18), width: 1.2),
                                ),
                                minX: 0,
                                maxX: (spots.length - 1).toDouble(),
                                minY: 0,
                                maxY: spots.map((e) => e.y).reduce(max) * 1.2,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: themeColor,
                                    barWidth: 3,
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: themeColor.withOpacity(0.13),
                                    ),
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.white,
                                        strokeWidth: 2,
                                        strokeColor: themeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.transparent),
                            itemBuilder: (context, i) {
                              final e = entries[i];
                              final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(e['date']));
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: themeColor.withOpacity(0.7)),
                                        const SizedBox(width: 7),
                                        Text(dateStr, style: const TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                    Text(
                                      '${e['quantity']} đơn vị',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withOpacity(0.13),
      avatar: Icon(icon, size: 18, color: color),
      label: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
