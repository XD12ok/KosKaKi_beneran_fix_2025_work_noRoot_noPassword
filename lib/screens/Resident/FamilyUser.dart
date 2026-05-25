import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/screens/Resident/QrScan.dart';
import 'package:koskaki/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color familyPrimaryColor = Color(0xFF2D2F8F);
const Color familySecondaryColor = Color(0xFF5B5FEF);
const Color familySoftBlue = Color(0xFFEFF2FF);
const Color familyDarkText = Color(0xFF161A33);

class FamilyUser extends StatefulWidget {
  const FamilyUser({super.key});

  @override
  State<FamilyUser> createState() => _FamilyUserState();
}

class _FamilyUserState extends State<FamilyUser> {
  bool loading = true;
  bool actionLoading = false;

  String? errorMessage;

  int currentUserId = 0;

  List<Map<String, dynamic>> families = [];
  Map<int, Map<String, dynamic>> bookingByPropertyId = {};
  Map<int, Map<String, dynamic>> propertyById = {};

  @override
  void initState() {
    super.initState();
    loadFamilyUser();
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

  Map<String, String> authHeaders(String token) {
    final cleanedToken = cleanToken(token);

    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $cleanedToken",
      "X-Requested-With": "XMLHttpRequest",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    };
  }

  Future<void> loadFamilyUser() async {
    try {
      if (!mounted) return;

      setState(() {
        loading = true;
        errorMessage = null;
      });

      final token = cleanToken(await ApiService().getToken());

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = "Token tidak ditemukan. Silakan login ulang.";
        });

