import 'package:flutter/material.dart';
import 'tab/shipper_delivering_tab.dart';
import 'tab/shipper_delivered_tab.dart';
import 'tab/shipper_waiting_tab.dart';
import 'shipper_utils.dart';

Widget buildTabContent(ShipperTab currentTab, TextTheme textTheme, String storeId, Color themeColor) {
  switch (currentTab) {
    case ShipperTab.waiting:
      return ShipperWaitingTab(storeId: storeId, textTheme: textTheme, themeColor: themeColor);
    case ShipperTab.delivering:
      return ShipperDeliveringTab(storeId: storeId, textTheme: textTheme, themeColor: themeColor);
    case ShipperTab.delivered:
      return ShipperDeliveredTab(storeId: storeId, textTheme: textTheme, themeColor: themeColor);
  }
}