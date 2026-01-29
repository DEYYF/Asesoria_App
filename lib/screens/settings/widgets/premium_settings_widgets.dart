import 'package:flutter/material.dart';

class PremiumCategory extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;

  const PremiumCategory({
    super.key,
    required this.title,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Colors.purple.shade400;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: themeColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: themeColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;
  final Color? activeColor;

  const PremiumToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile.adaptive(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: activeColor ?? Colors.purple.shade400,
      ),
    );
  }
}

class PremiumSlider extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final bool isInteger;
  final Color? color;

  const PremiumSlider({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.isInteger = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    double val = (value is int) ? value.toDouble() : (value ?? min);
    if (val < min) val = min;
    if (val > max) val = max;
    final themeColor = color ?? Colors.purple.shade400;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                isInteger ? val.toInt().toString() : val.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: themeColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: val,
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: themeColor,
              inactiveColor: themeColor.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumTextField extends StatelessWidget {
  final String label;
  final String hint;
  final Map<String, dynamic> data;
  final String field;
  final IconData icon;

  const PremiumTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.data,
    required this.field,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: data[field] ?? '',
        onChanged: (v) => data[field] = v,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class PremiumDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String) onChanged;

  const PremiumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : options.first,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(
                  o.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}

class PremiumColorTile extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;
  final String field;
  final Color defaultColor;
  final Function(void Function()) setDialogState;

  const PremiumColorTile({
    super.key,
    required this.label,
    required this.data,
    required this.field,
    required this.defaultColor,
    required this.setDialogState,
  });

  @override
  Widget build(BuildContext context) {
    final hexCode = data[field] ?? '';
    Color currentColor = defaultColor;
    if (hexCode.isNotEmpty) {
      try {
        currentColor = Color(int.parse(hexCode.replaceFirst('#', '0xFF')));
      } catch (e) {
        currentColor = defaultColor;
      }
    }

    return InkWell(
      onTap: () {
        // Implement color picker if needed, for now just toggle common colors or placeholder
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hexCode.isEmpty ? 'Por defecto' : hexCode,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
