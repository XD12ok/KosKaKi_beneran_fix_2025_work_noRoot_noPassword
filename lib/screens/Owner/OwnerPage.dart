import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';
import 'package:koskaki/screens/Owner/KostPage.dart';
import 'package:koskaki/screens/Owner/Laporan.dart';
import 'package:koskaki/screens/Owner/PengaturanOwner.dart';
import 'package:koskaki/screens/Owner/ListChat.dart';
import 'package:koskaki/screens/Owner/LaporanSewa.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  Map<String, dynamic>? userData;

  bool loading = true;
  bool pendingCountLoading = true;

  int currentIndex = 0;

  List<dynamic> properties = [];

  int totalKos = 0;
  int pendingPaymentCount = 0;

  Map<String, dynamic>? latestProperty;

  final Color _barColor = const Color(0xFFEAF5EB);
  final Color _activeColor = const Color(0xFF0A0E50);
  final Color _backgroundColor = const Color(0xFFF6F8FA);

  @override
  void initState() {
    super.initState();
    loadOwnerHomeData();
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

  Map<String, String> ownerAuthHeaders(String token) {
    final cleanedToken = cleanToken(token);

    return {
      "Authorization": "Bearer $cleanedToken",
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest",
    };
  }

  Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<dynamic> parseDynamicList(dynamic value) {
    if (value == null) return [];

    if (value is List) return value;

    if (value is Map) {
      if (value["data"] is List) return value["data"];

      if (value["data"] is Map && value["data"]["data"] is List) {
        return value["data"]["data"];
      }

      if (value["rental_bookings"] is List) return value["rental_bookings"];
      if (value["rentalBookings"] is List) return value["rentalBookings"];
      if (value["bookings"] is List) return value["bookings"];
      if (value["items"] is List) return value["items"];
      if (value["results"] is List) return value["results"];
    }

    return [];
  }

  String cleanLower(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? "";
  }

  int parseIntValue(dynamic value) {
    if (value == null) return 0;

    final cleaned = value.toString().replaceAll(RegExp(r"[^0-9]"), "");

    if (cleaned.isEmpty) return 0;

    return int.tryParse(cleaned) ?? 0;
  }

  Map<String, dynamic> getInvoiceFromBookingForBadge(
    Map<String, dynamic> booking,
  ) {
    final invoice =
        toMap(booking["invoice"]) ??
        toMap(booking["current_invoice"]) ??
        toMap(booking["currentInvoice"]) ??
        toMap(booking["initial_invoice"]) ??
        toMap(booking["initialInvoice"]);

    if (invoice != null) return invoice;

    final invoices = booking["invoices"];

    if (invoices is List && invoices.isNotEmpty) {
      final firstInvoice = toMap(invoices.first);

      if (firstInvoice != null) return firstInvoice;
    }

    return {};
  }

  Map<String, dynamic>? getPendingPaymentFromBookingForBadge(
    Map<String, dynamic> booking,
  ) {
    final List<dynamic> paymentCandidates = [];

    void addIfExists(dynamic value) {
      if (value == null) return;

      if (value is List) {
        paymentCandidates.addAll(value);
      } else {
        paymentCandidates.add(value);
      }
    }

    addIfExists(booking["rental_payments"]);
    addIfExists(booking["rentalPayments"]);
    addIfExists(booking["payments"]);
    addIfExists(booking["payment"]);
    addIfExists(booking["rental_payment"]);
    addIfExists(booking["rentalPayment"]);
    addIfExists(booking["latest_payment"]);
    addIfExists(booking["latestPayment"]);

    final invoice = getInvoiceFromBookingForBadge(booking);

    if (invoice.isNotEmpty) {
      addIfExists(invoice["payments"]);
      addIfExists(invoice["rental_payments"]);
      addIfExists(invoice["rentalPayments"]);
      addIfExists(invoice["payment"]);
      addIfExists(invoice["latest_payment"]);
      addIfExists(invoice["latestPayment"]);
    }

    for (final item in paymentCandidates) {
      final payment = toMap(item);

      if (payment == null) continue;

      final paymentStatus = cleanLower(
        payment["status"] ?? payment["payment_status"],
      );

      debugPrint("BADGE CHECK RENTAL PAYMENT:");
      debugPrint(
        {
          "payment_id": payment["id"],
          "payment_status": paymentStatus,
          "payment_type": payment["type"],
          "sender_name": payment["sender_name"],
          "notes": payment["notes"],
        }.toString(),
      );

      final isPending =
          paymentStatus == "pending" ||
          paymentStatus == "waiting_confirmation" ||
          paymentStatus == "waiting" ||
          paymentStatus == "unverified" ||
          paymentStatus == "waiting_verification" ||
          paymentStatus == "menunggu";

      if (isPending) {
        return payment;
      }
    }

    final bookingStatus = cleanLower(
      booking["status"] ??
          booking["rental_status"] ??
          booking["booking_status"] ??
          booking["payment_status"],
    );

    final fallbackPaymentId = parseIntValue(
      booking["rental_payment_id"] ??
          booking["rentalPaymentId"] ??
          booking["payment_id"] ??
          booking["paymentId"] ??
          booking["latest_payment_id"] ??
          booking["latestPaymentId"],
    );

    final hasFallbackPayment = fallbackPaymentId > 0;

    final isBookingWaiting =
        bookingStatus == "pending" ||
        bookingStatus == "pending_payment" ||
        bookingStatus == "waiting_payment" ||
        bookingStatus == "waiting_confirmation" ||
        bookingStatus == "unverified" ||
        bookingStatus == "waiting_verification" ||
        bookingStatus == "menunggu";

    if (isBookingWaiting && hasFallbackPayment) {
      debugPrint("BADGE CHECK FALLBACK BOOKING PAYMENT:");
      debugPrint(
        {
          "booking_id": booking["id"],
          "fallback_payment_id": fallbackPaymentId,
          "booking_status": bookingStatus,
        }.toString(),
      );

      return {"id": fallbackPaymentId, "status": "pending"};
    }

    return null;
  }

  Future<void> loadOwnerHomeData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      pendingCountLoading = true;
    });

    await Future.wait([loadUserAndProperties(), loadPendingPaymentCount()]);

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> refreshOwnerHomeData() async {
    await Future.wait([loadUserAndProperties(), loadPendingPaymentCount()]);
  }

  Future<void> loadUserAndProperties() async {
    try {
      final api = ApiService();

      final response = await api.getUser();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      debugPrint("OWNER HOME TOKEN:");
      debugPrint(
        token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
      );

      final propertyResponse = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/my-properties"),
            headers: ownerAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("GET MY PROPERTIES STATUS:");
      debugPrint(propertyResponse.statusCode.toString());

      debugPrint("GET MY PROPERTIES BODY:");
      debugPrint(propertyResponse.body);

      List<dynamic> propertyList = [];

      if (propertyResponse.statusCode == 200) {
        final decoded = jsonDecode(propertyResponse.body);

        if (decoded is Map &&
            decoded['data'] is Map &&
            decoded['data']['data'] is List) {
          propertyList = decoded['data']['data'];
        } else if (decoded is Map && decoded['data'] is List) {
          propertyList = decoded['data'];
        } else if (decoded is List) {
          propertyList = decoded;
        }
      }

      final List<Map<String, dynamic>> sortedProperties = propertyList
          .map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item);
          })
          .toList();

      sortedProperties.sort((a, b) {
        final aCreated = a['created_at']?.toString();
        final bCreated = b['created_at']?.toString();

        if (aCreated != null && bCreated != null) {
          final aDate = DateTime.tryParse(aCreated);
          final bDate = DateTime.tryParse(bCreated);

          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate);
          }
        }

        final aId = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final bId = int.tryParse(b['id']?.toString() ?? '0') ?? 0;

        return bId.compareTo(aId);
      });

      if (!mounted) return;

      setState(() {
        userData = {
          "id": response?['id'],
          "role": response?['role'],
          "username": response?['name'] ?? "Owner",
        };

        properties = sortedProperties;

        totalKos = sortedProperties.length;

        latestProperty = sortedProperties.isNotEmpty
            ? sortedProperties.first
            : null;
      });
    } catch (e) {
      debugPrint("ERROR LOAD USER API:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        userData = {"username": "Owner"};

        properties = [];

        totalKos = 0;

        latestProperty = null;
      });
    }
  }

  Future<void> loadPendingPaymentCount() async {
    if (!mounted) return;

    setState(() {
      pendingCountLoading = true;
    });

    try {
      final api = ApiService();

      final rawToken = await api.getToken();
      final token = cleanToken(rawToken);

      debugPrint("BADGE TOKEN STATUS:");
      debugPrint(
        token.isEmpty ? "TOKEN KOSONG" : "TOKEN ADA LENGTH: ${token.length}",
      );

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          pendingPaymentCount = 0;
          pendingCountLoading = false;
        });

        return;
      }

      final response = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/rental-bookings"),
            headers: ownerAuthHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("GET BADGE RENTAL BOOKINGS STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET BADGE RENTAL BOOKINGS BODY:");
      debugPrint(response.body);

      int totalPending = 0;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final bookings = parseDynamicList(decoded);

        debugPrint("BADGE TOTAL RENTAL BOOKINGS:");
        debugPrint(bookings.length.toString());

        for (final item in bookings) {
          final booking = toMap(item);

          if (booking == null) continue;

          final payment = getPendingPaymentFromBookingForBadge(booking);

          if (payment != null) {
            totalPending++;
          }
        }
      }

      debugPrint("FINAL BADGE PENDING COUNT:");
      debugPrint(totalPending.toString());

      if (!mounted) return;

      setState(() {
        pendingPaymentCount = totalPending;
        pendingCountLoading = false;
      });
    } catch (e) {
      debugPrint("GET PENDING PAYMENT COUNT ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        pendingPaymentCount = 0;
        pendingCountLoading = false;
      });
    }
  }

  Future<void> openLaporanSewaPage() async {
    debugPrint("CARD PENGAJUAN SEWA DIKLIK");

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LaporanSewa()),
    );

    await loadPendingPaymentCount();
  }

  void goToKostPage() {
    setState(() {
      currentIndex = 1;
    });
  }

  void goToLaporanPage() {
    setState(() {
      currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loading ? "Hai, ..." : "Hai, ${userData?['username'] ?? 'Owner'}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A0E50),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Kelola kos kamu hari ini",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.message_outlined,
                color: Color(0xFF0A0E50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatListOwnerPage()),
                );
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          BerandaPage(
            userData: userData,
            loading: loading,
            properties: properties,
            totalKos: totalKos,
            latestProperty: latestProperty,
            pendingPaymentCount: pendingPaymentCount,
            pendingCountLoading: pendingCountLoading,
            onOpenPengajuanSewa: openLaporanSewaPage,
            onOpenKelolaKos: goToKostPage,
            onOpenTagihan: goToLaporanPage,
            onRefresh: refreshOwnerHomeData,
          ),
          const KostPage(),
          const LaporanPage(),
          PengaturanOwnerPage(userData: userData, loading: loading),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 65,
        color: _barColor,
        buttonBackgroundColor: _activeColor,
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) async {
          setState(() {
            currentIndex = index;
          });

          if (index == 0) {
            await refreshOwnerHomeData();
          }
        },
        items: [
          Icon(
            Icons.home_outlined,
            size: 30,
            color: currentIndex == 0 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.business_outlined,
            size: 30,
            color: currentIndex == 1 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.assessment_outlined,
            size: 30,
            color: currentIndex == 2 ? Colors.white : _activeColor,
          ),
          Icon(
            Icons.settings_outlined,
            size: 30,
            color: currentIndex == 3 ? Colors.white : _activeColor,
          ),
        ],
      ),
    );
  }
}

