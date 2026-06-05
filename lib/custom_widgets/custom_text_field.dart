import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hintText;
  final bool isPassword;
  final TextEditingController? controller;  

  const CustomTextField({
    super.key,
    required this.label,
    this.hintText,
    this.isPassword = false,
    this.controller,                        
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: widget.controller,   
          obscureText: widget.isPassword ? _obscureText : false,
          obscuringCharacter: '*',

         decoration: InputDecoration(
  hintText: widget.isPassword ? "*******" : widget.hintText,
  hintStyle: const TextStyle(
    color: Colors.grey,
    fontSize: 16,
  ),

  suffixIcon: widget.isPassword
      ? IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        )
      : null,

  filled: true,
  fillColor: const Color(0xFFF7F8F9),

  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(
      color: Color(0xFFE0E0E0),
      width: 1,
    ),
  ),

  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(
      color: Color(0xFFCB30E0), 
      width: 1.5,
    ),
  ),
),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}