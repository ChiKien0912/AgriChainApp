import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class OrderManagement {
  // CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG
  static Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': status});
      Fluttertoast.showToast(msg: "Cập nhật trạng thái thành công");
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}");
    }
  }

  // CẬP NHẬT VỊ TRÍ SHIPPER
  static Future<void> updateShipperLocation(String orderId) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Fluttertoast.showToast(msg: "GPS chưa bật");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        Fluttertoast.showToast(msg: "Không có quyền GPS");
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'shipperLocation': {
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });

    Fluttertoast.showToast(msg: "Đã cập nhật vị trí");
  }

  // TÍNH KHOẢNG CÁCH
  static double calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // GOM ĐƠN THEO KHOẢNG CÁCH
  static List<List<QueryDocumentSnapshot>> groupOrdersByDistance(
      List<QueryDocumentSnapshot> orders) {
    List<List<QueryDocumentSnapshot>> grouped = [];
    Set<int> used = {};

    for (int i = 0; i < orders.length; i++) {
      if (used.contains(i)) continue;
      final group = [orders[i]];
      used.add(i);

      for (int j = i + 1; j < orders.length && group.length < 3; j++) {
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

        if (d < 3.0) {
          group.add(orders[j]);
          used.add(j);
        }
      }
      grouped.add(group);
    }
    return grouped;
  }

  // SẮP XẾP ĐƠN HÀNG ĐANG GIAO THEO LỘ TRÌNH TỐI ƯU
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

Future<void> createDeliveryGroup({
  required List<QueryDocumentSnapshot> orders,
  required String storeId,
  required Position position,
}) async {
  try {
    final shipper = FirebaseAuth.instance.currentUser;
    if (shipper == null) throw Exception("Chưa đăng nhập");

    final groupDoc = await FirebaseFirestore.instance.collection('delivery_groups').add({
      'shipperId': shipper.uid,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      'orders': orders.map((o) => o.id).toList(),
      'status': 'Đang giao',
      'location': {
        'lat': position.latitude,
        'lng': position.longitude,
      },
    });

    final batch = FirebaseFirestore.instance.batch();

    for (var order in orders) {
      batch.update(order.reference, {
        'status': 'Đang giao',
        'shipperId': shipper.uid,
        'shipperEmail': shipper.email,
        'shipperName': shipper.displayName ?? 'Không rõ',
        'shipperLocation': {
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'groupId': groupDoc.id,
        'deliveryStartTime': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    Fluttertoast.showToast(msg: "Đã bắt đầu giao nhóm ${groupDoc.id}");
  } catch (e) {
    Fluttertoast.showToast(msg: "Lỗi gom đơn: ${e.toString()}");
  }
}
