import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/sales/domain/models/sale_model.dart';
import 'package:projectbtt/features/sales/presentation/utils/sale_invoice_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Indian Rupee Number to Words Tests', () {
    test('Converts exact reference invoice values correctly', () {
      expect(numberToWordsIndian(70800), equals('Rs. Seventy Thousand Eight Hundred Only'));
      expect(numberToWordsIndian(5400), equals('Rs. Five Thousand Four Hundred Only'));
      expect(numberToWordsIndian(60000), equals('Rs. Sixty Thousand Only'));
    });

    test('Converts zero and complex amounts', () {
      expect(numberToWordsIndian(0), equals('Rs. Zero Only'));
      expect(numberToWordsIndian(1234567.89), equals('Rs. Twelve Lakh Thirty Four Thousand Five Hundred Sixty Seven and Eighty Nine Paise Only'));
    });
  });

  group('Sale Invoice PDF Generator Tests', () {
    test('Generates PDF for single-item backward-compatible Sale record', () async {
      final oldSale = SaleModel(
        saleId: 'SALE_001',
        companyId: 'COMP_001',
        saleNumber: 'SAL-0001',
        invoiceNumber: '168',
        customerName: 'RUDRA FARMS AND PROCESSING PVT LTD',
        customerPhone: '9876543210',
        address: 'PLOT NO D3/1/1,MIDC DEORI, DIST.GONDIA, PIN 441901',
        gstin: '27AAGCR2760P1ZT',
        state: 'MAHARASHTRA',
        stateCode: '27',
        vendorCode: 'V-102',
        itemNumber: 'ITM-400',
        itemName: 'ROTOR-400',
        hsnCode: '87089900',
        quantity: 5.0,
        unit: 'Nos',
        pricePerUnit: 12000.0,
        totalAmount: 60000.0,
        saleDate: DateTime(2026, 9, 1),
        remarks: 'Sample Sale Record',
        status: 'Delivered',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfBytes = await SaleInvoicePdfGenerator.generatePdf(
        sale: oldSale,
        companyName: 'S. M. ENGINEERING',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
    });

    test('Generates PDF for multi-item Sale record', () async {
      final multiItemSale = SaleModel(
        saleId: 'SALE_002',
        companyId: 'COMP_001',
        saleNumber: 'SAL-0002',
        invoiceNumber: '169',
        customerName: 'APEX INDUSTRIAL SOLUTIONS',
        customerPhone: '9876500000',
        address: 'PLOT NO 45, INDUSTRIAL ESTATE, PUNE',
        gstin: '27AAAAA0000A1Z5',
        state: 'MAHARASHTRA',
        stateCode: '27',
        itemName: 'Multi Item Order',
        quantity: 1.0,
        unit: 'Set',
        pricePerUnit: 100000.0,
        totalAmount: 100000.0,
        saleDate: DateTime(2026, 9, 15),
        remarks: 'Multi-item delivery',
        status: 'Delivered',
        items: const [
          SaleItem(
            itemNumber: 'ITM-01',
            itemName: 'ROTOR-400',
            description: 'SS316 ROTOR-400',
            hsnCode: '87089900',
            packing: 'Box',
            unit: 'Nos',
            quantity: 5.0,
            rate: 12000.0,
            amount: 60000.0,
          ),
          SaleItem(
            itemNumber: 'ITM-02',
            itemName: 'STATOR FLANGE',
            description: 'HIGH GRADE STATOR FLANGE',
            hsnCode: '84139190',
            packing: 'Pallet',
            unit: 'Pcs',
            quantity: 2.0,
            rate: 20000.0,
            amount: 40000.0,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfBytes = await SaleInvoicePdfGenerator.generatePdf(
        sale: multiItemSale,
        companyName: 'S. M. ENGINEERING',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
    });
  });
}
