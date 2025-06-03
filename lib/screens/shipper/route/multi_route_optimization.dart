import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class MultiRouteOptimization {
  // Tính khoảng cách giữa 2 điểm (Haversine)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Gom đơn theo khoảng cách (ví dụ: < 3km)
  static List<List<QueryDocumentSnapshot>> groupOrdersByDistance(
      List<QueryDocumentSnapshot> orders, {double maxDistance = 3.0, int maxGroup = 3}) {
    List<List<QueryDocumentSnapshot>> grouped = [];
    Set<int> used = {};

    for (int i = 0; i < orders.length; i++) {
      if (used.contains(i)) continue;
      final group = [orders[i]];
      used.add(i);

      for (int j = i + 1; j < orders.length && group.length < maxGroup; j++) {
        if (used.contains(j)) continue;
        final a = orders[i].data() as Map<String, dynamic>;
        final b = orders[j].data() as Map<String, dynamic>;
        if (a['shipperLocation'] == null || b['shipperLocation'] == null) continue;

        double d = calculateDistance(
          a['shipperLocation']['lat'],
          a['shipperLocation']['lng'],
          b['shipperLocation']['lat'],
          b['shipperLocation']['lng'],
        );

        if (d < maxDistance) {
          group.add(orders[j]);
          used.add(j);
        }
      }
      grouped.add(group);
    }
    return grouped;
  }

  // Sắp xếp đơn hàng theo lộ trình tối ưu (tham lam)
  static List<QueryDocumentSnapshot> sortOrdersByRoute(
      List<QueryDocumentSnapshot> orders, double startLat, double startLng) {
    List<QueryDocumentSnapshot> sorted = [];
    Set<int> used = {};
    double curLat = startLat, curLng = startLng;

    for (int i = 0; i < orders.length; i++) {
      double minDist = double.infinity;
      int minIdx = -1;
      for (int j = 0; j < orders.length; j++) {
        if (used.contains(j)) continue;
        final data = orders[j].data() as Map<String, dynamic>;
        if (data['destination'] == null) continue;
        double d = calculateDistance(
          curLat,
          curLng,
          data['destination']['lat'],
          data['destination']['lng'],
        );
        if (d < minDist) {
          minDist = d;
          minIdx = j;
        }
      }
      if (minIdx != -1) {
        sorted.add(orders[minIdx]);
        final data = orders[minIdx].data() as Map<String, dynamic>;
        curLat = data['destination']['lat'];
        curLng = data['destination']['lng'];
        used.add(minIdx);
      }
    }
    return sorted;
  }
}