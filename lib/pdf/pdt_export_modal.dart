import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/search_filter_service.dart';
import 'pdf_export_service.dart';

class PdfExportModal {
  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> reports,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, String>? addressCache, // ADDED
    Function(Map<String, String>)? onCacheUpdate, // ADDED
  }) {
    showDialog(
      context: context,
      builder: (context) => _PdfExportDialog(
        reports: reports,
        startDate: startDate,
        endDate: endDate,
        addressCache: addressCache, // ADDED
        onCacheUpdate: onCacheUpdate, // ADDED
      ),
    );
  }
}

class _PdfExportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> reports;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, String>? addressCache; // ADDED
  final Function(Map<String, String>)? onCacheUpdate; // ADDED

  const _PdfExportDialog({
    required this.reports,
    this.startDate,
    this.endDate,
    this.addressCache, // ADDED
    this.onCacheUpdate, // ADDED
  });

  @override
  State<_PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<_PdfExportDialog> {
  String _selectedPaperSize = 'A4';
  String _selectedSortBy = 'date';
  bool _sortAscending = false;
  bool _isExporting = false;
  String _exportingMessage = ''; // ADDED: Custom message for export status

  // Filter selections
  Set<String> _selectedLevels = {};
  Set<String> _selectedCrimeTypes = {};
  Set<String> _selectedBarangays = {};
  Set<String> _selectedStatuses = {};

  // Available options
  List<String> _availableLevels = [];
  List<String> _availableCrimeTypes = [];
  List<String> _availableBarangays = [];
  List<String> _availableStatuses = [];

  final List<Map<String, String>> _sortOptions = [
    {'value': 'date', 'label': 'Time of Incident'},
    {'value': 'crime_type', 'label': 'Crime Type'},
    {'value': 'category', 'label': 'Category'},
    {'value': 'level', 'label': 'Crime Level'},
    {'value': 'status', 'label': 'Status'},
    {'value': 'activity', 'label': 'Activity Status'},
    {'value': 'barangay', 'label': 'Barangay'},
    {'value': 'reporter', 'label': 'Reporter'},
  ];

  final Map<String, String> _crimeTypeToLevel = {};

  @override
  void initState() {
    super.initState();
    _initializeFilterOptions();
  }

  void _initializeFilterOptions() {
    // Get unique levels
    Set<String> levels = {};
    for (var report in widget.reports) {
      String level = SearchAndFilterService.getNestedString(report, [
        'crime_type',
        'level',
      ]);
      if (level.isNotEmpty) {
        levels.add(_capitalizeFirst(level));
      }
    }
    _availableLevels = levels.toList()..sort();

    // Get unique crime types
    Set<String> crimeTypes = {};
    for (var report in widget.reports) {
      String crimeType = SearchAndFilterService.getNestedString(report, [
        'crime_type',
        'name',
      ]);
      String level = SearchAndFilterService.getNestedString(report, [
        'crime_type',
        'level',
      ]);
      if (crimeType.isNotEmpty) {
        crimeTypes.add(crimeType);
        if (level.isNotEmpty) {
          _crimeTypeToLevel[crimeType] = _capitalizeFirst(level);
        }
      }
    }
    _availableCrimeTypes = crimeTypes.toList()..sort();

    // Get unique barangays FROM CACHED DATA - THIS IS THE KEY CHANGE
    Set<String> barangays = {};
    for (var report in widget.reports) {
      // Use cached_barangay which is already loaded in admin_dashboard
      String barangay = report['cached_barangay']?.toString() ?? '';
      if (barangay.isNotEmpty && barangay != 'Unknown Location') {
        barangays.add(barangay);
      }
    }
    _availableBarangays = barangays.toList()..sort();

    // Get unique statuses
    Set<String> statuses = {};
    for (var report in widget.reports) {
      String status = report['status']?.toString() ?? '';
      if (status.isNotEmpty) {
        statuses.add(_capitalizeFirst(status));
      }
    }
    _availableStatuses = statuses.toList()..sort();
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    List<Map<String, dynamic>> filtered = List.from(widget.reports);

    // Filter by crime level
    if (_selectedLevels.isNotEmpty) {
      filtered = filtered.where((report) {
        String level = SearchAndFilterService.getNestedString(report, [
          'crime_type',
          'level',
        ]);
        return _selectedLevels.contains(_capitalizeFirst(level));
      }).toList();
    }

    // Filter by crime type
    if (_selectedCrimeTypes.isNotEmpty) {
      filtered = filtered.where((report) {
        String crimeType = SearchAndFilterService.getNestedString(report, [
          'crime_type',
          'name',
        ]);
        return _selectedCrimeTypes.contains(crimeType);
      }).toList();
    }

    // Filter by barangay
    if (_selectedBarangays.isNotEmpty) {
      filtered = filtered.where((report) {
        String barangay = report['cached_barangay']?.toString() ?? '';
        return _selectedBarangays.contains(barangay);
      }).toList();
    }

    // Filter by status
    if (_selectedStatuses.isNotEmpty) {
      filtered = filtered.where((report) {
        String status = report['status']?.toString() ?? '';
        return _selectedStatuses.contains(_capitalizeFirst(status));
      }).toList();
    }

    return filtered;
  }

  void _updateAvailableOptions() {
    // Helper to get filtered reports excluding a specific filter
    List<Map<String, dynamic>> getFilteredExcluding(String excludeFilter) {
      List<Map<String, dynamic>> filtered = List.from(widget.reports);

      if (excludeFilter != 'levels' && _selectedLevels.isNotEmpty) {
        filtered = filtered.where((report) {
          String level = SearchAndFilterService.getNestedString(report, [
            'crime_type',
            'level',
          ]);
          return _selectedLevels.contains(_capitalizeFirst(level));
        }).toList();
      }

      if (excludeFilter != 'crimeTypes' && _selectedCrimeTypes.isNotEmpty) {
        filtered = filtered.where((report) {
          String crimeType = SearchAndFilterService.getNestedString(report, [
            'crime_type',
            'name',
          ]);
          return _selectedCrimeTypes.contains(crimeType);
        }).toList();
      }

      if (excludeFilter != 'barangays' && _selectedBarangays.isNotEmpty) {
        filtered = filtered.where((report) {
          String barangay = report['cached_barangay']?.toString() ?? '';
          return _selectedBarangays.contains(barangay);
        }).toList();
      }

      if (excludeFilter != 'statuses' && _selectedStatuses.isNotEmpty) {
        filtered = filtered.where((report) {
          String status = report['status']?.toString() ?? '';
          return _selectedStatuses.contains(_capitalizeFirst(status));
        }).toList();
      }

      return filtered;
    }

    // Levels are fixed: always all from full reports (per user request)
    // No update here; use the initial _availableLevels

    // Available crime types: exclude own filter
    Set<String> crimeTypes = {};
    var filteredForCrimeTypes = getFilteredExcluding('crimeTypes');
    for (var report in filteredForCrimeTypes) {
      String crimeType = SearchAndFilterService.getNestedString(report, [
        'crime_type',
        'name',
      ]);
      if (crimeType.isNotEmpty) crimeTypes.add(crimeType);
    }

    // Available barangays: exclude own
    Set<String> barangays = {};
    var filteredForBarangays = getFilteredExcluding('barangays');
    for (var report in filteredForBarangays) {
      String barangay = report['cached_barangay']?.toString() ?? '';
      if (barangay.isNotEmpty && barangay != 'Unknown Location') {
        barangays.add(barangay);
      }
    }

    // Available statuses: exclude own
    Set<String> statuses = {};
    var filteredForStatuses = getFilteredExcluding('statuses');
    for (var report in filteredForStatuses) {
      String status = report['status']?.toString() ?? '';
      if (status.isNotEmpty) statuses.add(_capitalizeFirst(status));
    }

    setState(() {
      _availableCrimeTypes = crimeTypes.toList()..sort();
      _availableBarangays = barangays.toList()..sort();
      _availableStatuses = statuses.toList()..sort();

      // Auto-remove selected if no longer available (for all except levels, since fixed)
      _selectedCrimeTypes.removeWhere(
        (item) => !_availableCrimeTypes.contains(item),
      );
      _selectedBarangays.removeWhere(
        (item) => !_availableBarangays.contains(item),
      );
      _selectedStatuses.removeWhere(
        (item) => !_availableStatuses.contains(item),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _getFilteredReports();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export to PDF',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Configure export settings and filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Summary
                    _buildReportSummary(filteredReports),
                    const SizedBox(height: 24),

                    // Crime Level Filter
                    _buildMultiSelectSection(
                      title: 'Crime Levels',
                      icon: Icons.warning_amber,
                      items: _availableLevels,
                      selectedItems: _selectedLevels,
                      onChanged: (selected) {
                        setState(() => _selectedLevels = selected);
                        // Enforce dependency: remove incompatible crime types
                        _selectedCrimeTypes.removeWhere((type) {
                          final level = _crimeTypeToLevel[type] ?? '';
                          return !_selectedLevels.contains(level);
                        });
                        _updateAvailableOptions();
                      },
                      emptyMessage: 'All levels included',
                      note:
                          'Default: All crime levels are included in the export.',
                    ),
                    const SizedBox(height: 20),

                    // Crime Type Filter
                    _buildMultiSelectSection(
                      title: 'Crime Types',
                      icon: Icons.category,
                      items: _availableCrimeTypes,
                      selectedItems: _selectedCrimeTypes,
                      onChanged: (selected) {
                        setState(() => _selectedCrimeTypes = selected);
                        _updateAvailableOptions();
                      },
                      emptyMessage: 'All crime types included',
                      note:
                          'Default: All crime types are included in the export.',
                    ),
                    const SizedBox(height: 20),

                    // Barangay Filter
                    _buildMultiSelectSection(
                      title: 'Barangays',
                      icon: Icons.location_on,
                      items: _availableBarangays,
                      selectedItems: _selectedBarangays,
                      onChanged: (selected) {
                        setState(() => _selectedBarangays = selected);
                        _updateAvailableOptions();
                      },
                      emptyMessage: 'All barangays included',
                      note:
                          'Default: All barangays are included. List is based on available cached location data.',
                    ),
                    const SizedBox(height: 20),

                    // Status Filter
                    _buildMultiSelectSection(
                      title: 'Status',
                      icon: Icons.info,
                      items: _availableStatuses,
                      selectedItems: _selectedStatuses,
                      onChanged: (selected) {
                        setState(() => _selectedStatuses = selected);
                        _updateAvailableOptions();
                      },
                      emptyMessage: 'All statuses included',
                      note: 'Default: All statuses are included in the export.',
                    ),
                    const SizedBox(height: 24),

                    // Paper Size Selection
                    const Text(
                      'Paper Size',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: PdfExportService.paperSizes.keys.map((size) {
                        final isSelected = _selectedPaperSize == size;
                        return ChoiceChip(
                          label: Text(size),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedPaperSize = size);
                          },
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Sort Options
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedSortBy,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: _sortOptions.map((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSortBy = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sort Order
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 20,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _sortAscending
                                  ? 'Ascending Order'
                                  : 'Descending Order',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          Switch(
                            value: _sortAscending,
                            onChanged: (value) {
                              setState(() => _sortAscending = value);
                            },
                            activeColor: const Color(0xFF6366F1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isExporting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isExporting || filteredReports.isEmpty
                          ? null
                          : _exportPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isExporting
                          ? Row(
                              // UPDATED: Show custom progress message
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _exportingMessage.isNotEmpty
                                      ? _exportingMessage
                                      : 'Exporting...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.download, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Export ${filteredReports.length} Report${filteredReports.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary(List<Map<String, dynamic>> filteredReports) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Report Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Total Reports', '${widget.reports.length}'),
          _buildSummaryRow(
            'Filtered Reports',
            '${filteredReports.length}',
            valueColor: filteredReports.length < widget.reports.length
                ? const Color(0xFF6366F1)
                : null,
          ),
          if (widget.startDate != null && widget.endDate != null)
            _buildSummaryRow(
              'Date Range',
              '${DateFormat('MMM d, yyyy').format(widget.startDate!)} - ${DateFormat('MMM d, yyyy').format(widget.endDate!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required Set<String> selectedItems,
    required Function(Set<String>) onChanged,
    required String emptyMessage,
    String? note, // ADDED: For permanent default note
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            if (selectedItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedItems.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        // ADDED: Default Note
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8), // Subtle text color
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                Text(
                  'No options available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (selectedItems.isEmpty)
                // UPDATED: Stylized "All Included" message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedItems.map((item) {
                    return Chip(
                      label: Text(item),
                      onDeleted: () {
                        final newSelected = Set<String>.from(selectedItems)
                          ..remove(item);
                        onChanged(newSelected);
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showMultiSelectDialog(
                    title: title,
                    items: items,
                    selectedItems: selectedItems,
                    onChanged: onChanged,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    selectedItems.isEmpty ? 'Select $title' : 'Edit Selection',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showMultiSelectDialog({
    required String title,
    required List<String> items,
    required Set<String> selectedItems,
    required Function(Set<String>) onChanged,
  }) {
    showDialog(
      context: context,
      builder: (context) => _MultiSelectDialog(
        title: title,
        items: items,
        selectedItems: selectedItems,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final filteredReports = _getFilteredReports();

    if (filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports match the selected filters'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportingMessage = 'Preparing PDF...';
    });

    try {
      final pageFormat = PdfExportService.paperSizes[_selectedPaperSize]!;
      final fileName =
          'crime_reports_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.pdf';

      await PdfExportService.exportReportsToPdf(
        reports: filteredReports,
        fileName: fileName,
        pageFormat: pageFormat,
        addressCache: widget.addressCache, // ADDED: Pass cache from parent
        onCacheUpdate: widget.onCacheUpdate, // ADDED: Pass callback
        sortBy: _selectedSortBy,
        ascending: _sortAscending,
        startDate: widget.startDate,
        endDate: widget.endDate,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _exportingMessage = 'Fetching Addresses: $current of $total';
            });
          }
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF exported successfully (${filteredReports.length} reports)',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingMessage = '';
        });
      }
    }
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final Set<String> selectedItems;
  final Function(Set<String>) onChanged;

  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late Set<String> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selectedItems);
  }

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items
        .where(
          (item) => item.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select ${widget.title}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.title.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Select all / Clear all
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          // Only select the currently filtered items if a query is active
                          final itemsToSelect = _searchQuery.isEmpty
                              ? widget.items
                              : _filteredItems;
                          setState(
                            () => _tempSelected = Set.from(itemsToSelect),
                          );
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Clear only the visible selection if search is active
                          if (_searchQuery.isNotEmpty) {
                            final filtered = _filteredItems;
                            setState(() {
                              _tempSelected.removeWhere(
                                (item) => filtered.contains(item),
                              );
                            });
                          } else {
                            setState(() => _tempSelected.clear());
                          }
                        },
                        child: const Text('Clear All'),
                      ),
                      const Spacer(),
                      Text(
                        '${_tempSelected.length} selected',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = _tempSelected.contains(item);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _tempSelected.add(item);
                        } else {
                          _tempSelected.remove(item);
                        }
                      });
                    },
                    title: Text(item, style: const TextStyle(fontSize: 14)),
                    activeColor: const Color(0xFF6366F1),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onChanged(_tempSelected);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
