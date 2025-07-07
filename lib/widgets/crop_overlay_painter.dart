import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CropOverlayPainter extends CustomPainter {
  final List<Offset> points;
  CropOverlayPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;

    // Vẽ vùng tối bên ngoài vùng crop
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    final cropPath =
        Path()
          ..moveTo(points[0].dx, points[0].dy)
          ..lineTo(points[1].dx, points[1].dy)
          ..lineTo(points[2].dx, points[2].dy)
          ..lineTo(points[3].dx, points[3].dy)
          ..close();

    // Vẽ vùng tối bên ngoài
    path.fillType = PathFillType.evenOdd;
    path.addPath(cropPath, Offset.zero);

    // Vẽ đường viền của vùng cắt
    final paint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 3.w
          ..style = PaintingStyle.stroke;
    canvas.drawPath(cropPath, paint);

    // Vẽ điểm góc
    for (final p in points) {
      // Vẽ viền ngoài
      canvas.drawCircle(
        p,
        13.r,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      // Vẽ điểm trắng ở giữa
      canvas.drawCircle(p, 8.r, Paint()..color = Colors.white);

      // Vẽ viền xanh
      canvas.drawCircle(
        p,
        10.r,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.w,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
