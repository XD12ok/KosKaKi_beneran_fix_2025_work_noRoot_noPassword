import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Owner/LaporanUang.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF123C8C);
  final Color backgroundColor = const Color(0xFFF4F7FB);
  final Color darkText = const Color(0xFF111827);
  final Color greyText = const Color(0xFF6B7280);

  bool isLoading = true;
  String? errorMessage;

  DateTime selectedMonth = DateTime.now();

  num totalIncome = 0;
  num totalOverdueAmount = 0;

  int totalTransactions = 0;
  int totalApproved = 0;
  int totalPending = 0;
  int totalRejected = 0;
  int totalOverdue = 0;

  List<Map<String, dynamic>> incomeReports = [];
  List<Map<String, dynamic>> overdueReports = [];

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  String cleanToken(String? token) {
    if (token == null) return "";

    String cleaned = token.trim();

    if (cleaned.toLowerCase().startsWith("bearer ")) {
      cleaned = cleaned.substring(7).trim();
    }

    cleaned = cleaned.replaceAll('"', '').replaceAll("'", "").trim();

    return cleaned;
  }

  Future<String> getValidToken() async {
    final apiToken = cleanToken(await ApiService().getToken());

    if (apiToken.isNotEmpty) return apiToken;

    final prefs = await SharedPreferences.getInstance();

    return cleanToken(
      prefs.getString('token') ??
          prefs.getString('access_token') ??
          prefs.getString('auth_token'),
    );
  }

  Map<String, String> authHeaders(String token) {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
      "X-Requested-With": "XMLHttpRequest",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    };
  }

  String formatDateForApi(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime get startOfMonth {
    return DateTime(selectedMonth.year, selectedMonth.month, 1);
  }

  DateTime get endOfMonth {
    return DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  }

  String getMonthName(int month) {
    const months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    return months[month - 1];
  }

  String get monthLabel {
    return "${getMonthName(selectedMonth.month)} ${selectedMonth.year}";
  }

  void previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    });

    fetchReport();
  }

  void nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    if (next.isAfter(currentMonth)) return;

    setState(() {
      selectedMonth = next;
    });

    fetchReport();
  }

  bool canGoNextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    return !next.isAfter(currentMonth);
  }

  num parseMoney(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value;

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return 0;

    text = text.replaceAll("Rp", "").trim();

    if (RegExp(r',\d{1,2}$').hasMatch(text)) {
      text = text.split(',').first;
    }

    if (RegExp(r'\.\d{1,2}$').hasMatch(text)) {
      text = text.split('.').first;
    }

    final normalNumber = num.tryParse(text);

    if (normalNumber != null) return normalNumber;

    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return 0;

    return num.tryParse(cleaned) ?? 0;
  }

  int parseIntValue(dynamic value) {
    return parseMoney(value).round();
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<Map<String, dynamic>> parseDynamicList(dynamic value) {
    dynamic rawData;

    if (value is Map) {
      rawData = value["data"];

      if (rawData is Map && rawData["data"] != null) {
        rawData = rawData["data"];
      }

      rawData ??= value["reports"];
      rawData ??= value["items"];
      rawData ??= value["payments"];
      rawData ??= value["transactions"];
      rawData ??= value["overdue"];
      rawData ??= value["overdues"];
    } else {
      rawData = value;
    }

    if (rawData is List) {
      return rawData
          .where((item) => item is Map)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    if (rawData is Map) {
      return [Map<String, dynamic>.from(rawData)];
    }

    return [];
  }

  String parseResponseMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        String message = decoded["message"]?.toString() ?? fallback;

        final errors = decoded["errors"];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          } else {
            message = firstError.toString();
          }
        }

        return message;
      }

      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  bool isApprovedStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    return status == 'approved' ||
        status == 'approve' ||
        status == 'paid' ||
        status == 'success' ||
        status == 'verified' ||
        status == 'lunas';
  }

  bool isPendingStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    return status == 'pending' ||
        status == 'waiting' ||
        status == 'waiting_confirmation' ||
        status == 'waiting_verification' ||
        status == 'unverified' ||
        status == 'menunggu';
  }

  bool isRejectedStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    return status == 'rejected' ||
        status == 'reject' ||
        status == 'failed' ||
        status == 'ditolak';
  }

  bool isOverdueStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    return status == 'overdue' ||
        status == 'terlambat' ||
        status == 'late';
  }

  num getReportAmount(Map<String, dynamic> item) {
    return parseMoney(
      item["verified_amount"] ??
          item["amount"] ??
          item["claimed_amount"] ??
          item["total_amount"] ??
          item["total_price"] ??
          item["remaining_amount"] ??
          item["price"] ??
          0,
    );
  }

  String getReportStatus(Map<String, dynamic> item) {
    return item["status"]?.toString().toLowerCase().trim() ??
        item["payment_status"]?.toString().toLowerCase().trim() ??
        "";
  }

  String getPropertyName(Map<String, dynamic> item) {
    final rentalBooking = toMap(item["rental_booking"]) ??
        toMap(item["rentalBooking"]) ??
        toMap(item["booking"]);

    final property = toMap(item["property"]) ??
        toMap(item["place_property"]) ??
        toMap(item["placeProperty"]) ??
        toMap(item["place_properties"]) ??
        toMap(item["placeProperties"]) ??
        toMap(rentalBooking?["property"]) ??
        toMap(rentalBooking?["place_property"]) ??
        toMap(rentalBooking?["placeProperty"]) ??
        toMap(rentalBooking?["place_properties"]) ??
        toMap(rentalBooking?["placeProperties"]);

    final candidates = [
      item["property_name"],
      item["place_property_name"],
      item["nama_kos"],
      item["nama_kost"],
      item["kos_name"],
      item["kost_name"],
      item["title"],
      item["name"],
      rentalBooking?["property_name"],
      rentalBooking?["place_property_name"],
      rentalBooking?["nama_kos"],
      rentalBooking?["nama_kost"],
      rentalBooking?["title"],
      rentalBooking?["name"],
      property?["property_name"],
      property?["place_property_name"],
      property?["nama_kos"],
      property?["nama_kost"],
      property?["title"],
      property?["name"],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }

    return "Nama kos tidak tersedia";
  }

  String getResidentName(Map<String, dynamic> item) {
    final rentalBookingMap = toMap(item["rental_booking"]) ??
        toMap(item["rentalBooking"]);
  
    final bookingMap = toMap(item["booking"]);
  
    final user = toMap(item["user"]) ??
        toMap(item["resident"]) ??
        toMap(item["tenant"]) ??
        toMap(rentalBookingMap?["user"]) ??
        toMap(bookingMap?["user"]);
  
    final candidates = [
      item["sender_name"],
      item["user_name"],
      item["resident_name"],
      item["tenant_name"],
      item["name"],
      user?["name"],
      user?["username"],
      user?["full_name"],
    ];
  
    for (final value in candidates) {
      final text = value?.toString().trim() ?? "";
  
      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }
  
    return "Penyewa";
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return null;

    return DateTime.tryParse(text);
  }

  String formatDate(dynamic value) {
    final date = parseDate(value);

    if (date == null) return "-";

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String getReportDate(Map<String, dynamic> item) {
    final date =
        item["verified_at"] ??
        item["paid_at"] ??
        item["created_at"] ??
        item["updated_at"] ??
        item["payment_date"] ??
        item["date"];

    return formatDate(date);
  }

  String formatRupiah(dynamic value) {
    final number = parseMoney(value).round();

    final result = number.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ".",
        );

    return "Rp $result";
  }

  Future<Map<String, dynamic>> fetchIncomeReport(String token) async {
    final uri = Uri.parse("${ApiService.baseUrl}/reports/income").replace(
      queryParameters: {
        "start_date": formatDateForApi(startOfMonth),
        "end_date": formatDateForApi(endOfMonth),
      },
    );

    debugPrint("LAPORAN INCOME URL:");
    debugPrint(uri.toString());

    final response = await http
        .get(uri, headers: authHeaders(token))
        .timeout(const Duration(seconds: 20));

    debugPrint("LAPORAN INCOME STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("LAPORAN INCOME BODY:");
    debugPrint(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        parseResponseMessage(response.body, "Gagal mengambil laporan income"),
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) return decoded;

    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    return {
      "data": decoded,
    };
  }

  Future<Map<String, dynamic>> fetchOverdueReport(String token) async {
    final uri = Uri.parse("${ApiService.baseUrl}/reports/overdue").replace(
      queryParameters: {
        "start_date": formatDateForApi(startOfMonth),
        "end_date": formatDateForApi(endOfMonth),
      },
    );

    debugPrint("LAPORAN OVERDUE URL:");
    debugPrint(uri.toString());

    final response = await http
        .get(uri, headers: authHeaders(token))
        .timeout(const Duration(seconds: 20));

    debugPrint("LAPORAN OVERDUE STATUS:");
    debugPrint(response.statusCode.toString());

    debugPrint("LAPORAN OVERDUE BODY:");
    debugPrint(response.body);

    if (response.statusCode != 200) {
      return {
        "data": [],
        "total_overdue": 0,
        "total_overdue_amount": 0,
      };
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) return decoded;

    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    return {
      "data": decoded,
    };
  }

  void applyIncomeResult(Map<String, dynamic> decoded) {
    final reports = parseDynamicList(decoded);

    num calculatedApprovedIncome = 0;
    int approvedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;

    for (final item in reports) {
      final status = getReportStatus(item);

      if (isApprovedStatus(status)) {
        approvedCount++;
        calculatedApprovedIncome += getReportAmount(item);
      } else if (isPendingStatus(status)) {
        pendingCount++;
      } else if (isRejectedStatus(status)) {
        rejectedCount++;
      }
    }

    final serverTotalIncome = parseMoney(
      decoded["total_income"] ??
          decoded["total"] ??
          decoded["income"] ??
          decoded["total_amount"],
    );

    final serverTotalTransactions = parseIntValue(
      decoded["total_transactions"] ??
          decoded["transactions"] ??
          decoded["count"] ??
          reports.length,
    );

    totalIncome =
        serverTotalIncome > 0 ? serverTotalIncome : calculatedApprovedIncome;

    totalTransactions =
        serverTotalTransactions > 0 ? serverTotalTransactions : reports.length;

    totalApproved = approvedCount;
    totalPending = pendingCount;
    totalRejected = rejectedCount;
    incomeReports = reports;
  }

  void applyOverdueResult(Map<String, dynamic> decoded) {
    final reports = parseDynamicList(decoded);

    num calculatedOverdueAmount = 0;

    for (final item in reports) {
      calculatedOverdueAmount += getReportAmount(item);
    }

    final serverTotalOverdue = parseIntValue(
      decoded["total_overdue"] ??
          decoded["total_overdue_transactions"] ??
          decoded["total_transactions"] ??
          decoded["count"] ??
          reports.length,
    );

    final serverOverdueAmount = parseMoney(
      decoded["total_overdue_amount"] ??
          decoded["total_amount"] ??
          decoded["remaining_amount"] ??
          decoded["total"],
    );

    totalOverdue = serverTotalOverdue > 0 ? serverTotalOverdue : reports.length;

    totalOverdueAmount =
        serverOverdueAmount > 0 ? serverOverdueAmount : calculatedOverdueAmount;

    overdueReports = reports;
  }

  Future<void> fetchReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await getValidToken();

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          totalIncome = 0;
          totalOverdueAmount = 0;
          totalTransactions = 0;
          totalApproved = 0;
          totalPending = 0;
          totalRejected = 0;
          totalOverdue = 0;
          incomeReports = [];
          overdueReports = [];
          isLoading = false;
          errorMessage = "Token login tidak ditemukan. Silakan login ulang.";
        });

        return;
      }

      final incomeResult = await fetchIncomeReport(token);
      final overdueResult = await fetchOverdueReport(token);

      if (!mounted) return;

      setState(() {
        applyIncomeResult(incomeResult);
        applyOverdueResult(overdueResult);
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      debugPrint("LAPORAN PAGE ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        totalIncome = 0;
        totalOverdueAmount = 0;
        totalTransactions = 0;
        totalApproved = 0;
        totalPending = 0;
        totalRejected = 0;
        totalOverdue = 0;
        incomeReports = [];
        overdueReports = [];
        isLoading = false;
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      });
    }
  }

  Color getStatusColor(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (isApprovedStatus(status)) return const Color(0xFF16A34A);
    if (isPendingStatus(status)) return const Color(0xFFF59E0B);
    if (isRejectedStatus(status)) return const Color(0xFFEF4444);
    if (isOverdueStatus(status)) return const Color(0xFFDC2626);

    return primaryColor;
  }

  String getStatusText(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (isApprovedStatus(status)) return "Approved";
    if (isPendingStatus(status)) return "Pending";
    if (isRejectedStatus(status)) return "Rejected";
    if (isOverdueStatus(status)) return "Overdue";

    if (status.isEmpty) return "Status";
    return status.replaceAll("_", " ").toUpperCase();
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Laporan Keuangan",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Data pemasukan dan tunggakan kost",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: isLoading ? null : fetchReport,
          icon: const Icon(Icons.refresh_rounded),
          color: primaryColor,
        ),
      ],
    );
  }

  Widget buildMonthSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isLoading ? null : previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            color: primaryColor,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${formatDate(startOfMonth)} - ${formatDate(endOfMonth)}",
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isLoading || !canGoNextMonth() ? null : nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            color: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget buildTotalIncomeCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LaporanUang(totalIncome: totalIncome),
          ),
        ).then((_) => fetchReport());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [primaryColor, secondColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -22,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 38,
              bottom: -34,
              child: Container(
                width: 95,
                height: 95,
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
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
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
                          Text(
                            "Detail",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  "Total Uang Masuk",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (isLoading)
                  const SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                else if (errorMessage != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gagal memuat data",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRupiah(totalIncome),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  "Periode $monthLabel",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildStatCard(
                icon: Icons.receipt_long_rounded,
                title: "Transaksi",
                value: totalTransactions.toString(),
                subtitle: "Semua data",
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: buildStatCard(
                icon: Icons.verified_rounded,
                title: "Approved",
                value: totalApproved.toString(),
                subtitle: "Sudah diterima",
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: buildStatCard(
                icon: Icons.hourglass_top_rounded,
                title: "Pending",
                value: totalPending.toString(),
                subtitle: "Menunggu",
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: buildStatCard(
                icon: Icons.warning_amber_rounded,
                title: "Overdue",
                value: totalOverdue.toString(),
                subtitle: formatRupiah(totalOverdueAmount),
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryColor, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: greyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildIncomeList() {
    final visibleReports = incomeReports.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          buildSectionTitle(
            title: "Riwayat Pemasukan",
            subtitle: "Data pembayaran dari API",
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 14),
          if (isLoading)
            buildMiniLoading()
          else if (incomeReports.isEmpty)
            buildEmptyMiniState(
              icon: Icons.receipt_long_outlined,
              title: "Belum ada pemasukan",
              subtitle: "Data pemasukan untuk periode ini masih kosong.",
            )
          else
            Column(
              children: visibleReports.map((item) {
                return buildIncomeItem(item);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget buildIncomeItem(Map<String, dynamic> item) {
    final status = getReportStatus(item);
    final statusColor = getStatusColor(status);
    final amount = getReportAmount(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isApprovedStatus(status)
                  ? Icons.check_circle_rounded
                  : isPendingStatus(status)
                      ? Icons.hourglass_top_rounded
                      : isRejectedStatus(status)
                          ? Icons.cancel_rounded
                          : Icons.receipt_long_rounded,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getPropertyName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getResidentName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getReportDate(item),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupiah(amount),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              buildStatusBadge(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildOverdueList() {
    final visibleReports = overdueReports.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          buildSectionTitle(
            title: "Laporan Overdue",
            subtitle: "Tagihan yang sudah lewat jatuh tempo",
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 14),
          if (isLoading)
            buildMiniLoading()
          else if (overdueReports.isEmpty)
            buildEmptyMiniState(
              icon: Icons.check_circle_outline_rounded,
              title: "Tidak ada overdue",
              subtitle: "Belum ada tagihan terlambat pada periode ini.",
            )
          else
            Column(
              children: visibleReports.map((item) {
                return buildOverdueItem(item);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget buildOverdueItem(Map<String, dynamic> item) {
    final amount = getReportAmount(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getPropertyName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getResidentName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Jatuh tempo: ${formatDate(item["due_date"] ?? item["dueDate"] ?? item["period_end"] ?? item["periodEnd"])}",
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(amount),
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBadge(dynamic status) {
    final color = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        getStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildMiniLoading() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          height: 66,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18),
          ),
        );
      }),
    );
  }

  Widget buildEmptyMiniState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: greyText, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorCard() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    return RefreshIndicator(
      onRefresh: fetchReport,
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: 18),
            buildMonthSelector(),
            const SizedBox(height: 18),
            buildTotalIncomeCard(),
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              buildErrorCard(),
            ],
            const SizedBox(height: 18),
            buildStatGrid(),
            const SizedBox(height: 20),
            buildIncomeList(),
            const SizedBox(height: 20),
            buildOverdueList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: buildContent(),
      ),
    );
  }
}