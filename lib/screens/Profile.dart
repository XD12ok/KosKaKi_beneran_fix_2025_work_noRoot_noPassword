import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  // 🔥 DUMMY DATA (anggap dari backend)
  final TextEditingController nameController =
      TextEditingController(text: "Wedus Gak Mandi");

  final TextEditingController emailController =
      TextEditingController(text: "wedus@gmail.com");

  final TextEditingController phoneController =
      TextEditingController(text: "+62 812 3456 789");

  final TextEditingController passwordController =
      TextEditingController(text: "12345678");

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

              // 🔙 BACK BUTTON
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              const SizedBox(height: 10),

              // 👤 FOTO PROFILE
              const CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage("assets/profile.png"),
              ),

              const SizedBox(height: 25),

              // ================= FORM =================

              buildField("Nama", nameController),
              buildField("Email", emailController),
              buildField("Password", passwordController, isPassword: true),
              buildField("Nomor Telepon", phoneController),

              const SizedBox(height: 20),

              // 🔘 BUTTON UPDATE
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2F8F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // 🔥 SIMULASI UPDATE
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Data berhasil diperbarui (dummy)"),
                      ),
                    );
                  },
                  child: const Text("Perbarui"),
                ),
              ),

              const SizedBox(height: 20),

              // 🔴 LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // balik ke home aja dulu
                  },
                  child: const Text("Logout"),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),

      // ➕ FLOAT BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  // 🔧 FIELD BUILDER
  Widget buildField(String title, TextEditingController controller,
      {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),

        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 14),
      ],
    );
  }
}