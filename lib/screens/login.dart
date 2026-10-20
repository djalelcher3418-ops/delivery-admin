import 'package:flutter/material.dart';

import '../admin.dart';
import '../ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;
  String err = '';

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = '';
    });
    final e = await app.login(email.text, pass.text);
    if (mounted) {
      setState(() {
        busy = false;
        err = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final denied = app.role == 'denied' || app.role == 'error';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 168,
              child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: brand)),
                const Zellige(opacity: 0.1),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const StarBadge(size: 76, color: star, child: Icon(Icons.shield_rounded, size: 36, color: ink)),
                    const SizedBox(height: 10),
                    Text('Delivery', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 24, height: 1.1)),
                    const Text('تطبيق الإدارة', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          if (denied) ...[
            Note(
              app.role == 'denied'
                  ? 'هذا الحساب ليس حساب إدارة. في Firestore افتح users/${app.user?.uid ?? ''} وأضف الحقل role بالقيمة admin.'
                  : 'تعذّر التحقق من الحساب. تحقق من الإنترنت.',
              color: harissa,
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 10),
            if (app.user?.uid != null) SelectableText('رقم حسابك: ${app.user!.uid}', style: TextStyle(color: hint, fontSize: 13)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: app.logout, child: const Text('خروج والدخول بحساب آخر')),
          ] else ...[
            Text('دخول المدير', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('بريد حساب الإدارة وكلمة سره.', style: TextStyle(color: hint)),
            const SizedBox(height: 18),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'البريد', prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: hide,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _go(),
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: hide ? 'إظهار' : 'إخفاء',
                  onPressed: () => setState(() => hide = !hide),
                  icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
            ),
            if (err.isNotEmpty) ...[const SizedBox(height: 12), Note(err, color: harissa, icon: Icons.error_outline_rounded)],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: busy ? null : _go,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('دخول'),
            ),
          ],
        ]),
      ),
    );
  }
}
