import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum ShipperTab { waiting ,delivering, delivered }

Future<String?> loadShipperStoreId() async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return null;

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();

  return snapshot.docs.isNotEmpty ? snapshot.docs.first['branch'] : null;
}

Widget buildTabButton(String label, ShipperTab tab, IconData icon, ShipperTab currentTab, Color themeColor, VoidCallback onTap) {
  final selected = tab == currentTab;
  return Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? themeColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected
            ? [BoxShadow(color: themeColor.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
        border: Border.all(color: themeColor, width: 1.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(icon, color: selected ? Colors.white : themeColor, size: 26),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    color: selected ? Colors.white : themeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    fontFamily: 'Poppins',
                    letterSpacing: 0.2,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
