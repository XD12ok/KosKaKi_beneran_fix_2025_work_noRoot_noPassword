import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/api_service.dart';

class OwnerFamily extends StatefulWidget {
  const OwnerFamily({super.key});

  @override
  State<OwnerFamily> createState() => _OwnerFamilyState();
}

class _OwnerFamilyState extends State<OwnerFamily> {

  bool isLoading = true;
  List<OwnerPropertyModel> properties = [];

  @override
  void initState() {
    super.initState();
    getMyProperties();
  }

  Future<String?> getToken() async {
    final api = ApiService();
    final token = await api.getToken();
  
    if (token == null) return null;
  
    String cleaned = token.trim();
  
    if (cleaned.toLowerCase().startsWith('bearer ')) {
      cleaned = cleaned.substring(7).trim();
    }
  
    cleaned = cleaned.replaceAll('"', '').replaceAll("'", "").trim();
  
    return cleaned;
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> getMyProperties() async {
    setState(() {
      isLoading = true;
    });

    try {
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/my-properties'),
        headers: headers,
      );

      debugPrint('GET MY PROPERTIES STATUS: ${response.statusCode}');
      debugPrint('GET MY PROPERTIES BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final List data = extractList(body);

        final result = data
            .map((item) => OwnerPropertyModel.fromJson(asMap(item)))
            .where((item) => item.id > 0)
            .toList();

        setState(() {
          properties = result;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });

        showSnackBar(
          body['message']?.toString() ?? 'Gagal memuat data kos owner',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('GET MY PROPERTIES ERROR: $e');

      setState(() {
        isLoading = false;
      });

      showSnackBar(
        'Terjadi kesalahan saat memuat data kos owner',
        isError: true,
      );
    }
  }

  void openDetail(OwnerPropertyModel property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerFamilyDetail(
          property: property,
        ),
      ),
    );
  }

  void showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5AA8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Family Kost Owner',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: getMyProperties,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: getMyProperties,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            headerCard(),
            const SizedBox(height: 16),
            const Text(
              'Daftar Kos Kamu',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (properties.isEmpty)
              emptyView()
            else
              ...properties.map((property) {
                return propertyCard(property);
              }),
          ],
        ),
      ),
    );
  }

  Widget headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E5AA8),
            Color(0xFF4A90FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5AA8).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kelola Family Kost',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Pilih kos untuk melihat member, buat kode, dan kick member.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget propertyCard(OwnerPropertyModel property) {
    return InkWell(
      onTap: () => openDetail(property),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: property.imageUrl == null || property.imageUrl!.isEmpty
                  ? const Icon(
                      Icons.home_work_rounded,
                      color: Color(0xFF1E5AA8),
                      size: 34,
                    )
                  : Image.network(
                      property.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.home_work_rounded,
                          color: Color(0xFF1E5AA8),
                          size: 34,
                        );
                      },
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Property ID: ${property.id}',
                          style: const TextStyle(
                            color: Color(0xFF1E5AA8),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyView() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada kos',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Kos yang kamu miliki akan tampil di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerFamilyDetail extends StatefulWidget {
  final OwnerPropertyModel property;

  const OwnerFamilyDetail({
    super.key,
    required this.property,
  });

  @override
  State<OwnerFamilyDetail> createState() => _OwnerFamilyDetailState();
}

class _OwnerFamilyDetailState extends State<OwnerFamilyDetail> {

  bool isLoading = true;
  bool isActionLoading = false;

  bool isOwner = false;
  int totalMembers = 0;

  int? activeRentalBookingId;
  String? inviteCode;
  String? inviteExpiredAt;

  List<FamilyMemberModel> members = [];

