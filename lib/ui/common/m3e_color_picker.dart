
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class M3EColorPicker extends StatefulWidget {
  const M3EColorPicker({
    super.key,
    required this.onColorChanged,
    required this.initialColor,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  @override
  State<M3EColorPicker> createState() => _M3EColorPickerState();
}

class _M3EColorPickerState extends State<M3EColorPicker> {
  late Hct _hct;

  @override
  void initState() {
    super.initState();
    _hct = Hct.fromInt(widget.initialColor.toARGB32());
  }

  void _updateColor() {
    final color = Color(_hct.toInt());
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeIn,
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Color(_hct.toInt()),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 24),
        _buildHueSlider(),
        _buildChromaSlider(),
        _buildToneSlider(),
      ],
    );
  }

  Widget _buildHueSlider() {
    return _buildSlider(
      label: 'Hue',
      value: _hct.hue,
      max: 360,
      onChanged: (value) {
        setState(() {
          _hct = Hct.from(_hct.hue = value, _hct.chroma, _hct.tone);
          _updateColor();
        });
      },
    );
  }

  Widget _buildChromaSlider() {
    return _buildSlider(
      label: 'Chroma',
      value: _hct.chroma,
      max: 150,
      onChanged: (value) {
        setState(() {
          _hct = Hct.from(_hct.hue, _hct.chroma = value, _hct.tone);
          _updateColor();
        });
      },
    );
  }

  Widget _buildToneSlider() {
    return _buildSlider(
      label: 'Tone',
      value: _hct.tone,
      max: 100,
      onChanged: (value) {
        setState(() {
          _hct = Hct.from(_hct.hue, _hct.chroma, _hct.tone = value);
          _updateColor();
        });
      },
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: value,
          min: 0,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
