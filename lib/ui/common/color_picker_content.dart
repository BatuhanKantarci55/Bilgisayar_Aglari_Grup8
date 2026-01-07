import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme; // Import theme.dart

class ColorPickerContent extends StatelessWidget {
  const ColorPickerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose a Seed Color',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          ColorWheel(
            pickerColor: Theme.of(context).colorScheme.primary, // Initial color
            onColorChanged: (color) {
              app_theme.seedColorNotifier.value = color; // Update seed color
              // Navigator.of(context).pop(color); // Return the selected color
            },
          ),
          const SizedBox(height: 20), // Add some spacing
          ValueListenableBuilder<ThemeMode>(
            valueListenable: app_theme.themeModeNotifier,
            builder: (context, themeMode, child) {
              return SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.wb_sunny),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.mode_night),
                  ),
                ],
                selected: <ThemeMode>{themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  app_theme.themeModeNotifier.value = newSelection.first;
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// A color wheel picker
class ColorWheel extends StatefulWidget {
  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;

  const ColorWheel({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
  });

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.pickerColor;
  }

  void _updateColor(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final radius = size.width / 2;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= radius) {
      double hue = (math.atan2(dy, dx) * 180 / math.pi);
      if (hue < 0) hue += 360;

      double saturation = distance / radius;
      if (saturation > 1) saturation = 1;

      final color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();

      setState(() {
        _currentColor = color;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        _updateColor(box.globalToLocal(details.globalPosition), box.size);
      },
      onPanEnd: (details) {
        widget.onColorChanged(_currentColor);
      },
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        _updateColor(box.globalToLocal(details.globalPosition), box.size);
        widget.onColorChanged(_currentColor);
      },
      child: CustomPaint(size: const Size(250, 250), painter: _WheelPainter()),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepGradient = SweepGradient(
      colors: const [
        Colors.red,
        Colors.yellow,
        Colors.green,
        Colors.cyan,
        Colors.blue,
        Color(0xFFFF00FF),
        Colors.red,
      ],
    );

    final radialGradient = RadialGradient(
      colors: const [Colors.white, Colors.transparent],
    );

    final paint = Paint()..shader = sweepGradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);

    final paintRadial = Paint()..shader = radialGradient.createShader(rect);
    canvas.drawCircle(center, radius, paintRadial);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}