  @override
  void initState() {
    super.initState();
    loadDetailData();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('token') ??
        prefs.getString('access_token') ??
        prefs.getString('auth_token') ??
        prefs.getString('sanctum_token');
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadDetailData() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      getFamilyMembers(showLoading: false),
      findActiveRentalBooking(showLoading: false),
    ]);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getFamilyMembers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/family/properties/${widget.property.id}/members',
        ),
        headers: headers,
      );

      debugPrint('GET OWNER FAMILY MEMBERS STATUS: ${response.statusCode}');
      debugPrint('GET OWNER FAMILY MEMBERS BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final List data = body['data'] is List ? body['data'] : [];

        setState(() {
          isOwner = body['is_owner'] == true;
          totalMembers = parseInt(body['total_members'] ?? data.length);
          members = data
              .map((item) => FamilyMemberModel.fromJson(asMap(item)))
              .toList();
          if (showLoading) {
            isLoading = false;
          }
        });
      } else {
        if (showLoading) {
          setState(() {
            isLoading = false;
          });
        }

        showSnackBar(
          body['message']?.toString() ?? 'Gagal memuat member family',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('GET OWNER FAMILY MEMBERS ERROR: $e');

      if (showLoading) {
        setState(() {
          isLoading = false;
        });
      }

      showSnackBar(
        'Terjadi kesalahan saat memuat member family',
        isError: true,
      );
    }
  }

  Future<void> findActiveRentalBooking({bool showLoading = true}) async {
    if (widget.property.rentalBookingId != null &&
        widget.property.rentalBookingId! > 0) {
      setState(() {
        activeRentalBookingId = widget.property.rentalBookingId;
      });
      return;
    }

    try {
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/rental-bookings'),
        headers: headers,
      );

      debugPrint('GET RENTAL BOOKINGS STATUS: ${response.statusCode}');
      debugPrint('GET RENTAL BOOKINGS BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final List data = extractList(body);

        final rentals = data.map((item) => asMap(item)).toList();

        Map<String, dynamic>? selected;

        final sameProperty = rentals.where((rental) {
          final rentalPropertyId = extractPropertyIdFromRental(rental);
          return rentalPropertyId == widget.property.id;
        }).toList();

        final activeRentals = sameProperty.where((rental) {
          final status = rental['status']?.toString().toLowerCase() ?? '';
          return status == 'active' ||
              status == 'approved' ||
              status == 'grace' ||
              status == 'overdue';
        }).toList();

        if (activeRentals.isNotEmpty) {
          selected = activeRentals.first;
        } else if (sameProperty.isNotEmpty) {
          selected = sameProperty.first;
        }

        setState(() {
          activeRentalBookingId = selected == null ? null : parseInt(selected['id']);
        });
      }
    } catch (e) {
      debugPrint('FIND ACTIVE RENTAL BOOKING ERROR: $e');
    }
  }

  Future<void> generateFamilyCode() async {
    if (activeRentalBookingId == null || activeRentalBookingId! <= 0) {
      showSnackBar(
        'Rental booking aktif untuk kos ini belum ditemukan.',
        isError: true,
      );
      return;
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      final headers = await getHeaders();

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/family/generate/$activeRentalBookingId'),
        headers: headers,
      );

      debugPrint('GENERATE FAMILY CODE STATUS: ${response.statusCode}');
      debugPrint('GENERATE FAMILY CODE BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      setState(() {
        isActionLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = asMap(body['data']);

        setState(() {
          inviteCode = data['code']?.toString();
          inviteExpiredAt = data['expired_at']?.toString();
        });

        showSnackBar(
          body['message']?.toString() ?? 'Kode family berhasil dibuat',
        );
      } else {
        showSnackBar(
          body['message']?.toString() ?? 'Gagal membuat kode family',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('GENERATE FAMILY CODE ERROR: $e');

      setState(() {
        isActionLoading = false;
      });

      showSnackBar(
        'Terjadi kesalahan saat membuat kode family',
        isError: true,
      );
    }
  }

  Future<void> kickMember(FamilyMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Kick Member?'),
          content: Text(
            'Kamu yakin ingin mengeluarkan ${member.name} dari family kos ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kick'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isActionLoading = true;
    });

    try {
      final headers = await getHeaders();

      final response = await http.delete(
        Uri.parse(
          '${ApiService.baseUrl}/properties/${widget.property.id}/members/${member.userId}',
        ),
        headers: headers,
      );

      debugPrint('KICK MEMBER STATUS: ${response.statusCode}');
      debugPrint('KICK MEMBER BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      setState(() {
        isActionLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar(
          body['message']?.toString() ?? 'Member berhasil di-kick',
        );

        getFamilyMembers(showLoading: false);
      } else {
        showSnackBar(
          body['message']?.toString() ?? 'Gagal kick member',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('KICK MEMBER ERROR: $e');

      setState(() {
        isActionLoading = false;
      });

      showSnackBar(
        'Terjadi kesalahan saat kick member',
        isError: true,
      );
    }
  }

  Future<void> openMemberDetail(FamilyMemberModel member) async {
    setState(() {
      isActionLoading = true;
    });

    try {
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/family/properties/${widget.property.id}/members/${member.userId}',
        ),
        headers: headers,
      );

      debugPrint('GET MEMBER DETAIL STATUS: ${response.statusCode}');
      debugPrint('GET MEMBER DETAIL BODY: ${response.body}');

      final body = safeJsonDecode(response.body);

      setState(() {
        isActionLoading = false;
      });

      if (response.statusCode == 200) {
        showMemberDetailBottomSheet(asMap(body['data']));
      } else {
        showSnackBar(
          body['message']?.toString() ?? 'Gagal memuat detail member',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('GET MEMBER DETAIL ERROR: $e');

      setState(() {
        isActionLoading = false;
      });

      showSnackBar(
        'Terjadi kesalahan saat memuat detail member',
        isError: true,
      );
    }
  }

  void showMemberDetailBottomSheet(Map<String, dynamic> data) {
    final user = asMap(data['user']);
    final rental = asMap(data['rental']);
    final paymentHistory = data['payment_history'] is List
        ? data['payment_history'] as List
        : [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.36,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFF6F8FC),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFFEAF2FF),
                          child: Text(
                            getInitial(user['name']?.toString()),
                            style: const TextStyle(
                              color: Color(0xFF1E5AA8),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name']?.toString() ?? 'Tanpa Nama',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email']?.toString() ?? '-',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  detailCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Tanggal Bergabung',
                    value: formatDate(data['joined_at']?.toString()),
                  ),
                  if (rental.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Informasi Sewa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    detailCard(
                      icon: Icons.login_rounded,
                      title: 'Mulai Sewa',
                      value: formatDate(rental['start_date']?.toString()),
                    ),
                    const SizedBox(height: 10),
                    detailCard(
                      icon: Icons.logout_rounded,
                      title: 'Selesai Sewa',
                      value: formatDate(rental['end_date']?.toString()),
                    ),
                    const SizedBox(height: 10),
                    detailCard(
                      icon: Icons.timelapse_rounded,
                      title: 'Sisa Hari',
                      value: '${rental['days_left'] ?? 0} hari',
                    ),
                    const SizedBox(height: 10),
                    detailCard(
                      icon: Icons.verified_rounded,
                      title: 'Status',
                      value: rental['status']?.toString() ?? '-',
                    ),
                    const SizedBox(height: 10),
                    detailCard(
                      icon: Icons.payments_rounded,
                      title: 'Total Harga',
                      value: formatRupiah(rental['total_price']),
                    ),
                  ],
                  if (paymentHistory.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Riwayat Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...paymentHistory.map((payment) {
                      return paymentHistoryCard(asMap(payment));
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget detailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1E5AA8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget paymentHistoryCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF1E5AA8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRupiah(payment['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment['method'] ?? '-'} • ${payment['status'] ?? '-'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (payment['verified_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Diverifikasi: ${formatDate(payment['verified_at']?.toString())}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
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

  void showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  Color getStatusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'waiting':
        return Colors.orange;
      case 'pending':
        return Colors.orange;
      case 'grace':
        return Colors.deepOrange;
      case 'overdue':
        return Colors.red;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5AA8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.property.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isActionLoading ? null : loadDetailData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: loadDetailData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                propertyHeaderCard(),
                const SizedBox(height: 14),
                generateCodeCard(),
                const SizedBox(height: 14),
                membersCard(),
              ],
            ),
          ),
          if (isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.12),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget propertyHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E5AA8),
            Color(0xFF4A90FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5AA8).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.property.imageUrl == null ||
                    widget.property.imageUrl!.isEmpty
                ? const Icon(
                    Icons.home_work_rounded,
                    color: Colors.white,
                    size: 34,
                  )
                : Image.network(
                    widget.property.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.home_work_rounded,
                        color: Colors.white,
                        size: 34,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.property.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.property.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$totalMembers',
                  style: const TextStyle(
                    color: Color(0xFF1E5AA8),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Member',
                  style: TextStyle(
                    color: Color(0xFF1E5AA8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget generateCodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kode Family',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            activeRentalBookingId == null
                ? 'Rental booking aktif untuk kos ini belum ditemukan.'
                : 'Rental Booking ID: $activeRentalBookingId',
            style: TextStyle(
              color: activeRentalBookingId == null
                  ? Colors.red.shade600
                  : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (inviteCode != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFBFD9FF),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kode Undangan',
                          style: TextStyle(
                            color: Color(0xFF1E5AA8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inviteCode!,
                          style: const TextStyle(
                            color: Color(0xFF1E5AA8),
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (inviteExpiredAt != null)
                          Text(
                            'Expired: ${formatDate(inviteExpiredAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: inviteCode!),
                      );

                      showSnackBar('Kode berhasil disalin');
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF1E5AA8),
                    ),
                  ),
                ],
              ),
            ),
          if (inviteCode != null) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isActionLoading ? null : generateFamilyCode,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text(
                'Generate Kode Family',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5AA8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget membersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Member Family',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$totalMembers orang',
                style: const TextStyle(
                  color: Color(0xFF1E5AA8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (members.isEmpty)
            emptyMembersView()
          else
            ...members.map((member) {
              return memberItem(member);
            }),
        ],
      ),
    );
  }

  Widget emptyMembersView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 44,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            'Belum ada member family',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget memberItem(FamilyMemberModel member) {
    final statusColor = getStatusColor(member.status);

    return InkWell(
      onTap: isActionLoading ? null : () => openMemberDetail(member),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFEAF2FF),
              child: Text(
                getInitial(member.name),
                style: const TextStyle(
                  color: Color(0xFF1E5AA8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Bergabung: ${formatDate(member.joinedAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  if (member.status != null || member.daysLeft != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (member.status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              member.status!,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (member.daysLeft != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${member.daysLeft} hari lagi',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Kick member',
              onPressed: isActionLoading ? null : () => kickMember(member),
              icon: Icon(
                Icons.person_remove_rounded,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class OwnerPropertyModel {
  final int id;
  final int? rentalBookingId;
  final String name;
  final String address;
  final String? imageUrl;

  OwnerPropertyModel({
    required this.id,
    required this.rentalBookingId,
    required this.name,
    required this.address,
    required this.imageUrl,
  });

  factory OwnerPropertyModel.fromJson(Map<String, dynamic> json) {
    final place = asMap(json['place']);
    final property = asMap(json['property']);
    final placeProperty = asMap(json['place_property']);

    final List images = json['images'] is List
        ? json['images']
        : json['property_images'] is List
            ? json['property_images']
            : [];

    String? image;

    if (json['image_url'] != null) {
      image = json['image_url'].toString();
    } else if (json['image'] != null) {
      image = json['image'].toString();
    } else if (json['main_image'] != null) {
      image = json['main_image'].toString();
    } else if (images.isNotEmpty) {
      final firstImage = asMap(images.first);
      image = firstImage['url']?.toString() ??
          firstImage['image_url']?.toString() ??
          firstImage['path']?.toString() ??
          firstImage['image_path']?.toString();
    }
    
    final id = parseInt(
      json['place_property_id'] ??
          json['placePropertyId'] ??
          json['place_property']?['id'] ??
          placeProperty['id'] ??
          json['id'] ??
          property['id'] ??
          place['id'],
    );

    final rentalBookingId = parseIntNullable(
      json['rental_booking_id'] ??
          json['rental_id'] ??
          json['active_rental_booking_id'] ??
          json['booking_id'],
    );

    final name = json['name']?.toString() ??
        json['nama']?.toString() ??
        json['title']?.toString() ??
        json['property_name']?.toString() ??
        place['name']?.toString() ??
        place['nama']?.toString() ??
        property['name']?.toString() ??
        'Kos Tanpa Nama';

    final address = json['address']?.toString() ??
        json['alamat']?.toString() ??
        json['location']?.toString() ??
        place['address']?.toString() ??
        place['alamat']?.toString() ??
        property['address']?.toString() ??
        'Alamat tidak tersedia';

    return OwnerPropertyModel(
      id: id,
      rentalBookingId: rentalBookingId,
      name: name,
      address: address,
      imageUrl: image,
    );
  }
}

class FamilyMemberModel {
  final int id;
  final int userId;
  final String name;
  final String email;
  final String? joinedAt;
  final String? status;
  final int? daysLeft;
  final dynamic totalPrice;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.joinedAt,
    required this.status,
    required this.daysLeft,
    required this.totalPrice,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    final rental = asMap(json['rental']);

    return FamilyMemberModel(
      id: parseInt(json['id']),
      userId: parseInt(user['id']),
      name: user['name']?.toString() ?? 'Tanpa Nama',
      email: user['email']?.toString() ?? '-',
      joinedAt: json['joined_at']?.toString(),
      status: rental['status']?.toString(),
      daysLeft: parseIntNullable(rental['days_left']),
      totalPrice: rental['total_price'],
    );
  }
}

Map<String, dynamic> safeJsonDecode(String source) {
  try {
    final decoded = jsonDecode(source);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return {
      'data': decoded,
    };
  } catch (_) {
    return {
      'message': source,
    };
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

List extractList(Map<String, dynamic> body) {
  if (body['data'] is List) {
    return body['data'];
  }

  if (body['properties'] is List) {
    return body['properties'];
  }

  if (body['data'] is Map) {
    final dataMap = asMap(body['data']);

    if (dataMap['data'] is List) {
      return dataMap['data'];
    }

    if (dataMap['properties'] is List) {
      return dataMap['properties'];
    }

    if (dataMap['items'] is List) {
      return dataMap['items'];
    }
  }

  if (body['items'] is List) {
    return body['items'];
  }

  return [];
}

int parseInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) return value;

  if (value is double) return value.toInt();

  return int.tryParse(value.toString()) ?? 0;
}

int? parseIntNullable(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  if (value is double) return value.toInt();

  return int.tryParse(value.toString());
}

int extractPropertyIdFromRental(Map<String, dynamic> rental) {
  final property = asMap(rental['property']);
  final placeProperty = asMap(rental['place_property']);
  final place = asMap(rental['place']);

  return parseInt(
    rental['place_property_id'] ??
        rental['property_id'] ??
        rental['kost_id'] ??
        placeProperty['id'] ??
        property['id'] ??
        place['id'],
  );
}

String getInitial(String? name) {
  if (name == null || name.trim().isEmpty) {
    return '?';
  }

  return name.trim()[0].toUpperCase();
}

String formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return '-';
  }

  final date = DateTime.tryParse(value);

  if (date == null) {
    return value;
  }

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

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatRupiah(dynamic value) {
  if (value == null) {
    return 'Rp0';
  }

  final number = double.tryParse(value.toString()) ?? 0;
  final raw = number.toStringAsFixed(0);

  final result = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return 'Rp$result';
}