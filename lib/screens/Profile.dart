import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koskaki/service/upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? profileImage;
  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // FOTO PROFIL + GANTI FOTO
              GestureDetector(
                onTap: pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : const NetworkImage(
                        "https://i.pinimg.com/564x/4d/13/e9/4d13e9d97e57493e7cde4cd2e5f05a2f.jpg",
                      ) as ImageProvider,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // FORM DATA LAINNYA
              buildLabel("Nama"),
              buildInput(controller: TextEditingController(text: "Wedus Gak Mandi")),

              buildLabel("Email"),
              buildInput(controller: TextEditingController(text: "wedus.cyanitks@gmail.com")),

              buildLabel("Password"),
              buildInput(controller: TextEditingController(text: "********")),

              buildLabel("Nomor Telepon"),
              buildInput(controller: TextEditingController(text: "+62 098 1290 990")),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () async {
                  // 1. Pastikan user sudah pilih gambar
                  if (profileImage != null) {

                    final userId = supabase.auth.currentUser!.id;

                    // 2. Upload gambar ke Supabase Storage
                    final avatarUrl = await uploadAvatar(profileImage!, userId);

                    // 3. Jika berhasil, simpan URL avatar ke tabel "profiles"
                    if (avatarUrl != null) {
                      await supabase.from('profiles').update({
                        'avatar_url': avatarUrl,
                      }).eq('id', userId);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Foto profil berhasil diperbarui!")),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pilih foto dulu")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20208A),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Perbarui", style: TextStyle(fontSize: 18)),
              )

            ],
          ),
        ),
      ),
    );
  }

  // Reusable widget untuk label
  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 15),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Reusable widget untuk input
  Widget buildInput({required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}
