import 'package:flutter/material.dart';

import '../admin.dart';
import '../ui.dart';

/// الرئيسية: قائمة المراجعة، كل الإعلانات المنشورة، والمحظورون
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final top = MediaQuery.of(context).padding.top;
        Widget body;
        if (!app.loaded) {
          body = const Center(child: CircularProgressIndicator());
        } else if (tab == 0) {
          body = app.review.isEmpty
              ? const EmptyState(icon: Icons.verified_rounded, title: 'لا شيء ينتظر المراجعة', text: 'الإعلانات المبلَّغ عنها أو المشبوهة تظهر هنا.')
              : _list(app.review);
        } else if (tab == 1) {
          body = app.live.isEmpty ? const EmptyState(icon: Icons.storefront_outlined, title: 'لا إعلانات منشورة بعد') : _list(app.live);
        } else {
          body = app.bans.isEmpty
              ? const EmptyState(icon: Icons.person_off_outlined, title: 'لا أحد محظور')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: app.bans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final b = app.bans[i];
                    return Box(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${b['name'] ?? ''}'.isEmpty ? 'بلا اسم' : '${b['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${b['reason'] ?? ''}، ${ago(asInt(b['at']))}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                            if ('${b['title'] ?? ''}'.isNotEmpty)
                              Text('بسبب: ${b['title']}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                          ]),
                        ),
                        TextButton(onPressed: () => app.unban('${b['id']}'), child: const Text('رفع الحظر')),
                      ]),
                    );
                  },
                );
        }
        return Scaffold(
          body: Column(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: brand)),
                const Zellige(opacity: 0.1),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, top + 12, 8, 18),
                  child: Row(children: [
                    const StarBadge(size: 46, color: star, child: Icon(Icons.shield_rounded, color: ink, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('إدارة السوق', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 24)),
                        Text(
                          app.review.isEmpty ? 'كل شيء نظيف' : '${app.review.length} ينتظر المراجعة',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'الخروج',
                      color: Colors.white,
                      onPressed: () async {
                        if (await confirm(context, 'الخروج؟', 'تحتاج البريد وكلمة السر للدخول مرة أخرى.', 'خروج')) app.logout();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ]),
                ),
              ]),
            ),
            Expanded(child: body),
          ]),
          bottomNavigationBar: BottomBar(
            index: tab,
            onTap: (i) => setState(() => tab = i),
            items: [
              BarItem(Icons.flag_outlined, Icons.flag_rounded, 'المراجعة', badge: app.review.isEmpty ? null : '${app.review.length}'),
              BarItem(Icons.sell_outlined, Icons.sell_rounded, 'المنشورة (${app.live.length})'),
              const BarItem(Icons.person_off_outlined, Icons.person_off_rounded, 'المحظورون'),
            ],
          ),
        );
      },
    );
  }

  Widget _list(List<Doc> l) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => ListingCard(l: l[i], key: ValueKey(l[i]['id'])),
      );
}

/// بطاقة إعلان للمراجعة: الصور، التفاصيل، سبب الإخفاء، البلاغات، والقرار
class ListingCard extends StatefulWidget {
  final Doc l;
  const ListingCard({super.key, required this.l});
  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  List<Doc>? reports;
  bool busy = false;

  Future<void> _loadReports() async {
    try {
      final r = await app.reportsOf('${widget.l['id']}');
      if (mounted) setState(() => reports = r);
    } catch (e) {
      app.toast(errText(e));
    }
  }

  Future<void> _act(Future<void> Function() f) async {
    setState(() => busy = true);
    await f();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _ban() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('سبب حظر البائع', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontSize: 19)),
          ),
          for (final r in const ['احتيال', 'بيع ممنوعات', 'محتوى غير لائق', 'إزعاج متكرر'])
            ListTile(title: Text(r), onTap: () => Navigator.pop(c, r)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (reason == null || !mounted) return;
    if (await confirm(context, 'حظر ${widget.l['name'] ?? 'البائع'}؟', 'لن يستطيع النشر في السوق، وتُحذف كل إعلاناته المنشورة.', 'احظر')) {
      _act(() => app.ban(widget.l, reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final hint = Theme.of(context).hintColor;
    final n = asInt(l['imgN']);
    final inReview = l['status'] == 'review';
    final ai = l['ai'] is Map ? l['ai'] as Map : null; // رأي الذكاء الاصطناعي (عند تفعيله على الخادم)
    return Box(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (n > 0)
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: n,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final img = app.photo(l, i);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 154,
                    child: img != null
                        ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
                        : ColoredBox(color: brandSoft, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: hint))),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ('${l['flag'] ?? ''}'.isNotEmpty) ...[
              Pill('${l['flag']}', bg: harissaSoft, fg: harissaDark, icon: Icons.flag_rounded),
              const SizedBox(height: 8),
            ],
            if (ai != null) ...[
              Note('رأي الذكاء الاصطناعي: ${ai['verdict'] ?? ''}${'${ai['reason'] ?? ''}'.isEmpty ? '' : '، ${ai['reason']}'}',
                  color: ink, icon: Icons.auto_awesome_rounded),
              const SizedBox(height: 8),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text('${l['title'] ?? ''}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18))),
              Text(money(asInt(l['price'])), style: TextStyle(fontWeight: FontWeight.w800, color: accentOf(context))),
            ]),
            if ('${l['desc'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${l['desc']}', style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _meta(Icons.person_outline_rounded, '${l['name'] ?? ''}${app.isBanned(l['uid']) ? ' (محظور)' : ''}'),
              _meta(Icons.place_outlined, '${l['zoneName'] ?? ''}'),
              _meta(Icons.schedule_rounded, ago(asInt(l['at']))),
              if (asInt(l['reports']) > 0) _meta(Icons.flag_outlined, '${asInt(l['reports'])} بلاغات'),
            ]),
            if (asInt(l['reports']) > 0) ...[
              const SizedBox(height: 6),
              if (reports == null)
                TextButton.icon(onPressed: _loadReports, icon: const Icon(Icons.expand_more_rounded), label: const Text('اعرض البلاغات'))
              else
                for (final r in reports!)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${r['reason'] ?? ''}، ${ago(asInt(r['at']))}', style: TextStyle(color: hint, fontSize: 13)),
                  ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (inReview) ...[
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: tea, minimumSize: const Size(0, 48)),
                    onPressed: busy ? null : () => _act(() => app.restore(l)),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('أرجعه'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: harissaDark, minimumSize: const Size(0, 48)),
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(context, 'حذف الإعلان؟', 'يُحذف الإعلان وصوره نهائياً.', 'احذف')) _act(() => app.remove(l));
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('احذف'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'احظر البائع',
                onPressed: busy || app.isBanned(l['uid']) ? null : _ban,
                icon: const Icon(Icons.person_off_outlined, color: harissaDark),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _meta(IconData icon, String t) {
    final c = Theme.of(context).hintColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: c),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 13, color: c)),
    ]);
  }
}
