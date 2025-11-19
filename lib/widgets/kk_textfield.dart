import 'package:flutter/material.dart';

class KKTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;

  const KKTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}
