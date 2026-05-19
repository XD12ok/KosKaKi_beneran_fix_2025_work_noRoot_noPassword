import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:koskaki/service/api_service.dart';

class EditKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;

  const EditKostPage({super.key, required this.kost});

  @override
  State<EditKostPage> createState() => _EditKostPageState();
}

class _EditKostPageState extends State<EditKostPage> {
  bool isLoading = false;

  // =========================
  // CONTROLLER
  // =========================
  late TextEditingController titleC;
  late TextEditingController descC;
  late TextEditingController addressC;
  late TextEditingController maxPeopleC;

  late TextEditingController nightC;
  late TextEditingController weekC;
  late TextEditingController monthC;
  late TextEditingController yearC;

  // =========================
  // FEATURES
  // =========================
  List<String> propertyFeatures = [];
  List<String> placeFeatures = [];

  List<String> customPropertyFeatures = [];
  List<String> customPlaceFeatures = [];

  final List<String> propertyFeatureOptions = [
    "WiFi",
    "CCTV",
    "Parkir",
    "Laundry",
    "Dapur",
  ];

  final List<String> placeFeatureOptions = [
    "AC",
    "TV",
    "Kasur",
    "Lemari",
  ];

  // =========================
  // POLICIES
  // =========================
  List<Map<String, TextEditingController>> propertyPolicies = [];
  List<Map<String, TextEditingController>> placePolicies = [];

  @override
  void initState() {
    super.initState();

    final k = widget.kost;

    titleC = TextEditingController(text: k['title'] ?? '');
    descC = TextEditingController(text: k['description'] ?? '');
    addressC = TextEditingController(text: k['address'] ?? '');
    maxPeopleC = TextEditingController(text: k['max_people']?.toString() ?? '');

    nightC = TextEditingController(text: k['price_perNight']?.toString() ?? '');
    weekC = TextEditingController(text: k['price_perWeek']?.toString() ?? '');
    monthC = TextEditingController(text: k['price_perMonth']?.toString() ?? '');
    yearC = TextEditingController(text: k['price_perYear']?.toString() ?? '');

    // =========================
    // LOAD FEATURE (SAFE)
    // =========================
    propertyFeatures = List<String>.from(k['property_features'] ?? []);
    placeFeatures = List<String>.from(k['place_features'] ?? []);

    // =========================
    // LOAD POLICY (SAFE)
    // =========================
    final propPol = (k['property_policies'] ?? []) as List;
    final placePol = (k['place_policies'] ?? []) as List;

    propertyPolicies = propPol.map((e) {
      return {
        "title": TextEditingController(text: e['title'] ?? ''),
        "desc": TextEditingController(text: e['description'] ?? ''),
      };
    }).toList();

    placePolicies = placePol.map((e) {
      return {
        "title": TextEditingController(text: e['title'] ?? ''),
        "desc": TextEditingController(text: e['description'] ?? ''),
      };
    }).toList();

    if (propertyPolicies.isEmpty) {
      propertyPolicies.add({
        "title": TextEditingController(),
        "desc": TextEditingController(),
      });
    }

    if (placePolicies.isEmpty) {
      placePolicies.add({
        "title": TextEditingController(),
        "desc": TextEditingController(),
      });
    }
  }

