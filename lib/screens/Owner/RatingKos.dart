import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

class RatingKos extends StatefulWidget {
  final Map<String, dynamic> kost;

  const RatingKos({super.key, required this.kost});

  @override
  State<RatingKos> createState() => _RatingKosState();
}

class _RatingKosState extends State<RatingKos> {
  final Color primaryColor = const Color(0xFF0A0E50);
  final Color secondColor = const Color(0xFF2D2F8F);
  final Color backgroundColor = const Color(0xFFF6F8FA);
  final Color softYellow = const Color(0xFFFFF7E6);

  bool isLoading = true;
  String? errorMessage;

  double averageRating = 0;
  int totalReviews = 0;

  List<Map<String, dynamic>> reviews = [];

  @override
  void initState() {
    super.initState();
    loadReviews();
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

  Map<String, String> headers(String token) {
    return {
      "Accept": "application/json",
      if (token.isNotEmpty) "Authorization": "Bearer $token",
      "X-Requested-With": "XMLHttpRequest",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    };
  }

  int toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    final text = value.toString().replaceAll(RegExp(r"[^0-9]"), "");

    if (text.isEmpty) return 0;

    return int.tryParse(text) ?? 0;
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<Map<String, dynamic>> parseReviewList(dynamic decoded) {
    dynamic rawData;

    if (decoded is Map) {
      rawData = decoded["data"];

      if (rawData is Map && rawData["data"] != null) {
        rawData = rawData["data"];
      }

      if (rawData == null && decoded["reviews"] != null) {
        rawData = decoded["reviews"];
      }
    } else {
      rawData = decoded;
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

  int getPropertyId() {
    final property = asMap(widget.kost["property"]);
    final placeProperty = asMap(widget.kost["place_property"]);
    final placePropertyCamel = asMap(widget.kost["placeProperty"]);
    final placeProperties = asMap(widget.kost["place_properties"]);
    final placePropertiesCamel = asMap(widget.kost["placeProperties"]);

    return toInt(
      widget.kost["id"] ??
          widget.kost["property_id"] ??
          widget.kost["place_property_id"] ??
          widget.kost["place_properties_id"] ??
          widget.kost["placePropertyId"] ??
          widget.kost["propertyId"] ??
          property?["id"] ??
          placeProperty?["id"] ??
          placePropertyCamel?["id"] ??
          placeProperties?["id"] ??
          placePropertiesCamel?["id"],
    );
  }

  String getPropertyName() {
    final property = asMap(widget.kost["property"]);
    final placeProperty = asMap(widget.kost["place_property"]);
    final placePropertyCamel = asMap(widget.kost["placeProperty"]);
    final placeProperties = asMap(widget.kost["place_properties"]);
    final placePropertiesCamel = asMap(widget.kost["placeProperties"]);

    final candidates = [
      widget.kost["title"],
      widget.kost["name"],
      widget.kost["property_name"],
      widget.kost["place_property_name"],
      widget.kost["nama_kos"],
      widget.kost["nama_kost"],
      widget.kost["kos_name"],
      widget.kost["kost_name"],
      property?["title"],
      property?["name"],
      property?["property_name"],
      placeProperty?["title"],
      placeProperty?["name"],
      placeProperty?["property_name"],
      placePropertyCamel?["title"],
      placePropertyCamel?["name"],
      placePropertyCamel?["property_name"],
      placeProperties?["title"],
      placeProperties?["name"],
      placeProperties?["property_name"],
      placePropertiesCamel?["title"],
      placePropertiesCamel?["name"],
      placePropertiesCamel?["property_name"],
    ];

    for (final item in candidates) {
      final text = item?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddress() {
    final property = asMap(widget.kost["property"]);
    final placeProperty = asMap(widget.kost["place_property"]);
    final placePropertyCamel = asMap(widget.kost["placeProperty"]);
    final placeProperties = asMap(widget.kost["place_properties"]);
    final placePropertiesCamel = asMap(widget.kost["placeProperties"]);

    final candidates = [
      widget.kost["address"],
      widget.kost["alamat"],
      widget.kost["location"],
      widget.kost["lokasi"],
      widget.kost["full_address"],
      widget.kost["alamat_lengkap"],
      property?["address"],
      property?["alamat"],
      property?["location"],
      placeProperty?["address"],
      placeProperty?["alamat"],
      placeProperty?["location"],
      placePropertyCamel?["address"],
      placePropertyCamel?["alamat"],
      placePropertyCamel?["location"],
      placeProperties?["address"],
      placeProperties?["alamat"],
      placeProperties?["location"],
      placePropertiesCamel?["address"],
      placePropertiesCamel?["alamat"],
      placePropertiesCamel?["location"],
    ];

    for (final item in candidates) {
      final text = item?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }

    return "Alamat belum tersedia";
  }

  String getUserName(Map<String, dynamic> review) {
    final user = asMap(review["user"]);

    final candidates = [
      user?["name"],
      user?["username"],
      user?["full_name"],
      review["user_name"],
      review["username"],
      review["name"],
    ];

    for (final item in candidates) {
      final text = item?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }

    return "Pengguna";
  }

  String getUserEmail(Map<String, dynamic> review) {
    final user = asMap(review["user"]);

    final candidates = [user?["email"], review["email"], review["user_email"]];

    for (final item in candidates) {
      final text = item?.toString().trim() ?? "";

      if (text.isNotEmpty && text != "null") {
        return text;
      }
    }

    return "";
  }

  int getReviewRating(Map<String, dynamic> review) {
    final rating = toInt(review["rating"]);

    if (rating < 1) return 0;
    if (rating > 5) return 5;

    return rating;
  }

  String getReviewComment(Map<String, dynamic> review) {
    final comment =
        review["comment"] ??
        review["komentar"] ??
        review["review"] ??
        review["message"];

    final text = comment?.toString().trim() ?? "";

    if (text.isEmpty || text == "null") {
      return "Tidak ada komentar.";
    }

    return text;
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

  int countRating(int rating) {
    return reviews.where((review) {
      return getReviewRating(review) == rating;
    }).length;
  }

  Future<void> loadReviews() async {
    try {
      if (!mounted) return;

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final propertyId = getPropertyId();

      if (propertyId <= 0) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage = "Property ID tidak ditemukan.";
        });

        return;
      }

      final token = cleanToken(await ApiService().getToken());

      final urls = [
        "${ApiService.baseUrl}/properties/$propertyId/reviews",
        "${ApiService.baseUrl}/places/$propertyId/reviews",
      ];

      http.Response? lastResponse;

      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url), headers: headers(token))
              .timeout(const Duration(seconds: 20));

          lastResponse = response;

          debugPrint("GET OWNER RATING URL:");
          debugPrint(url);

          debugPrint("GET OWNER RATING STATUS:");
          debugPrint(response.statusCode.toString());

          debugPrint("GET OWNER RATING BODY:");
          debugPrint(response.body);

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);

            final data = parseReviewList(decoded);

            double avg = 0;
            int total = 0;

            if (decoded is Map) {
              avg = toDouble(
                decoded["average_rating"] ??
                    decoded["rating_avg"] ??
                    decoded["avg_rating"],
              );

              total = toInt(
                decoded["total_reviews"] ??
                    decoded["rating_count"] ??
                    decoded["total"] ??
                    data.length,
              );
            } else {
              total = data.length;
            }

            if (avg <= 0 && data.isNotEmpty) {
              int sum = 0;

              for (final review in data) {
                sum += getReviewRating(review);
              }

              avg = sum / data.length;
            }

            if (total <= 0) {
              total = data.length;
            }

            if (!mounted) return;

            setState(() {
              reviews = data;
              averageRating = avg;
              totalReviews = total;
              isLoading = false;
              errorMessage = null;
            });

            return;
          }

          if (response.statusCode == 404 || response.statusCode == 405) {
            continue;
          }

          if (!mounted) return;

          setState(() {
            isLoading = false;
            errorMessage = parseResponseMessage(
              response.body,
              "Gagal memuat rating kos.",
            );
          });

          return;
        } catch (e) {
          debugPrint("GET OWNER RATING ERROR:");
          debugPrint(e.toString());
        }
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = parseResponseMessage(
          lastResponse?.body ?? "",
          "Route rating tidak ditemukan.",
        );
      });
    } catch (e) {
      debugPrint("LOAD OWNER RATING ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = "Terjadi kesalahan saat memuat rating.";
      });
    }
  }

  Widget buildStars({
    required double rating,
    double size = 22,
    MainAxisAlignment alignment = MainAxisAlignment.start,
  }) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;

        IconData icon;

        if (rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }

        return Icon(icon, color: Colors.amber, size: size);
      }),
    );
  }

  Widget buildHeader() {
    final propertyName = getPropertyName();
    final address = getPropertyAddress();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 42,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rating Kos",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  propertyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                    height: 1.35,
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

  Widget buildSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            averageRating <= 0 ? "0.0" : averageRating.toStringAsFixed(1),
            style: TextStyle(
              color: primaryColor,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          buildStars(
            rating: averageRating,
            size: 28,
            alignment: MainAxisAlignment.center,
          ),
          const SizedBox(height: 10),
          Text(
            totalReviews <= 0
                ? "Belum ada review"
                : "$totalReviews review dari penghuni",
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(5, (index) {
              final rating = 5 - index;
              final count = countRating(rating);

              final percent = totalReviews <= 0 ? 0.0 : count / totalReviews;

              return buildRatingBar(
                rating: rating,
                count: count,
                percent: percent,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget buildRatingBar({
    required int rating,
    required int count,
    required double percent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Row(
              children: [
                Text(
                  "$rating",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent.clamp(0, 1),
                minHeight: 8,
                backgroundColor: const Color(0xFFE9ECF5),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              "$count",
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReviewCard(Map<String, dynamic> review, int index) {
    final name = getUserName(review);
    final email = getUserEmail(review);
    final rating = getReviewRating(review);
    final comment = getReviewComment(review);
    final createdAt = review["created_at"] ?? review["updated_at"];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: primaryColor.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: softYellow,
              child: Text(
                name.trim().isEmpty ? "U" : name.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF161A33),
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Text(
                        formatDate(createdAt),
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  buildStars(rating: rating.toDouble(), size: 18),
                  const SizedBox(height: 9),
                  Text(
                    comment,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
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

  Widget buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
      children: [
        buildHeader(),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(child: CircularProgressIndicator(color: primaryColor)),
        ),
      ],
    );
  }

  Widget buildError() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: loadReviews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        children: [
          buildHeader(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 58,
                ),
                const SizedBox(height: 14),
                const Text(
                  "Gagal memuat rating",
                  style: TextStyle(
                    color: Color(0xFF161A33),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage ?? "Terjadi kesalahan.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: loadReviews,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    "Coba Lagi",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  Widget buildEmptyReview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: softYellow,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              color: Colors.amber,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum ada review",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF161A33),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Review dari penghuni akan muncul di halaman ini setelah mereka memberi rating.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (isLoading) return buildLoading();

    if (errorMessage != null) return buildError();

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: loadReviews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        children: [
          buildHeader(),
          buildSummaryCard(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Daftar Review",
                  style: TextStyle(
                    color: Color(0xFF161A33),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$totalReviews review",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            buildEmptyReview()
          else
            ...reviews.asMap().entries.map((entry) {
              return buildReviewCard(entry.value, entry.key);
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Rating Kos",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadReviews,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: buildContent(),
    );
  }
}
