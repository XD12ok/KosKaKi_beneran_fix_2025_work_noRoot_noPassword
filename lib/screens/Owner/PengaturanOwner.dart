import 'package:flutter/material.dart';
import 'package:koskaki/screens/WelcomeScreen.dart';
import 'package:koskaki/screens/auth/forgotpass.dart';
import 'package:koskaki/screens/Owner/ListChat.dart';
import 'package:koskaki/service/api_service.dart';

class PengaturanOwnerPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final bool loading;

  const PengaturanOwnerPage({super.key, this.userData, this.loading = false});

  @override
  State<PengaturanOwnerPage> createState() => _PengaturanOwnerPageState();
}

class _PengaturanOwnerPageState extends State<PengaturanOwnerPage> {
  final Color primaryColor = const Color(0xFF0A0E50);

  bool isLoading = true;
  bool isLogoutLoading = false;

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();

    final fromParent = findUserMap(widget.userData);

    if (fromParent != null) {
      user = fromParent;
      isLoading = false;
    }

    getUserProfile();
  }

  Map<String, dynamic>? findUserMap(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      final hasUserIdentity =
          map['email'] != null ||
          map['username'] != null ||
          map['name'] != null ||
          map['full_name'] != null ||
          map['nama'] != null;

      if (hasUserIdentity) {
        return map;
      }

      final possibleKeys = [
        'data',
        'user',
        'owner',
        'profile',
        'account',
        'auth',
        'result',
      ];

      for (final key in possibleKeys) {
        final found = findUserMap(map[key]);

        if (found != null) {
          return found;
        }
      }

      for (final item in map.values) {
        final found = findUserMap(item);

        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  Future<void> getUserProfile() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final api = ApiService();
      final data = await api.getUser();

      debugPrint("PROFILE RAW USER DATA:");
      debugPrint(data.toString());

      final foundUser = findUserMap(data);

      debugPrint("PROFILE FOUND USER:");
      debugPrint(foundUser.toString());

      if (!mounted) return;

      setState(() {
        user = foundUser ?? data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("GET PROFILE ERROR:");
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showAlert(
        title: "Gagal Memuat Profile",
        message: "Terjadi kesalahan saat mengambil data user.",
        isSuccess: false,
      );
    }
  }

  String getValueFromUser(List<String> keys) {
    final currentUser = user;

    if (currentUser == null) return "";

    for (final key in keys) {
      final value = currentUser[key];

      if (value != null &&
          value.toString().trim().isNotEmpty &&
          value.toString() != "null") {
        return value.toString();
      }
    }

    final nestedUser = findUserMap(currentUser);

    if (nestedUser != null && nestedUser != currentUser) {
      for (final key in keys) {
        final value = nestedUser[key];

        if (value != null &&
            value.toString().trim().isNotEmpty &&
            value.toString() != "null") {
          return value.toString();
        }
      }
    }

    return "";
  }

  String getUsername() {
    if (isLoading && user == null) return "Memuat...";

    final value = getValueFromUser([
      'username',
      'name',
      'full_name',
      'nama',
      'display_name',
    ]);

    if (value.trim().isEmpty) return "Owner";

    return value;
  }

  String getEmail() {
    if (isLoading && user == null) return "Memuat...";

    final value = getValueFromUser([
      'email',
      'user_email',
      'mail',
      'email_address',
    ]);

    if (value.trim().isEmpty) return "-";

    return value;
  }

  String getInitial() {
    final username = getUsername();

    if (username.trim().isEmpty || username == "Memuat...") {
      return "O";
    }

    return username.trim()[0].toUpperCase();
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Logout",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Apakah kamu yakin ingin keluar dari akun ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isLogoutLoading = true;
    });

    try {
      final api = ApiService();
      final success = await api.logout();

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      } else {
        showAlert(
          title: "Gagal Logout",
          message: "Tidak bisa logout. Coba lagi.",
          isSuccess: false,
        );
      }
    } catch (e) {
      debugPrint("ERROR LOGOUT:");
      debugPrint(e.toString());

      if (!mounted) return;

      showAlert(
        title: "Error",
        message: "Terjadi kesalahan saat logout.",
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLogoutLoading = false;
        });
      }
    }
  }

  void goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPassPage()),
    );
  }

  void goToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatListOwnerPage()),
    );
  }

  void showAlert({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: RefreshIndicator(
        color: primaryColor,
        onRefresh: getUserProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            profileHeader(),
            const SizedBox(height: 22),
            accountInfoCard(),
            const SizedBox(height: 18),
            actionCard(),
          ],
        ),
      ),
    );
  }

  Widget profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E50), Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 92,
            width: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 4,
              ),
            ),
            child: Center(
              child: isLoading && user == null
                  ? CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    )
                  : Text(
                      getInitial(),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            getUsername(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            getEmail(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "Pemilik Kos",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget accountInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informasi Akun",
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          profileInfoTile(
            icon: Icons.person_outline_rounded,
            title: "Username",
            value: getUsername(),
          ),

          const SizedBox(height: 12),

          profileInfoTile(
            icon: Icons.email_outlined,
            title: "Email",
            value: getEmail(),
          ),
        ],
      ),
    );
  }

  Widget actionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          actionButton(
            icon: Icons.lock_reset_rounded,
            title: "Lupa Password",
            subtitle: "Ubah password melalui email",
            color: primaryColor,
            onTap: goToForgotPassword,
          ),

          const SizedBox(height: 12),

          actionButton(
            icon: Icons.chat_bubble_outline_rounded,
            title: "Chat",
            subtitle: "Lihat dan balas pesan penghuni",
            color: primaryColor,
            onTap: goToChat,
          ),

          const SizedBox(height: 12),

          actionButton(
            icon: Icons.logout_rounded,
            title: "Logout",
            subtitle: "Keluar dari akun ini",
            color: Colors.red,
            onTap: isLogoutLoading ? null : logout,
            trailing: isLogoutLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget profileInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 23),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            trailing ??
                Icon(Icons.chevron_right_rounded, color: color, size: 26),
          ],
        ),
      ),
    );
  }
}
