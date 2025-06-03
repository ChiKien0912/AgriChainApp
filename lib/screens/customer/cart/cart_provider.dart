import 'package:flutter/material.dart';

class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _cartItems = [];
  Map<String, int> _branchStockMap = {}; // <productId, maxQty>

  List<Map<String, dynamic>> get items => _cartItems;

  void setBranchStock(Map<String, int> stockMap) {
    _branchStockMap = stockMap;
  }

  bool addItem(Map<String, dynamic> product) {
    final index = _cartItems.indexWhere((p) => p['id'] == product['id']);
    final maxQty = _branchStockMap[product['id']] ?? 0;

    if (index >= 0) {
      if (_cartItems[index]['quantity'] < maxQty) {
        _cartItems[index]['quantity'] += 1;
        notifyListeners();
        return true;
      } else {
        return false; // vượt kho
      }
    } else {
      if (maxQty > 0) {
        _cartItems.add({...product, 'quantity': 1});
        notifyListeners();
        return true;
      } else {
        return false;
      }
    }
  }

  bool increase(String productId) {
    final index = _cartItems.indexWhere((item) => item['id'] == productId);
    final maxQty = _branchStockMap[productId] ?? 0;

    if (index >= 0 && _cartItems[index]['quantity'] < maxQty) {
      _cartItems[index]['quantity'] += 1;
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }


  void removeItem(String productId) {
    _cartItems.removeWhere((item) => item['id'] == productId);
    notifyListeners();
  }


  void decrease(String productId) {
    final index = _cartItems.indexWhere((item) => item['id'] == productId);
    if (index >= 0 && _cartItems[index]['quantity'] > 1) {
      _cartItems[index]['quantity'] -= 1;
      notifyListeners();
    }
  }

  double get total {
    return _cartItems.fold(0, (sum, item) => sum + item['price'] * item['quantity']);
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
