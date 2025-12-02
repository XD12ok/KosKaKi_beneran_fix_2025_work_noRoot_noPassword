import 'package:flutter/material.dart';

class KKTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final String hintText;

  const KKTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    required this.hintText,
  });

  @override
  State<KKTextField> createState() => _KKTextFieldState();
}

class _KKTextFieldState extends State<KKTextField> {
  late bool hide;

  @override
  void initState() {
    super.initState();
    hide = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        // bungkus dengan Container putih jika perlu
        TextField(
          controller: widget.controller,
          obscureText: hide,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade700, width: 1.4),
            ),
            suffixIcon: widget.obscure
                ? IconButton(
              icon: Icon(hide ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => hide = !hide),
            )
                : null,
          ),
        ),
      ],
    );
  }
}