  // =========================
  // UPDATE
  // =========================
  Future<void> update() async {
    setState(() => isLoading = true);

    final token = await ApiService().getToken();
    final id = widget.kost['id'];

    final body = {
      "title": titleC.text,
      "description": descC.text,
      "address": addressC.text,
      "max_people": maxPeopleC.text,
      "price_perNight": nightC.text,
      "price_perWeek": weekC.text,
      "price_perMonth": monthC.text,
      "price_perYear": yearC.text,

      // 🔥 FEATURES (IMPORTANT)
      "property_features": jsonEncode([
        ...propertyFeatures,
        ...customPropertyFeatures,
      ]),
      "place_features": jsonEncode([
        ...placeFeatures,
        ...customPlaceFeatures,
      ]),
    };

    final res = await http.put(
      Uri.parse("${ApiService.baseUrl}/properties/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    setState(() => isLoading = false);

    if (res.statusCode == 200) {
      Navigator.pop(context, true);
    }
  }

  // =========================
  // UI HELPERS
  // =========================
  Widget input(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget policyCard(List list, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: list[i]['title'],
            decoration: const InputDecoration(labelText: "Judul"),
          ),
          TextField(
            controller: list[i]['desc'],
            decoration: const InputDecoration(labelText: "Deskripsi"),
          ),
        ],
      ),
    );
  }

  // =========================
  // ADD FEATURE DIALOG
  // =========================
  void addFeatureDialog(bool isProperty) {
    final options = isProperty
        ? propertyFeatureOptions
        : placeFeatureOptions;

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView(
          children: options.map((e) {
            final selected = isProperty
                ? propertyFeatures.contains(e)
                : placeFeatures.contains(e);

            return ListTile(
              title: Text(e),
              trailing: selected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() {
                  if (isProperty) {
                    if (propertyFeatures.contains(e)) {
                      propertyFeatures.remove(e);
                    } else {
                      propertyFeatures.add(e);
                    }
                  } else {
                    if (placeFeatures.contains(e)) {
                      placeFeatures.remove(e);
                    } else {
                      placeFeatures.add(e);
                    }
                  }
                });

                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Kost")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            input("Nama", titleC),
            input("Deskripsi", descC),
            input("Alamat", addressC),
            input("Max Orang", maxPeopleC),

            Row(
              children: [
                Expanded(child: input("Night", nightC)),
                const SizedBox(width: 10),
                Expanded(child: input("Week", weekC)),
              ],
            ),

            Row(
              children: [
                Expanded(child: input("Month", monthC)),
                const SizedBox(width: 10),
                Expanded(child: input("Year", yearC)),
              ],
            ),

            const SizedBox(height: 20),

            // ================= FEATURE KOST =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fasilitas Kost"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addFeatureDialog(true),
                )
              ],
            ),

            Wrap(
              spacing: 8,
              children: [
                ...propertyFeatureOptions,
                ...customPropertyFeatures,
              ].map((e) {
                final isCustom = customPropertyFeatures.contains(e);

                return InputChip(
                  label: Text(e),
                  selected: propertyFeatures.contains(e),
                  onSelected: (v) {
                    setState(() {
                      v
                          ? propertyFeatures.add(e)
                          : propertyFeatures.remove(e);
                    });
                  },
                  onDeleted: isCustom
                      ? () {
                    setState(() {
                      customPropertyFeatures.remove(e);
                      propertyFeatures.remove(e);
                    });
                  }
                      : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ================= FEATURE KAMAR =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fasilitas Kamar"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addFeatureDialog(false),
                )
              ],
            ),

            Wrap(
              spacing: 8,
              children: [
                ...placeFeatureOptions,
                ...customPlaceFeatures,
              ].map((e) {
                final isCustom = customPlaceFeatures.contains(e);

                return InputChip(
                  label: Text(e),
                  selected: placeFeatures.contains(e),
                  onSelected: (v) {
                    setState(() {
                      v
                          ? placeFeatures.add(e)
                          : placeFeatures.remove(e);
                    });
                  },
                  onDeleted: isCustom
                      ? () {
                    setState(() {
                      customPlaceFeatures.remove(e);
                      placeFeatures.remove(e);
                    });
                  }
                      : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ================= POLICY KOST =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Aturan Kost"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      propertyPolicies.add({
                        "title": TextEditingController(),
                        "desc": TextEditingController(),
                      });
                    });
                  },
                )
              ],
            ),

            ...List.generate(propertyPolicies.length,
                    (i) => policyCard(propertyPolicies, i)),

            const SizedBox(height: 20),

            // ================= POLICY KAMAR =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Aturan Kamar"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      placePolicies.add({
                        "title": TextEditingController(),
                        "desc": TextEditingController(),
                      });
                    });
                  },
                )
              ],
            ),

            ...List.generate(placePolicies.length,
                    (i) => policyCard(placePolicies, i)),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : update,
                child: Text(isLoading ? "Loading..." : "Update Kost"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}