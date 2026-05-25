import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LaporanUang extends StatefulWidget {
  const LaporanUang({super.key, required this.totalIncome});

  final num totalIncome;

  @override
  State<LaporanUang> createState() => _LaporanUangState();
}

class _LaporanUangState extends State<LaporanUang> {
  bool isLoading = true;
  String? errorMessage;

  num totalIncomeFromApi = 0;
  num filteredIncome = 0;
  int totalTransactions = 0;
  List<dynamic> incomeData = [];

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();

    totalIncomeFromApi = widget.totalIncome;
    filteredIncome = widget.totalIncome;

    setCurrentMonthRange();
    fetchIncomeReport();
  }

  void setCurrentMonthRange() {
    final now = DateTime.now();

    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
  }

  bool get isDefaultMonthFilter {
    if (startDate == null || endDate == null) return false;

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    return startDate!.year == firstDay.year &&
        startDate!.month == firstDay.month &&
        startDate!.day == firstDay.day &&
        endDate!.year == lastDay.year &&
        endDate!.month == lastDay.month &&
        endDate!.day == lastDay.day;
  }

  String formatRupiah(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '0') ?? 0;
    final intNumber = number.round();

    final result = intNumber.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'Rp $result';
  }

  String formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(value.toString());
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    } catch (_) {
      return value.toString();
    }
  }

  String formatDateForApi(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String getMonthName(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return months[date.month - 1];
  }

  num parseMoney(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value;

    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleaned.trim().isEmpty) return 0;

    return num.tryParse(cleaned) ?? 0;
  }

  bool isApprovedPayment(Map<String, dynamic> item) {
    final status = item['status']?.toString().toLowerCase().trim() ?? '';

    if (status.isEmpty) return true;

    return status == 'approved' ||
        status == 'approve' ||
        status == 'paid' ||
        status == 'success' ||
        status == 'verified';
  }

  num getPaymentAmount(Map<String, dynamic> item) {
    return parseMoney(
      item['verified_amount'] ??
          item['amount'] ??
          item['claimed_amount'] ??
          item['total_amount'] ??
          0,
    );
  }

  DateTime? getPaymentDate(Map<String, dynamic> item) {
    final raw =
        item['verified_at'] ??
        item['paid_at'] ??
        item['updated_at'] ??
        item['created_at'];

    if (raw == null) return null;

    return DateTime.tryParse(raw.toString());
  }

  bool isInsideSelectedDateRange(Map<String, dynamic> item) {
    final date = getPaymentDate(item);

    if (date == null) return true;

    if (startDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);

      if (date.isBefore(start)) {
        return false;
      }
    }

    if (endDate != null) {
      final end = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        23,
        59,
        59,
      );

      if (date.isAfter(end)) {
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> normalizeIncomeData(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(isApprovedPayment)
          .where(isInsideSelectedDateRange)
          .toList();
    }

    return [];
  }

  num calculateIncomeFromData(List<Map<String, dynamic>> data) {
    num total = 0;

    for (final item in data) {
      total += getPaymentAmount(item);
    }

    return total;
  }

  dynamic decodeResponseBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchIncomeReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token =
          prefs.getString('token') ??
          prefs.getString('access_token') ??
          prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage = 'Token login tidak ditemukan. Silakan login ulang.';
        });

        return;
      }

      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['start_date'] = formatDateForApi(startDate!);
      }

      if (endDate != null) {
        queryParams['end_date'] = formatDateForApi(endDate!);
      }

      final uri = Uri.parse(
        '${ApiService.baseUrl}/reports/income',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('INCOME REPORT URL: $uri');
      debugPrint('INCOME REPORT STATUS: ${response.statusCode}');
      debugPrint('INCOME REPORT RESPONSE: ${response.body}');

      final decoded = decodeResponseBody(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        if (decoded is! Map) {
          setState(() {
            isLoading = false;
            errorMessage = 'Format response laporan tidak valid.';
          });

          return;
        }

        final decodedMap = Map<String, dynamic>.from(decoded);

        final normalizedData = normalizeIncomeData(decodedMap['data']);
        final calculatedIncome = calculateIncomeFromData(normalizedData);

        final apiIncomeTotal = decodedMap['total_income'] is num
            ? decodedMap['total_income'] as num
            : num.tryParse(decodedMap['total_income']?.toString() ?? '0') ?? 0;

        final finalIncome = normalizedData.isNotEmpty
            ? calculatedIncome
            : apiIncomeTotal;

        setState(() {
          incomeData = normalizedData;
          totalIncomeFromApi = finalIncome;
          filteredIncome = finalIncome;
          totalTransactions = normalizedData.length;
          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage = decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ?? 'Gagal memuat laporan'
              : 'Gagal memuat laporan';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Terjadi kesalahan koneksi: $e';
      });
    }
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal awal',
    );

    if (picked == null) return;

    setState(() {
      startDate = picked;

      if (endDate != null && endDate!.isBefore(startDate!)) {
        endDate = picked;
      }
    });

    await fetchIncomeReport();
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal akhir',
    );

    if (picked == null) return;

    setState(() {
      endDate = picked;
    });

    await fetchIncomeReport();
  }

  Future<void> resetFilter() async {
    setState(() {
      setCurrentMonthRange();
    });

    await fetchIncomeReport();
  }

  String safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;

    final text = value.toString();

    if (text.trim().isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  String getNestedText(
    Map<String, dynamic> item,
    List<List<String>> paths, {
    String fallback = '-',
  }) {
    for (final path in paths) {
      dynamic current = item;

      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }

      if (current != null && current.toString().trim().isNotEmpty) {
        return current.toString();
      }
    }

    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0A0E50),
          onRefresh: fetchIncomeReport,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildFilterCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: _buildLoadingCard(),
                  ),
                )
              else if (errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: _buildErrorCard(),
                  ),
                )
              else if (incomeData.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: _buildEmptyCard(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final rawItem = incomeData[index];

                      if (rawItem is Map<String, dynamic>) {
                        return _buildIncomeItem(rawItem);
                      }

                      if (rawItem is Map) {
                        return _buildIncomeItem(
                          Map<String, dynamic>.from(rawItem),
                        );
                      }

                      return const SizedBox.shrink();
                    }, childCount: incomeData.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detail Uang Masuk',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                startDate == null || endDate == null
                    ? 'Riwayat pembayaran approved'
                    : 'Periode ${formatDate(startDate!.toIso8601String())} - ${formatDate(endDate!.toIso8601String())}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: fetchIncomeReport,
          icon: const Icon(Icons.refresh_rounded),
          color: const Color(0xFF0A0E50),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final monthText = startDate == null
        ? 'Bulan berjalan'
        : '${getMonthName(startDate!)} ${startDate!.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E50), Color(0xFF123C8C), Color(0xFF246BFD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A0E50).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 44,
            bottom: -48,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Approved',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Total Uang Masuk',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                monthText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  formatRupiah(totalIncomeFromApi),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '$totalTransactions transaksi pembayaran disetujui',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded, color: Color(0xFF0A0E50)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Filter Tanggal',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isDefaultMonthFilter)
                InkWell(
                  onTap: resetFilter,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Bulan Ini',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  title: 'Tanggal Awal',
                  value: startDate == null
                      ? 'Pilih tanggal'
                      : formatDate(startDate!.toIso8601String()),
                  onTap: pickStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateButton(
                  title: 'Tanggal Akhir',
                  value: endDate == null
                      ? 'Pilih tanggal'
                      : formatDate(endDate!.toIso8601String()),
                  onTap: pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Uang masuk sesuai filter: ${formatRupiah(filteredIncome)}',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF0A0E50),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Riwayat Uang Masuk',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E50).withOpacity(0.08),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$totalTransactions data',
            style: const TextStyle(
              color: Color(0xFF0A0E50),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeItem(Map<String, dynamic> item) {
    final amount = getPaymentAmount(item);

    final verifiedAt =
        item['verified_at'] ??
        item['paid_at'] ??
        item['updated_at'] ??
        item['created_at'];

    final invoiceCode = getNestedText(item, [
      ['invoice', 'invoice_number'],
      ['invoice', 'code'],
      ['invoice', 'id'],
    ], fallback: 'Invoice #${safeText(item['invoice_id'])}');

    final propertyName = getNestedText(item, [
      ['rental_booking', 'property', 'name'],
      ['rentalBooking', 'property', 'name'],
      ['rental_booking', 'kost', 'name'],
      ['rentalBooking', 'kost', 'name'],
      ['rental_booking', 'room', 'name'],
      ['rentalBooking', 'room', 'name'],
      ['rental_booking', 'property_name'],
      ['rentalBooking', 'property_name'],
      ['rental_booking', 'place_property', 'name'],
      ['rentalBooking', 'placeProperty', 'name'],
      ['rental_booking', 'place_property', 'title'],
      ['rentalBooking', 'placeProperty', 'title'],
    ], fallback: 'Pembayaran Sewa');

    final paymentMethod = safeText(
      item['payment_method'] ?? item['method'],
      fallback: 'Pembayaran',
    );

    final status = safeText(item['status'], fallback: 'approved');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  propertyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$invoiceCode • $paymentMethod',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        formatDate(verifiedAt),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatRupiah(amount),
              style: const TextStyle(
                color: Color(0xFF15803D),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF0A0E50)),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 46,
          ),
          const SizedBox(height: 10),
          const Text(
            'Gagal memuat data',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            errorMessage ?? '-',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: fetchIncomeReport,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A0E50),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.payments_outlined, color: Color(0xFF0A0E50), size: 54),
          SizedBox(height: 12),
          Text(
            'Belum ada uang masuk bulan ini',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Setiap ganti bulan, total uang masuk otomatis mulai dari Rp 0 sampai ada pembayaran approved baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
