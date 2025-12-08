import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? profileImage;
  final picker = ImagePicker();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();

  bool loading = false;
  Map<String, dynamic>? userRow;
  Map<String, dynamic>? avatarRow;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  // Load Profile
  Future<void> loadUserData() async {
    final auth = supabase.auth.currentUser;

    if (auth == null) {
      print("ERROR: auth user null");
      return;
    }

    final email = auth.email;

    final user = await supabase
        .from("Users")
        .select()
        .eq("Email", email as Object)
        .maybeSingle();

    if (user == null) {
      print("ERROR: User row not found in table Users");
      setState(() {
        userRow = {'id': -1};
      });
      return;
    }

    final avatar = await supabase
        .from("useravatars")
        .select()
        .eq("user_id", user['id'])
        .maybeSingle();

    setState(() {
      userRow = user;
      avatarRow = avatar;

      _name.text = user["UserName"] ?? "";
      _email.text = user["Email"] ?? "";
      _password.text = user["Password"] ?? "";
      _phone.text = user["PhoneNumber"]?.toString() ?? "";
    });
  }

  // ===============================================================
  //                  PICK & UPLOAD AVATAR
  // ===============================================================
  Future<String?> uploadAvatar() async {
    if (profileImage == null) return avatarRow?['avatar_url'];

    final user = supabase.auth.currentUser;
    if (user == null || userRow == null) return null;

    final fileName = "avatar_${user.id}.jpg";

    await supabase.storage.from("avatars").upload(
      fileName,
      profileImage!,
      fileOptions: const FileOptions(upsert: true),
    );

    final url = supabase.storage.from("avatars").getPublicUrl(fileName);

    await supabase.from("useravatars").upsert({
      "user_id": userRow!["id"], // integer dari database
      "avatar_url": url,
    });

    return url;
  }

  // Upd Profile
  Future<void> updateProfile() async {
    if (userRow == null) return;

    setState(() => loading = true);

    try {
      final avatarUrl = await uploadAvatar();

      await supabase.from("Users").update({
        "UserName": _name.text,
        "Email": _email.text,
        "Password": _password.text,
        "PhoneNumber": int.tryParse(_phone.text),
      }).eq("id", userRow!["id"]);

      // Upd auth email/password
      await supabase.auth.updateUser(
        UserAttributes(
          email: _email.text,
          password: _password.text,
        ),
      );

      // Upd state avatar
      if (avatarUrl != null) {
        setState(() {
          avatarRow = {"avatar_url": avatarUrl};
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil berhasil diperbarui")),
      );
    } catch (e) {
      print("UPDATE ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memperbarui profil: $e")),
      );
    }

    setState(() => loading = false);
  }

  // Ui
  @override
  Widget build(BuildContext context) {
    if (userRow == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final avatarUrl = avatarRow?["avatar_url"];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () async {
                  final XFile? image =
                  await picker.pickImage(source: ImageSource.gallery);

                  if (image != null) {
                    setState(() {
                      profileImage = File(image.path);
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : (avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : const NetworkImage(
                          "https://i.pinimg.com/564x/4d/13/e9/4d13e9d97e57493e7cde4cd2e5f05a2f.jpg"))
                      as ImageProvider,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                      child:
                      const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              buildLabel("Nama"),
              buildInput(controller: _name),

              buildLabel("Email"),
              buildInput(controller: _email),

              buildLabel("Password"),
              buildInput(controller: _password),

              buildLabel("Nomor Telepon"),
              buildInput(controller: _phone),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: loading ? null : updateProfile,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Simpan Perubahan"),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
