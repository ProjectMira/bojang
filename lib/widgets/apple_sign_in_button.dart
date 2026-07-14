import 'package:flutter/material.dart';

/// "Sign in with Apple" button following Apple's Human Interface Guidelines:
/// solid black in light mode, white in dark mode, Apple logo, and the
/// platform's system font (San Francisco on iOS).
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const AppleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Apple',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? Colors.white : Colors.black;
    final foreground = isDark ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: background,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foreground),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(Icons.apple, size: 26, color: foreground),
                  const SizedBox(width: 10),
                ],
                Text(
                  isLoading ? 'Signing in...' : text,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