class BerandaPage extends StatelessWidget {
  final Map<String, dynamic>? userData;

  final bool loading;

  final List<dynamic> properties;

  final int totalKos;

  final Map<String, dynamic>? latestProperty;

  final int pendingPaymentCount;

  final bool pendingCountLoading;

  final VoidCallback onOpenPengajuanSewa;

  final VoidCallback onOpenKelolaKos;

  final VoidCallback onOpenTagihan;

  final Future<void> Function() onRefresh;

  const BerandaPage({
    super.key,
    required this.userData,
    required this.loading,
    required this.properties,
    required this.totalKos,
    required this.latestProperty,
    required this.pendingPaymentCount,
    required this.pendingCountLoading,
    required this.onOpenPengajuanSewa,
    required this.onOpenKelolaKos,
    required this.onOpenTagihan,
    required this.onRefresh,
  });

  final Color primaryColor = const Color(0xFF0A0E50);
  final Color softGreen = const Color(0xFFEAF5EB);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 22),
            _buildStatCard(
              icon: Icons.home_work_outlined,
              title: "$totalKos",
              subtitle: "Total Kos",
              color: primaryColor,
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.description_outlined,
                    iconColor: Colors.blue,
                    title: 'Pengajuan Sewa',
                    subtitle: 'Balas pengajuan penyewa',
                    showBadge: true,
                    badgeCount: pendingPaymentCount,
                    badgeLoading: pendingCountLoading,
                    onTap: onOpenPengajuanSewa,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: Colors.orange,
                    title: 'Tagihan',
                    subtitle: 'Ingatkan pembayaran',
                    showBadge: false,
                    badgeCount: 0,
                    badgeLoading: false,
                    onTap: onOpenTagihan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWideActionCard(
              icon: Icons.home_repair_service_outlined,
              iconColor: Colors.green,
              title: 'Kelola Data Kos',
              subtitle: 'Lihat dan atur data kos yang kamu miliki',
              onTap: onOpenKelolaKos,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Kos Saya",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: softGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    latestProperty == null ? "0 Kos" : "Terbaru",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (latestProperty == null)
              _buildEmptyKosCard()
            else
              _buildPropertyCard(
                context: context,
                property: latestProperty!,
                onTap: onOpenKelolaKos,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E50), Color(0xFF18227A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "Dashboard Owner",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Pantau Kos Lebih Mudah",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Kelola data kos, tagihan, dan pengajuan dalam satu tempat.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "Aktif",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBadge({required int count, required bool loading}) {
    final bool hasPending = count > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasPending ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: loading
          ? const SizedBox(
              height: 10,
              width: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              count > 99 ? "99+" : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showBadge,
    required int badgeCount,
    required bool badgeLoading,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 145,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: showBadge && badgeCount > 0
                ? const Color(0xFFFFD1D1)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showBadge) ...[
                  const SizedBox(width: 6),
                  _buildPendingBadge(count: badgeCount, loading: badgeLoading),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyKosCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenKelolaKos,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 82,
              width: 82,
              decoration: BoxDecoration(
                color: softGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 42,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Belum Ada Kos",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Kos yang kamu tambahkan akan muncul di bagian ini.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard({
    required BuildContext context,
    required Map<String, dynamic> property,
    required VoidCallback onTap,
  }) {
    final propertyName =
        property['title'] ??
        property['name'] ??
        property['nama'] ??
        property['property_name'] ??
        'Kos Saya';

    final address =
        property['address'] ??
        property['alamat'] ??
        property['city']?['name'] ??
        'Alamat belum tersedia';

    final status = property['status']?.toString() ?? 'active';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF18227A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    propertyName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          address.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status == "active"
                          ? Colors.green.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      status == "active" ? "Aktif" : status,
                      style: TextStyle(
                        color: status == "active"
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
