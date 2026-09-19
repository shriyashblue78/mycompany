import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/sale_model.dart';

class SaleInvoicePdfGenerator {
  static Future<Uint8List> generatePdf({
    required SaleModel sale,
    required String companyName,
  }) async {
    // 1. Fetch Company Data from Firestore if available
    Map<String, dynamic>? companyData;
    try {
      if (sale.companyId.isNotEmpty) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(sale.companyId)
            .get();
        if (companyDoc.exists) {
          companyData = companyDoc.data();
        }
      }
    } catch (_) {}

    // 2. Fetch Party Master Data if partyId is linked
    Map<String, dynamic>? partyData;
    try {
      if (sale.partyId != null && sale.partyId!.isNotEmpty) {
        final partyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(sale.companyId)
            .collection('parties')
            .doc(sale.partyId)
            .get();
        if (partyDoc.exists) {
          partyData = partyDoc.data();
        }
      }
    } catch (_) {}

    // Extract Company Fields
    final resolvedCompanyName = (companyData?['companyName'] ?? companyData?['name'] ?? companyName).toString().trim();
    final companyAddress = (companyData?['address'] ?? companyData?['fullAddress'] ?? '').toString().trim();
    final companyCity = (companyData?['city'] ?? '').toString().trim();
    final companyState = (companyData?['state'] ?? '').toString().trim();
    final companyStateCode = (companyData?['stateCode'] ?? '').toString().trim();
    final companyPhone = (companyData?['phone'] ?? '').toString().trim();
    final companyEmail = (companyData?['email'] ?? '').toString().trim();
    final companyGstin = (companyData?['gstNumber'] ?? companyData?['gstin'] ?? '').toString().trim();
    final companyPan = (companyData?['panNumber'] ?? companyData?['pan'] ?? '').toString().trim();
    final companyUan = (companyData?['uanNumber'] ?? companyData?['uan'] ?? '').toString().trim();
    final companyLogoUrl = (companyData?['companyLogoUrl'] ?? companyData?['logoUrl'] ?? '').toString().trim();

    // Bank Details
    final bankName = (companyData?['bankName'] ?? '').toString().trim();
    final bankBranch = (companyData?['bankBranch'] ?? companyData?['branch'] ?? '').toString().trim();
    final accountNo = (companyData?['accountNumber'] ?? companyData?['accountNo'] ?? '').toString().trim();
    final ifscCode = (companyData?['ifscCode'] ?? companyData?['ifsc'] ?? '').toString().trim();

    // Extract Party / Customer Details
    final receiverName = sale.customerName.isNotEmpty
        ? sale.customerName
        : (partyData?['partyName'] ?? 'CUSTOMER / RECEIVER').toString();
    final receiverAddress = sale.address.isNotEmpty
        ? sale.address
        : (partyData?['address'] ?? '').toString();
    final receiverState = sale.state.isNotEmpty
        ? sale.state
        : (partyData?['state'] ?? '').toString();
    final receiverStateCode = sale.stateCode.isNotEmpty
        ? sale.stateCode
        : (partyData?['stateCode'] ?? '').toString();
    final receiverGstin = sale.gstin.isNotEmpty
        ? sale.gstin
        : (partyData?['gstin'] ?? '').toString();
    final vendorCode = sale.vendorCode.isNotEmpty
        ? sale.vendorCode
        : (partyData?['vendorCode'] ?? '').toString();

    // Invoice Meta
    final invNo = sale.invoiceNumber != null && sale.invoiceNumber!.isNotEmpty
        ? sale.invoiceNumber!
        : sale.saleNumber;
    final invDateStr = DateFormat('dd.MM.yyyy').format(sale.saleDate);
    final timeOfSupplyStr = sale.timeOfSupply.isNotEmpty
        ? sale.timeOfSupply
        : DateFormat('hh:mm a').format(sale.saleDate);

