import 'package:flutter/material.dart';

class AnimatedInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String labelText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const AnimatedInputField({
    super.key,
    this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.onTap,
    this.suffixIcon,
  });

  @override
  State<AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<AnimatedInputField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        onFocusChange: (focus) {
          setState(() {
            _isFocused = focus;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isFocused
                ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            onSaved: widget.onSaved,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              labelText: widget.labelText,
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.7),
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                color: _isFocused
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withOpacity(0.7),
              ),
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}