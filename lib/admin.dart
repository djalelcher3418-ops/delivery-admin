// Delivery — تطبيق الإدارة: مراجعة إعلانات السوق والبلاغات والحظر
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef Doc = Map<String, dynamic>;

final AdminState app = AdminState();

int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
int nowMs() => DateTime.now().millisecondsSinceEpoch;

String fmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' '); // مسافة ضيقة لا تكسر الرقم في النص العربي
    b.write(s[i]);
  }
  return b.toString();
}

String money(num n) => '${fmt(n)} دج';

String ago(int ms) {
  final m = ((nowMs() - ms) / 60000).floor();
  if (m < 1) return 'الآن';
  if (m < 60) return 'منذ $m د';
  final h = (m / 60).floor();
  if (h < 24) return 'منذ $h سا';
  final d = (h / 24).floor();
  return d == 1 ? 'منذ يوم' : 'منذ $d أيام';
}

String errText(Object e) {
  final code = e is FirebaseException ? e.code : '';
  const m = {
    'permission-denied': 'ليست لديك صلاحية. تأكد من نشر قواعد الحماية الجديدة في Firestore.',
    'invalid-credential': 'البريد أو كلمة السر غير صحيحة.',
    'wrong-password': 'كلمة السر غير صحيحة.',
    'user-not-found': 'لا يوجد حساب بهذا البريد.',
    'invalid-email': 'البريد غير صحيح.',
    'too-many-requests': 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.',
    'network-request-failed': 'لا يوجد اتصال بالإنترنت.',
    'unavailable': 'لا يوجد اتصال بالخادم الآن.',
  };
  return m[code] ?? 'حدث خطأ غير متوقع (${code.isEmpty ? e : code}).';
}

class AdminState extends ChangeNotifier {
  late final auth = FirebaseAuth.instance;
  late final fs = FirebaseFirestore.instance;

  bool ready = false;
  User? user;
  String role = ''; // '' | checking | admin | denied | error

  List<Doc> review = [], live = [], bans = [];
  bool loaded = false;
  final List<StreamSubscription> _subs = [];
  final Map<String, Uint8List?> _img = {};
  final Set<String> _imgLoading = {};
  void Function(String msg)? onToast;

  void toast(String m) => onToast?.call(m);

  Future<void> init() async {
    auth.authStateChanges().listen(_onUser);
  }

  Future<void> _onUser(User? u) async {
    _stop();
    user = u;
    ready = true;
    role = '';
    if (u == null) {
      notifyListeners();
      return;
    }
    role = 'checking';
    notifyListeners();
    try {
      final d = (await fs.collection('users').doc(u.uid).get()).data();
      role = d?['role'] == 'admin' ? 'admin' : 'denied';
    } catch (_) {
      role = 'error';
    }
    if (role == 'admin') _start();
    notifyListeners();
  }

  List<Doc> _docs(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

  void _start() {
    _subs.add(fs.collection('listings').where('status', isEqualTo: 'review').snapshots().listen((s) {
      review = _docs(s)..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
      loaded = true;
      notifyListeners();
    }, onError: (e) => toast(errText(e))));
    _subs.add(fs.collection('listings').where('status', isEqualTo: 'live').snapshots().listen((s) {
      live = _docs(s)..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('bans').snapshots().listen((s) {
      bans = _docs(s)..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
      notifyListeners();
    }, onError: (_) {}));
  }

  void _stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    review = [];
    live = [];
    bans = [];
    loaded = false;
  }

  Future<String> login(String email, String pass) async {
    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: pass);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  Future<void> logout() => auth.signOut();

  // ---------------- الصور ----------------
  Uint8List? photo(Doc l, int i) {
    if (i >= asInt(l['imgN'])) return null;
    final key = '${l['id']}_$i';
    if (_img.containsKey(key)) return _img[key];
    if (_imgLoading.add(key)) {
      fs.collection('listingImages').doc(key).get().then((s) {
        final d = s.data()?['data'];
        Uint8List? b;
        if (d is String && d.contains(',')) {
          try {
            b = base64Decode(d.substring(d.indexOf(',') + 1));
          } catch (_) {}
        }
        _img[key] = b;
        notifyListeners();
      }).catchError((_) {
        _imgLoading.remove(key);
      });
    }
    return null;
  }

  Future<List<Doc>> reportsOf(String listingId) async {
    final s = await fs.collection('reports').where('listingId', isEqualTo: listingId).get();
    return _docs(s)..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
  }

  bool isBanned(String? uid) => bans.any((b) => b['id'] == uid);

  // ---------------- القرارات ----------------
  Future<void> _run(Future<void> Function() f, String ok) async {
    try {
      await f();
      toast(ok);
    } catch (e) {
      toast(errText(e));
    }
  }

  /// الإعلان سليم: يرجع للسوق وتُمسح بلاغاته
  Future<void> restore(Doc l) => _run(
      () => fs.collection('listings').doc(l['id']).update({
            'status': 'live',
            'reports': 0,
            'reporters': <String>[],
            'flag': FieldValue.delete(),
            'reviewedAt': nowMs(),
            'reviewedBy': user?.uid,
          }),
      'رجع الإعلان إلى السوق');

  /// حذف الإعلان وصوره
  Future<void> remove(Doc l, {String reason = ''}) => _run(() async {
        final b = fs.batch();
        b.update(fs.collection('listings').doc(l['id']), {
          'status': 'removed',
          'removedReason': reason,
          'reviewedAt': nowMs(),
          'reviewedBy': user?.uid,
        });
        for (int i = 0; i < asInt(l['imgN']); i++) {
          b.delete(fs.collection('listingImages').doc('${l['id']}_$i'));
        }
        await b.commit();
      }, 'حُذف الإعلان');

  /// حظر البائع من النشر وحذف كل إعلاناته المنشورة
  Future<void> ban(Doc l, String reason) => _run(() async {
        final uid = '${l['uid']}';
        final mine = await fs.collection('listings').where('uid', isEqualTo: uid).get();
        final b = fs.batch();
        b.set(fs.collection('bans').doc(uid), {'name': l['name'] ?? '', 'reason': reason, 'title': l['title'] ?? '', 'at': nowMs(), 'by': user?.uid});
        for (final d in mine.docs) {
          if (d.data()['status'] != 'removed') b.update(d.reference, {'status': 'removed', 'removedReason': 'حظر البائع'});
        }
        await b.commit();
      }, 'حُظر البائع وحُذفت إعلاناته');

  Future<void> unban(String uid) => _run(() => fs.collection('bans').doc(uid).delete(), 'رُفع الحظر');
}
