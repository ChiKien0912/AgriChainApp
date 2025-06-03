import 'package:flutter/material.dart';

class StoreProvider extends ChangeNotifier {
  String? _selectedStoreId;

  String? get selectedStoreId => _selectedStoreId;

  void setStore(String storeId) {
    _selectedStoreId = storeId;
    notifyListeners();
  }
}
