import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

Future<void> generateShippingLabelPdf({
  required String orderId,
  required String customerName,
  required String customerAddress,
  required List<Map<String, dynamic>> items,
  required String storeId,
}) async {

  final qrData = json.encode({
    'orderId': orderId,
    'storeId': storeId,
    'timestamp': DateTime.now().toIso8601String(),
  });
final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
final ttf = pw.Font.ttf(fontData);

final pdf = pw.Document();
pdf.addPage(
  pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('MÃ VẬN ĐƠN', style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Mã đơn hàng: $orderId', style: pw.TextStyle(font: ttf)),
          pw.Text('Khách hàng: $customerName', style: pw.TextStyle(font: ttf)),
          pw.Text('Địa chỉ: $customerAddress', style: pw.TextStyle(font: ttf)),
          pw.SizedBox(height: 12),
          pw.Text('Danh sách sản phẩm:', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Tên sản phẩm', 'Số lượng'],
            data: items.map((item) => [item['name'], item['quantity'].toString()]).toList(),
            headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: ttf),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 150,
              height: 150,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text("Quét mã để xác nhận giao hàng", style: pw.TextStyle(font: ttf))),
        ],
      );
    },
  ),
);
  // Lưu và mở PDF
  final output = await getTemporaryDirectory();
  final file = File('${output.path}/shipping_label_$orderId.pdf');
  await file.writeAsBytes(await pdf.save());

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}
