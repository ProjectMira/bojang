import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  _buildGoogleIcon(),
                  const SizedBox(width: 12),
                ],
                Text(
                  isLoading ? 'Signing in...' : text,
                  style: GoogleFonts.kalam(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    // Google logo SVG representation as a custom painted widget
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Google "G" colors
    final blueColor = const Color(0xFF4285F4);
    final greenColor = const Color(0xFF34A853);
    final yellowColor = const Color(0xFFFBBC05);
    final redColor = const Color(0xFFEA4335);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the Google "G" shape
    // Blue section (top-right)
    paint.color = blueColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * 3.14159 / 180, // -90 degrees in radians
      90 * 3.14159 / 180,  // 90 degrees in radians
      true,
      paint,
    );

    // Green section (bottom-right)
    paint.color = greenColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0 * 3.14159 / 180,   // 0 degrees in radians
      90 * 3.14159 / 180,  // 90 degrees in radians
      true,
      paint,
    );

    // Yellow section (bottom-left)
    paint.color = yellowColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      90 * 3.14159 / 180,  // 90 degrees in radians
      90 * 3.14159 / 180,  // 90 degrees in radians
      true,
      paint,
    );

    // Red section (top-left)
    paint.color = redColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      180 * 3.14159 / 180, // 180 degrees in radians
      90 * 3.14159 / 180,  // 90 degrees in radians
      true,
      paint,
    );

    // Draw inner white circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, paint);

    // Draw the "G" shape
    paint.color = const Color(0xFF4285F4);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.6,
      height: size.height * 0.6,
    );
    
    final path = Path();
    path.addRect(Rect.fromLTWH(
      center.dx, 
      center.dy - size.height * 0.15, 
      size.width * 0.3, 
      size.height * 0.1,
    ));
    
    path.addRect(Rect.fromLTWH(
      center.dx + size.width * 0.1, 
      center.dy - size.height * 0.05, 
      size.width * 0.2, 
      size.height * 0.1,
    ));
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