        return;
      }

      currentUserId = await fetchCurrentUserId(token);

      await loadPropertiesForName(token);

      final propertyIds = await collectPropertyIds(token);

      final List<Map<String, dynamic>> result = [];

      for (final propertyId in propertyIds) {
        final family = await fetchFamilyByPropertyId(
          propertyId: propertyId,
          token: token,
        );

        if (family != null) {
          result.add(family);
        }
      }

      result.sort((a, b) {
        final dateA = parseDateTime(a["joined_at"] ?? a["created_at"]);
        final dateB = parseDateTime(b["joined_at"] ?? b["created_at"]);

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        families = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD FAMILY USER ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "Terjadi kesalahan saat memuat family.";
      });
    }
  }

  Future<int> fetchCurrentUserId(String token) async {
    final urls = [
      "${ApiService.baseUrl}/user",
      "${ApiService.baseUrl}/profile",
      "${ApiService.baseUrl}/me",
    ];

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: authHeaders(token))
            .timeout(const Duration(seconds: 20));

        debugPrint("GET USER FOR FAMILY URL:");
        debugPrint(url);

        debugPrint("GET USER FOR FAMILY STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("GET USER FOR FAMILY BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          if (decoded is Map) {
            final data =
                asMap(decoded["data"]) ?? asMap(decoded["user"]) ?? decoded;

            final id = toInt(data["id"]);

            if (id > 0) return id;
          }
        }
      } catch (e) {
        debugPrint("GET USER FOR FAMILY ERROR:");
        debugPrint(e.toString());
      }
    }

    return 0;
  }

  Future<void> loadPropertiesForName(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse("${ApiService.baseUrl}/properties"),
            headers: authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("GET PROPERTIES FOR FAMILY NAME STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET PROPERTIES FOR FAMILY NAME BODY:");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = parseDataList(decoded);

        final Map<int, Map<String, dynamic>> result = {};

        for (final item in data) {
          final property = Map<String, dynamic>.from(item);

          final ids = getPossiblePropertyIdsFromProperty(property);

          for (final id in ids) {
            if (id > 0) {
              result[id] = property;
            }
          }
        }

        propertyById = result;
      }
    } catch (e) {
      debugPrint("GET PROPERTIES FOR FAMILY NAME ERROR:");
      debugPrint(e.toString());
    }
  }

  Set<int> getPossiblePropertyIdsFromProperty(Map<String, dynamic> property) {
    final placeProperty = asMap(property["place_property"]);
    final placePropertyAlt = asMap(property["placeProperty"]);
    final placeProperties = asMap(property["place_properties"]);
    final placePropertiesAlt = asMap(property["placeProperties"]);
    final propertyData = asMap(property["property"]);

    return {
      toInt(property["id"]),
      toInt(property["place_property_id"]),
      toInt(property["place_properties_id"]),
      toInt(property["property_id"]),
      toInt(property["properties_id"]),
      toInt(property["placePropertyId"]),
      toInt(property["propertyId"]),
      toInt(placeProperty?["id"]),
      toInt(placePropertyAlt?["id"]),
      toInt(placeProperties?["id"]),
      toInt(placePropertiesAlt?["id"]),
      toInt(propertyData?["id"]),
    }..removeWhere((id) => id <= 0);
  }

  Future<Set<int>> collectPropertyIds(String token) async {
    final Set<int> ids = {};

    bookingByPropertyId.clear();

    await collectPropertyIdsFromLocal(ids);

    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final urls = [
      "${ApiService.baseUrl}/rental-bookings?_=$cacheBuster",
      "${ApiService.baseUrl}/rental-bookings/history?_=$cacheBuster",
    ];

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: authHeaders(token))
            .timeout(const Duration(seconds: 20));

        debugPrint("COLLECT FAMILY PROPERTY IDS URL:");
        debugPrint(url);

        debugPrint("COLLECT FAMILY PROPERTY IDS STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("COLLECT FAMILY PROPERTY IDS BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = parseDataList(decoded);

          for (final item in data) {
            final booking = Map<String, dynamic>.from(item);

            final propertyId = getPropertyIdFromBooking(booking);

            if (propertyId > 0) {
              ids.add(propertyId);
              bookingByPropertyId[propertyId] = booking;
            }
          }
        }
      } catch (e) {
        debugPrint("COLLECT FAMILY PROPERTY IDS ERROR:");
        debugPrint(e.toString());
      }
    }

    return ids;
  }

  Future<void> collectPropertyIdsFromLocal(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final listKeys = [
        "joined_family_property_ids",
        "family_property_ids",
        "my_family_property_ids",
      ];

      for (final key in listKeys) {
        final list = prefs.getStringList(key) ?? [];

        for (final item in list) {
          final id = toInt(item);

          if (id > 0) {
            ids.add(id);
          }
        }
      }

      final singleKeys = [
        "last_joined_family_property_id",
        "joined_family_property_id",
      ];

      for (final key in singleKeys) {
        final id = toInt(prefs.getString(key));

        if (id > 0) {
          ids.add(id);
        }
      }

      final rentalIds = prefs.getStringList("cached_rental_property_ids") ?? [];

      for (final rawRentalId in rentalIds) {
        final rentalId = toInt(rawRentalId);

        if (rentalId <= 0) continue;

        final raw = prefs.getString("rental_property_info_$rentalId");

        if (raw == null || raw.trim().isEmpty) continue;

        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);

          final propertyId = toInt(
            data["place_property_id"] ??
                data["place_properties_id"] ??
                data["property_id"],
          );

          if (propertyId > 0) {
            ids.add(propertyId);
            bookingByPropertyId[propertyId] = data;
          }
        }
      }
    } catch (e) {
      debugPrint("READ LOCAL FAMILY IDS ERROR:");
      debugPrint(e.toString());
    }
  }

  Future<Map<String, dynamic>?> fetchFamilyByPropertyId({
    required int propertyId,
    required String token,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              "${ApiService.baseUrl}/family/properties/$propertyId/members",
            ),
            headers: authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("GET FAMILY MEMBERS FOR USER STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("GET FAMILY MEMBERS FOR USER PROPERTY ID:");
      debugPrint(propertyId.toString());

      debugPrint("GET FAMILY MEMBERS FOR USER BODY:");
      debugPrint(response.body);

      final booking = bookingByPropertyId[propertyId];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final members = parseDataList(decoded);

        final isOwner = decoded is Map && decoded["is_owner"] == true;

        final totalMembers = decoded is Map
            ? toInt(decoded["total_members"] ?? members.length)
            : members.length;

        Map<String, dynamic>? myMember;

        for (final member in members) {
          final user = asMap(member["user"]);
          final userId = toInt(user?["id"] ?? member["user_id"]);

          if (currentUserId > 0 && userId == currentUserId) {
            myMember = member;
            break;
          }
        }

        final joinedAt =
            myMember?["joined_at"] ??
            booking?["family_joined_at"] ??
            booking?["approved_at"] ??
            booking?["created_at"];

        final rental =
            asMap(myMember?["rental"]) ?? booking ?? <String, dynamic>{};

        return {
          "place_property_id": propertyId,
          "property": {
            "id": propertyId,
            "name": getPropertyNameFromBooking(booking, propertyId),
            "address": getPropertyAddressFromBooking(booking, propertyId),
          },
          "joined_at": joinedAt,
          "created_at": booking?["created_at"],
          "is_owner": isOwner,
          "is_main_tenant": isMainTenant(booking),
          "total_members": totalMembers,
          "members": members,
          "rental": rental,
        };
      }

      if (booking != null) {
        return {
          "place_property_id": propertyId,
          "property": {
            "id": propertyId,
            "name": getPropertyNameFromBooking(booking, propertyId),
            "address": getPropertyAddressFromBooking(booking, propertyId),
          },
          "joined_at":
              booking["family_joined_at"] ??
              booking["approved_at"] ??
              booking["created_at"],
          "created_at": booking["created_at"],
          "is_owner": false,
          "is_main_tenant": isMainTenant(booking),
          "total_members": 0,
          "members": <Map<String, dynamic>>[],
          "rental": booking,
          "access_denied_members": true,
        };
      }

      final property = propertyById[propertyId];

      if (property != null) {
        return {
          "place_property_id": propertyId,
          "property": {
            "id": propertyId,
            "name": getPropertyNameFromProperty(property, propertyId),
            "address": getPropertyAddressFromProperty(property),
          },
          "joined_at": null,
          "created_at": null,
          "is_owner": false,
          "is_main_tenant": false,
          "total_members": 0,
          "members": <Map<String, dynamic>>[],
          "rental": <String, dynamic>{},
          "access_denied_members": true,
        };
      }
    } catch (e) {
      debugPrint("GET FAMILY MEMBERS FOR USER ERROR:");
      debugPrint(e.toString());
    }

    return null;
  }

  bool isMainTenant(Map<String, dynamic>? booking) {
    if (booking == null) return false;

    final user = asMap(booking["user"]);

    final userId = toInt(
      booking["user_id"] ?? booking["userId"] ?? user?["id"],
    );

    if (currentUserId <= 0 || userId <= 0) return false;

    return currentUserId == userId;
  }

  Future<Map<String, dynamic>> fetchReviewSummary(int propertyId) async {
    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      return {
        "average_rating": 0.0,
        "total_reviews": 0,
        "data": <Map<String, dynamic>>[],
        "my_review": null,
        "loaded": false,
      };
    }

    final urls = getReviewUrls(propertyId);

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: authHeaders(token))
            .timeout(const Duration(seconds: 20));

        debugPrint("GET REVIEWS URL:");
        debugPrint(url);

        debugPrint("GET REVIEWS STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("GET REVIEWS BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          final reviews = parseDataList(decoded);

          Map<String, dynamic>? myReview;

          for (final review in reviews) {
            final user = asMap(review["user"]);

            final userId = toInt(
              review["user_id"] ?? review["userId"] ?? user?["id"],
            );

            if (currentUserId > 0 && userId == currentUserId) {
              myReview = review;
              break;
            }
          }

          double averageRating = 0;

          if (decoded is Map) {
            averageRating =
                double.tryParse(
                  decoded["average_rating"]?.toString() ??
                      decoded["rating_avg"]?.toString() ??
                      decoded["avg_rating"]?.toString() ??
                      "0",
                ) ??
                0;
          }

          if (averageRating <= 0 && reviews.isNotEmpty) {
            int total = 0;

            for (final review in reviews) {
              total += toInt(review["rating"]);
            }

            averageRating = total / reviews.length;
          }

          int totalReviews = 0;

          if (decoded is Map) {
            totalReviews = toInt(
              decoded["total_reviews"] ??
                  decoded["rating_count"] ??
                  decoded["total"] ??
                  reviews.length,
            );
          } else {
            totalReviews = reviews.length;
          }

          return {
            "average_rating": averageRating,
            "total_reviews": totalReviews,
            "data": reviews,
            "my_review": myReview,
            "loaded": true,
          };
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          return {
            "average_rating": 0.0,
            "total_reviews": 0,
            "data": <Map<String, dynamic>>[],
            "my_review": null,
            "loaded": false,
            "message": parseResponseMessage(
              response.body,
              "Gagal memuat review.",
            ),
          };
        }
      } catch (e) {
        debugPrint("GET REVIEWS ERROR:");
        debugPrint(e.toString());
      }
    }

    return {
      "average_rating": 0.0,
      "total_reviews": 0,
      "data": <Map<String, dynamic>>[],
      "my_review": null,
      "loaded": false,
      "message": "Route review tidak ditemukan.",
    };
  }

  List<String> getReviewUrls(int propertyId) {
    return [
      "${ApiService.baseUrl}/reviews/$propertyId",
      "${ApiService.baseUrl}/properties/$propertyId/reviews",
      "${ApiService.baseUrl}/place-properties/$propertyId/reviews",
      "${ApiService.baseUrl}/places/$propertyId/reviews",
      "${ApiService.baseUrl}/review/$propertyId",
    ];
  }

  List<String> getReviewStoreUrls(int propertyId) {
    return [
      "${ApiService.baseUrl}/reviews/$propertyId",
      "${ApiService.baseUrl}/properties/$propertyId/reviews",
      "${ApiService.baseUrl}/place-properties/$propertyId/reviews",
      "${ApiService.baseUrl}/places/$propertyId/reviews",
      "${ApiService.baseUrl}/review/$propertyId",
    ];
  }

  Future<bool> submitReview({
    required int propertyId,
    required int rating,
    required String comment,
  }) async {
    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      showMessage("Token tidak ditemukan. Silakan login ulang.", isError: true);
      return false;
    }

    final urls = getReviewStoreUrls(propertyId);

    http.Response? lastResponse;

    for (final url in urls) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: authHeaders(token),
              body: jsonEncode({"rating": rating, "comment": comment.trim()}),
            )
            .timeout(const Duration(seconds: 20));

        lastResponse = response;

        debugPrint("POST REVIEW URL:");
        debugPrint(url);

        debugPrint("POST REVIEW STATUS:");
        debugPrint(response.statusCode.toString());

        debugPrint("POST REVIEW BODY:");
        debugPrint(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          showMessage(
            parseResponseMessage(response.body, "Rating berhasil dikirim."),
          );

          return true;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        showMessage(
          parseResponseMessage(response.body, "Gagal mengirim rating."),
          isError: true,
        );

        return false;
      } catch (e) {
        debugPrint("POST REVIEW ERROR:");
        debugPrint(e.toString());
      }
    }

    showMessage(
      parseResponseMessage(
        lastResponse?.body ?? "",
        "Route rating tidak ditemukan. Cek route review di backend.",
      ),
      isError: true,
    );

    return false;
  }

  Future<void> openJoinFamilyPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );

    if (!mounted) return;

    await loadFamilyUser();
  }

  Future<void> leaveFamily(Map<String, dynamic> family) async {
    final property = asMap(family["property"]);

    final propertyId = toInt(
      family["place_property_id"] ?? property?["id"] ?? family["property_id"],
    );

    if (propertyId <= 0) {
      showMessage("Property ID tidak ditemukan.", isError: true);
      return;
    }

    final mainTenant = family["is_main_tenant"] == true;

    if (mainTenant) {
      showMessage(
        "Penghuni utama tidak bisa keluar dari family.",
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Keluar Family?",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            "Kamu yakin ingin keluar dari ${getPropertyName(family)}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Keluar",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final token = cleanToken(await ApiService().getToken());

    if (token.isEmpty) {
      showMessage("Token tidak ditemukan. Silakan login ulang.", isError: true);
      return;
    }

    if (!mounted) return;

    setState(() {
      actionLoading = true;
    });

    try {
      final response = await http
          .delete(
            Uri.parse("${ApiService.baseUrl}/properties/$propertyId/leave"),
            headers: authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("LEAVE FAMILY STATUS:");
      debugPrint(response.statusCode.toString());

      debugPrint("LEAVE FAMILY BODY:");
      debugPrint(response.body);

      if (!mounted) return;

      setState(() {
        actionLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await removeLocalFamilyPropertyId(propertyId);

        showMessage(
          parseResponseMessage(response.body, "Berhasil keluar dari family."),
        );

        await loadFamilyUser();
        return;
      }

      showMessage(
        parseResponseMessage(response.body, "Gagal keluar dari family."),
        isError: true,
      );
    } catch (e) {
      debugPrint("LEAVE FAMILY ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        actionLoading = false;
      });

      showMessage("Terjadi kesalahan saat keluar family.", isError: true);
    }
  }

  Future<void> removeLocalFamilyPropertyId(int propertyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keys = [
        "joined_family_property_ids",
        "family_property_ids",
        "my_family_property_ids",
      ];

      for (final key in keys) {
        final list = prefs.getStringList(key) ?? [];
        final updated = list
            .where((item) => toInt(item) != propertyId)
            .toList();
        await prefs.setStringList(key, updated);
      }

      final singleKeys = [
        "last_joined_family_property_id",
        "joined_family_property_id",
      ];

      for (final key in singleKeys) {
        if (toInt(prefs.getString(key)) == propertyId) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint("REMOVE LOCAL FAMILY ID ERROR:");
      debugPrint(e.toString());
    }
  }

  void showFamilyDetail(Map<String, dynamic> family) {
    final property = asMap(family["property"]);

    final propertyId = toInt(
      family["place_property_id"] ?? property?["id"] ?? family["property_id"],
    );

    final rental = asMap(family["rental"]);
    final members = parseDataList(family["members"]);
    final accessDeniedMembers = family["access_denied_members"] == true;
    final isMain = family["is_main_tenant"] == true;

    Future<Map<String, dynamic>> reviewFuture = propertyId > 0
        ? fetchReviewSummary(propertyId)
        : Future.value({
            "average_rating": 0.0,
            "total_reviews": 0,
            "data": <Map<String, dynamic>>[],
            "my_review": null,
            "loaded": false,
          });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshReviews() {
              if (!context.mounted) return;

              setSheetState(() {
                reviewFuture = propertyId > 0
                    ? fetchReviewSummary(propertyId)
                    : Future.value({
                        "average_rating": 0.0,
                        "total_reviews": 0,
                        "data": <Map<String, dynamic>>[],
                        "my_review": null,
                        "loaded": false,
                      });
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.38,
              maxChildSize: 0.94,
              builder: (context, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 54,
                            height: 6,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    familyPrimaryColor,
                                    familySecondaryColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.family_restroom_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getPropertyName(family),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: familyDarkText,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    accessDeniedMembers
                                        ? "Data member belum bisa dibuka dari route saat ini"
                                        : "${family["total_members"] ?? members.length} member family",
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        buildDetailInfo(
                          icon: Icons.location_on_rounded,
                          title: "Alamat",
                          value: getPropertyAddress(family),
                        ),
                        buildDetailInfo(
                          icon: Icons.calendar_month_rounded,
                          title: "Tanggal Bergabung",
                          value: formatDate(family["joined_at"]),
                        ),
                        if (rental != null && rental.isNotEmpty) ...[
                          buildDetailInfo(
                            icon: Icons.login_rounded,
                            title: "Mulai Sewa",
                            value: formatDate(rental["start_date"]),
                          ),
                          buildDetailInfo(
                            icon: Icons.logout_rounded,
                            title: "Selesai Sewa",
                            value: formatDate(rental["end_date"]),
                          ),
                          buildDetailInfo(
                            icon: Icons.verified_rounded,
                            title: "Status",
                            value: getStatusText(
                              rental["payment_status"] ?? rental["status"],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        FutureBuilder<Map<String, dynamic>>(
                          future: reviewFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return buildReviewLoadingBox();
                            }

                            final data = snapshot.data ?? {};

                            return buildReviewBox(
                              propertyId: propertyId,
                              reviewData: data,
                              onRefresh: refreshReviews,
                            );
                          },
                        ),
                        if (!accessDeniedMembers && members.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            "Member Family",
                            style: TextStyle(
                              color: familyDarkText,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...members.map(buildMemberItem).toList(),
                        ],
                        const SizedBox(height: 10),
                        if (isMain)
                          buildMainTenantBox()
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(
                                  color: Colors.red.withOpacity(0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: actionLoading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      leaveFamily(family);
                                    },
                              icon: const Icon(Icons.exit_to_app_rounded),
                              label: const Text(
                                "Keluar dari Family",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildReviewLoadingBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: familyPrimaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Memuat rating kost...",
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReviewBox({
    required int propertyId,
    required Map<String, dynamic> reviewData,
    required VoidCallback onRefresh,
  }) {
    final averageRating =
        double.tryParse(reviewData["average_rating"]?.toString() ?? "0") ?? 0;

    final totalReviews = toInt(reviewData["total_reviews"]);

    final myReview = asMap(reviewData["my_review"]);

    final myRating = toInt(myReview?["rating"]);
    final myComment = myReview?["comment"]?.toString() ?? "";

    final loaded = reviewData["loaded"] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: familyPrimaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rating Kost",
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loaded
                          ? "${averageRating.toStringAsFixed(1)} / 5 • $totalReviews review"
                          : "Belum bisa memuat review",
                      style: const TextStyle(
                        color: familyDarkText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final filled = index < averageRating.round();

                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 18,
                  );
                }),
              ),
            ],
          ),
          if (myRating > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: familySoftBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Rating kamu:",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < myRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                  if (myComment.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      myComment,
                      style: const TextStyle(
                        color: familyDarkText,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: propertyId <= 0
                  ? null
                  : () {
                      showRatingDialog(
                        propertyId: propertyId,
                        existingReview: myReview,
                        onSuccess: onRefresh,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: familyPrimaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.rate_review_rounded),
              label: Text(
                myRating > 0 ? "Ubah Rating Kost" : "Beri Rating Kost",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showRatingDialog({
    required int propertyId,
    required Map<String, dynamic>? existingReview,
    required VoidCallback onSuccess,
  }) async {
    int selectedRating = toInt(existingReview?["rating"]);

    if (selectedRating <= 0) {
      selectedRating = 5;
    }

    final commentController = TextEditingController(
      text: existingReview?["comment"]?.toString() ?? "",
    );

    bool submitting = false;

    final bool? successResult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (submitting) return;

              if (selectedRating < 1 || selectedRating > 5) {
                showMessage("Pilih rating 1 sampai 5.", isError: true);
                return;
              }

              setDialogState(() {
                submitting = true;
              });

              final success = await submitReview(
                propertyId: propertyId,
                rating: selectedRating,
                comment: commentController.text,
              );

              if (!dialogContext.mounted) return;

              if (!success) {
                setDialogState(() {
                  submitting = false;
                });
                return;
              }

              Navigator.of(dialogContext).pop(true);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                existingReview == null ? "Beri Rating Kost" : "Ubah Rating",
                style: const TextStyle(
                  color: familyDarkText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Pilih bintang sesuai pengalaman kamu tinggal di kost ini.",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final ratingValue = index + 1;

                        return IconButton(
                          onPressed: submitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = ratingValue;
                                  });
                                },
                          icon: Icon(
                            ratingValue <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 36,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentController,
                      enabled: !submitting,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: "Tulis komentar opsional...",
                        filled: true,
                        fillColor: familySoftBlue,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text("Batal"),
                ),
                ElevatedButton.icon(
                  onPressed: submitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: familyPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    submitting ? "Mengirim..." : "Kirim",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();

    if (successResult == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      onSuccess();
    }
  }

  Widget buildMemberItem(Map<String, dynamic> member) {
    final user = asMap(member["user"]);
    final name = user?["name"]?.toString() ?? "Tanpa Nama";
    final email = user?["email"]?.toString() ?? "-";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: familySoftBlue,
            child: Text(
              name.isEmpty ? "?" : name[0].toUpperCase(),
              style: const TextStyle(
                color: familyPrimaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: familyDarkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> parseDataList(dynamic decoded) {
    dynamic rawData;

    if (decoded is Map) {
      rawData = decoded["data"];

      if (rawData is Map && rawData["data"] != null) {
        rawData = rawData["data"];
      }

      if (rawData == null && decoded["members"] != null) {
        rawData = decoded["members"];
      }

      if (rawData == null && decoded["families"] != null) {
        rawData = decoded["families"];
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

  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  int toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    String text = value.toString().trim();

    if (text.isEmpty || text == "null") return 0;

    text = text.replaceAll("Rp", "").trim();

    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text)?.round() ?? 0;
    }

    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      return double.tryParse(text.replaceAll(",", "."))?.round() ?? 0;
    }

    text = text.replaceAll(".", "").replaceAll(",", "");

    final cleanText = text.replaceAll(RegExp(r"[^0-9]"), "");

    if (cleanText.isEmpty) return 0;

    return int.tryParse(cleanText) ?? 0;
  }

  DateTime parseDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? "");

    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int getPropertyIdFromBooking(Map<String, dynamic> booking) {
    final property = asMap(booking["property"]);
    final placeProperty = asMap(booking["place_property"]);
    final placePropertyCamel = asMap(booking["placeProperty"]);
    final placeProperties = asMap(booking["place_properties"]);
    final placePropertiesCamel = asMap(booking["placeProperties"]);
    final place = asMap(booking["place"]);
    final kos = asMap(booking["kos"]);
    final kost = asMap(booking["kost"]);

    return toInt(
      booking["place_property_id"] ??
          booking["place_properties_id"] ??
          booking["property_id"] ??
          booking["placePropertyId"] ??
          booking["propertyId"] ??
          placeProperty?["id"] ??
          placePropertyCamel?["id"] ??
          placeProperties?["id"] ??
          placePropertiesCamel?["id"] ??
          property?["id"] ??
          place?["id"] ??
          kos?["id"] ??
          kost?["id"],
    );
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

  bool isValidText(String? value) {
    final text = value?.trim() ?? "";

    if (text.isEmpty) return false;
    if (text == "null") return false;
    if (text.startsWith("{")) return false;
    if (text.startsWith("[")) return false;

    return true;
  }

  String pickTextFromMap(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return "";

    for (final key in keys) {
      final value = source[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (isValidText(text)) {
        return text;
      }
    }

    return "";
  }

  List<String> propertyNameKeys({bool includeGenericName = false}) {
    final keys = [
      "title",
      "property_name",
      "place_property_name",
      "nama_kos",
      "nama_kost",
      "kos_name",
      "kost_name",
      "place_name",
      "property_title",
    ];

    if (includeGenericName) {
      keys.addAll(["name", "nama"]);
    }

    return keys;
  }

  List<String> propertyAddressKeys() {
    return [
      "address",
      "alamat",
      "location",
      "lokasi",
      "full_address",
      "alamat_lengkap",
      "property_address",
      "place_property_address",
    ];
  }

  String getPropertyNameFromProperty(
    Map<String, dynamic> property,
    int propertyId,
  ) {
    final value = pickTextFromMap(
      property,
      propertyNameKeys(includeGenericName: true),
    );

    if (isValidText(value)) {
      return value;
    }

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddressFromProperty(Map<String, dynamic> property) {
    final value = pickTextFromMap(property, propertyAddressKeys());

    if (isValidText(value)) {
      return value;
    }

    return "Alamat belum tersedia";
  }

  String getPropertyNameFromBooking(
    Map<String, dynamic>? booking,
    int propertyId,
  ) {
    final propertyFromList = propertyById[propertyId];

    final property = asMap(booking?["property"]);
    final placeProperty = asMap(booking?["place_property"]);
    final placePropertyCamel = asMap(booking?["placeProperty"]);
    final placeProperties = asMap(booking?["placeProperties"]);
    final place = asMap(booking?["place"]);
    final kost = asMap(booking?["kost"]);
    final kos = asMap(booking?["kos"]);

    final possibleMaps = [
      property,
      placeProperty,
      placePropertyCamel,
      placeProperties,
      place,
      kost,
      kos,
      propertyFromList,
    ];

    for (final map in possibleMaps) {
      final text = pickTextFromMap(
        map,
        propertyNameKeys(includeGenericName: true),
      );

      if (isValidText(text)) {
        return text;
      }
    }

    final fromBookingOnly = pickTextFromMap(
      booking,
      propertyNameKeys(includeGenericName: false),
    );

    if (isValidText(fromBookingOnly)) {
      return fromBookingOnly;
    }

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddressFromBooking(
    Map<String, dynamic>? booking,
    int propertyId,
  ) {
    final propertyFromList = propertyById[propertyId];

    final property = asMap(booking?["property"]);
    final placeProperty = asMap(booking?["place_property"]);
    final placePropertyCamel = asMap(booking?["placeProperty"]);
    final placeProperties = asMap(booking?["placeProperties"]);
    final place = asMap(booking?["place"]);
    final kost = asMap(booking?["kost"]);
    final kos = asMap(booking?["kos"]);

    final possibleMaps = [
      property,
      placeProperty,
      placePropertyCamel,
      placeProperties,
      place,
      kost,
      kos,
      propertyFromList,
    ];

    for (final map in possibleMaps) {
      final text = pickTextFromMap(map, propertyAddressKeys());

      if (isValidText(text)) {
        return text;
      }
    }

    final fromBookingOnly = pickTextFromMap(booking, propertyAddressKeys());

    if (isValidText(fromBookingOnly)) {
      return fromBookingOnly;
    }

    return "Alamat belum tersedia";
  }

  String getPropertyName(Map<String, dynamic> family) {
    final property = asMap(family["property"]);

    final propertyId = toInt(
      family["place_property_id"] ?? property?["id"] ?? family["property_id"],
    );

    final propertyFromList = propertyById[propertyId];

    final fromProperty = pickTextFromMap(
      property,
      propertyNameKeys(includeGenericName: true),
    );

    if (isValidText(fromProperty)) {
      return fromProperty;
    }

    if (propertyFromList != null) {
      final fromList = getPropertyNameFromProperty(
        propertyFromList,
        propertyId,
      );

      if (isValidText(fromList) && fromList != "Nama kos tidak tersedia") {
        return fromList;
      }
    }

    return "Nama kos tidak tersedia";
  }

  String getPropertyAddress(Map<String, dynamic> family) {
    final property = asMap(family["property"]);

    final propertyId = toInt(
      family["place_property_id"] ?? property?["id"] ?? family["property_id"],
    );

    final propertyFromList = propertyById[propertyId];

    final fromProperty = pickTextFromMap(property, propertyAddressKeys());

    if (isValidText(fromProperty)) {
      return fromProperty;
    }

    if (propertyFromList != null) {
      final fromList = getPropertyAddressFromProperty(propertyFromList);

      if (isValidText(fromList) && fromList != "Alamat belum tersedia") {
        return fromList;
      }
    }

    return "Alamat belum tersedia";
  }

  String formatDate(dynamic value) {
    if (value == null) return "-";

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return "-";

    final date = DateTime.tryParse(text);

    if (date == null) return text;

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

  String formatRupiah(dynamic value) {
    final number = toInt(value);

    final result = number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ".",
    );

    return "Rp $result";
  }

  String getStatusText(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (status == "pending") return "Menunggu";
    if (status == "pending_payment") return "Menunggu Pembayaran";
    if (status == "approved") return "Disetujui";
    if (status == "active") return "Aktif";
    if (status == "paid") return "Lunas";
    if (status == "lunas") return "Lunas";
    if (status == "grace") return "Grace";
    if (status == "overdue") return "Terlambat";
    if (status == "rejected") return "Ditolak";
    if (status == "cancelled" || status == "canceled") return "Dibatalkan";
    if (status == "completed" || status == "finish") return "Selesai";

    if (status.isEmpty || status == "null") return "Tidak diketahui";

    return status;
  }

  Color getStatusColor(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? "";

    if (status == "approved" ||
        status == "active" ||
        status == "paid" ||
        status == "lunas" ||
        status == "completed" ||
        status == "finish") {
      return Colors.green;
    }

    if (status == "pending" ||
        status == "waiting" ||
        status == "pending_payment" ||
        status == "grace") {
      return Colors.orange;
    }

    if (status == "rejected" ||
        status == "cancelled" ||
        status == "canceled" ||
        status == "overdue") {
      return Colors.red;
    }

    return familyPrimaryColor;
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : familyPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget buildDetailInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: familyPrimaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: familySoftBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: familyPrimaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: familyDarkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMainTenantBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Kamu adalah penghuni utama, jadi tidak bisa keluar dari family ini.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) {
        return Container(
          height: 142,
          decoration: BoxDecoration(
            color: familySoftBlue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget buildEmpty() {
    return RefreshIndicator(
      color: familyPrimaryColor,
      onRefresh: loadFamilyUser,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: familyPrimaryColor.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: familySoftBlue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.group_off_rounded,
                    color: familyPrimaryColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Belum ada family",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: familyDarkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Family yang bisa dibaca dari route saat ini akan muncul di sini. Untuk masuk family, gunakan kode family.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: openJoinFamilyPage,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text(
                      "Masukkan Kode Family",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: familyPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
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

  Widget buildError() {
    return RefreshIndicator(
      color: familyPrimaryColor,
      onRefresh: loadFamilyUser,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Gagal memuat family",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: familyDarkText,
                    fontSize: 19,
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
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: loadFamilyUser,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: familyPrimaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Coba Lagi",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget buildFamilyCard(Map<String, dynamic> family, int index) {
    final rental = asMap(family["rental"]);
    final status = rental?["payment_status"] ?? rental?["status"];
    final statusColor = getStatusColor(status);
    final isMain = family["is_main_tenant"] == true;
    final accessDeniedMembers = family["access_denied_members"] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 70)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => showFamilyDetail(family),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: familyPrimaryColor.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [familyPrimaryColor, familySecondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      getPropertyName(family),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: familyDarkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      getStatusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: familyPrimaryColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      getPropertyAddress(family),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Icon(
                    Icons.group_rounded,
                    size: 16,
                    color: familyPrimaryColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      accessDeniedMembers
                          ? "Family aktif • detail member terbatas"
                          : "${family["total_members"] ?? 0} member • Bergabung ${formatDate(family["joined_at"])}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (rental != null && rental.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: familySoftBlue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${formatDate(rental["start_date"])} - ${formatDate(rental["end_date"])}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: familyPrimaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: familyPrimaryColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
              if (isMain) ...[
                const SizedBox(height: 10),
                const Text(
                  "Kamu adalah penghuni utama family ini",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildContent() {
    if (loading) return buildLoading();

    if (errorMessage != null) return buildError();

    if (families.isEmpty) return buildEmpty();

    return RefreshIndicator(
      color: familyPrimaryColor,
      onRefresh: loadFamilyUser,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: families.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return buildFamilyCard(families[index], index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [familyPrimaryColor, familySecondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: familyPrimaryColor.withOpacity(0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Family Saya",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Lihat family kost yang kamu ikuti",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: openJoinFamilyPage,
                        child: Container(
                          width: 42,
                          height: 42,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: loadFamilyUser,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: buildContent()),
              ],
            ),
          ),
          if (actionLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.16),
                child: const Center(
                  child: CircularProgressIndicator(color: familyPrimaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
