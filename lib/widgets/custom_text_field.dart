import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  
  const CustomTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
  });
  
  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _isObscured;
  
  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              widget.labelText!,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _isObscured,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            validator: widget.validator,
            style: TextStyle(
              fontSize: 16,
              color: widget.enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 16,
              ),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  )
                : widget.suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

