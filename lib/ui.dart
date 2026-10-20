import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


// ألوان «سوق الحي». لون تطبيق المحل نعناع الشاي، والهريسة للطلبات الجديدة والعاجلة
// تطبيق الإدارة: الأزرار والرأس بالنيلي، والأخضر للإرجاع، والهريسة للحذف والحظر
const brand = Color(0xFF1E2A4A);
const brandDark = Color(0xFF141C33);
const brandSoft = Color(0xFFE5E9F3);
const tea = Color(0xFF0F7B5F);
const teaSoft = Color(0xFFE1F1EA);
const teaDark = Color(0xFF0A5A43);
const harissa = Color(0xFFC2410C); // طلب جديد، تأخير
const harissaDark = Color(0xFF9A3412);
const harissaSoft = Color(0xFFFBE3D6);
const ink = Color(0xFF1E2A4A); // النيلي: النصوص والأزرار الثانوية
const inkSoft = Color(0xFFE5E9F3);
const star = Color(0xFFF2A516); // الزعفران: التقييم والعروض (نصه نيلي)
const saffronSoft = Color(0xFFFDF0D5);
const saffronText = Color(0xFF7A4A12);
const paper = Color(0xFFF6F7F9);
const muted = Color(0xFF5B6474);
const hairline = Color(0xFFDDE1E8);
const warn = Color(0xFFB45309);

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// لون النصوص المميزة (أفتح في الوضع الداكن حتى يبقى مقروءاً)
Color accentOf(BuildContext context) => Theme.of(context).colorScheme.primary;

List<BoxShadow> softShadow(BuildContext context) =>
    isDark(context) ? const [] : const [BoxShadow(color: Color(0xFFE3E7ED), offset: Offset(0, 1))];

/// نقش الزليج: مربعان متقاطعان ونقطة في كل خلية
class ZelligePainter extends CustomPainter {
  final Color color;
  const ZelligePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 46.0, half = 12.0;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final dot = Paint()..color = color;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        canvas.drawRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2), line);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.785398);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2), line);
        canvas.restore();
        canvas.drawCircle(c, 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(ZelligePainter old) => old.color != color;
}

/// طبقة النقش تملأ ما تحتها ولا تلتقط اللمس (داخل Stack)
class Zellige extends StatelessWidget {
  final double opacity;
  const Zellige({super.key, this.opacity = 0.13});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: ClipRect(child: CustomPaint(painter: ZelligePainter(Colors.white.withValues(alpha: opacity)))),
        ),
      );
}

/// نجمة الزليج الثمانية
class StarClipper extends CustomClipper<Path> {
  const StarClipper();
  static const _pts = [
    [0.5, 0.0], [0.343, 0.121], [0.146, 0.146], [0.121, 0.343], //
    [0.0, 0.5], [0.121, 0.657], [0.146, 0.854], [0.343, 0.879],
    [0.5, 1.0], [0.657, 0.879], [0.854, 0.854], [0.879, 0.657],
    [1.0, 0.5], [0.879, 0.343], [0.854, 0.146], [0.657, 0.121],
  ];

  @override
  Path getClip(Size s) {
    final p = Path()..moveTo(_pts[0][0] * s.width, _pts[0][1] * s.height);
    for (final q in _pts.skip(1)) {
      p.lineTo(q[0] * s.width, q[1] * s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(StarClipper old) => false;
}

class StarBadge extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;
  const StarBadge({super.key, this.size = 58, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: const StarClipper(),
        child: Container(width: size, height: size, color: color, alignment: Alignment.center, child: child),
      );
}

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.border, this.onTap});

  // Material بدل Container ملوّن حتى تظهر لمسات ListTile داخل البطاقة
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    final inner = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: color == null ? softShadow(context) : null),
      child: Material(
        color: color ?? Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: r, side: border?.top ?? BorderSide.none),
        child: onTap == null ? inner : InkWell(borderRadius: r, onTap: onTap, child: inner),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.bg = const Color(0xFFF1F3F6), this.fg = ink, this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: dark ? fg.withValues(alpha: 0.28) : bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: dark ? Colors.white70 : fg), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dark ? Colors.white : fg))),
      ]),
    );
  }
}


class Line extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const Line(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: bold ? null : Theme.of(context).hintColor, fontWeight: bold ? FontWeight.w700 : null)),
          ),
          Text(value,
              style: bold
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: color)
                  : TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
        ]),
      );
}

class Note extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const Note(this.text, {super.key, this.color = ink, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: isDark(context) ? 0.22 : 0.10), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: isDark(context) ? Colors.white70 : color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const EmptyState({super.key, required this.icon, required this.title, this.text = ''});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StarBadge(
            size: 72,
            color: isDark(context) ? brand.withValues(alpha: 0.3) : brandSoft,
            child: Icon(icon, size: 30, color: isDark(context) ? Colors.white : brandDark),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
          ],
        ]),
      );
}

Future<void> callPhone(String p) async {
  if (p.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: p));
}

Future<void> openMaps(double lat, double lng) async {
  final u = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

Future<bool> confirm(BuildContext context, String title, String body, String ok) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

class BarItem {
  final IconData icon, active;
  final String label;
  final String? badge;
  const BarItem(this.icon, this.active, this.label, {this.badge});
}

/// شريط سفلي أبيض بخط علوي رفيع: التبويب المختار بلون التطبيق وأيقونته ممتلئة
class BottomBar extends StatelessWidget {
  final int index;
  final List<BarItem> items;
  final ValueChanged<int> onTap;
  const BottomBar({super.key, required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final accent = accentOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(children: [
            for (int k = 0; k < items.length; k++)
              Expanded(
                child: Semantics(
                  selected: k == index,
                  button: true,
                  label: items[k].label,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => onTap(k),
                    radius: 36,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Badge(
                        isLabelVisible: items[k].badge != null,
                        backgroundColor: harissa,
                        label: Text(items[k].badge ?? ''),
                        child: Icon(k == index ? items[k].active : items[k].icon, color: k == index ? accent : hint, size: 25),
                      ),
                      const SizedBox(height: 4),
                      Text(items[k].label,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12, fontWeight: k == index ? FontWeight.w700 : FontWeight.w500, color: k == index ? accent : hint)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