    // Fetch logo image bytes if available
    pw.ImageProvider? logoImage;
    if (companyLogoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(companyLogoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }

    // Line Items Calculation
    final items = sale.effectiveItems;
    double calculatedSubtotal = 0.0;
    for (final item in items) {
      calculatedSubtotal += item.amount;
    }
    final subtotal = sale.subtotal ?? (calculatedSubtotal > 0 ? calculatedSubtotal : sale.totalAmount);

    // GST Tax calculations (Default 9% CGST + 9% SGST if intra-state or missing)
    final bool isInterState = receiverStateCode.isNotEmpty &&
        companyStateCode.isNotEmpty &&
        receiverStateCode != companyStateCode;

    double cgstPercent = 9.0;
    double sgstPercent = 9.0;
    double igstPercent = 18.0;

    double cgstVal = sale.cgstAmount ?? (isInterState ? 0.0 : (subtotal * cgstPercent / 100));
    double sgstVal = sale.sgstAmount ?? (isInterState ? 0.0 : (subtotal * sgstPercent / 100));
    double igstVal = sale.igstAmount ?? (isInterState ? (subtotal * igstPercent / 100) : 0.0);

    double grandTotal = subtotal + cgstVal + sgstVal + igstVal;
    if (grandTotal == 0.0) {
      grandTotal = sale.totalAmount;
    }

    final cgstWords = numberToWordsIndian(cgstVal);
    final sgstWords = numberToWordsIndian(sgstVal);
    final igstWords = numberToWordsIndian(igstVal);
    final grandTotalWords = numberToWordsIndian(grandTotal);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context pdfContext) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER BAR
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Stack(
                    children: [
                      pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'TAX INVOICE',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'TRIPLICATE FOR SUPPLIER',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. COMPANY LOGO & NAME HEADER SECTION
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Row(
                    children: [
                      // Left: Logo
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: logoImage != null
                            ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                            : _buildDefaultLogo(resolvedCompanyName),
                      ),
                      // Center: Details
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              resolvedCompanyName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            if (companyAddress.isNotEmpty || companyCity.isNotEmpty || companyState.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                _formatCompanyAddress(companyAddress, companyCity, companyState),
                                style: const pw.TextStyle(fontSize: 8),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                            if (companyPhone.isNotEmpty || companyEmail.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Tel : ${companyPhone.isNotEmpty ? companyPhone : "-"}   Email : ${companyEmail.isNotEmpty ? companyEmail : "-"}',
                                style: const pw.TextStyle(fontSize: 8),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 50), // Balance logo on left
                    ],
                  ),
                ),

                // 3. GST & INVOICE DETAILS ROW (2 Columns)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column: GSTIN, State, PAN, UAN
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildKvRow('GSTIN', companyGstin),
                              _buildKvRow('STATE', companyState.toUpperCase()),
                              _buildKvRow('STATE CODE', companyStateCode),
                              _buildKvRow('P.A.N.', companyPan),
                              _buildKvRow('U.A.N.', companyUan),
                            ],
                          ),
                        ),
                      ),
                      // Right Column: Invoice Details
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildKvRow('INVOICE NO.', invNo, isBoldValue: true),
                              _buildKvRow('INVOICE DATE', invDateStr),
                              _buildKvRow('TIME OF SUPPLY', timeOfSupplyStr),
                              _buildKvRow('WHETHER TAX ON REVERSE CHARGE', sale.reverseCharge),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. RECEIVER & CONSIGNEE SECTION (2 Columns)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Details of Receiver (Billed to)
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Details of Receiver (Billed to)',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                receiverName.toUpperCase(),
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                              if (receiverAddress.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  receiverAddress,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                              pw.SizedBox(height: 4),
                              _buildKvRow('STATE', receiverState.toUpperCase()),
                              _buildKvRow('STATE CODE', receiverStateCode),
                              _buildKvRow('GSTIN', receiverGstin),
                            ],
                          ),
                        ),
                      ),
                      // Details of Consignee (Shipped to)
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Details of Consignee (Shipped to)',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                receiverName.toUpperCase(),
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                              if (receiverAddress.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  receiverAddress,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                              pw.SizedBox(height: 4),
                              _buildKvRow('STATE', receiverState.toUpperCase()),
                              _buildKvRow('STATE CODE', receiverStateCode),
                              _buildKvRow('GSTIN', receiverGstin),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. P.O. NO & VENDOR CODE ROW
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'P.O.NO.  ${sale.poNo}     Dt. ${sale.poDate}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'VENDOR CODE  $vendorCode',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 6. MAIN LINE ITEMS TABLE
                pw.Expanded(
                  child: pw.Container(
                    child: _buildItemTable(items),
                  ),
                ),

                // 7. TRANSPORT / VEHICLE & SUB TOTAL ROW
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.75),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.75),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Transport Info
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Expanded(child: _buildKvRow('Mode of transport', sale.modeOfTransport)),
                                  pw.Expanded(child: _buildKvRow('Vehicle No', sale.vehicleNo)),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  pw.Expanded(child: _buildKvRow('Transporter', sale.transporter)),
                                  pw.Expanded(child: _buildKvRow('L.R. No.', sale.lrNo)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Sub total
                      pw.Container(
                        width: 140,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SUB TOTAL', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(_formatAmount(subtotal), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 8. TAX WORDS, BANK DETAILS & TOTAL BREAKDOWN ROW
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left: Tax Words & Bank Details
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (!isInterState) ...[
                                _buildWordsRow('CGST Value in Words', cgstWords),
                                pw.SizedBox(height: 3),
                                _buildWordsRow('SGST Value in Words', sgstWords),
                              ] else ...[
                                _buildWordsRow('IGST Value in Words', igstWords),
                              ],
                              pw.SizedBox(height: 8),
                              _buildBankDetailsRow(bankName, bankBranch, accountNo, ifscCode),
                              pw.SizedBox(height: 8),
                              _buildWordsRow('Invoice Value in Words', grandTotalWords, isBoldLabel: true),
                            ],
                          ),
                        ),
                      ),
                      // Right: Tax Breakdown & Grand Total Table
                      pw.Container(
                        width: 140,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Column(
                                children: [
                                  _buildTotalRow('SUB TOTAL', subtotal),
                                  if (!isInterState) ...[
                                    pw.SizedBox(height: 3),
                                    _buildTotalRow('CGST ${cgstPercent.toStringAsFixed(2)} %', cgstVal),
                                    pw.SizedBox(height: 3),
                                    _buildTotalRow('SGST ${sgstPercent.toStringAsFixed(2)} %', sgstVal),
                                  ] else ...[
                                    pw.SizedBox(height: 3),
                                    _buildTotalRow('IGST ${igstPercent.toStringAsFixed(2)} %', igstVal),
                                  ],
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.75)),
                              ),
                              child: _buildTotalRow('GRAND TOTAL', grandTotal, isGrandTotal: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 9. BOTTOM STATUTORY DECLARATION & SIGNATURES SECTION
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Declaration
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '1/We hereby certify that my/our registration certificate under the GST Act, 2017 is in force on the date on which the supply of the goods specified in this tax invoice is made by me/us and that the transaction of supplies covered by this tax invoice has been effected by me/us and it shall be accounted for in the turnover of supplies while filing of return and the due tax, if any, payable on the supplies has been paid or shall be paid.',
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey900),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Certified that the particulars given above are true and correct and the amount indicated represents the price actually charged and that there is no flow of additional consideration directly or indirectly from buyer.',
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey900),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Interest @ 24% P.A. will be charged on all overdue invoices.',
                              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Subject To ${companyCity.isNotEmpty ? companyCity : "Local"} Jurisdiction',
                              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Receiver's Signature
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.SizedBox(height: 25),
                            pw.Text(
                              "Receiver's Signature",
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Authorised Signatory
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'For ${resolvedCompanyName.toUpperCase()}',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 25),
                            pw.Text(
                              'Authorised Signatory',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- HELPER BUILDERS & FORMATTERS ---

  static pw.Widget _buildKvRow(String label, String value, {bool isBoldValue = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildWordsRow(String label, String words, {bool isBoldLabel = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 105,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          ': ',
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.Expanded(
          child: pw.Text(
            words,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBoldLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBankDetailsRow(String bankName, String bankBranch, String accountNo, String ifscCode) {
    final bName = bankName.isNotEmpty ? bankName : 'INDIAN OVERSEAS BANK';
    final bBranch = bankBranch.isNotEmpty ? bankBranch : 'CHINCHWAD';
    final acc = accountNo.isNotEmpty ? accountNo : '122933000000049';
    final ifsc = ifscCode.isNotEmpty ? ifscCode : 'IOBA0001991';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 105,
          child: pw.Text(
            'BANK DETAILS',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          ': ',
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BANK NAME:${bName.toUpperCase()} BR:${bBranch.toUpperCase()}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'A/C NO:${acc.toUpperCase()} IFSC:${ifsc.toUpperCase()}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount, {bool isGrandTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isGrandTotal ? 8.5 : 7.5,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _formatAmount(amount),
          style: pw.TextStyle(
            fontSize: isGrandTotal ? 9 : 7.5,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemTable(List<SaleItem> items) {
    // Build Rows
    final List<pw.TableRow> tableRows = [];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.white),
        children: [
          _cellHeader('S.N.', width: 25, alignment: pw.TextAlign.center),
          _cellHeader('Description', isFlex: true, alignment: pw.TextAlign.center),
          _cellHeader('HSN / SAC', width: 60, alignment: pw.TextAlign.center),
          _cellHeader('Packing', width: 45, alignment: pw.TextAlign.center),
          _cellHeader('Unit', width: 35, alignment: pw.TextAlign.center),
          _cellHeader('Qty.', width: 40, alignment: pw.TextAlign.center),
          _cellHeader('Rate', width: 55, alignment: pw.TextAlign.center),
          _cellHeader('Amount', width: 65, alignment: pw.TextAlign.center),
        ],
      ),
    );

    // Items Rows
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      tableRows.add(
        pw.TableRow(
          children: [
            _cellText('${i + 1}', width: 25, alignment: pw.TextAlign.center),
            _cellDescription(item.itemName, item.description, item.itemNumber),
            _cellText(item.hsnCode.isNotEmpty ? item.hsnCode : '-', width: 60, alignment: pw.TextAlign.center),
            _cellText(item.packing.isNotEmpty ? item.packing : '', width: 45, alignment: pw.TextAlign.center),
            _cellText(item.unit.isNotEmpty ? item.unit : 'Nos', width: 35, alignment: pw.TextAlign.center),
            _cellText(item.quantity.toStringAsFixed(2), width: 40, alignment: pw.TextAlign.right),
            _cellText(_formatAmount(item.rate), width: 55, alignment: pw.TextAlign.right),
            _cellText(_formatAmount(item.amount), width: 65, alignment: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.75),
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(35),
        5: const pw.FixedColumnWidth(40),
        6: const pw.FixedColumnWidth(55),
        7: const pw.FixedColumnWidth(65),
      },
      children: tableRows,
    );
  }

  static pw.Widget _cellHeader(String text, {double? width, bool isFlex = false, pw.TextAlign alignment = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: alignment,
      ),
    );
  }

  static pw.Widget _cellText(String text, {double? width, pw.TextAlign alignment = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
        textAlign: alignment,
      ),
    );
  }

  static pw.Widget _cellDescription(String title, String description, String itemNum) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          if (description.isNotEmpty && description.toUpperCase() != title.toUpperCase()) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              description.toUpperCase(),
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ] else if (itemNum.isNotEmpty && itemNum.toUpperCase() != title.toUpperCase()) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              itemNum.toUpperCase(),
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildDefaultLogo(String companyName) {
    String initials = 'SM';
    final parts = companyName.trim().split(' ');
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (companyName.isNotEmpty) {
      initials = companyName.substring(0, companyName.length >= 2 ? 2 : 1).toUpperCase();
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColor.fromHex('#1976D2'), width: 2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        initials,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1976D2'),
        ),
      ),
    );
  }

  static String _formatCompanyAddress(String addr, String city, String state) {
    final list = [addr, city, state].where((s) => s.isNotEmpty).toList();
    return list.join(', ');
  }

  static String _formatAmount(double amt) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(amt);
  }
}

// --- NUMBER TO WORDS INDIAN RUPEES HELPER ---

String numberToWordsIndian(double amount) {
  if (amount <= 0) return 'Rs. Zero Only';
  int rupees = amount.floor();
  int paise = ((amount - rupees) * 100).round();

  String rupeesText = _convertNumberToWords(rupees);
  if (rupeesText.isEmpty) rupeesText = 'Zero';

  String result = 'Rs. $rupeesText';
  if (paise > 0) {
    String paiseText = _convertNumberToWords(paise);
    result += ' and $paiseText Paise';
  }
  result += ' Only';
  return result;
}

String _convertNumberToWords(int number) {
  if (number == 0) return '';

  final units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  final tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  if (number < 20) return units[number];
  if (number < 100) {
    final remainder = number % 10;
    return '${tens[number ~/ 10]}${remainder != 0 ? " ${units[remainder]}" : ""}';
  }
  if (number < 1000) {
    final remainder = number % 100;
    return '${units[number ~/ 100]} Hundred${remainder != 0 ? " ${_convertNumberToWords(remainder)}" : ""}';
  }
  if (number < 100000) {
    final remainder = number % 1000;
    return '${_convertNumberToWords(number ~/ 1000)} Thousand${remainder != 0 ? " ${_convertNumberToWords(remainder)}" : ""}';
  }
  if (number < 10000000) {
    final remainder = number % 100000;
    return '${_convertNumberToWords(number ~/ 100000)} Lakh${remainder != 0 ? " ${_convertNumberToWords(remainder)}" : ""}';
  }
  final remainder = number % 10000000;
  return '${_convertNumberToWords(number ~/ 10000000)} Crore${remainder != 0 ? " ${_convertNumberToWords(remainder)}" : ""}';
}
