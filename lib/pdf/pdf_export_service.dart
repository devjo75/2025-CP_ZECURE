import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PdfExportService {
  // Paper size options
  static const Map<String, PdfPageFormat> paperSizes = {
    'A4': PdfPageFormat.a4,
    'Letter': PdfPageFormat.letter,
  };

  // Export reports to PDF with address enrichment
  static Future<void> exportReportsToPdf({
    required List<Map<String, dynamic>> reports,
    required String fileName,
    required PdfPageFormat pageFormat,
    Map<String, String>? addressCache, // ADDED: Optional address cache
    Function(Map<String, String>)? onCacheUpdate, // ADDED: Callback to update cache
    String? sortBy,
    bool ascending = false,
    DateTime? startDate,
    DateTime? endDate,
    Function(int current, int total)? onProgress,
  }) async {
    // Use provided cache or create new one
    Map<String, String> workingCache = addressCache != null 
        ? Map.from(addressCache) 
        : {};

    // Enrich reports with full addresses before generating PDF
    List<Map<String, dynamic>> enrichedReports = await _enrichReportsWithAddresses(
      reports,
      addressCache: workingCache,
      onProgress: onProgress,
    );

    // Update parent cache if new addresses were fetched
    if (onCacheUpdate != null && addressCache != null) {
      onCacheUpdate(workingCache);
    }

    final pdf = pw.Document();

    // Sort reports if needed
    List<Map<String, dynamic>> sortedReports = List.from(enrichedReports);
    if (sortBy != null) {
      _sortReports(sortedReports, sortBy, ascending);
    }

    // Split data into pages
    const int rowsPerPage = 15;
    int totalPages = (sortedReports.length / rowsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * rowsPerPage;
      final endIndex = (startIndex + rowsPerPage > sortedReports.length)
          ? sortedReports.length
          : startIndex + rowsPerPage;
      final pageReports = sortedReports.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(
                  pageIndex + 1,
                  totalPages,
                  sortedReports.length,
                  startDate,
                  endDate,
                ),
                pw.SizedBox(height: 20),
                _buildPdfTable(pageReports, startIndex: startIndex), // ADDED: Pass startIndex
                pw.Spacer(),
                _buildPdfFooter(),
              ],
            );
          },
        ),
      );
    }

    // Save PDF - Use Printing.layoutPdf for both web and mobile
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: fileName,
      format: pageFormat,
    );
  }

  // Enrich reports with full address information
  static Future<List<Map<String, dynamic>>> _enrichReportsWithAddresses(
    List<Map<String, dynamic>> reports, {
    required Map<String, String> addressCache,
    Function(int current, int total)? onProgress,
  }) async {
    List<Map<String, dynamic>> enrichedReports = [];
    int processedCount = 0;
    
    for (var report in reports) {
      Map<String, dynamic> enrichedReport = Map.from(report);
      
      if ((enrichedReport['full_address_display']?.toString() ?? '').isEmpty) {
        if (enrichedReport['location'] != null) {
          try {
            String address = await _getAddressFromCoordinates(
              enrichedReport['location'],
              addressCache: addressCache,
            );
            enrichedReport['full_address_display'] = address;
          } catch (e) {
            print('Error getting address for report ${enrichedReport['id']}: $e');
            enrichedReport['full_address_display'] = 
              enrichedReport['cached_barangay']?.toString() ?? 'Unknown Location';
          }
        } else {
          enrichedReport['full_address_display'] = 
            enrichedReport['cached_barangay']?.toString() ?? 'Unknown Location';
        }
      }
      
      enrichedReports.add(enrichedReport);
      processedCount++;
      
      if (onProgress != null) {
        onProgress(processedCount, reports.length);
      }
    }
    
    return enrichedReports;
  }

  // Get address from coordinates using Nominatim
  static Future<String> _getAddressFromCoordinates(
    dynamic location, {
    required Map<String, String> addressCache,
  }) async {
    if (location == null) return 'Unknown Location';
   
    try {
      if (location is Map && location.containsKey('coordinates')) {
        final coords = location['coordinates'];
        if (coords is List && coords.length >= 2) {
          final lng = coords[0];
          final lat = coords[1];
         
          final cacheKey = '${lat}_${lng}';
         
          // Check cache first
          if (addressCache.containsKey(cacheKey)) {
            return addressCache[cacheKey]!;
          }
         
          await Future.delayed(const Duration(milliseconds: 1000));
         
          final response = await http.get(
            Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final address = data['address'] as Map<String, dynamic>?;
           
            if (address != null) {
              final List<String> addressParts = [];
             
              if (address['house_number'] != null && address['road'] != null) {
                addressParts.add('${address['house_number']} ${address['road']}');
              } else if (address['road'] != null) {
                addressParts.add(address['road'].toString());
              }
             
              if (address['suburb'] != null) {
                addressParts.add(address['suburb'].toString());
              } else if (address['neighbourhood'] != null) {
                addressParts.add(address['neighbourhood'].toString());
              }
             
              if (address['village'] != null) {
                addressParts.add(address['village'].toString());
              } else if (address['hamlet'] != null) {
                addressParts.add(address['hamlet'].toString());
              }
             
              String? barangay;
              if (address['city_district'] != null) {
                barangay = address['city_district'].toString();
              } else if (address['quarter'] != null) {
                barangay = address['quarter'].toString();
              }
             
              if (barangay != null && !addressParts.contains(barangay)) {
                addressParts.add(barangay);
              }
             
              if (address['city'] != null) {
                addressParts.add(address['city'].toString());
              } else if (address['municipality'] != null) {
                addressParts.add(address['municipality'].toString());
              } else if (address['town'] != null) {
                addressParts.add(address['town'].toString());
              }
             
              if (address['state'] != null) {
                addressParts.add(address['state'].toString());
              } else if (address['region'] != null) {
                addressParts.add(address['region'].toString());
              }
             
              if (address['postcode'] != null) {
                addressParts.add(address['postcode'].toString());
              }
             
              if (address['country'] != null) {
                addressParts.add(address['country'].toString());
              }
             
              final fullAddress = addressParts.join(', ');
             
              // Cache the result
              addressCache[cacheKey] = fullAddress.isNotEmpty ? fullAddress : data['display_name'] ?? 'Unknown Location';
              return addressCache[cacheKey]!;
            }
           
            final displayName = data['display_name']?.toString() ?? 'Unknown Location';
            addressCache[cacheKey] = displayName;
            return displayName;
          }
        }
      }
    } catch (e) {
      print('Error fetching address: $e');
    }
    return 'Unknown Location';
  }

  // Build PDF header
  static pw.Widget _buildPdfHeader(
    int currentPage,
    int totalPages,
    int totalReports,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Zamboanga City Crime Reports',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ZECURE - Crime Management System',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Page $currentPage of $totalPages',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Total Reports: $totalReports',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (startDate != null && endDate != null)
          pw.Text(
            'Period: ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 2),
      ],
    );
  }

  // Build PDF table
  static pw.Widget _buildPdfTable(List<Map<String, dynamic>> reports, {int startIndex = 0}) { // ADDED: startIndex parameter
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(2.5),
        6: const pw.FlexColumnWidth(2),
        7: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('#'),
            _buildTableHeader('Crime Type'),
            _buildTableHeader('Category'),
            _buildTableHeader('Level'),
            _buildTableHeader('Status'),
            _buildTableHeader('Location'),
            _buildTableHeader('Time of Incident'),
            _buildTableHeader('Reporter'),
          ],
        ),
        ...reports.asMap().entries.map((entry) {
          final index = startIndex + entry.key + 1; // CHANGED: Add startIndex to continue numbering
          final report = entry.value;
          return _buildTableRow(report, index);
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.TableRow _buildTableRow(Map<String, dynamic> report, int index) {
    return pw.TableRow(
      children: [
        _buildTableCell(index.toString()),
        _buildTableCell(
          report['crime_type']?['name']?.toString() ?? 'Unknown',
        ),
        _buildTableCell(
          report['crime_type']?['category']?.toString() ?? 'N/A',
        ),
        _buildTableCell(
          (report['crime_type']?['level']?.toString() ?? 'N/A').toUpperCase(),
        ),
        _buildTableCell(
          '${(report['status']?.toString() ?? 'PENDING').toUpperCase()}\n${(report['active_status']?.toString() ?? 'ACTIVE').toUpperCase()}',
        ),
        _buildTableCell(
          (report['full_address_display']?.toString() ?? '').isNotEmpty
              ? report['full_address_display'].toString()
              : (report['cached_barangay']?.toString() ?? '').isNotEmpty
                  ? report['cached_barangay'].toString()
                  : 'Unknown Location',
          fontSize: 7,
        ),
        _buildTableCell(
          report['time'] != null
              ? DateFormat('MMM d, yyyy\nh:mm a').format(DateTime.parse(report['time']))
              : 'N/A',
        ),
        _buildTableCell(
          _getReporterName(report),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {double fontSize = 7}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static String _getReporterName(Map<String, dynamic> report) {
    if (report['reporter'] != null && report['reported_by'] != null) {
      final firstName = report['reporter']['first_name']?.toString() ?? '';
      final lastName = report['reporter']['last_name']?.toString() ?? '';
      return '$firstName $lastName'.trim();
    } else if (report['users'] != null) {
      final firstName = report['users']['first_name']?.toString() ?? '';
      final lastName = report['users']['last_name']?.toString() ?? '';
      return '$firstName $lastName'.trim();
    }
    return 'Admin';
  }

  static pw.Widget _buildPdfFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'ZECURE - Crime Management System',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static void _sortReports(
    List<Map<String, dynamic>> reports,
    String sortBy,
    bool ascending,
  ) {
    reports.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortBy) {
        case 'crime_type':
          aValue = a['crime_type']?['name']?.toString().toLowerCase() ?? '';
          bValue = b['crime_type']?['name']?.toString().toLowerCase() ?? '';
          break;
        case 'category':
          aValue = a['crime_type']?['category']?.toString().toLowerCase() ?? '';
          bValue = b['crime_type']?['category']?.toString().toLowerCase() ?? '';
          break;
        case 'level':
          Map<String, int> levelPriority = {
            'critical': 4,
            'high': 3,
            'medium': 2,
            'low': 1,
          };
          aValue = levelPriority[a['crime_type']?['level']?.toString().toLowerCase()] ?? 0;
          bValue = levelPriority[b['crime_type']?['level']?.toString().toLowerCase()] ?? 0;
          break;
        case 'status':
          aValue = a['status']?.toString().toLowerCase() ?? '';
          bValue = b['status']?.toString().toLowerCase() ?? '';
          break;
        case 'activity':
          aValue = a['active_status']?.toString().toLowerCase() ?? '';
          bValue = b['active_status']?.toString().toLowerCase() ?? '';
          break;
        case 'barangay':
          aValue = a['cached_barangay']?.toString().toLowerCase() ?? '';
          bValue = b['cached_barangay']?.toString().toLowerCase() ?? '';
          break;
        case 'date':
          aValue = a['time'] != null ? DateTime.parse(a['time']) : DateTime.now();
          bValue = b['time'] != null ? DateTime.parse(b['time']) : DateTime.now();
          break;
        case 'reporter':
          aValue = _getReporterName(a).toLowerCase();
          bValue = _getReporterName(b).toLowerCase();
          break;
        default:
          aValue = '';
          bValue = '';
      }

      if (aValue is DateTime && bValue is DateTime) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      if (aValue is int && bValue is int) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      int comparison = aValue.toString().compareTo(bValue.toString());
      return ascending ? comparison : -comparison;
    });
  }
}