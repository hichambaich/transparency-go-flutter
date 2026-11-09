import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'launcher/open_url_stub.dart'
    if (dart.library.io) 'launcher/open_url_io.dart'
    if (dart.library.html) 'launcher/open_url_web.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppTranslations.load();
    final prefs = await SharedPreferences.getInstance();
    languageNotifier.value = prefs.getString('app_language') ?? 'en';
  } catch (e, stacktrace) {
    debugPrint("Startup Error: $e\n$stacktrace");
  }
  runApp(const MyApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

final ValueNotifier<String> languageNotifier = ValueNotifier('en');

class AppTranslations {
  static Map<String, dynamic> _en = {};
  static Map<String, dynamic> _ar = {};
  static Map<String, dynamic> _fr = {};

  static Future<void> load() async {
    try {
      final enStr = await rootBundle.loadString('assets/translations/en.json');
      final arStr = await rootBundle.loadString('assets/translations/ar.json');
      final frStr = await rootBundle.loadString('assets/translations/fr.json');
      _en = jsonDecode(enStr);
      _ar = jsonDecode(arStr);
      _fr = jsonDecode(frStr);
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading translations: $e");
    }
  }

  static String t(String key) {
    final lang = languageNotifier.value;
    final map = lang == 'ar' ? _ar : (lang == 'fr' ? _fr : _en);
    final parts = key.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return key; // Fallback to key
      }
    }
    if (current is Map) {
      return (current['other'] ?? key).toString();
    }
    return current.toString();
  }

  static String _pluralForm(num count, String lang) {
    final n = count.abs();
    if (lang == 'ar') {
      if (n == 0) return 'zero';
      if (n == 1) return 'one';
      if (n == 2) return 'two';
      final rem = n % 100;
      if (rem >= 3 && rem <= 10) return 'few';
      if (rem >= 11 && rem <= 99) return 'many';
      return 'other';
    } else if (lang == 'fr') {
      return n == 0 || n == 1 ? 'one' : 'other';
    } else {
      return n == 1 ? 'one' : 'other';
    }
  }

  static String plural(String key, num count) {
    final lang = languageNotifier.value;
    final map = lang == 'ar' ? _ar : (lang == 'fr' ? _fr : _en);
    final parts = key.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return key;
      }
    }
    if (current is! Map) return key;
    final form = _pluralForm(count, lang);
    return (current[form] ?? current['other'] ?? key).toString();
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, child) {
            return MaterialApp(
              key: ValueKey(currentLang),
              locale: Locale(currentLang),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('ar'),
                Locale('fr'),
              ],
              title: 'SMARTWALLET',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              builder: (context, child) {
                return Directionality(
                  textDirection: currentLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: child!,
                );
              },
              theme: ThemeData.light().copyWith(
                scaffoldBackgroundColor: const Color(0xFFf8fafc),
                cardColor: const Color(0xFFffffff),
                dividerColor: const Color(0xFFe2e8f0),
                primaryColor: const Color(0xFF0891b2),
                textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: const Color(0xFF0f172a),
                  displayColor: const Color(0xFF0f172a),
                ),
              ),
              darkTheme: ThemeData.dark().copyWith(
                scaffoldBackgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                cardColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white),
                dividerColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)),
                primaryColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)),
                textTheme: ThemeData.dark().textTheme.apply(
                  bodyColor: const Color(0xFFe2e8f0),
                  displayColor: const Color(0xFFe2e8f0),
                ),
              ),
              home: const AuthGateWithSplash(),
            );
          },
        );
      },
    );
  }
}


// ============================================================
// TODO: Known i18n limitations (documented, not silently ignored)
// ============================================================
// 1. Pluralization: misc.trades_unit = "صفقات" fails for 1, 2, 11-99
//    (e.g. "1 صفقات" should be "1 صفقة")
//    Fix: implement proper plural rules via intl package.
//
// 2. Remaining audit hits (deferred, low priority):
//    - L2846 'Trade $sym' (AppBar title, mixed)
//    - L597  'ROI ${formatPct(roi)}' (ROI is technical, may not need)
//    - L830  'July' (month name, needs Intl.DateTimeFormat)
//    - L3037 'No' (context-dependent, may be RouteSettings)
//
// 3. `_meta.name` was replaced by 'English' as hardcoded string
//    (matching Flet's exact behavior - language names not translated).
// ============================================================

// TODO (2026-10-26): Period picker labels (1H/1D/...) not translating in AR.
// Root cause suspected: AppTranslations.load() caches _ar at startup; JSON updates
// require full app restart AND cache bypass, which is fragile on mobile.
// Workaround for now: keep English labels (1H, 1D, ...) in AR — acceptable UX.
// Proper fix (deferred): pass explicit label list from a FutureBuilder, or
//   add languageNotifier listener to reload translations on change.

// ================= AUTH GATE =================

bool _splashShownOnce = false;

// ================= SPLASH SCREEN =================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
      body: Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/snowflake.png', width: 140, height: 140),
              const SizedBox(height: 24),
              const Text(
                'SMARTWALLET',
                style: TextStyle(
                  color: Color(0xFF00d9ff),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'by smart solutions.py',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= AUTH GATE WITH SPLASH =================
class AuthGateWithSplash extends StatefulWidget {
  const AuthGateWithSplash({super.key});
  @override
  State<AuthGateWithSplash> createState() => _AuthGateWithSplashState();
}

class _AuthGateWithSplashState extends State<AuthGateWithSplash> {
  late bool _splashDone;

  @override
  void initState() {
    super.initState();
    if (_splashShownOnce) {
      _splashDone = true;
    } else {
      _splashDone = false;
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _splashDone = true);
          _splashShownOnce = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _splashDone ? const AuthGate() : const SplashScreen();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('auth_token');
      _checking = false;
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))));
    }
    if (_token != null) {
      return DashboardScreen(token: _token!, onLogout: _logout);
    }
    return LoginScreen(onLoginSuccess: (token) {
      setState(() => _token = token);
    });
  }
}

// ================= LOGIN SCREEN =================
class LoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _error = '';
  bool _rememberMe = true;

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token']);
        }
        widget.onLoginSuccess(data['token']);
      } else {
        setState(() => _error = data['detail'] ?? AppTranslations.t('auth.err_login_failed'));
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/snowflake.png', width: 80, height: 80),
              const SizedBox(height: 10),
              const Text('SMARTWALLET', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
              const SizedBox(height: 4),
              Text(
                'by smart solutions.py',
                style: TextStyle(
                  fontSize: 12,
                  color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF94a3b8) : const Color(0xFF475569)),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: AppTranslations.t('support.email'), border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: AppTranslations.t('auth.password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? true), activeColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))),
                    Text(AppTranslations.t('auth.remember_me'), style: const TextStyle(fontSize: 12)),
                  ]),
                ],
              ),
              if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RegisterScreen())),
                    child: Text(AppTranslations.t('auth.register_link'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= DASHBOARD SCREEN =================
class DashboardScreen extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.token, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  List<FlSpot> _rawSpots = [];
  double _chartChangePct = 0.0;
  double _chartChangeUsd = 0.0;
  List<String> _chartLabels = [];
  Timer? _pollingTimer;
  String _errorMsg = '';
  String _currentPeriod = '1d';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  final String bnbLogoUrl = "https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/bnb.png";

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchData(isPolling: true));
  }



  

  double get _minY {
    if (_rawSpots.isEmpty) return 0;
    double minVal = _rawSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxVal = _rawSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxVal - minVal < 0.0001) maxVal = minVal + 0.01;
    double pad = (maxVal - minVal) * 0.05;
    return minVal - pad;
  }

  double get _maxY {
    if (_rawSpots.isEmpty) return 1;
    double minVal = _rawSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxVal = _rawSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxVal - minVal < 0.0001) maxVal = minVal + 0.01;
    double pad = (maxVal - minVal) * 0.05;
    return maxVal + pad;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool isPolling = false}) async {
    if (!isPolling) setState(() { _isLoading = true; _errorMsg = ''; });

    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};
      final resDash = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/dashboard'), headers: headers);
      if (resDash.statusCode == 401) {
        setState(() { _errorMsg = "Session expired. Please log in again."; _isLoading = false; });
        _pollingTimer?.cancel();
        widget.onLogout();
        return;
      }
      if (resDash.statusCode == 200) {
        setState(() => _data = jsonDecode(resDash.body));
      }

      final resChart = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/trend_history?period=$_currentPeriod'), headers: headers);
      if (resChart.statusCode == 200) {
        final chartData = jsonDecode(resChart.body);
        final rawList = chartData['raw'] as List? ?? [];
        final dietzList = chartData['dietz'] as List? ?? [];
        final labelsList = chartData['labels'] as List? ?? [];

        List<FlSpot> newRaw = [];
        for (int i = 0; i < rawList.length; i++) {
          double v = double.tryParse(rawList[i][1].toString()) ?? 0.0;
          if (v > 0) newRaw.add(FlSpot(i.toDouble(), v));
        }

        List<FlSpot> newDietz = [];
        for (int i = 0; i < dietzList.length; i++) {
          double v = double.tryParse(dietzList[i][1].toString()) ?? 0.0;
          if (v > 0) newDietz.add(FlSpot(i.toDouble(), v));
        }

        setState(() {
          _rawSpots = newRaw;
          _chartLabels = labelsList.map((e) => e.toString()).toList();
          _chartChangePct = (chartData['change_pct'] as num?)?.toDouble() ?? 0.0;
          _chartChangeUsd = (chartData['change_val'] as num?)?.toDouble() ?? 0.0;
        });
      }

      if (!isPolling) setState(() => _isLoading = false);
    } catch (e) {
      if (!isPolling) setState(() { _errorMsg = 'Connection error: $e'; _isLoading = false; });
    }
  }

  String formatPct(double val) => '\u200e${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)}%';
  String formatUsd(double val) => '\u200e${val >= 0 ? '+' : ''}\$${val.toStringAsFixed(2)}';

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTranslations.t('misc.select_period'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['1h', '1d', '1w', '1mo', '1y'].map((p) {
                  final isSel = _currentPeriod == p;
                  return ChoiceChip(
                    label: Text(AppTranslations.t('misc.period_$p'), style: TextStyle(color: isSel ? Colors.black : (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                    selected: isSel, selectedColor: accent, backgroundColor: borderColor,
                    onSelected: (val) {
                      setState(() => _currentPeriod = p);
                      Navigator.pop(context);
                      _fetchData();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStatDetail(BuildContext context, String title) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => StatDetailScreen(title: title, data: _data, token: widget.token)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), body: Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))));
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(_errorMsg, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: widget.onLogout, child: Text(AppTranslations.t('auth.back_to_login'))),
            ],
          ),
        ),
      );
    }

    final cap = _data['capital'] ?? {};
    final stats = _data['stats'] ?? {};
    final risk = _data['risk'] ?? {};
    final events = _data['events'] ?? {};
    final positions = _data['positions'] as List? ?? [];

    final totalCapital = (cap['total'] ?? 0.0).toDouble();
    final freeBalance = (cap['free'] ?? 0.0).toDouble();
    final roi = (cap['roi_pct'] ?? 0.0).toDouble();
    final bnbValue = (cap['bnb_value'] ?? 0.0).toDouble();
    final refCapital = (cap['ref_capital'] ?? 0.0).toDouble();
    final closedTrades = stats['closed_trades'] ?? 0;
    final profitTrades = stats['profit_trades'] ?? 0;
    final winRate = (stats['win_rate'] ?? 0.0).toDouble();
    final realizedPnl = (stats['realized_pnl'] ?? 0.0).toDouble();
    final realizedPnlPct = (stats['realized_pnl_pct'] ?? 0.0).toDouble();
    final exposurePct = (risk['exposure_pct'] ?? 0.0).toDouble();
    // حساب المجموع مباشرة من قائمة المراكز (مطابقة لـ Flet)
    final posValue = positions.fold(0.0, (sum, p) => sum + (double.tryParse(p['value']?.toString() ?? '0') ?? 0.0));
    final netEvents = (events['net'] ?? 0.0).toDouble();
    final deposits = (events['deposits'] ?? 0.0).toDouble();
    final withdrawals = (events['withdrawals'] ?? 0.0).toDouble();

    Color expColor = exposurePct >= 65 ? red : (exposurePct >= 50 ? Colors.orange : green);
    int expInt = exposurePct.toInt().clamp(1, 99);
    if (_rawSpots.length >= 2) {
      double pastVal = _rawSpots.first.y;
      double currentVal = _rawSpots.last.y;
      if (pastVal != 0) {
        _chartChangeUsd = currentVal - pastVal;
        _chartChangePct = (_chartChangeUsd / pastVal) * 100;
      }
    }
    Color trendColor = _chartChangePct != 0 ? (_chartChangePct >= 0 ? green : red) : (roi >= 0 ? green : red);

    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Image.asset('assets/images/snowflake.png', width: 28, height: 28),
                        const Text('SMARTWALLET', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _fetchData(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
                          child: Icon(Icons.refresh, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), size: 13),
                        ),
                      ),
                      const SizedBox(width: 7),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => MenuScreen(onLogout: widget.onLogout, userId: _data['user_id']?.toString() ?? ''))).then((_) => _fetchData()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
                          child: Row(
                            children: [
                              Icon(Icons.menu, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), size: 13),
                              const SizedBox(width: 3),
                              Text(AppTranslations.t('menu.title'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
                children: [
                  // ============ MAIN WRAPPER CARD ============
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF0d141e) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        // Exchange Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppTranslations.t('dash.exchange_balances'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                            Row(
                              children: [
                                Text(AppTranslations.t('dash.performance'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _showPeriodPicker,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sync, size: 11, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                                        const SizedBox(width: 4),
                                        Text(_currentPeriod.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: trendColor)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => StatsScreen(token: widget.token))),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.insights, size: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                                        const SizedBox(width: 4),
                                        Text(AppTranslations.t('dash.stats'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Two-column body
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => _openStatDetail(context, AppTranslations.t('stat.capital')),
                                    child: Row(children: [
                                      Text(AppTranslations.t('dash.total_capital'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      const SizedBox(width: 6),
                                      Text(textDirection: TextDirection.ltr, 'ROI ${formatPct(roi)}', style: TextStyle(fontSize: 10, color: roi >= 0 ? green : red, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.chevron_right, size: 12, color: Colors.grey),
                                    ]),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(textDirection: TextDirection.ltr, '${totalCapital.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Image(
                                        image: const NetworkImage('https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdt.png'),
                                        errorBuilder: (c, o, s) => const Icon(Icons.circle, color: Color(0xFF26A17B), size: 18),
                                      ),
                                    ),
                                      const SizedBox(width: 4),
                                      const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('USDT', style: TextStyle(color: Color(0xFF10b981), fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Tether US', style: TextStyle(color: Colors.grey, fontSize: 7)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Image(
                                        image: NetworkImage(bnbLogoUrl),
                                        errorBuilder: (c, o, s) => const Icon(Icons.circle, color: Color(0xFFf0b90b), size: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Binance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFf0b90b))),
                                  ]),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Text('Balance ', style: TextStyle(fontSize: 11, color: Color(0xFFf0b90b), fontWeight: FontWeight.bold)),
                                      Text(textDirection: TextDirection.ltr, '\$${freeBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(textDirection: TextDirection.ltr, formatPct(_chartChangePct), style: TextStyle(fontSize: 12, color: trendColor, fontWeight: FontWeight.bold)),
                                  Text(textDirection: TextDirection.ltr, formatUsd(_chartChangeUsd), style: TextStyle(fontSize: 10, color: trendColor)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 50,
                                    child: _rawSpots.isEmpty
                                        ? Center(child: Text(AppTranslations.t('misc.loading'), style: const TextStyle(color: Colors.grey, fontSize: 10)))
                                        : Stack(
                                            children: [
                                              Positioned.fill(top: 25, child: CustomPaint(painter: DashedLinePainter(color: Colors.grey.withOpacity(0.4)))),
                                              LineChart(
                                                LineChartData(
                                                  clipData: const FlClipData.all(),
                                                  gridData: const FlGridData(show: false),
                                                  titlesData: const FlTitlesData(show: false),
                                                  borderData: FlBorderData(show: false),
                                                  minX: 0,
                                                  maxX: (_rawSpots.length - 1).toDouble() > 0 ? (_rawSpots.length - 1).toDouble() : 1,
                                                  minY: _minY,
                                                  maxY: _maxY,
                                                  lineBarsData: [
                                                    LineChartBarData(
                                                      preventCurveOverShooting: true,
                                                      spots: _rawSpots,
                                                      isCurved: true,
                                                      color: trendColor,
                                                      barWidth: 2,
                                                      dotData: const FlDotData(show: false),
                                                      belowBarData: BarAreaData(show: false),
                                                    ),
                                                      LineChartBarData(
                                                        isCurved: true,
                                                        color: accent,
                                                        barWidth: 1,
                                                        dotData: const FlDotData(show: false),
                                                        dashArray: [4, 3],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: _chartLabels.isNotEmpty
                                      ? _buildChartLabels()
                                      : _buildDynamicTimeMarkers(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Divider
                        const SizedBox(height: 6),
                        Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
                        const SizedBox(height: 6),
                        // Capital Events
                        InkWell(
                          onTap: () => _openStatDetail(context, AppTranslations.t('menu.capital_events')),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance, size: 16, color: accent),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(AppTranslations.t('dash.capital_events'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      Text(textDirection: TextDirection.ltr, '${AppTranslations.t('dash.deposits')} \$${deposits.toStringAsFixed(2)} | ${AppTranslations.t('dash.withdrawals_label')} \$${withdrawals.toStringAsFixed(2)} | ${AppTranslations.t('dash.ref_label')} \$${refCapital.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Text(textDirection: TextDirection.ltr, formatUsd(netEvents), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: netEvents >= 0 ? green : Colors.orange)),
                                const SizedBox(width: 3),
                                const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 15),
                              ],
                            ),
                          ),
                        ),
                        // Divider
                        const SizedBox(height: 6),
                        Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
                        const SizedBox(height: 6),
                        // Stats Grid 2x2
                        Row(
                          children: [
                            Expanded(child: _buildInnerCard(AppTranslations.t('dash.closed_trades'), '$closedTrades', Icons.receipt_long, Colors.grey, null, bnbLogoUrl, onTap: () => _openStatDetail(context, AppTranslations.t('dash.closed_trades')))),
                            const SizedBox(width: 7),
                            Expanded(child: _buildInnerCard(AppTranslations.t('dash.profit_trades'), '$profitTrades', Icons.emoji_events, green, '${AppTranslations.t('dash.winrate')} ${winRate.toStringAsFixed(1)}%', bnbLogoUrl, onTap: () => _openStatDetail(context, AppTranslations.t('dash.profit_trades')), valueColor: green)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(child: _buildInnerCard(AppTranslations.t('dash.bnb_fees_reserve'), '\$${bnbValue.toStringAsFixed(2)}', null, gold, null, bnbLogoUrl, isBnbIcon: true, onTap: () => _openStatDetail(context, AppTranslations.t('dash.bnb_fees_reserve')), titleColor: gold)),
                            const SizedBox(width: 7),
                            Expanded(child: _buildInnerCard(AppTranslations.t('dash.realized_pnl'), formatUsd(realizedPnl), Icons.account_balance_wallet, green, null, bnbLogoUrl, onTap: () => _openStatDetail(context, AppTranslations.t('dash.realized_pnl')), valueColor: green, customTitle: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(AppTranslations.t('dash.realized_pnl'), style: TextStyle(fontSize: 10, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF94a3b8) : const Color(0xFF475569)))),
      const SizedBox(width: 4),
      Text(formatPct(realizedPnlPct), style: const TextStyle(fontSize: 10, color: Color(0xFF10b981), fontWeight: FontWeight.bold)),
    ]))),
                          ],
                        ),
                        // Divider
                        const SizedBox(height: 6),
                        Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
                        const SizedBox(height: 6),
                        // Exposure
                        InkWell(
                          onTap: () => _openStatDetail(context, AppTranslations.t('dash.capital_exposure')),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.pie_chart_outline, size: 16, color: expColor),
                                      const SizedBox(width: 5),
                                      Text(AppTranslations.t('dash.capital_exposure'), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ]),
                                    Row(children: [
                                      Text(textDirection: TextDirection.ltr, '${exposurePct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: expColor)),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 13),
                                    ]),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Expanded(flex: expInt, child: Container(height: 7, color: expColor)),
                                  Expanded(
                                    flex: 100 - expInt,
                                    child: Container(
                                      height: 7,
                                      color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                                      child: CustomPaint(painter: StripedBarPainter(color: expColor)),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(textDirection: TextDirection.ltr, '${AppTranslations.t('dash.positions_value')}: \$${posValue.toStringAsFixed(2)}/\$${totalCapital.toStringAsFixed(2)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Divider
                        const SizedBox(height: 6),
                        Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
                        const SizedBox(height: 6),
                        // All-Time + Cost (Row)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _openStatDetail(context, AppTranslations.t('dash.all_time_pnl_range')),
                                child: _buildInnerCardContent(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 1), borderRadius: BorderRadius.circular(4)),
                                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          const Text('July', style: TextStyle(fontSize: 5, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          Text('17', style: TextStyle(fontSize: 8, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                                        ]),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(AppTranslations.t('dash.all_time_pnl'), style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              SizedBox(
                                                width: 60,
                                                child: Text('${AppTranslations.t('dash.min')} 0.41%', style: TextStyle(fontSize: 9, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(3)),
                                                child: const Icon(Icons.south_east, color: Colors.white, size: 10),
                                              ),
                                            ]),
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              SizedBox(
                                                width: 60,
                                                child: Text('${AppTranslations.t('dash.max')} 0.92%', style: TextStyle(fontSize: 9, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(3)),
                                                child: const Icon(Icons.north_east, color: Colors.white, size: 10),
                                              ),
                                            ]),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: InkWell(
                                onTap: () => _openStatDetail(context, AppTranslations.t('dash.cost_efficiency_full')),
                                child: _buildInnerCardContent(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Icon(Icons.savings_outlined, size: 16, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))),
                                              const SizedBox(width: 4),
                                              Text(AppTranslations.t('dash.cost_efficiency'), style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                            ]),
                                            const SizedBox(height: 4),
                                            Text('${AppTranslations.t('dash.fees_paid')}: \$${(_data['fees'] ?? 0.0).toStringAsFixed(2)}', style: TextStyle(fontSize: 9, color: gold)),
                                            const SizedBox(height: 1),
                                            Text('${AppTranslations.t('dash.avg_hour')}: \$${(_data['avg_hour'] ?? 0.0).toStringAsFixed(4)}', style: TextStyle(fontSize: 9, color: green)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),

                  // ============ JOURNAL ============
                  InkWell(
                    onTap: () => _openStatDetail(context, AppTranslations.t('dash.journal')),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                      child: Row(
                        children: [
                          Icon(Icons.article_outlined, size: 15, color: accent),
                          const SizedBox(width: 7),
                          Text(AppTranslations.t('dash.journal'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                          const Spacer(),
                          const Text('5', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                            child: Icon(Icons.keyboard_double_arrow_down, size: 16, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),

                  // ============ POSITIONS HEADER ============
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Text(AppTranslations.t('dash.positions'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                        const SizedBox(width: 5),
                        Text('${positions.length}/${_data['max_positions'] ?? 7}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                      ]),
                      Row(children: [
                        const Icon(Icons.list_alt, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(textDirection: TextDirection.ltr, '${AppTranslations.t('dash.total_value')}: \$${posValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // ============ POSITIONS LIST ============
                  if (positions.isEmpty)
                    Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(AppTranslations.t('dash.no_open_positions'), style: const TextStyle(color: Colors.grey))))
                  else
                    ...(positions.toList()..sort((a, b) {
                      final valA = (a['value'] ?? 0.0).toDouble();
                      final valB = (b['value'] ?? 0.0).toDouble();
                      return valB.compareTo(valA);
                    })).map((p) => ExpandablePositionCard(p: p, cardBg: cardBg, borderColor: borderColor, green: green, red: red, accent: accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  List<Widget> _buildChartLabels() {
    List<Widget> items = [];
    for (int i = 0; i < _chartLabels.length; i++) {
      if (i > 0) {
        for (int d = 0; d < 3; d++) {
          items.add(Container(
            width: 1, height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: const Color(0xFF3d4a5f),
          ));
        }
      }
      items.add(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(
              color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 1),
          Text(_chartLabels[i], style: const TextStyle(fontSize: 7, color: Color(0xFF94a3b8))),
        ],
      ));
    }
    return items;
  }

  List<Widget> _buildDynamicTimeMarkers() {
    if (_currentPeriod == '1d' || _currentPeriod == '1h') {
      return [
        _buildTimeMarker('00:00'),
        _buildTimeMarker('04:00'),
        _buildTimeMarker('08:00'),
        _buildTimeMarker('12:00'),
        _buildTimeMarker('16:00'),
        _buildTimeMarker('20:00'),
      ];
    } else {
      // للفترات الأسبوعية والشهرية، نعتمد على التواريخ الفعلية
      if ([].isEmpty) return [];
      int count = 5;
      List<Widget> markers = [];
      for (int i = 0; i < count; i++) {
        int index = (i * ([].length - 1) / (count - 1)).round();
        if (index >= [].length) index = [].length - 1;
        DateTime dt = [][index];
        markers.add(_buildTimeMarker('${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}'));
      }
      return markers;
    }
  }

  Widget _buildTimeMarker(String text) {
    return Column(
      children: [
        Container(width: 4, height: 4, decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), shape: BoxShape.circle)),
        const SizedBox(height: 2),
        Text(text, style: const TextStyle(fontSize: 7, color: Colors.grey)),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildStatCard(String title, String value, IconData? icon, Color iconColor, String? subtitle, String bnbLogoUrl, {Color titleColor = Colors.grey, bool isBnbIcon = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(10.5),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isBnbIcon)
                  SizedBox(width: 16.25, height: 16.25, child: Image(image: NetworkImage(bnbLogoUrl), errorBuilder: (c,o,s) => Icon(Icons.diamond, size: 16.25, color: iconColor)))
                else if (icon != null)
                  Icon(icon, size: 16.25, color: iconColor),
                const SizedBox(width: 6.25),
                Text(title, style: TextStyle(fontSize: 10.5, color: titleColor)),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                const Spacer(),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 9, color: green, fontWeight: FontWeight.bold)),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


  Widget _buildInnerCard(String title, String value, IconData? icon, Color iconColor, String? subtitle, String bnbLogoUrl, {bool isBnbIcon = false, VoidCallback? onTap, Color? titleColor, Color? valueColor, Widget? customTitle}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF141b28) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF2a3446) : const Color(0xFFe2e8f0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customTitle ?? Text(title, style: TextStyle(fontSize: 10, color: titleColor ?? (themeNotifier.value == ThemeMode.dark ? const Color(0xFF94a3b8) : const Color(0xFF475569)))),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (isBnbIcon)
                    SizedBox(width: 16, height: 16, child: Image(image: NetworkImage(bnbLogoUrl), errorBuilder: (c,o,s) => Icon(Icons.diamond, size: 16, color: iconColor)))
                  else if (icon != null)
                    Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                  Text(value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                  const Spacer(),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF10b981), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildInnerCardContent({required Widget child}) {
    return Container(
      height: 65,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF141b28) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF2a3446) : const Color(0xFFe2e8f0))),
      ),
      child: child,
    );
  }

// ================= EXPANDABLE POSITION CARD =================
class ExpandablePositionCard extends StatefulWidget {
  final Map<String, dynamic> p;
  final Color cardBg, borderColor, green, red, accent;

  const ExpandablePositionCard({
    super.key,
    required this.p,
    required this.cardBg,
    required this.borderColor,
    required this.green,
    required this.red,
    required this.accent,
  });

  @override
  State<ExpandablePositionCard> createState() => _ExpandablePositionCardState();
}

class _ExpandablePositionCardState extends State<ExpandablePositionCard> {
  bool _isExpanded = false;

  String _formatOpened(dynamic ts) {
    if (ts == null) return '';
    try {
      double v = double.parse(ts.toString());
      if (v <= 0) return '';
      final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}:${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fmtPrice(double price) {
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }


  final List<Map<String, double>> _dcaProtocol = [
    {"tp": 0.60},
    {"drop": -1.5, "tp": 0.7},
    {"drop": -4.0, "tp": 0.80},
    {"drop": -6.5, "tp": 0.90},
    {"drop": -9.0, "tp": 1.00},
    {"drop": -11.5, "tp": 1.10},
    {"drop": -14.0, "tp": 1.20},
    {"drop": -16.5, "tp": 1.30},
    {"drop": -19.0, "tp": 1.40},
    {"drop": -21.5, "tp": 1.50},
    {"drop": -24.0, "tp": 1.60},
    {"drop": -26.5, "tp": 1.70},
    {"drop": -29.0, "tp": 1.80},
    {"drop": -31.5, "tp": 1.90},
    {"drop": -34.0, "tp": 2.00},
    {"drop": -36.5, "tp": 2.10},
    {"drop": -39.0, "tp": 2.20},
    {"drop": -41.5, "tp": 2.30},
    {"drop": -44.0, "tp": 2.40},
    {"drop": -46.5, "tp": 2.50},
    {"drop": -49.0, "tp": 2.60},
  ];
  final double _totalFees = 0.15;

  Future<void> _show24hDetails(String symbol) async {
    final base = symbol.split('/')[0].replaceAll('USDT', '');
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/binance/24h?symbol=$base'));
      if (!mounted) return;
      Navigator.pop(context);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final last = double.tryParse(d['lastPrice']?.toString() ?? '0') ?? 0.0;
        final pct = double.tryParse(d['priceChangePercent']?.toString() ?? '0') ?? 0.0;
        final high = double.tryParse(d['highPrice']?.toString() ?? '0') ?? 0.0;
        final low = double.tryParse(d['lowPrice']?.toString() ?? '0') ?? 0.0;
        final vol = double.tryParse(d['quoteVolume']?.toString() ?? '0') ?? 0.0;
        final wavg = double.tryParse(d['weightedAvgPrice']?.toString() ?? '0') ?? 0.0;
        
        final isUp = pct >= 0;
        final pctColor = isUp ? const Color(0xFF10b981) : const Color(0xFFef4444);
        final pctStr = '${isUp ? "+" : ""}${pct.toStringAsFixed(2)}%';
        
        showDialog(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Row(children: [
            CircleAvatar(
              backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
              radius: 14,
              child: ClipOval(
                child: Image.network(
                  'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${symbol.split('/')[0].toLowerCase()}.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      symbol.isNotEmpty ? (symbol.split('/')[0].length > 3 ? symbol.split('/')[0].substring(0, 3) : symbol.split('/')[0]) : '?',
                      style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(symbol, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dlgRow(AppTranslations.t('pos.price'), '\$${last.toStringAsFixed(4)}'),
              _dlgRow(AppTranslations.t('pos.change_24h'), pctStr, color: pctColor),
              _dlgRow(AppTranslations.t('pos.high_24h'), '\$${high.toStringAsFixed(4)}'),
              _dlgRow(AppTranslations.t('pos.low_24h'), '\$${low.toStringAsFixed(4)}'),
              _dlgRow(AppTranslations.t('pos.weighted_24h'), '\$${wavg.toStringAsFixed(4)}', color: Colors.grey),
              _dlgRow(AppTranslations.t('pos.volume_24h'), '\$${vol.toStringAsFixed(0)}', color: const Color(0xFFf0b90b)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTranslations.t('misc.close')))],
        ));
      } else {
        if (kDebugMode) debugPrint('Failed to load 24h data');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      if (kDebugMode) debugPrint('Error: \$e');
    }
  }
  
  Widget _dlgRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(color: color ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sym = p['symbol'] ?? 'UNKNOWN';
    final pnl = (p['pnl'] ?? 0.0).toDouble();
    final c = pnl >= 0 ? widget.green : widget.red;

    final value = (p['value'] ?? 0.0).toDouble();
    final entry = (p['entry'] ?? 0.0).toDouble();
    final current = (p['current'] ?? entry).toDouble();

    final dcaSteps = int.tryParse(p['dca_steps']?.toString() ?? '0') ?? 0;
    
    // Next TP Logic (Flet matched)
    final tpCfg = _dcaProtocol.length > dcaSteps ? _dcaProtocol[dcaSteps] : _dcaProtocol.last;
    final tpPct = tpCfg['tp'] ?? 0.0;
    final grossTp = tpPct + _totalFees;
    final nextTpTarget = entry * (1 + grossTp / 100.0);
    final nextTpDist = grossTp - pnl;

    // Next DCA Logic (Flet matched)
    final nextStep = dcaSteps + 1;
    String? nextDcaPctStr;
    double? nextDcaTarget;
    double? nextDcaDist;
    if (nextStep <= 20 && nextStep < _dcaProtocol.length) {
      final dcaCfg = _dcaProtocol[nextStep];
      final dropPct = dcaCfg['drop'] ?? 0.0;
      final grossDrop = dropPct + _totalFees;
      nextDcaPctStr = grossDrop.toStringAsFixed(2);
      nextDcaTarget = entry * (1 + grossDrop / 100.0);
      nextDcaDist = pnl - grossDrop;
    }

    final openedStr = _formatOpened(p['opened']);
    final dcaPct = (dcaSteps / 20).clamp(0.0, 1.0);
    final costValue = pnl != 0 ? value / (1 + pnl / 100) : value;

    Color dcaBarColor = const Color(0xFF3b82f6);
    if (dcaPct >= 0.75) {
      dcaBarColor = widget.red;
    } else if (dcaPct >= 0.5) {
      dcaBarColor = Colors.orange;
    } else if (dcaPct >= 0.25) {
      dcaBarColor = const Color(0xFF8b5cf6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: c, width: 3),
          top: BorderSide(color: widget.borderColor),
          right: BorderSide(color: widget.borderColor),
          bottom: BorderSide(color: widget.borderColor),
        ),
      ),
      child: Column(
        children: [
          // Top row: Symbol | Open on Binance | Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                  child: ClipOval(
                    child: Image.network(
                      'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(sym, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    final url = 'https://www.binance.com/en/trade/${sym.split('/')[0]}_USDT?type=spot';
                    final ok = await openUrl(url);
                    if (!ok) if (kDebugMode) debugPrint('❌ Binance launch failed: $url');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, color: widget.accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.t('pos.open_binance').replaceAll('{symbol}', sym.split('/')[0]), 
                        style: TextStyle(fontSize: 13, color: widget.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: Icon(
                      _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                      size: 14, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
          // Middle row: PNL | DCA | Cost/Value
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppTranslations.t('pos.pnl'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(textDirection: TextDirection.ltr, AppTranslations.t('pos.dca'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(textDirection: TextDirection.ltr, '$dcaSteps/20', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: dcaPct,
                          backgroundColor: widget.borderColor,
                          color: dcaBarColor,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(AppTranslations.t('pos.cost'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 6),
                          Text(textDirection: TextDirection.ltr, '\$${costValue.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(AppTranslations.t('pos.value'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 6),
                          Text(textDirection: TextDirection.ltr, '\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
          // Bottom row: Entry | Opened | Price
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(textDirection: TextDirection.ltr, AppTranslations.t('pos.entry'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                const SizedBox(width: 4),
                Text(textDirection: TextDirection.ltr, _fmtPrice(entry), style: TextStyle(fontSize: 10, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                if (openedStr.isNotEmpty) ...[
                  const Spacer(),
                  Text(openedStr, style: const TextStyle(fontSize: 9, color: Color(0xFF64748b))),
                ],
                const Spacer(),
                Text(textDirection: TextDirection.ltr, AppTranslations.t('pos.price'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                const SizedBox(width: 4),
                Text(_fmtPrice(current), style: TextStyle(fontSize: 10, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Expanded content
          if (_isExpanded) ...[
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(AppTranslations.t('pos.next_tp'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(textDirection: TextDirection.ltr, '+${grossTp.toStringAsFixed(2)}%  ->  \$${nextTpTarget.toStringAsFixed(4)}', style: TextStyle(fontSize: 10, color: widget.green, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text(textDirection: TextDirection.ltr, '(${nextTpDist > 0 ? '+' : ''}${nextTpDist.toStringAsFixed(2)}% ${AppTranslations.t('pos.away')})', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(textDirection: TextDirection.ltr, AppTranslations.t('pos.next_dca'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      if (nextDcaTarget != null) ...[
                        Text(textDirection: TextDirection.ltr, '$nextDcaPctStr%  ->  \$${nextDcaTarget.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text(textDirection: TextDirection.ltr, '(${nextDcaDist! > 0 ? '+' : ''}${nextDcaDist.toStringAsFixed(2)}% ${AppTranslations.t('pos.away')})', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ] else
                        Text(AppTranslations.t('pos.max_reached'), style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    double holdHours = 0.0;
                    double ts = 0.0;
                    if (p['opened'] != null) ts = double.tryParse(p['opened'].toString()) ?? 0.0;
                    if (ts > 0) holdHours = (DateTime.now().millisecondsSinceEpoch / 1000 - ts) / 3600;
                    
                    return Row(
                      children: [
                        Text(AppTranslations.t('pos.hold'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(textDirection: TextDirection.ltr, '${holdHours.toStringAsFixed(1)} ${AppTranslations.t('pos.hours')}', style: TextStyle(fontSize: 10, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                      ],
                    );
                  }),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _show24hDetails(sym),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart, size: 12, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))),
                        const SizedBox(width: 4),
                        Text(AppTranslations.t('pos.details_24h'), style: TextStyle(fontSize: 10, color: widget.accent, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 8, color: widget.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StripedBarPainter extends CustomPainter {
  final Color color;
  StripedBarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
    double spacing = 6.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= STAT DETAIL SCREEN =================
class StatDetailScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic> data;
  final String token;

  const StatDetailScreen({super.key, required this.title, required this.data, required this.token});

  @override
  State<StatDetailScreen> createState() => _StatDetailScreenState();
}

class _StatDetailScreenState extends State<StatDetailScreen> {
  bool _isLoading = true;
  String _token = '';
  Map<String, dynamic> _dashboardData = {};
  Map<String, dynamic> _extraData = {};
  List<dynamic> _trades = [];
  String _selectedPeriod = '1d';
  String _errorMsg = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _dashboardData = widget.data;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (_token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token') ?? '';
      }
      
      // جلب بيانات الداشبورد إذا كنا في Capital Events وكانت البيانات فارغة
      if (widget.title == AppTranslations.t('menu.capital_events') && _dashboardData.isEmpty) {
        final resDash = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/dashboard'), headers: {'Authorization': 'Bearer $_token'});
        if (resDash.statusCode == 200) {
          _dashboardData = jsonDecode(resDash.body);
        }
      }

      final headers = {'Authorization': 'Bearer $_token'};

      if (widget.title == AppTranslations.t('dash.closed_trades') || widget.title == AppTranslations.t('dash.profit_trades')) {
        final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/history'), headers: headers);
        if (res.statusCode == 200) {
          final allTrades = jsonDecode(res.body)['trades'] ?? [];
          setState(() {
            if (widget.title == AppTranslations.t('dash.profit_trades')) {
              _trades = allTrades.where((t) => ((t['realized_profit_usdt'] ?? 0.0) as num).toDouble() > 0).toList();
            } else {
              _trades = allTrades;
            }
            _isLoading = false;
          });
        } else {
          setState(() { _errorMsg = 'Failed to load trades'; _isLoading = false; });
        }
      } else if (widget.title == AppTranslations.t('dash.all_time_pnl_range')) {
        final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/stats/pnl_range'), headers: headers);
        if (res.statusCode == 200) {
          setState(() { _extraData = jsonDecode(res.body); _isLoading = false; });
        } else {
          setState(() { _errorMsg = 'Failed'; _isLoading = false; });
        }
      } else if (widget.title == AppTranslations.t('dash.cost_efficiency_full')) {
        final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/stats/fees'), headers: headers);
        if (res.statusCode == 200) {
          setState(() { _extraData = jsonDecode(res.body); _isLoading = false; });
        } else {
          setState(() { _errorMsg = 'Failed'; _isLoading = false; });
        }
      } else if (widget.title == AppTranslations.t('dash.bnb_fees_reserve')) {
        final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/bnb/status'), headers: headers);
        if (res.statusCode == 200) {
          setState(() { _extraData = jsonDecode(res.body); _isLoading = false; });
        } else {
          setState(() { _errorMsg = 'Failed'; _isLoading = false; });
        }
      } else if (widget.title == AppTranslations.t('dash.realized_pnl')) {
        final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/history'), headers: headers);
        if (res.statusCode == 200) {
          setState(() { 
            _trades = jsonDecode(res.body)['trades'] ?? [];
            _isLoading = false; 
          });
        } else {
          setState(() { _errorMsg = 'Failed'; _isLoading = false; });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() { _errorMsg = 'Error: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
        appBar: AppBar(backgroundColor: cardBg, leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)), title: Text(widget.title, style: TextStyle(color: accent))),
        body: Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))),
      );
    }

    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _errorMsg.isNotEmpty
          ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.title == AppTranslations.t('dash.closed_trades') || widget.title == AppTranslations.t('dash.profit_trades')) return _buildTradesList();
    if (widget.title == AppTranslations.t('dash.all_time_pnl_range')) return _buildPnlRange();
    if (widget.title == AppTranslations.t('dash.cost_efficiency_full')) return _buildFees();
    if (widget.title == AppTranslations.t('dash.bnb_fees_reserve')) return _buildBnb();
    if (widget.title == AppTranslations.t('dash.realized_pnl')) return _buildRealized();
    if (widget.title == AppTranslations.t('stat.capital')) return _buildCapitalBreakdown();
    if (widget.title == AppTranslations.t('menu.capital_events') || widget.title == AppTranslations.t('dash.capital_events')) return _buildCapitalEvents();
    if (widget.title == AppTranslations.t('dash.capital_exposure')) return _buildCapitalExposure();
    // WARNING: 'Journal' is an internal identifier (routing), not a display string.
    if (widget.title == 'Journal' || widget.title == AppTranslations.t('dash.journal')) return _buildJournal();
    return Center(child: Text(AppTranslations.t('misc.no_data'), style: const TextStyle(color: Colors.grey)));
  }

  Widget _buildTradesList() {
    if (_trades.isEmpty) return Center(child: Text(AppTranslations.t('misc.no_trades'), style: const TextStyle(color: Colors.grey)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
          child: Text('${widget.title} (${_trades.length})', style: TextStyle(color: widget.title == AppTranslations.t('dash.profit_trades') ? green : accent, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trades.length,
            itemBuilder: (context, index) {
              final t = _trades[index];
              final sym = t['symbol'] ?? 'UNKNOWN';
              final pnl = (t['realized_profit_usdt'] ?? 0.0).toDouble();
              final time = t['last_action'] ?? 0;
              final isWin = pnl >= 0;
              String dateStr = '';
              if (time > 0) {
                final dt = DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());
                dateStr = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}:${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
              }
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TradeDetailScreen(trade: t, cardBg: cardBg, borderColor: borderColor, green: green, red: red, accent: accent))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), width: 1))),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                        child: ClipOval(
                          child: Image.network(
                            'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                            width: 28, height: 28, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: Text(sym, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 3, child: Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 10))),
                      Text(textDirection: TextDirection.ltr, '${isWin ? '+' : ''}${pnl.toStringAsFixed(2)} USDT', style: TextStyle(color: isWin ? green : red, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPnlRange() {
    final minPct = (_extraData['min_pct'] ?? 0.0).toDouble();
    final minSym = _extraData['min_sym'] ?? 'N/A';
    final maxPct = (_extraData['max_pct'] ?? 0.0).toDouble();
    final maxSym = _extraData['max_sym'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.t('dash.all_time_pnl'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 24),
            InkWell(
              onTap: () {
                final trade = _extraData['min_trade'];
                if (trade != null) Navigator.push(context, MaterialPageRoute(builder: (c) => TradeDetailScreen(trade: trade, cardBg: cardBg, borderColor: borderColor, green: green, red: red, accent: accent)));
              },
              child: Row(
                children: [
                  SizedBox(width: 35, child: Text(AppTranslations.t('dash.min'), style: const TextStyle(color: Colors.grey, fontSize: 11))),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${minPct >= 0 ? '+' : ''}${minPct.toStringAsFixed(2)}% ($minSym)',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 11),
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                final trade = _extraData['max_trade'];
                if (trade != null) Navigator.push(context, MaterialPageRoute(builder: (c) => TradeDetailScreen(trade: trade, cardBg: cardBg, borderColor: borderColor, green: green, red: red, accent: accent)));
              },
              child: Row(
                children: [
                  SizedBox(width: 35, child: Text(AppTranslations.t('dash.max'), style: const TextStyle(color: Colors.grey, fontSize: 11))),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '+${maxPct.toStringAsFixed(2)}% ($maxSym)',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 11),
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFees() {
    final fees = (_extraData['fees'] ?? 0.0).toDouble();
    final avg = (_extraData['avg'] ?? 0.0).toDouble();
    final List assets = _extraData['assets'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('dash.cost_efficiency'), style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14)),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(textDirection: TextDirection.ltr, AppTranslations.t('dash.fees_paid'), style: const TextStyle(color: Colors.grey, fontSize: 13)), Text('\$${fees.toStringAsFixed(2)}', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 13))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(textDirection: TextDirection.ltr, AppTranslations.t('dash.avg_hour'), style: const TextStyle(color: Colors.grey, fontSize: 13)), Text('\$${avg.toStringAsFixed(4)}', style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 13))]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: Text('${assets.length} ${AppTranslations.t('misc.assets_sorted_suffix')}', style: const TextStyle(color: Colors.grey, fontSize: 11))),
          const SizedBox(height: 8),
          ...assets.map((a) {
            final sym = a['symbol'] ?? '?';
            final net = (a['net'] ?? 0.0).toDouble();
            final profit = (a['profit'] ?? 0.0).toDouble();
            final fee = (a['fees'] ?? 0.0).toDouble();
            final trades = a['trades'] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                        child: ClipOval(
                          child: Image.network(
                            'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                            width: 24, height: 24, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(sym, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('$trades ${AppTranslations.plural('misc.trades_unit', trades)}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      const Spacer(),
                      Text(textDirection: TextDirection.ltr, '${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}', style: TextStyle(color: net >= 0 ? green : red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(textDirection: TextDirection.ltr, 'Profit ${profit >= 0 ? '+' : ''}\$${profit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(width: 16),
                    Text(textDirection: TextDirection.ltr, 'Fees -\$${fee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBnb() {
    final status = _extraData['status'] ?? 'UNKNOWN';
    final balance = (_extraData['balance'] ?? 0.0).toDouble();
    final price = (_extraData['price'] ?? 0.0).toDouble();
    final value = (_extraData['value'] ?? 0.0).toDouble();
    final lastCheck = _extraData['last_check'] ?? 0;
    String timeStr = 'N/A';
    if (lastCheck > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch((lastCheck * 1000).toInt());
      timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.t('dash.bnb_fees_reserve'), style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14)),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
            _buildDetailRow(AppTranslations.t('field.status'), status == 'RUNNING' ? AppTranslations.t('status.running') : status, status == 'RUNNING' ? green : Colors.orange),
            _buildDetailRow(AppTranslations.t('admin.balance'), '${balance.toStringAsFixed(8)} BNB', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
            _buildDetailRow(AppTranslations.t('field.price_hint'), '\$${price.toStringAsFixed(2)}', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
            _buildDetailRow(AppTranslations.t('pos.value'), '\$${value.toStringAsFixed(2)}', gold),
            _buildDetailRow(AppTranslations.t('field.last_check'), timeStr, (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _aggregatePnl(String period, List<dynamic> trades) {
    Map<String, double> buckets = {};
    Map<String, String> sortKeys = {};
    
    for (var t in trades) {
      if (t['closed'] != true) continue;
      final ts = (t['last_action'] ?? 0.0).toDouble();
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000);
      final pnl = (t['realized_profit_usdt'] ?? 0.0).toDouble();
      
      String key = '';
      String sortKey = '';
      
      if (period == '1h') {
        key = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:00';
        sortKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}';
      } else if (period == '1d' || period == '1D') {
        key = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        sortKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else if (period == '1w' || period == '1W') {
        final firstDayOfYear = DateTime(dt.year, 1, 1);
        final daysOffset = firstDayOfYear.weekday - 1;
        final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
        final weekNumber = ((dt.difference(firstMonday).inDays) / 7).floor() + 1;
        key = 'W${weekNumber.toString().padLeft(2, '0')}-${dt.year}';
        sortKey = '${dt.year}-W${weekNumber.toString().padLeft(2, '0')}';
      } else if (period == '1mo' || period == '1MO') {
        key = '${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        sortKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      } else if (period == '1y' || period == '1Y') {
        key = '${dt.year}';
        sortKey = '${dt.year}';
      }
      
      buckets[key] = (buckets[key] ?? 0.0) + pnl;
      sortKeys[key] = sortKey;
    }
    
    final sortedKeys = buckets.keys.toList()..sort((a, b) => sortKeys[b]!.compareTo(sortKeys[a]!));
    return sortedKeys.map((k) => {'date': k, 'pnl': buckets[k]}).toList();
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101722) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTranslations.t('misc.select_period'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0f172a), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: ['1H', '1D', '1W', '1MO', '1Y'].map((p) {
                  final isSelected = _selectedPeriod.toLowerCase() == p.toLowerCase();
                  final periodLabel = AppTranslations.t('misc.period_${p.toLowerCase()}');
                  return InkWell(
                    onTap: () {
                      setState(() { _selectedPeriod = p.toLowerCase(); });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? accent : borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check, color: Colors.black, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            periodLabel,
                            style: TextStyle(
                              color: isSelected ? Colors.black : (isDark ? Colors.white : const Color(0xFF0f172a)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealized() {
    final stats = widget.data['stats'] ?? {};
    final totalProfit = (stats['realized_pnl'] ?? 0.0).toDouble();
    final totalTrades = stats['closed_trades'] ?? 0;
    final wins = stats['profit_trades'] ?? 0;
    
    final breakdown = _aggregatePnl(_selectedPeriod, _trades);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(AppTranslations.t('dash.realized_pnl'), style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 14)),
                  InkWell(
                    onTap: _showPeriodPicker,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [Icon(Icons.sync, size: 11, color: accent), const SizedBox(width: 4), Text(AppTranslations.t('misc.period_$_selectedPeriod'), style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ]),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                _buildDetailRow(AppTranslations.t('field.total_profit'), '\$${totalProfit.toStringAsFixed(4)}', green),
                _buildDetailRow(AppTranslations.t('field.total_trades'), '$totalTrades', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                _buildDetailRow(AppTranslations.t('field.wins'), '$wins', green),
                _buildDetailRow(AppTranslations.t('field.total_dcas'), '30', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_selectedPeriod.toUpperCase()} ${AppTranslations.t('misc.breakdown_label')}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(textDirection: TextDirection.ltr, '+\$${totalProfit.toStringAsFixed(2)}', style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                if (breakdown.isEmpty) 
                  Padding(padding: const EdgeInsets.all(20), child: Text(AppTranslations.t('misc.no_data_period'), style: const TextStyle(color: Colors.grey, fontSize: 12)))
                else
                  ...breakdown.map((b) {
                    final date = b['date'] ?? '';
                    final pnl = (b['pnl'] ?? 0.0).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(date, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 13)),
                        Text(textDirection: TextDirection.ltr, '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: pnl >= 0 ? green : red, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalBreakdown() {
    final cap = widget.data['capital'] ?? {};
    final risk = widget.data['risk'] ?? {};
    final freeUsdt = (cap['free'] ?? 0.0).toDouble();
    final posValue = (risk['positions_value'] ?? 0.0).toDouble();
    final bnbValue = (cap['bnb_value'] ?? 0.0).toDouble();
    final total = (cap['total'] ?? 0.0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppTranslations.t('page.total_capital_breakdown'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 24),
            _buildDetailRow(AppTranslations.t('field.free_usdt'), '\$${freeUsdt.toStringAsFixed(2)}', accent),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
            _buildDetailRow(AppTranslations.t('dash.positions_value'), '\$${posValue.toStringAsFixed(2)}', const Color(0xFFa78bfa)),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
            _buildDetailRow(AppTranslations.t('field.bnb_reserve'), '\$${bnbValue.toStringAsFixed(2)}', gold),
            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
            _buildDetailRow(AppTranslations.t('field.total'), '\$${total.toStringAsFixed(2)}', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalEvents() {
    final cap = _dashboardData['capital'] ?? {};
    final events = _dashboardData['events'] ?? {};
    final refCapital = (cap['ref_capital'] ?? 0.0).toDouble();
    final deposits = (events['deposits'] ?? 0.0).toDouble();
    final withdrawals = (events['withdrawals'] ?? 0.0).toDouble();
    final movements = List.from(events['movements'] ?? []);
    // Flet uses reversed(events) -> newest first
    movements.sort((a, b) => ((b['timestamp'] ?? 0) as num).compareTo((a['timestamp'] ?? 0) as num));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('card.capital_summary'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 24),
                _buildDetailRow(AppTranslations.t('dash.reference_capital'), '\$${refCapital.toStringAsFixed(2)}', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                _buildDetailRow(AppTranslations.t('field.total_deposits'), '\$${deposits.toStringAsFixed(2)}', green),
                _buildDetailRow(AppTranslations.t('field.total_withdrawals'), '\$${withdrawals.toStringAsFixed(2)}', Colors.orange),
                _buildDetailRow(AppTranslations.t('field.events_count'), '${movements.length}', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (movements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(AppTranslations.t('empty.no_capital_movements'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...movements.map((m) {
              final type = (m['type'] ?? '?').toString();
              final ts = (m['timestamp'] ?? 0).toDouble();
              final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
              final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

              String title = '';
              Color color = Colors.grey;
              IconData icon = Icons.help_outline;
              bool showBa = false;

              if (type == 'DEPOSIT') {
                final amt = (m['amount'] ?? 0.0).toDouble();
                title = '${AppTranslations.t('evt.deposit')}  \$${amt.toStringAsFixed(2)}';
                color = green;
                icon = Icons.arrow_downward;
                showBa = true;
              } else if (type == 'WITHDRAW') {
                final amt = (m['amount'] ?? 0.0).toDouble();
                title = '${AppTranslations.t('evt.withdraw')}  \$${amt.toStringAsFixed(2)}';
                color = Colors.orange;
                icon = Icons.arrow_upward;
                showBa = true;
              } else if (type == 'BNB_TOPUP') {
                final usd = (m['usdt_spent'] ?? 0.0).toDouble();
                final bnbAmt = (m['bnb_amount'] ?? 0.0).toDouble();
                title = '${AppTranslations.t('evt.bnb_topup')}  \$${usd.toStringAsFixed(2)}  (${bnbAmt.toStringAsFixed(6)} BNB)';
                color = const Color(0xFFa78bfa);
                icon = Icons.diamond;
                showBa = false;
              } else if (type == 'BNB_FEE') {
                final bnbAmt = (m['bnb_amount'] ?? 0.0).toDouble();
                title = '${AppTranslations.t('evt.bnb_fee')}  ${bnbAmt.toStringAsFixed(6)} BNB';
                color = Colors.orange;
                icon = Icons.diamond;
                showBa = false;
              } else {
                final amt = (m['amount'] ?? 0.0).toDouble();
                title = '$type  \$${amt.toStringAsFixed(2)}';
                color = Colors.grey;
                icon = Icons.help_outline;
                showBa = false;
              }

              final before = (m['usdt_before'] ?? m['balance_before'] ?? 0.0).toDouble();
              final after = (m['usdt_after'] ?? m['balance_after'] ?? 0.0).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9)), borderRadius: BorderRadius.circular(16)),
                          alignment: Alignment.center,
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (showBa) ...[
                      const SizedBox(height: 8),
                      Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppTranslations.t('field.before'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('\$${before.toStringAsFixed(2)}', style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppTranslations.t('field.after'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('\$${after.toStringAsFixed(2)}', style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCapitalExposure() {
    final risk = widget.data['risk'] ?? {};
    final cap = widget.data['capital'] ?? {};
    final positions = widget.data['positions'] as List? ?? [];
    final exp = (risk['exposure_pct'] ?? 0.0).toDouble();
    final posValue = (risk['positions_value'] ?? 0.0).toDouble();
    final total = (cap['total'] ?? 0.0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بطاقة الإحصائيات
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('dash.capital_exposure'), style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 10)),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                _buildDetailRow(AppTranslations.t('dash.exposure_pct'), '${exp.toStringAsFixed(2)}%', exp >= 65 ? red : (exp >= 50 ? Colors.orange : green)),
                _buildDetailRow(AppTranslations.t('dash.positions_value'), '\$${posValue.toStringAsFixed(2)}', accent),
                _buildDetailRow(AppTranslations.t('dash.total_capital_full'), '\$${total.toStringAsFixed(2)}', (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // شارة المراكز المفتوحة
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF0f172a) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: green),
              ),
              child: Text(
                '${AppTranslations.t('dash.positions')} (${positions.length})',
                style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // قائمة المراكز
          if (positions.isNotEmpty)
            ...positions.map((p) {
              final sym = p['symbol'] ?? 'UNKNOWN';
              final val = (p['value'] ?? 0.0).toDouble();
              final pnlPct = (p['pnl'] ?? 0.0).toDouble();
              final isWin = pnlPct >= 0;
              final pnlColor = isWin ? green : red;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // الصف الأول: الأيقونة والرمز
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                          child: ClipOval(
                            child: Image.network(
                              'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                              width: 24, height: 24, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(sym, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
                    // الصف الثاني: القيمة والربح
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppTranslations.t('dash.positions_value'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('\$${val.toStringAsFixed(2)}', textDirection: TextDirection.ltr, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppTranslations.t('pos.pnl'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('${isWin ? '+' : ''}${pnlPct.toStringAsFixed(2)}%', textDirection: TextDirection.ltr, style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildJournal() {
    final List journal = widget.data['journal'] ?? [];
    if (journal.isEmpty) return Center(child: Text(AppTranslations.t('journal.empty'), style: const TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: journal.length,
      itemBuilder: (context, index) {
        final j = journal[index];
        final type = j['type'] ?? 'INFO';
        final msg = j['message'] ?? '';
        final time = j['time'] ?? '';
        
        String displayMsg = msg;
        if (displayMsg.startsWith('DEPOSIT ')) {
          displayMsg = displayMsg.replaceFirst('DEPOSIT ', '${AppTranslations.t('evt.deposit')} ');
        } else if (displayMsg.startsWith('WITHDRAW ')) {
          displayMsg = displayMsg.replaceFirst('WITHDRAW ', '${AppTranslations.t('evt.withdraw')} ');
        }
        displayMsg = displayMsg.replaceAll('step ', '${AppTranslations.t('pos.step')} ');
        Color c = Colors.grey;
        IconData icon = Icons.info_outline;
        if (type.contains('BUY')) { c = green; icon = Icons.arrow_downward; }
        else if (type.contains('SELL')) { c = red; icon = Icons.arrow_upward; }
        else if (type.contains('DCA')) { c = Colors.blue; icon = Icons.repeat; }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${(() {
                      String dt = type;
                      if (type.contains('BUY')) {
                        dt = AppTranslations.t('events.BUY');
                      } else if (type.contains('SELL')) {
                        dt = AppTranslations.t('events.SELL');
                      } else if (type.contains('DCA')) {
                        dt = AppTranslations.t('events.DCA');
                      } else if (type.contains('DEPOSIT')) {
                        dt = AppTranslations.t('evt.deposit');
                      } else if (type.contains('WITHDRAW')) {
                        dt = AppTranslations.t('evt.withdraw');
                      }
                      return dt;
                    })()} - $time', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(displayMsg, style: TextStyle(fontSize: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color valColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(color: valColor, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

// ================= STATS SCREEN =================
class StatsScreen extends StatefulWidget {
  final String token;
  const StatsScreen({super.key, required this.token});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  List<FlSpot> _rawSpots = [];
  List<String> _chartLabels = [];
  double _changePct = 0.0;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/stats/performance'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final chart = d['chart'] ?? {};
        final rawList = chart['raw'] as List? ?? [];
        final dietzList = chart['dietz'] as List? ?? [];
        final labelsList = chart['labels'] as List? ?? [];

        List<FlSpot> raw = [];
        for (int i = 0; i < rawList.length; i++) {
          double v = double.tryParse(rawList[i][1].toString()) ?? 0.0;
          if (v > 0) raw.add(FlSpot(i.toDouble(), v));
        }
        List<FlSpot> dietz = [];
        for (int i = 0; i < dietzList.length; i++) {
          double v = double.tryParse(dietzList[i][1].toString()) ?? 0.0;
          if (v > 0) dietz.add(FlSpot(i.toDouble(), v));
        }

        setState(() {
          _data = d;
          _rawSpots = raw;
          _chartLabels = labelsList.map((e) => e.toString()).toList();
          _changePct = (d['trend']?['net_pct'] as num?)?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
        appBar: AppBar(
          backgroundColor: cardBg,
          leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
          title: Text(AppTranslations.t('page.capital_performance'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        ),
        body: Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))),
      );
    }

    final periods = _data['periods'] ?? {};
    final extremes = _data['extremes'] ?? {};
    final trend = _data['trend'] ?? {};

    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('page.capital_performance'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4 Period Cards
            _buildPeriodCard(AppTranslations.t('perf.today'), '1d', periods['1d']),
            const SizedBox(height: 8),
            _buildPeriodCard(AppTranslations.t('perf.week'), '1w', periods['1w']),
            const SizedBox(height: 8),
            _buildPeriodCard(AppTranslations.t('perf.month'), '1mo', periods['1mo']),
            const SizedBox(height: 8),
            _buildPeriodCard(AppTranslations.t('perf.year'), '1y', periods['1y']),
            const SizedBox(height: 16),

            // Chart Title
            Text(AppTranslations.t('card.chart'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(height: 8),

            // Big Chart (transparent - Flet style)
            Container(
              height: 160,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: _rawSpots.isEmpty
                        ? Center(child: Text(AppTranslations.t('misc.no_chart_data'), style: const TextStyle(color: Colors.grey, fontSize: 11)))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => const FlLine(
                                  color: Color(0xFF2d3a52),
                                  strokeWidth: 1,
                                  dashArray: [3, 3],
                                ),
                              ),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: (_rawSpots.length - 1).toDouble() > 0 ? (_rawSpots.length - 1).toDouble() : 1,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _rawSpots,
                                  isCurved: true,
                                  color: _changePct >= 0 ? green : red,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                ),

                              ],
                            ),
                          ),
                  ),
                  if (_chartLabels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _buildStatsChartLabels(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Extremes Card
            if (extremes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.t('card.extremes'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
                    _buildRow(AppTranslations.t('perf.peak'), '\$${extremes['peak_val']?.toStringAsFixed(2)}  ${extremes['peak_str']}'),
                    _buildRow(AppTranslations.t('perf.trough'), '\$${extremes['trough_val']?.toStringAsFixed(2)}  ${extremes['trough_str']}'),
                    _buildRow(AppTranslations.t('perf.range'), '\$${extremes['range_dollar']?.toStringAsFixed(2)}  (${extremes['range_pct']?.toStringAsFixed(2)}%)', Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Trend Card
            if (trend.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.t('card.trend'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
                    _buildRow(AppTranslations.t('perf.start'), '\$${trend['start_val']?.toStringAsFixed(2)}'),
                    _buildRow(AppTranslations.t('perf.end'), '\$${trend['end_val']?.toStringAsFixed(2)}'),
                    _buildRow(
                      AppTranslations.t('perf.net'),
                      '${(trend['net_dollar'] ?? 0) >= 0 ? '+' : ''}\$${(trend['net_dollar'] ?? 0).toStringAsFixed(2)}  (${(trend['net_pct'] ?? 0) >= 0 ? '+' : ''}${(trend['net_pct'] ?? 0).toStringAsFixed(2)}%)',
                      (trend['net_dollar'] ?? 0) >= 0 ? green : red,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatsChartLabels() {
    List<Widget> items = [];
    for (int i = 0; i < _chartLabels.length; i++) {
      if (i > 0) {
        for (int d = 0; d < 3; d++) {
          items.add(Container(
            width: 1, height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: const Color(0xFF3d4a5f),
          ));
        }
      }
      items.add(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(
              color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 1),
          Text(_chartLabels[i], style: const TextStyle(fontSize: 7, color: Color(0xFF94a3b8))),
        ],
      ));
    }
    return items;
  }

  Widget _buildPeriodCard(String label, String code, dynamic data) {
    double pct = (data?['pct'] ?? 0.0).toDouble();
    double usd = (data?['usd'] ?? 0.0).toDouble();
    Color c = pct >= 0 ? green : red;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => PeriodHistoryScreen(
            token: widget.token,
            period: code,
            title: label,
          )),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                Text(code, style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(textDirection: TextDirection.ltr, '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: c)),
                Text(textDirection: TextDirection.ltr, '${usd >= 0 ? '+' : ''}\$${usd.toStringAsFixed(2)}', style: TextStyle(fontSize: 10, color: c)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
        ],
      ),
    );
  }
}

// ================= PERIOD HISTORY SCREEN =================
class PeriodHistoryScreen extends StatefulWidget {
  final String token;
  final String period;
  final String title;
  const PeriodHistoryScreen({super.key, required this.token, required this.period, required this.title});

  @override
  State<PeriodHistoryScreen> createState() => _PeriodHistoryScreenState();
}

class _PeriodHistoryScreenState extends State<PeriodHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/stats/period_history?period=${widget.period}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _history = d['history'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${AppTranslations.t('history.page_title')} ${widget.title}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
          : _history.isEmpty
              ? Center(child: Text(AppTranslations.t('misc.no_history'), style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final key = item['key'] ?? '';
                    final pct = (item['pct'] ?? 0.0).toDouble();
                    final usd = (item['dollar'] ?? 0.0).toDouble();
                    final c = pct >= 0 ? green : red;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Text(key, style: TextStyle(fontSize: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(textDirection: TextDirection.ltr, '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                              Text(textDirection: TextDirection.ltr, '${usd >= 0 ? '+' : ''}\$${usd.toStringAsFixed(2)}', style: TextStyle(fontSize: 10, color: c)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ================= TRADE DETAIL SCREEN =================
class TradeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> trade;
  final Color cardBg, borderColor, green, red, accent;
  final Color gold = const Color(0xFFf0b90b);

  const TradeDetailScreen({super.key, required this.trade, required this.cardBg, required this.borderColor, required this.green, required this.red, required this.accent});

  String _fmtNum(dynamic val, {int decimals = 4}) {
    double d = double.tryParse(val?.toString() ?? '0') ?? 0.0;
    return d.toStringAsFixed(decimals);
  }

  String _fmtDate(dynamic ts) {
    double v = double.tryParse(ts?.toString() ?? '0') ?? 0.0;
    if (v <= 0) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _kv(String k, String v, {Color? vColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(v, style: TextStyle(fontSize: 12, color: vColor ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sym = trade['symbol'] ?? 'UNKNOWN';
    final pnl = (trade['realized_profit_usdt'] ?? 0.0).toDouble();
    final isWin = pnl >= 0;
    final c = isWin ? green : red;
    
    final entry = (trade['entry'] ?? 0.0).toDouble();
    final sellPrice = (trade['sell_price'] ?? 0.0).toDouble();
    final qty = (trade['executed_qty'] ?? 0.0).toDouble();
    final fees = (trade['fees_deducted'] ?? 0.0).toDouble();
    
    final opened = trade['opened'] ?? trade['first_action'];
    final closed = trade['last_action'];
    final openedTs = double.tryParse(opened?.toString() ?? '0') ?? 0.0;
    final closedTs = double.tryParse(closed?.toString() ?? '0') ?? 0.0;
    final durationMin = (closedTs > openedTs) ? ((closedTs - openedTs) / 60).toStringAsFixed(1) : '0.0';
    final dcaSteps = trade['dca_steps'] ?? 0;
    final lifecycle = trade['lifecycle'] as List? ?? [];
    
    final netPnlPct = (trade['realized_profit_pct'] ?? 0.0);
    final grossPnlPct = (trade['gross_profit_pct'] ?? 0.0);

    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text('${AppTranslations.t('pos.trade_title_prefix')} $sym', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Card 1: Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                      radius: 12,
                      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                      child: ClipOval(
                        child: Image.network(
                          'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                          width: 24, height: 24, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8))),
                          ),
                        ),
                      ),
                    ),
                      const SizedBox(width: 8),
                      Text(sym, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                    ],
                  ),
                  Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                  _kv(AppTranslations.t('trade.net_pnl'), '\$${_fmtNum(pnl, decimals: 4)}', vColor: c),
                  _kv(AppTranslations.t('trade.net_pnl_pct'), '${isWin ? '+' : ''}${_fmtNum(netPnlPct, decimals: 2)}%', vColor: c),
                  _kv(AppTranslations.t('trade.gross_pnl_pct'), '${isWin ? '+' : ''}${_fmtNum(grossPnlPct, decimals: 2)}%', vColor: c),
                  _kv(AppTranslations.t('stat.fees'), '\$${_fmtNum(fees, decimals: 4)}', vColor: gold),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Card 2: Prices
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTranslations.t('trade.prices'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                  _kv(AppTranslations.t('trade.entry_avg'), '\$${_fmtNum(entry, decimals: 2)}'),
                  _kv(AppTranslations.t('trade.sell_price'), '\$${_fmtNum(sellPrice, decimals: 2)}'),
                  _kv(AppTranslations.t('trade.executed_qty'), _fmtNum(qty, decimals: 6)),
                  _kv(AppTranslations.t('trade.lifecycle_cost'), '\$${_fmtNum(entry * qty, decimals: 4)}'),
                  _kv(AppTranslations.t('trade.sell_value'), '\$${_fmtNum(sellPrice * qty, decimals: 4)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Card 3: Timing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTranslations.t('trade.timing'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                  _kv(AppTranslations.t('trade.opened'), _fmtDate(opened)),
                  _kv(AppTranslations.t('trade.closed'), _fmtDate(closed)),
                  _kv(AppTranslations.t('trade.duration'), '$durationMin mln'),
                  _kv(AppTranslations.t('trade.dca_executions'), '$dcaSteps'),
                ],
              ),
            ),
            
            // Card 4: Lifecycle
            if (lifecycle.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.t('trade.lifecycle'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                    ...lifecycle.map((ev) {
                      final action = ev['action'] ?? '?';
                      final price = double.tryParse(ev['price']?.toString() ?? '0') ?? 0.0;
                      final val = double.tryParse(ev['value']?.toString() ?? '0') ?? 0.0;
                      final stepQty = val > 0 && price > 0 ? val / price : 0.0;
                      return _kv(action, '${stepQty.toStringAsFixed(4)} @ \$${price.toStringAsFixed(2)} = \$${val.toStringAsFixed(2)}');
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MenuScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final String userId;
  const MenuScreen({super.key, required this.onLogout, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.title'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          FutureBuilder<String?>(
            future: SharedPreferences.getInstance().then((p) => p.getString('admin_backup_token')),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return _menuItem(
                  title: AppTranslations.t('admin.exit_impersonation'),
                  subtitle: AppTranslations.t('admin.return_to_admin'),
                  icon: Icons.arrow_back,
                  iconColor: const Color(0xFFef4444),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final adminToken = snapshot.data!;
                    await prefs.setString('auth_token', adminToken);
                    await prefs.remove('admin_backup_token');
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (c) => AuthGate(key: ValueKey('impersonate_${DateTime.now().millisecondsSinceEpoch}'))), (route) => false);
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _menuItem(title: AppTranslations.t('menu.submenu_explore'), subtitle: AppTranslations.t('menu.submenu_explore_sub'), icon: Icons.explore, iconColor: const Color(0xFFfbbf24), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SubMenuScreen(title: AppTranslations.t('menu.submenu_explore'), items: [
            SubMenuItem(title: AppTranslations.t('menu.search_asset'), subtitle: AppTranslations.t('menu.search_asset_sub'), icon: Icons.search, iconColor: const Color(0xFFfbbf24), route: const SearchAssetScreen()),
            SubMenuItem(title: AppTranslations.t('menu.active_universe'), subtitle: AppTranslations.t('menu.active_universe_sub'), icon: Icons.public, iconColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), route: const ActiveUniverseScreen()),
            SubMenuItem(title: AppTranslations.t('permanent.menu_title'), subtitle: AppTranslations.t('permanent.menu_sub'), icon: Icons.push_pin, iconColor: const Color(0xFFa78bfa), route: const PermanentAssetsScreen()),
            SubMenuItem(title: AppTranslations.t('menu.blocked_assets'), subtitle: AppTranslations.t('menu.blocked_assets_sub'), icon: Icons.block, iconColor: const Color(0xFFef4444), route: const BlockedAssetsScreen()),
          ])))),
          _menuItem(title: AppTranslations.t('menu.submenu_history'), subtitle: AppTranslations.t('menu.submenu_history_sub'), icon: Icons.receipt_long, iconColor: const Color(0xFF10b981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SubMenuScreen(title: AppTranslations.t('menu.submenu_history'), items: [
            SubMenuItem(title: AppTranslations.t('menu.trade_history'), subtitle: AppTranslations.t('menu.trade_history_sub'), icon: Icons.receipt_long, iconColor: const Color(0xFF10b981), route: StatDetailScreen(title: AppTranslations.t('dash.closed_trades'), data: const {}, token: '')),
            SubMenuItem(title: AppTranslations.t('menu.capital_events'), subtitle: AppTranslations.t('menu.capital_events_sub'), icon: Icons.account_balance, iconColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), route: StatDetailScreen(title: AppTranslations.t('menu.capital_events'), data: const {}, token: '')),
          ])))),
          _menuItem(title: AppTranslations.t('menu.submenu_analytics'), subtitle: AppTranslations.t('menu.submenu_analytics_sub'), icon: Icons.psychology, iconColor: const Color(0xFFa78bfa), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SubMenuScreen(title: AppTranslations.t('menu.submenu_analytics'), items: [
            SubMenuItem(title: AppTranslations.t('menu.experience'), subtitle: AppTranslations.t('menu.experience_sub'), icon: Icons.psychology, iconColor: const Color(0xFFa78bfa), route: const ExperienceScreen()),
            SubMenuItem(title: AppTranslations.t('menu.errors'), subtitle: AppTranslations.t('menu.errors_sub'), icon: Icons.bug_report, iconColor: const Color(0xFFef4444), route: const TechnicalErrorsScreen()),
          ])))),
          _menuItem(title: AppTranslations.t('menu.connect_binance_full'), subtitle: AppTranslations.t('menu.connect_binance_full_sub'), icon: Icons.link, iconColor: const Color(0xFF38bdf8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TradingSettingsScreen()))),
          _menuItem(title: AppTranslations.t('menu.submenu_account'), subtitle: AppTranslations.t('menu.submenu_account_sub'), icon: Icons.person, iconColor: const Color(0xFFa78bfa), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SubMenuScreen(title: AppTranslations.t('menu.submenu_account'), items: [
            SubMenuItem(title: AppTranslations.t('menu.submenu_account'), subtitle: AppTranslations.t('account.sub'), icon: Icons.person, iconColor: const Color(0xFFa78bfa), route: const MyAccountScreen()),
            SubMenuItem(title: AppTranslations.t('menu.settings'), subtitle: AppTranslations.t('menu.settings_sub'), icon: Icons.settings, iconColor: const Color(0xFF94a3b8), route: const AppSettingsScreen()),
          ])))),
          _menuItem(title: AppTranslations.t('support.title'), subtitle: AppTranslations.t('support.sub'), icon: Icons.help_outline, iconColor: const Color(0xFF38bdf8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SupportScreen()))),
          _menuItem(
            title: AppTranslations.t('subscription.title'),
            subtitle: AppTranslations.t('subscription.menu_sub'),
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFfbbf24),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SubscriptionScreen())),
          ),
          _menuItem(title: AppTranslations.t('menu.submenu_legal'), subtitle: AppTranslations.t('menu.submenu_legal_sub'), icon: Icons.gavel, iconColor: const Color(0xFF38bdf8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SubMenuScreen(title: AppTranslations.t('menu.submenu_legal'), items: [
            SubMenuItem(title: AppTranslations.t('legal.terms_title'), subtitle: AppTranslations.t('legal.terms_sub'), icon: Icons.gavel, iconColor: const Color(0xFF38bdf8), route: const TermsScreen()),
            SubMenuItem(title: AppTranslations.t('legal.privacy_title'), subtitle: AppTranslations.t('legal.privacy_sub'), icon: Icons.shield, iconColor: const Color(0xFFa78bfa), route: const PrivacyScreen()),
          ])))),
          if (userId == '556')
            _menuItem(title: AppTranslations.t('menu.admin_panel'), subtitle: AppTranslations.t('menu.admin_panel_sub'), icon: Icons.admin_panel_settings, iconColor: const Color(0xFFf59e0b), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DeveloperPanelScreen()))),
          _menuItem(
            title: AppTranslations.t('menu.logout'), 
            subtitle: AppTranslations.t('menu.logout_sub'), 
            icon: Icons.logout, 
            iconColor: const Color(0xFFef4444), 
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF1e293b) : Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    AppTranslations.t('menu.logout_confirm'),
                    style: TextStyle(
                      color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        AppTranslations.t('misc.no'),
                        style: TextStyle(
                          color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        onLogout();
                      },
                      child: Text(AppTranslations.t('misc.yes'), style: const TextStyle(color: Color(0xFFef4444), fontSize: 16)),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _menuItem({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white), borderRadius: BorderRadius.circular(9), border: Border.all(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)))),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 10.8, color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 18),
          ],
        ),
      ),
    );
  }
}

class SubMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget route;

  const SubMenuItem({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.route});
}

class SubMenuScreen extends StatelessWidget {
  final String title;
  final List<SubMenuItem> items;
  const SubMenuScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => item.route)),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white), borderRadius: BorderRadius.circular(9), border: Border.all(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)))),
              child: Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), shape: BoxShape.circle), child: Icon(item.icon, color: item.iconColor, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ])),
                  const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



// ================= SUPPORT SCREEN =================
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isSending = false;
  String _statusMsg = "";
  Color _statusColor = Colors.grey;

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      setState(() { _statusMsg = "Message is empty"; _statusColor = Colors.red; });
      return;
    }
    setState(() { _isSending = true; _statusMsg = "Sending..."; _statusColor = Colors.grey; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/support/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text}),
      );
      if (res.statusCode == 200) {
        setState(() { _statusMsg = "✓ Message sent. We'll reply soon."; _statusColor = const Color(0xFF10b981); _msgCtrl.clear(); });
      } else {
        setState(() { _statusMsg = "Failed to send. Please try again."; _statusColor = Colors.red; });
      }
    } catch (e) {
      setState(() { _statusMsg = "Error: $e"; _statusColor = Colors.red; });
    } finally {
      setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
    final inputBg = isDark ? const Color(0xFF1a2230) : const Color(0xFFf1f5f9);

    Widget contactRow(IconData icon, String label, String value, {String? url}) {
      return InkWell(
        onTap: url != null ? () => openUrl(url) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
          child: Row(
            children: [
              Icon(icon, size: 22, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 10, color: textMuted)),
                    Text(value, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (url != null) Icon(Icons.open_in_new, size: 16, color: accent),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('support.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.support_agent, color: accent, size: 22), const SizedBox(width: 8), Text(AppTranslations.t('support.contact'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14))]),
                const SizedBox(height: 12),
                contactRow(Icons.email, AppTranslations.t('support.email'), AppTranslations.t('legal.footer_contact'), url: 'mailto:transparancygo@gmail.com'),
                const SizedBox(height: 8),
                contactRow(Icons.send, AppTranslations.t('support.telegram'), '@TransparencyGoSupport_bot', url: 'https://t.me/TransparencyGoSupport_bot'),
                const SizedBox(height: 8),
                contactRow(Icons.campaign, AppTranslations.t('support.telegram_channel'), '@TransparencyGoChannel', url: 'https://t.me/TransparencyGoChannel'),
                const SizedBox(height: 8),
                contactRow(Icons.access_time, AppTranslations.t('support.hours'), AppTranslations.t('support.hours_value_short')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.mail_outline, color: accent, size: 22), const SizedBox(width: 8), Text(AppTranslations.t('support.message'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14))]),
                const SizedBox(height: 12),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: AppTranslations.t('support.message_hint'),
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_statusMsg, style: TextStyle(color: _statusColor, fontSize: 11)),
                    ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? const Color(0xFF0b1120) : Colors.white),
                      child: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppTranslations.t('support.send')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.menu_book, color: accent, size: 22), const SizedBox(width: 8), Text(AppTranslations.t('guide.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14))]),
                const SizedBox(height: 8),
                Text(AppTranslations.t('guide.short_desc'), style: TextStyle(fontSize: 11, color: textMuted)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UserGuideScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? const Color(0xFF0b1120) : Colors.white),
                  child: Text(AppTranslations.t('guide.open_btn')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(AppTranslations.t('support.faq'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _faqItem(AppTranslations.t('support.faq_q1'), AppTranslations.t('support.faq_a1'), cardBg, borderColor, textColor, textMuted),
          _faqItem(AppTranslations.t('support.faq_q2'), AppTranslations.t('support.faq_a2'), cardBg, borderColor, textColor, textMuted),
          _faqItem(AppTranslations.t('support.faq_q3'), AppTranslations.t('support.faq_a3'), cardBg, borderColor, textColor, textMuted),
          _faqItem(AppTranslations.t('support.faq_q4'), AppTranslations.t('support.faq_a4'), cardBg, borderColor, textColor, textMuted),
          _faqItem(AppTranslations.t('support.faq_q5'), AppTranslations.t('support.faq_a5'), cardBg, borderColor, textColor, textMuted),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _faqItem(String q, String a, Color cardBg, Color borderColor, Color textColor, Color textMuted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          Text(a, style: TextStyle(fontSize: 11, color: textMuted)),
        ],
      ),
    );
  }
}

// ================= USER GUIDE SCREEN =================
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);

    final sections = [
      {'h': AppTranslations.t('guide.s1_h'), 'b': AppTranslations.t('guide.s1_b')},
      {'h': AppTranslations.t('guide.s2_h'), 'b': AppTranslations.t('guide.s2_b')},
      {'h': AppTranslations.t('guide.s3_h'), 'b': AppTranslations.t('guide.s3_b')},
      {'h': AppTranslations.t('guide.s4_h'), 'b': AppTranslations.t('guide.s4_b')},
      {'h': AppTranslations.t('guide.s5_h'), 'b': AppTranslations.t('guide.s5_b')},
      {'h': AppTranslations.t('guide.s6_h'), 'b': AppTranslations.t('guide.s6_b')},
      {'h': AppTranslations.t('guide.s7_h'), 'b': AppTranslations.t('guide.s7_b')},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('guide.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.menu_book, color: accent, size: 22), const SizedBox(width: 8), Text(AppTranslations.t('guide.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 4),
                Text(AppTranslations.t('guide.sub'), style: TextStyle(fontSize: 10, color: textMuted, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...sections.map((sec) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sec['h']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
                const Divider(height: 16, color: Color(0xFF202d42)),
                Text(sec['b']!, style: TextStyle(fontSize: 11, color: textColor, height: 1.4)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  final String title;
  final String type;  // 'terms' or 'privacy'
  final String lastUpdated;
  final List<Map<String, String>> sections;
  final String? acceptNote;

  const LegalScreen({super.key, required this.title, required this.type, required this.lastUpdated, required this.sections, this.acceptNote});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final textMuted = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(type == 'terms' ? Icons.gavel : Icons.privacy_tip, color: accent, size: 22), const SizedBox(width: 8), Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 4),
                Text(lastUpdated, style: TextStyle(fontSize: 10, color: textMuted, fontStyle: FontStyle.italic)),
                if (acceptNote != null) ...[
                  const Divider(height: 20),
                  Text(acceptNote!, style: TextStyle(fontSize: 11, color: textMuted)),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...sections.map((sec) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sec['h']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
                const Divider(height: 16, color: Color(0xFF202d42)),
                Text(sec['b']!, style: TextStyle(fontSize: 11, color: textMuted, height: 1.4)),
              ],
            ),
          )),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('legal.footer_owner'), style: TextStyle(fontSize: 10, color: textMuted)),
                const SizedBox(height: 4),
                Image.asset('assets/images/snowflake.png', width: 12, height: 12),
                const SizedBox(height: 4),
                InkWell(onTap: () => openUrl('mailto:transparancygo@gmail.com'), child: Text(AppTranslations.t('legal.footer_contact'), style: TextStyle(fontSize: 10, color: accent))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return LegalScreen(
      title: AppTranslations.t('legal.terms_title'),
      type: 'terms',
      lastUpdated: AppTranslations.t('legal.last_updated'),
      acceptNote: AppTranslations.t('legal.accept_note'),
      sections: [
        {'h': AppTranslations.t('legal.terms_s1_h'), 'b': AppTranslations.t('legal.terms_s1_b')},
        {'h': AppTranslations.t('legal.terms_s2_h'), 'b': AppTranslations.t('legal.terms_s2_b')},
        {'h': AppTranslations.t('legal.terms_s3_h'), 'b': AppTranslations.t('legal.terms_s3_b')},
        {'h': AppTranslations.t('legal.terms_s4_h'), 'b': AppTranslations.t('legal.terms_s4_b')},
        {'h': AppTranslations.t('legal.terms_s5_h'), 'b': AppTranslations.t('legal.terms_s5_b')},
        {'h': AppTranslations.t('legal.terms_s6_h'), 'b': AppTranslations.t('legal.terms_s6_b')},
        {'h': AppTranslations.t('legal.terms_s7_h'), 'b': AppTranslations.t('legal.terms_s7_b')},
        {'h': AppTranslations.t('legal.terms_s8_h'), 'b': AppTranslations.t('legal.terms_s8_b')},
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return LegalScreen(
      title: AppTranslations.t('legal.privacy_title'),
      type: 'privacy',
      lastUpdated: AppTranslations.t('legal.last_updated'),
      sections: [
        {'h': AppTranslations.t('legal.privacy_s1_h'), 'b': AppTranslations.t('legal.privacy_s1_b')},
        {'h': AppTranslations.t('legal.privacy_s2_h'), 'b': AppTranslations.t('legal.privacy_s2_b')},
        {'h': AppTranslations.t('legal.privacy_s3_h'), 'b': AppTranslations.t('legal.privacy_s3_b')},
        {'h': AppTranslations.t('legal.privacy_s4_h'), 'b': AppTranslations.t('legal.privacy_s4_b')},
        {'h': AppTranslations.t('legal.privacy_s5_h'), 'b': AppTranslations.t('legal.privacy_s5_b')},
        {'h': AppTranslations.t('legal.privacy_s6_h'), 'b': AppTranslations.t('legal.privacy_s6_b')},
        {'h': AppTranslations.t('legal.privacy_s7_h'), 'b': AppTranslations.t('legal.privacy_s7_b')},
        {'h': AppTranslations.t('legal.privacy_s8_h'), 'b': AppTranslations.t('legal.privacy_s8_b')},
      ],
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(child: Text('$title Page\n(Content Coming Soon)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16))),
    );
  }
}



// ================= DEVELOPER PANEL SCREEN =================
class DeveloperPanelScreen extends StatefulWidget {
  const DeveloperPanelScreen({super.key});
  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _errorMsg = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/users'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _users = data['users'] ?? [];
          _isLoading = false;
        });
      } else if (res.statusCode == 403) {
        setState(() { _errorMsg = 'Access denied. Admin only.'; _isLoading = false; });
      } else {
        setState(() { _errorMsg = 'Failed to load users'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Error: $e'; _isLoading = false; });
    }
  }

    void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: gold, size: 24),
                  const SizedBox(width: 8),
                  Text(AppTranslations.t('admin.tools_title'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Divider(color: borderColor, height: 1),
            ListTile(
              leading: Icon(Icons.payments, color: green),
              title: Text(AppTranslations.t('admin.payment_approvals'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
              subtitle: Text(AppTranslations.t('admin.payment_approvals_sub'), style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const PendingPaymentsScreen())).then((_) => _fetchUsers());
              },
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Color(0xFFa78bfa)),
              title: Text(AppTranslations.t('global.title'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
              subtitle: Text(AppTranslations.t('global.menu_sub'), style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const GlobalPermanentAssetsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: accent),
              title: Text(AppTranslations.t('admin.wallet_settings'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
              subtitle: Text(AppTranslations.t('admin.wallet_settings_sub'), style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletSettingsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: accent),
              title: Text(AppTranslations.t('admin.refresh_users'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
              onTap: () {
                Navigator.pop(c);
                _fetchUsers();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
    return Scaffold(floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdminMenu(context),
        backgroundColor: gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.admin_panel_settings),
        label: Text(AppTranslations.t('admin.tools_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.admin_panel'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const _SystemAdminCard();
                    final u = _users[index - 1];                    final isSuspended = u['is_suspended'] ?? false;
                    final isRunning = u['is_running'] ?? u['bot_running'] ?? false;
                    return InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => UserDetailsScreen(
                          userId: u['id'],
                          username: u['username'],
                          email: u['email'],
                          isSuspended: isSuspended,
                          isRunning: isRunning,
                          balance: (u['balance'] ?? 0.0).toDouble(),
                          positions: u['positions'] ?? u['positions_count'] ?? 0,
                          isExempt: u['is_exempt'] == true,
                        ))).then((_) => _fetchUsers());
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: accent, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${u['username']} (ID: ${u['id']})', style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(isRunning ? AppTranslations.t('admin.bot_running') : AppTranslations.t('admin.bot_stopped'), style: TextStyle(color: isRunning ? green : Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('${AppTranslations.t('admin.balance')}: \$${(u['balance'] ?? 0.0).toStringAsFixed(2)}', style: TextStyle(color: accent, fontSize: 11)),
                                      const SizedBox(width: 10),
                                      Text('${AppTranslations.t('admin.positions')}: ${u['positions'] ?? u['positions_count'] ?? 0}', style: TextStyle(color: gold, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SystemAdminCard extends StatelessWidget {
  const _SystemAdminCard();
  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    const gold = Color(0xFFf0b90b);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SystemAdminPanelScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: gold, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTranslations.t('admin.system_admin_title'),
                    style: const TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(AppTranslations.t('admin.system_admin_sub'),
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accent, size: 24),
          ],
        ),
      ),
    );
  }
}

class SystemAdminPanelScreen extends StatefulWidget {
  const SystemAdminPanelScreen({super.key});
  @override
  State<SystemAdminPanelScreen> createState() => _SystemAdminPanelScreenState();
}

class _SystemAdminPanelScreenState extends State<SystemAdminPanelScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  bool _isBackupLoading = false;
  bool _isRestartLoading = false;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchStats() async {
    try {
      final t = await _token();
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/system/stats'), headers: {'Authorization': 'Bearer $t'});
      if (res.statusCode == 200) {
        setState(() { _stats = jsonDecode(res.body); _isLoading = false; });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _fmtUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '$d ${AppTranslations.plural('misc.days', d)}, ${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  Future<void> _takeBackup() async {
    setState(() => _isBackupLoading = true);
    try {
      final t = await _token();
      final res = await http.post(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/system/backup'), headers: {'Authorization': 'Bearer $t'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? AppTranslations.t('admin.backup_success') : AppTranslations.t('admin.backup_failed')),
        backgroundColor: res.statusCode == 200 ? green : red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.t('admin.backup_failed')), backgroundColor: red));
      }
    } finally {
      setState(() => _isBackupLoading = false);
    }
  }

  Future<void> _restartMacro() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(AppTranslations.t('admin.macro_restart_confirm'),
          style: TextStyle(color: themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a), fontWeight: FontWeight.bold)),
        content: Text(AppTranslations.t('admin.macro_restart_msg'),
          style: TextStyle(color: themeNotifier.value == ThemeMode.dark ? Colors.white70 : const Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTranslations.t('misc.cancel'), style: const TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTranslations.t('misc.confirm'), style: TextStyle(color: red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isRestartLoading = true);
    try {
      final t = await _token();
      await http.post(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/system/restart_macro'), headers: {'Authorization': 'Bearer $t'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.t('admin.macro_restarted')), backgroundColor: green));
      }
    } catch (_) {} finally {
      setState(() => _isRestartLoading = false);
    }
  }

  Future<void> _showLogs() async {
    try {
      final t = await _token();
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/system/logs'), headers: {'Authorization': 'Bearer $t'});
      final logs = res.statusCode == 200 ? (jsonDecode(res.body)['logs'] as List? ?? []) : <dynamic>[];
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardBg,
          title: Text(AppTranslations.t('admin.logs_title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite, height: 400,
            child: logs.isEmpty
              ? Center(child: Text(AppTranslations.t('admin.no_logs'), style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(logs[i].toString(),
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
                  ),
                ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTranslations.t('misc.close')))],
        ),
      );
    } catch (_) {}
  }

  Future<void> _showBlockAssetDialog() async {
    final assetController = TextEditingController();
    final token = await _token();
    
    // جلب القائمة الحالية
    List<dynamic> blockedList = [];
    try {
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/blocked_assets'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        blockedList = jsonDecode(res.body)['blocked_assets'] ?? [];
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cardBg,
          title: Text("Global Blocked Assets", style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: assetController,
                        decoration: const InputDecoration(labelText: "Asset (e.g., TRX)", isDense: true),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final sym = assetController.text.trim().toUpperCase();
                        if (sym.isEmpty) return;
                        assetController.clear();
                        final res = await http.post(
                          Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/block_asset'),
                          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                          body: jsonEncode({'asset': sym, 'block': true}),
                        );
                        if (res.statusCode == 200) {
                          setState(() => blockedList.add(sym));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                      child: const Text("Block", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Currently Blocked:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                blockedList.isEmpty 
                  ? const Text("None", style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: blockedList.map((item) {
                        // التعامل مع البيانات سواء كانت نص أو كائن
                        final sym = item is Map ? item['symbol'].toString() : item.toString();
                        return Chip(
                          label: Text(sym, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                          deleteIconColor: Colors.redAccent,
                          onDeleted: () async {
                            final res = await http.post(
                              Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/block_asset'),
                              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                              body: jsonEncode({'asset': sym, 'block': false}),
                            );
                            if (res.statusCode == 200) {
                              setState(() => blockedList.remove(item));
                            }
                          },
                        );
                      }).toList(),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  Future<void> _showGlobalSettingsDialog() async {
    // 1. جلب القيم الحالية من السيرفر
    String currentSize = "10";
    String currentPos = "1";
    String currentMinPos = "0";
    String currentMin = "10";
    String currentMax = "100";

    try {
      final t = await _token();
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/global_settings'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        currentSize = data['trade_size'].toString();
        currentPos = data['max_positions'].toString();
        currentMinPos = (data['min_open_positions'] ?? 0).toString();
        currentMin = (data['min_trade_size'] ?? 10.0).toString();
        currentMax = (data['max_trade_size'] ?? 100.0).toString();
      }
    } catch (_) {}

    if (!mounted) return;

    // 2. إنشاء الحقول بالقيم المجلوبة
    final sizeController = TextEditingController(text: currentSize);
    final posController = TextEditingController(text: currentPos);
    final minPosController = TextEditingController(text: currentMinPos);
    final minController = TextEditingController(text: currentMin);
    final maxController = TextEditingController(text: currentMax);

    // 3. عرض النافذة
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text("Global Trading Settings", style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: sizeController, decoration: const InputDecoration(labelText: "Default Trade Size (USDT)"), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: posController, decoration: const InputDecoration(labelText: "Max Open Positions"), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: minPosController, decoration: const InputDecoration(labelText: "Min Open Positions"), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: minController, decoration: const InputDecoration(labelText: "Min Trade Size (USDT)"), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: maxController, decoration: const InputDecoration(labelText: "Max Trade Size (USDT)"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final token = await _token();
              final res = await http.post(
                Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/global_settings'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: jsonEncode({
                  'trade_size': double.tryParse(sizeController.text) ?? 10.0,
                  'max_positions': int.tryParse(posController.text) ?? 1,
                  'min_open_positions': int.tryParse(minPosController.text) ?? 0,
                  'min_trade_size': double.tryParse(minController.text) ?? 10.0,
                  'max_trade_size': double.tryParse(maxController.text) ?? 100.0
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (res.statusCode == 200) {
                messenger.showSnackBar(const SnackBar(content: Text('Settings Saved!'), backgroundColor: Colors.green));
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('Failed to save settings'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _restartSystem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text("Restart System?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This will restart the dashboard, API, and all bots. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Restart", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final token = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/restart_system'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System is restarting...'), backgroundColor: Colors.orange));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to restart system'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: themeNotifier.value == ThemeMode.dark ? Colors.white70 : const Color(0xFF475569), fontSize: 13)),
        Text(value, style: TextStyle(color: themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('admin.system_admin_title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: accent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.dns, color: accent, size: 22),
                    const SizedBox(width: 8),
                    Text(AppTranslations.t('admin.system_admin_title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  Divider(color: borderColor, height: 20),
                  _statRow(AppTranslations.t('admin.cpu'), '${_stats['cpu'] ?? 0}%'),
                  _statRow(AppTranslations.t('admin.ram'), '${_stats['ram_percent'] ?? 0}% (${_stats['ram_used_gb'] ?? 0}GB / ${_stats['ram_total_gb'] ?? 0}GB)'),
                  _statRow(AppTranslations.t('admin.disk'), '${_stats['disk_percent'] ?? 0}% (${_stats['disk_used_gb'] ?? 0}GB / ${_stats['disk_total_gb'] ?? 0}GB)'),
                  _statRow(AppTranslations.t('admin.uptime'), _fmtUptime(_stats['uptime_seconds'] ?? 0)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppTranslations.t('admin.system_actions'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  Divider(color: borderColor, height: 20),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: _isBackupLoading ? null : _takeBackup,
                      icon: _isBackupLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download),
                      label: Text(AppTranslations.t('admin.take_backup'), style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: _isRestartLoading ? null : _restartMacro,
                      icon: _isRestartLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh),
                      label: Text(AppTranslations.t('admin.restart_macro'), style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showBlockAssetDialog(),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text("Block Assets", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showGlobalSettingsDialog(),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text("Global Settings", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _restartSystem(),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text("Restart System", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppTranslations.t('admin.system_logs'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  Divider(color: borderColor, height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _showLogs, icon: const Icon(Icons.list_alt),
                    label: Text(AppTranslations.t('admin.view_error_logs')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                ]),
              ),
            ]),
          ),
    );
  }
}

// ================= USER DETAILS SCREEN =================
class UserDetailsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String email;
  final bool isSuspended;
  final bool isRunning;
  final double balance;
  final int positions;
  final bool isExempt;

  const UserDetailsScreen({super.key, required this.userId, required this.username, required this.email, required this.isSuspended, required this.isRunning, required this.balance, required this.positions, this.isExempt = false});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late bool _isRunning;
  late bool _isSuspended;
  late bool _isExempt;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _isRunning = widget.isRunning;
    _isSuspended = widget.isSuspended;
    _isExempt = widget.isExempt;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> _confirmAction(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white,
        title: Text(title, style: TextStyle(
          color: themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a),
          fontWeight: FontWeight.bold,
        )),
        content: Text(message, style: TextStyle(
          color: themeNotifier.value == ThemeMode.dark ? Colors.white70 : const Color(0xFF475569),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.t('misc.cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTranslations.t('misc.confirm'), style: const TextStyle(color: Color(0xFFef4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleBot() async {
    if (_isBusy) return;
    // Confirm only when stopping (disabling action)
    if (_isRunning) {
      final confirmed = await _confirmAction(
        AppTranslations.t('admin.confirm_stop_bot_title'),
        AppTranslations.t('admin.confirm_stop_bot_msg').replaceAll('{username}', widget.username),
      );
      if (!confirmed) return;
    }
    setState(() => _isBusy = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/toggle_bot/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _isRunning = !_isRunning);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isRunning ? 'Bot Started' : 'Bot Stopped'), backgroundColor: const Color(0xFF10b981)),
        );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed'), backgroundColor: Color(0xFFef4444)),
        );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)),
      );
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleSuspend() async {
    if (_isBusy) return;
    // Confirm only when suspending (disabling action)
    if (!_isSuspended) {
      final confirmed = await _confirmAction(
        AppTranslations.t('admin.confirm_suspend_title'),
        AppTranslations.t('admin.confirm_suspend_msg').replaceAll('{username}', widget.username),
      );
      if (!confirmed) return;
    }
    setState(() => _isBusy = true);
    try {
      final token = await _getToken();
      final newState = !_isSuspended;
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/suspend/${widget.userId}?suspend=$newState'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _isSuspended = newState);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newState ? 'Suspended' : 'Unsuspended'), backgroundColor: const Color(0xFF10b981)),
        );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)),
      );
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

    Future<void> _toggleExempt() async {
    if (_isBusy) return;
    final confirmed = await _confirmAction(
      _isExempt ? 'Remove Exemption?' : 'Exempt from Subscription?',
      _isExempt
          ? '${widget.username} will be required to have a paid subscription to trade. Continue?'
          : '${widget.username} will be able to trade without a subscription. Continue?',
    );
    if (!confirmed) return;
    setState(() => _isBusy = true);
    try {
      final token = await _getToken();
      final newState = !_isExempt;
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/user/${widget.userId}/exempt'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'is_exempt': newState}),
      );
      if (res.statusCode == 200) {
        setState(() => _isExempt = newState);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newState ? 'User exempted from subscription' : 'Exemption removed'),
              backgroundColor: const Color(0xFF10b981),
            ),
          );
        }
      } else {
        if (mounted) {
          final d = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(d['detail'] ?? 'Failed'), backgroundColor: const Color(0xFFef4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)),
        );
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

Future<void> _showResetPasswordDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white,
        title: Text(AppTranslations.t('admin.reset_password_title')),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppTranslations.t('admin.new_password_label'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTranslations.t('misc.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTranslations.t('misc.confirm'), style: const TextStyle(color: Color(0xFFef4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.isEmpty) return;
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/reset_password/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'new_password': controller.text}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.statusCode == 200 ? 'Password reset' : 'Failed'),
          backgroundColor: res.statusCode == 200 ? const Color(0xFF10b981) : const Color(0xFFef4444),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)),
      );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white,
        title: Text(AppTranslations.t('admin.delete_account_title')),
        content: Text(AppTranslations.t('admin.delete_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTranslations.t('misc.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTranslations.t('admin.delete_btn'), style: const TextStyle(color: Color(0xFFef4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/delete_user/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFef4444)),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    const green = Color(0xFF10b981);
    const red = Color(0xFFef4444);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('admin.user_details'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.person, color: accent, size: 28), const SizedBox(width: 10), Text('${widget.username} (ID: ${widget.userId})', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 4),
                  Text(widget.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions Grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _actionBtn(AppTranslations.t('admin.login_as_user'), const Color(0xFF9c27b0), () async {
                  final prefs = await SharedPreferences.getInstance();
                  final oldToken = prefs.getString('auth_token') ?? '';
                  final res = await http.post(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/impersonate/${widget.userId}'), headers: {'Authorization': 'Bearer $oldToken'});
                  if (res.statusCode == 200) {
                    final newToken = jsonDecode(res.body)['token'];
                    await prefs.setString('admin_backup_token', oldToken);
                    await prefs.setString('auth_token', newToken);
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (c) => AuthGate(key: ValueKey('impersonate_${DateTime.now().millisecondsSinceEpoch}'))), (route) => false);
                    }
                  }
                }),
                _actionBtn(AppTranslations.t('admin.view_user_trades'), accent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => AdminUserTradesScreen(userId: widget.userId, username: widget.username)));
                }),
                _actionBtn(_isRunning ? AppTranslations.t('admin.force_stop_bot') : AppTranslations.t('admin.force_start_bot'), _isRunning ? red : green, _isBusy ? () {} : _toggleBot),
                _actionBtn(_isExempt ? AppTranslations.t('admin.remove_exempt') : AppTranslations.t('admin.exempt_from_sub'), _isExempt ? const Color(0xFF10b981) : const Color(0xFF00d9ff), _isBusy ? () {} : _toggleExempt),
                _actionBtn(_isSuspended ? AppTranslations.t('admin.unsuspend_account') : AppTranslations.t('admin.suspend_account'), const Color(0xFFf59e0b), _isBusy ? () {} : _toggleSuspend),
                _actionBtn(AppTranslations.t('admin.reset_password'), const Color(0xFFd32f2f), _showResetPasswordDialog),
                _actionBtn(AppTranslations.t('admin.delete_account'), const Color(0xFF7f0000), _confirmDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 160,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
      ),
    );
  }
}



// ================= ADMIN: USER TRADES SCREEN =================
class AdminUserTradesScreen extends StatefulWidget {
  final int userId;
  final String username;
  const AdminUserTradesScreen({super.key, required this.userId, required this.username});
  @override
  State<AdminUserTradesScreen> createState() => _AdminUserTradesScreenState();
}

class _AdminUserTradesScreenState extends State<AdminUserTradesScreen> {
  bool _loading = true;
  List<dynamic> _trades = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/user_trades/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() { _trades = jsonDecode(res.body)['trades'] ?? []; _loading = false; });
      } else {
        setState(() { _error = 'Failed (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    const green = Color(0xFF10b981);
    const red = Color(0xFFef4444);
    final border = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text('${widget.username} - ${AppTranslations.t('admin.trades_label')} (${_trades.length})', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : _trades.isEmpty
                  ? const Center(child: Text('No trades', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trades.length,
                      itemBuilder: (c, i) {
                        final t = _trades[i];
                        final sym = t['symbol'] ?? '?';
                        final pnl = (t['realized_profit_usdt'] ?? 0.0).toDouble();
                        final win = pnl >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                          child: Row(
                            children: [
                              Text(sym, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0f172a), fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('${win ? '+' : ''}\$${pnl.toStringAsFixed(4)}',
                                style: TextStyle(color: win ? green : red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ================= SEARCH ASSET SCREEN =================
class SearchAssetScreen extends StatefulWidget {
  const SearchAssetScreen({super.key});

  @override
  State<SearchAssetScreen> createState() => _SearchAssetScreenState();
}

class _SearchAssetScreenState extends State<SearchAssetScreen> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

  Future<void> _doSearch() async {
    String q = _searchCtrl.text.trim().toUpperCase();
    if (q.isEmpty) return;
    if (!q.contains('/')) q = '$q/USDT';

    setState(() { _isLoading = true; _error = ''; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token'};
      
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/search?symbol=$q'), headers: headers);
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['asset'] == null) {
          setState(() { _error = 'Asset not found'; _isLoading = false; });
        } else {
          setState(() { _isLoading = false; });
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (c) => AssetDetailsScreen(
            asset: data['asset'],
            experience: data['experience'],
            history: data['history'] ?? [],
          )));
        }
      } else {
        setState(() { _error = 'Failed to load data (Code: ${res.statusCode})'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('search.button'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTranslations.t('menu.search_asset'), style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                    decoration: InputDecoration(
                      hintText: AppTranslations.t('search.hint'),
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent, width: 2), borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _doSearch(),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
                  else if (_error.isNotEmpty)
                    Center(child: Text(_error, style: const TextStyle(color: Colors.red))),
                  Center(
                    child: ElevatedButton(
                      onPressed: _doSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(AppTranslations.t('search.button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ================= ASSET DETAILS SCREEN =================
class AssetDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  final Map<String, dynamic>? experience;
  final List<dynamic> history;

  const AssetDetailsScreen({super.key, required this.asset, this.experience, required this.history});

  @override
  State<AssetDetailsScreen> createState() => _AssetDetailsScreenState();
}

class _AssetDetailsScreenState extends State<AssetDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _fetchBlockStatus();
  }

  bool _isBlocked = false;
  bool _isCustomBlocked = false;
  bool _isGlobalBlocked = false;
  bool _isLoadingBlock = true;

  Future<void> _fetchBlockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final sym = widget.asset['symbol'] ?? 'UNKNOWN';
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/asset/block_status?symbol=$sym'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _isBlocked = data['is_blocked'] ?? false;
          _isCustomBlocked = data['is_custom'] ?? false;
          _isGlobalBlocked = data['is_global'] ?? false;
          _isLoadingBlock = false;
        });
      } else {
        setState(() => _isLoadingBlock = false);
      }
    } catch (e) {
      setState(() => _isLoadingBlock = false);
    }
  }

  Future<void> _toggleBlock() async {
    final newState = !_isBlocked;
    setState(() => _isBlocked = newState);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final sym = widget.asset['symbol'] ?? 'UNKNOWN';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/asset/block'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'symbol': sym, 'block': newState}),
      );
      if (res.statusCode == 200) {
        setState(() {
          _isCustomBlocked = newState;
          _isGlobalBlocked = false; // عند إلغاء الحظر، نتجاوز الحظر العالمي
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newState ? AppTranslations.t('search.asset_blocked_success') : AppTranslations.t('search.asset_unblocked_success')),
              backgroundColor: const Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() => _isBlocked = !newState);
      }
    } catch (e) {
      setState(() => _isBlocked = !newState);
    }
  }

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  String _fmtNum(dynamic val, {int decimals = 2}) {
    if (val == null) return '0';
    double d = double.tryParse(val.toString()) ?? 0.0;
    return d.toStringAsFixed(decimals);
  }

  String _fmtPrice(dynamic val) {
    if (val == null) return '\$0';
    double d = double.tryParse(val.toString()) ?? 0.0;
    if (d >= 1000000) return '\$${(d / 1000000).toStringAsFixed(0)},${(d % 1000000).toStringAsFixed(0).padLeft(6, '0')}';
    if (d >= 1000) return '\$${d.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return '\$${d.toStringAsFixed(2)}';
  }

  Widget _buildRow(String label, String value, {Color? valColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(color: valColor ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String symbol = widget.asset['symbol'] ?? 'UNKNOWN';
    String status = widget.asset['status'] ?? 'UNKNOWN';
    Color statusColor = status == 'ACTIVE' ? green : red;

    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text('${AppTranslations.t('misc.search_results')} $symbol', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Asset Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and Block button
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                        child: ClipOval(
                          child: Image.network(
                            'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${symbol.split('/')[0].toLowerCase()}.png',
                            width: 36, height: 36, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(symbol.isNotEmpty ? (symbol.split('/')[0].length > 3 ? symbol.split('/')[0].substring(0, 3) : symbol.split('/')[0]) : '?', style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(symbol, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Block button
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF141b28) : const Color(0xFFf1f5f9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isBlocked ? red : borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _isBlocked ? red.withOpacity(0.15) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.block, color: _isBlocked ? red : Colors.grey, size: 24),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isCustomBlocked 
                                    ? AppTranslations.t('search.asset_blocked_custom')
                                    : (_isGlobalBlocked ? AppTranslations.t('search.asset_blocked') : AppTranslations.t('search.block_asset_hint')),
                                style: TextStyle(fontSize: 11, color: _isBlocked ? red : (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoadingBlock ? null : _toggleBlock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              _isBlocked 
                                  ? (_isGlobalBlocked ? AppTranslations.t('search.unblock_asset') : AppTranslations.t('search.unblock_asset_custom'))
                                  : AppTranslations.t('search.block_asset'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow(AppTranslations.t('field.asset'), symbol),
                  _buildRow(AppTranslations.t('field.status'), status == 'SUSPENDED' ? AppTranslations.t('status.suspended') : (status == 'ACTIVE' ? AppTranslations.t('status.active') : status), valColor: statusColor),
                  _buildRow(AppTranslations.t('field.confidence'), '${_fmtNum(widget.asset['confidence_score'])}/100', valColor: green),
                  _buildRow(AppTranslations.t('field.health'), '${_fmtNum(widget.asset['health_score'])}/100', valColor: green),
                  _buildRow(AppTranslations.t('field.liquidity'), _fmtPrice(widget.asset['liquidity_24h'])),
                  _buildRow('${AppTranslations.t('dash.max')} DD', '-${_fmtNum(widget.asset['max_drawdown'])}%', valColor: red),
                  _buildRow(AppTranslations.t('field.current_dd'), '-${_fmtNum(widget.asset['current_drawdown'])}%', valColor: gold),
                  _buildRow(AppTranslations.t('field.dd_duration'), '${_fmtNum(widget.asset['current_dd_duration_days'])} days'),
                  _buildRow(AppTranslations.t('field.liquidity_trend'), widget.asset['liquidity_trend'] ?? 'N/A'),
                  _buildRow(AppTranslations.t('field.valid_exchanges'), '${widget.asset['valid_exchanges'] ?? 0}'),
                  _buildRow(AppTranslations.t('field.model'), '${widget.asset['model_version'] ?? 'N/A'}'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Trade Experience Card
            if (widget.experience != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.t('card.trade_experience'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                    _buildRow(AppTranslations.t('field.total_positions'), '${widget.experience!['total_positions'] ?? 0}'),
                    _buildRow(AppTranslations.t('field.wins_losses'), '${widget.experience!['winning_positions'] ?? 0} / ${widget.experience!['losing_positions'] ?? 0}'),
                    _buildRow(AppTranslations.t('field.total_net_pnl'), '\$${_fmtNum(widget.experience!['total_net_pnl'], decimals: 4)}', valColor: green),
                    _buildRow(AppTranslations.t('field.avg_pnl_trade'), '\$${_fmtNum(widget.experience!['avg_pnl'], decimals: 4)}', valColor: green),
                    _buildRow(AppTranslations.t('field.avg_hold'), '${_fmtNum(widget.experience!['avg_hold_minutes'], decimals: 1)} min'),
                    _buildRow(AppTranslations.t('field.avg_max_dca'), '${_fmtNum(widget.experience!['avg_dca_levels'])} / ${widget.experience!['max_dca_levels'] ?? 0}'),
                    _buildRow(AppTranslations.t('field.experience_score'), _fmtNum(widget.experience!['experience_score'], decimals: 4), valColor: const Color(0xFFa78bfa)),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Status History Card
            if (widget.history.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status History (${widget.history.length})', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                    ...widget.history.map((h) {
                      String oldSt = h['old_status'] ?? '';
                      String newSt = h['new_status'] ?? '';
                      String reason = h['reason'] ?? '';
                      double ts = double.tryParse(h['timestamp']?.toString() ?? '0') ?? 0;
                      String dateStr = '';
                      if (ts > 0) {
                        final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
                        dateStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$oldSt -> $newSt', style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                              ],
                            ),
                            if (reason.isNotEmpty)
                              Text(reason, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ================= ACTIVE UNIVERSE SCREEN =================

// ================= BLOCKED ASSETS SCREEN =================
class BlockedAssetsScreen extends StatefulWidget {
  const BlockedAssetsScreen({super.key});
  @override
  State<BlockedAssetsScreen> createState() => _BlockedAssetsScreenState();
}

class _BlockedAssetsScreenState extends State<BlockedAssetsScreen> {
  List<dynamic> _assets = [];
  bool _isLoading = true;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/blocked_assets'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _assets = d['blocked_assets'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed (${res.statusCode})'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _isLoading = false; });
    }
  }

  Future<void> _unblock(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/asset/block'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': symbol, 'block': false}),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.t('search.asset_unblocked_success')), backgroundColor: green),
        );
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.blocked_assets'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: accent))
        : _error.isNotEmpty
          ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
          : _assets.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, color: Colors.grey, size: 48),
                    const SizedBox(height: 12),
                    Text(AppTranslations.t('blocked.empty'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assets.length,
                itemBuilder: (context, i) {
                  final a = _assets[i];
                  final sym = a['symbol'] ?? '?';
                  final source = a['source'] ?? 'user';
                  Color sourceColor;
                  IconData sourceIcon;
                  String sourceText;
                  if (source == 'developer' || source == 'both') {
                    sourceColor = red;
                    sourceIcon = Icons.verified_user;
                    sourceText = AppTranslations.t('blocked.source_$source');
                  } else {
                    sourceColor = gold;
                    sourceIcon = Icons.person;
                    sourceText = AppTranslations.t('blocked.source_user');
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                          child: ClipOval(
                            child: Image.network(
                              'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.toLowerCase()}.png',
                              width: 28, height: 28, fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Center(child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(color: Color(0xFF38bdf8), fontWeight: FontWeight.bold, fontSize: 10))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$sym/USDT', style: TextStyle(color: themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 14)),
                              Row(children: [
                                Icon(sourceIcon, color: sourceColor, size: 11),
                                const SizedBox(width: 3),
                                Text(sourceText, style: TextStyle(color: sourceColor, fontSize: 10)),
                              ]),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unblock(sym),
                          style: TextButton.styleFrom(foregroundColor: green, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          child: Text(AppTranslations.t('blocked.unblock'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

class ActiveUniverseScreen extends StatefulWidget {
  const ActiveUniverseScreen({super.key});

  @override
  State<ActiveUniverseScreen> createState() => _ActiveUniverseScreenState();
}

class _ActiveUniverseScreenState extends State<ActiveUniverseScreen> {
  List<dynamic> _assets = [];
  bool _isLoading = true;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

  @override
  void initState() {
    super.initState();
    _fetchUniverse();
  }

  Future<void> _fetchUniverse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/active_universe'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _assets = data['assets'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed to load (Code: ${res.statusCode})'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  String _formatAdmitted(dynamic ts) {
    if (ts == null) return 'N/A';
    double v = double.tryParse(ts.toString()) ?? 0.0;
    if (v <= 0) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _openAssetDetails(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/search?symbol=$symbol'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['asset'] != null) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (c) => AssetDetailsScreen(
            asset: data['asset'],
            experience: data['experience'],
            history: data['history'] ?? [],
          )));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.active_universe'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${_assets.length} ${AppTranslations.plural('menu.active_assets_unit', _assets.length)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    ..._assets.map((a) {
                      String sym = a['symbol'] ?? '';
                      double conf = double.tryParse(a['confidence_score'].toString()) ?? 0.0;
                      double health = double.tryParse(a['health_score'].toString()) ?? 0.0;
                      double priority = double.tryParse(a['priority'].toString()) ?? 0.0;
                      double exp = double.tryParse(a['experience_score'].toString()) ?? 0.0;
                      String admitted = _formatAdmitted(a['admitted_at']);

                      return InkWell(
                        onTap: () => _openAssetDetails(sym),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                                child: ClipOval(
                                  child: Image.network(
                                    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].trim().toLowerCase()}.png',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF38bdf8), fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sym, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(textDirection: TextDirection.ltr, 'CS ${conf.toStringAsFixed(2)} · HS ${health.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                    Text('Admitted $admitted', style: const TextStyle(color: Color(0xFF475569), fontSize: 9)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(textDirection: TextDirection.ltr, priority.toStringAsFixed(2), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(textDirection: TextDirection.ltr, 'exp ${exp.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 16),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}


// ================= EXPERIENCE SCREEN =================
class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  List<dynamic> _exps = [];
  bool _isLoading = true;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/experience'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() {
          _exps = jsonDecode(res.body)['experiences'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed to load data'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  String _fmtDate(dynamic ts) {
    double v = double.tryParse(ts?.toString() ?? '0') ?? 0.0;
    if (v <= 0) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _kv(String k, String v, {Color? vColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(v, style: TextStyle(fontSize: 11, color: vColor ?? (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.experience'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${_exps.length} ${AppTranslations.plural('misc.assets_tracked_suffix', _exps.length)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    ..._exps.map((e) {
                      String sym = e['symbol'] ?? 'UNKNOWN';
                      double score = double.tryParse(e['experience_score']?.toString() ?? '0') ?? 0.0;
                      int total = int.tryParse(e['total_positions']?.toString() ?? '0') ?? 0;
                      int wins = int.tryParse(e['winning_positions']?.toString() ?? '0') ?? 0;
                      int losses = int.tryParse(e['losing_positions']?.toString() ?? '0') ?? 0;
                      double wr = double.tryParse(e['win_rate']?.toString() ?? '0') ?? 0.0;
                      double avgPnl = double.tryParse(e['avg_pnl']?.toString() ?? '0') ?? 0.0;
                      double netPnl = double.tryParse(e['total_net_pnl']?.toString() ?? '0') ?? 0.0;
                      double avgHold = double.tryParse(e['avg_hold_minutes']?.toString() ?? '0') ?? 0.0;
                      double avgDca = double.tryParse(e['avg_dca_levels']?.toString() ?? '0') ?? 0.0;
                      int maxDca = int.tryParse(e['max_dca_levels']?.toString() ?? '0') ?? 0;
                      double avgCap = double.tryParse(e['avg_capital_locked']?.toString() ?? '0') ?? 0.0;
                      int tp = int.tryParse(e['tp_count']?.toString() ?? '0') ?? 0;
                      int sl = int.tryParse(e['sl_count']?.toString() ?? '0') ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                                  child: ClipOval(
                                    child: Image.network(
                                      'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/${sym.split('/')[0].toLowerCase()}.png',
                                      width: 24, height: 24, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Text(sym.isNotEmpty ? (sym.split('/')[0].length > 3 ? sym.split('/')[0].substring(0, 3) : sym.split('/')[0]) : '?', style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sym, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(textDirection: TextDirection.ltr, 'score ${score.toStringAsFixed(4)}', style: const TextStyle(color: Color(0xFFa78bfa), fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 16),
                            _kv(AppTranslations.t('admin.positions'), '$total'),
                            _kv(AppTranslations.t('field.wins_losses'), '$wins / $losses', vColor: wins > 0 ? green : red),
                            _kv(AppTranslations.t('field.win_rate'), '${wr.toStringAsFixed(1)}%', vColor: wr >= 50 ? green : Colors.orange),
                            _kv(AppTranslations.t('field.avg_pnl_trade'), '\$${avgPnl.toStringAsFixed(4)}', vColor: avgPnl >= 0 ? green : red),
                            _kv(AppTranslations.t('field.total_net_pnl'), '\$${netPnl.toStringAsFixed(4)}', vColor: netPnl >= 0 ? green : red),
                            _kv(AppTranslations.t('field.avg_hold'), '${avgHold.toStringAsFixed(1)} min'),
                            _kv(AppTranslations.t('field.avg_max_dca'), '${avgDca.toStringAsFixed(2)} / $maxDca'),
                            _kv(AppTranslations.t('field.avg_capital_locked'), '\$${avgCap.toStringAsFixed(2)}'),
                            _kv(AppTranslations.t('field.tp_sl'), '$tp / $sl'),
                            _kv(AppTranslations.t('field.updated'), _fmtDate(e['last_updated'])),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

// ================= TECHNICAL ERRORS SCREEN =================
class TechnicalErrorsScreen extends StatefulWidget {
  const TechnicalErrorsScreen({super.key});

  @override
  State<TechnicalErrorsScreen> createState() => _TechnicalErrorsScreenState();
}

class _TechnicalErrorsScreenState extends State<TechnicalErrorsScreen> {
  List<dynamic> _errors = [];
  bool _isLoading = true;
  String _errorMsg = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/errors'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() {
          _errors = jsonDecode(res.body)['errors'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _errorMsg = AppTranslations.t('errors.failed_load'); _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMsg = AppTranslations.t('errors.connection_error'); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.errors'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _errors.length,
                  itemBuilder: (context, index) {
                    String raw = _errors[index]['raw'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(raw, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 11))),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}


// ================= TRADING SETTINGS SCREEN =================
class TradingSettingsScreen extends StatefulWidget {
  const TradingSettingsScreen({super.key});

  @override
  State<TradingSettingsScreen> createState() => _TradingSettingsScreenState();
}

class _TradingSettingsScreenState extends State<TradingSettingsScreen> {
  double _tradeSize = 10.0;
  double _maxPositions = 5.0;
  bool _isLoading = true;
  bool _isSaving = false;
  
  bool _botRunning = false;
  bool _binanceConnected = false;
  String _binanceLabel = '';
  String _binanceMasked = '';
  
  // Form Controllers for Binance Connect
  final _apiKeyCtrl = TextEditingController();
  final _apiSecretCtrl = TextEditingController();
  final _labelCtrl = TextEditingController(text: 'Default');
  bool _isConnecting = false;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final headers = {'Authorization': 'Bearer $token'};

      final resSettings = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/trading/settings'), headers: headers);
      if (resSettings.statusCode == 200) {
        final data = jsonDecode(resSettings.body);
        setState(() {
          _tradeSize = (data['trade_size_usdt'] ?? 10.0).toDouble();
          _maxPositions = (data['max_open_positions'] ?? 5).toDouble();
        });
      }

      final resBot = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/bot/status'), headers: headers);
      if (resBot.statusCode == 200) {
        setState(() => _botRunning = jsonDecode(resBot.body)['is_running'] ?? false);
      }

      final resBinance = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/binance/status'), headers: headers);
      if (resBinance.statusCode == 200) {
        final data = jsonDecode(resBinance.body);
        setState(() {
          _binanceConnected = data['connected'] ?? false;
          if (_binanceConnected) {
            _binanceLabel = data['label'] ?? '';
            _binanceMasked = data['masked'] ?? '';
          }
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Connection error');
    }
  }

  Future<void> _connectBinance() async {
    if (_apiKeyCtrl.text.isEmpty || _apiSecretCtrl.text.isEmpty) {
      _showSnack('Please fill all fields');
      return;
    }
    setState(() => _isConnecting = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/binance/connect'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': _apiKeyCtrl.text.trim(),
          'secret': _apiSecretCtrl.text.trim(),
          'label': _labelCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        _showSnack('Binance Connected Successfully!', isSuccess: true);
        _fetchAllData(); // Refresh page
      } else {
        final data = jsonDecode(res.body);
        _showSnack(data['detail'] ?? 'Failed to connect');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
    setState(() => _isConnecting = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/trading/settings'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'trade_size_usdt': _tradeSize, 'max_open_positions': _maxPositions}),
      );
      if (res.statusCode == 200) {
        _showSnack('Settings saved successfully!', isSuccess: true);
      } else {
        _showSnack('Failed to save settings');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
    setState(() => _isSaving = false);
  }

  Future<void> _toggleBot() async {
    if (_botRunning) {
      // إظهار نافذة تأكيد قبل إيقاف البوت
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: cardBg,
          title: Text(AppTranslations.t('bot.stop'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
          content: Text(AppTranslations.t('bot.stop_confirm'), style: const TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(AppTranslations.t('common.cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(AppTranslations.t('misc.stop'), style: TextStyle(color: red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final token = await _getToken();
      final endpoint = _botRunning ? '/api/bot/stop' : '/api/bot/start';
      final res = await http.post(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000$endpoint'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() => _botRunning = !_botRunning); // تحديث فوري للواجهة
        _showSnack(_botRunning ? AppTranslations.t('admin.force_stop_msg') : AppTranslations.t('admin.force_start_msg'), isSuccess: true);
        // تأخير بسيط للسماح للباك إند بإنهاء العملية قبل تحديث البيانات
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) _fetchAllData(); // تحديث باقي البيانات في الخلفية
      } else {
        _showSnack('Failed to toggle bot');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
  }

  Future<void> _disconnectBinance() async {
    final pwdController = TextEditingController();
    
    bool obscure = true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: cardBg,
            title: Text(AppTranslations.t('bot.binance_disconnect'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('bot.binance_disconnect_confirm'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: pwdController,
                  obscureText: obscure,
                  style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                  decoration: InputDecoration(
                    hintText: AppTranslations.t('auth.password'),
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setStateDialog(() => obscure = !obscure),
                    ),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(AppTranslations.t('common.cancel'), style: const TextStyle(color: Colors.grey))),
              TextButton(onPressed: () => Navigator.pop(c, true), child: Text(AppTranslations.t('bot.disconnect'), style: TextStyle(color: red, fontWeight: FontWeight.bold))),
            ],
          );
        }
      ),
    );
    
    if (confirm != true) return;

    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/binance/disconnect'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'password': pwdController.text}),
      );
      
      if (res.statusCode == 200) {
        _showSnack('Binance disconnected successfully', isSuccess: true);
        _fetchAllData();
      } else {
        final errorData = jsonDecode(res.body);
        _showSnack(errorData['detail'] ?? 'Failed to disconnect');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)))),
      backgroundColor: isSuccess ? green : red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('menu.connect_binance_full'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2))))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_binanceConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: const Color(0xFF2c1d00), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 8),
                            Text("Connect Binance First", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text("You need to connect your Binance account before configuring trading settings", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  // --- Connect Form ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link, color: accent, size: 24),
                            const SizedBox(width: 8),
                            Text("Connect Binance Account", style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text("Enter API keys from your Binance account. Required permissions: Spot Trading + Read.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyCtrl,
                          style: TextStyle(fontSize: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                          decoration: InputDecoration(
                            labelText: "API Key",
                            labelStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiSecretCtrl,
                          obscureText: true,
                          style: TextStyle(fontSize: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                          decoration: InputDecoration(
                            labelText: "Secret Key",
                            labelStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _labelCtrl,
                          style: TextStyle(fontSize: 12, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                          decoration: InputDecoration(
                            labelText: "Label",
                            labelStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectBinance,
                            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                            child: _isConnecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Connect Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                // Settings Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppTranslations.t('admin.trade_size'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(AppTranslations.t('trading.trade_size_desc'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _tradeSize,
                              min: 5, max: 100, divisions: 19,
                              activeColor: accent,
                              onChanged: (v) => setState(() => _tradeSize = v),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(border: Border.all(color: accent), borderRadius: BorderRadius.circular(6)),
                            child: Text('${_tradeSize.toInt()}', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(AppTranslations.t('dash.max_open_positions'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(AppTranslations.t('dash.max_positions_desc'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _maxPositions,
                              min: 0, max: 20, divisions: 20,
                              activeColor: accent,
                              onChanged: (v) => setState(() => _maxPositions = v),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(border: Border.all(color: accent), borderRadius: BorderRadius.circular(6)),
                            child: Text('${_maxPositions.toInt()}', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveSettings,
                            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                            child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppTranslations.t('trading.save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                final t = prefs.getString('auth_token') ?? '';
                                if (!context.mounted) return;
                                if (!mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final res = await http.get(
                                  Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/trading/defaults'),
                                  headers: {'Authorization': 'Bearer $t'},
                                );
                                if (!context.mounted) return;
                                if (res.statusCode == 200) {
                                  final data = jsonDecode(res.body);
                                  setState(() {
                                    _tradeSize = (data['trade_size_usdt'] ?? 10.0).toDouble();
                                    _maxPositions = (data['max_open_positions'] ?? 1).toDouble();
                                  });
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Reset to Global Defaults'), backgroundColor: Colors.blue)
                                  );
                                }
                              } catch (e) {
                                if (kDebugMode) debugPrint("Error resetting defaults: $e");
                              }
                            },
                            child: Text(AppTranslations.t('trading.reset'), style: const TextStyle(color: Colors.grey)),
                          ),
                        ],
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: _fetchAllData,
                          icon: Icon(Icons.refresh, color: accent, size: 16),
                          label: Text(AppTranslations.t('dash.refresh'), style: TextStyle(color: accent)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Binance Connection Section
                Row(
                  children: [
                    Icon(Icons.link, color: green, size: 20),
                    const SizedBox(width: 8),
                    Text(AppTranslations.t('binance.page_title'), style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Bot Status
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _botRunning ? green : borderColor)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(_botRunning ? Icons.play_circle : Icons.stop_circle, color: _botRunning ? green : red, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_botRunning ? AppTranslations.t('admin.bot_running') : AppTranslations.t('admin.bot_stopped'), style: TextStyle(color: _botRunning ? green : red, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(_botRunning ? AppTranslations.t('bot.working_now') : 'Currently idle', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _toggleBot,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _botRunning ? red : green, 
                              foregroundColor: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(_botRunning ? AppTranslations.t('bot.stop') : AppTranslations.t('bot.start'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ], // End of if (_binanceConnected)

                // Binance Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _binanceConnected ? green : borderColor)),
                  child: _binanceConnected
                      ? Column(
                          children: [
                            Icon(Icons.check_circle, color: green, size: 40),
                            const SizedBox(height: 8),
                            Text(AppTranslations.t('binance.connected'), style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 15)),
                            Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 24),
                            Text('${AppTranslations.t('misc.api_key_label')}: $_binanceMasked', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('${AppTranslations.t('misc.label_label')}: $_binanceLabel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _disconnectBinance,
                              icon: Icon(Icons.link_off, color: red, size: 16),
                              label: Text(AppTranslations.t('binance.disconnect'), style: TextStyle(color: red)),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(Icons.link_off, color: red, size: 40),
                            const SizedBox(height: 8),
                            Text(AppTranslations.t('bot.binance_not_connected'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            // هنا يمكن إضافة زر الاتصال لاحقاً
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}


// ================= MY ACCOUNT SCREEN =================
class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});
  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final bool _isImpersonating = false;
  Map<String, dynamic> _account = {};
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  String _error = '';

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  bool _isChangingPass = false;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color red = const Color(0xFFef4444);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    double v = double.tryParse(ts.toString()) ?? 0.0;
    if (v <= 0) return 'N/A';
    // If timestamp is in milliseconds
    if (v > 100000000000) v = v / 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchData() async {
    try {
      final token = await _getToken();
      final headers = {'Authorization': 'Bearer $token'};
      
      final resAcc = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/account'), headers: headers);
      if (resAcc.statusCode == 200) _account = jsonDecode(resAcc.body);

      final resSess = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/account/sessions'), headers: headers);
      if (resSess.statusCode == 200) _sessions = jsonDecode(resSess.body)['sessions'] ?? [];

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      _showSnack(AppTranslations.t('account.err_passwords_mismatch'));
      return;
    }
    setState(() => _isChangingPass = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/account/change_password'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'current_password': _oldPassCtrl.text, 'new_password': _newPassCtrl.text}),
      );
      if (res.statusCode == 200) {
        _showSnack('Password updated successfully', isSuccess: true);
        _oldPassCtrl.clear(); _newPassCtrl.clear(); _confPassCtrl.clear();
      } else {
        final d = jsonDecode(res.body);
        _showSnack(d['detail'] ?? 'Failed to update password');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
    setState(() => _isChangingPass = false);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isSuccess ? Colors.green : red));
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(v, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _passField(String hint, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: toggle),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(backgroundColor: cardBg, leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)), title: Text(AppTranslations.t('menu.submenu_account'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold))),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))) : _error.isNotEmpty ? Center(child: Text(_error, style: const TextStyle(color: Colors.red))) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.person, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('account.profile'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                  Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                  _kv(AppTranslations.t('account.username'), _account['username'] ?? 'N/A'),
                  _kv(AppTranslations.t('support.email'), _account['email'] ?? 'N/A'),
                  _kv(AppTranslations.t('account.user_id'), '${_account['id'] ?? 'N/A'}'),
                  _kv(AppTranslations.t('account.member_since'), _formatDate(_account['created_at'])),
                  _kv(AppTranslations.t('account.last_login'), _formatDate(_account['last_login'])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Change Password Card (hidden in impersonation)
            if (!_isImpersonating) Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.lock, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('account.change_password'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 16),
                  _passField(AppTranslations.t('account.current_password'), _oldPassCtrl, _obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
                  _passField(AppTranslations.t('account.new_password'), _newPassCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                  _passField(AppTranslations.t('account.confirm_password'), _confPassCtrl, _obscureConf, () => setState(() => _obscureConf = !_obscureConf)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isChangingPass ? null : _changePassword,
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: _isChangingPass ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppTranslations.t('account.update_password'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(AppTranslations.t('account.warning_logout'), style: const TextStyle(color: Colors.orange, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Sessions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.devices, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('account.sessions_title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                  Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                  Text(AppTranslations.t('account.sessions_sub'), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ActiveSessionsScreen(sessions: _sessions))),
                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                    child: Text(AppTranslations.t('account.sessions_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= APP SETTINGS SCREEN =================
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notifEnabled = true;
  bool _notifBuy = true;
  bool _notifSell = true;
  bool _notifDca = true;
  bool _notifErrors = true;
  final _chatIdCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetchSettings() async {
    try {
      final token = await _getToken();
      final res = await http.get(Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/notifications'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _notifEnabled = d['notifications_enabled'] == 1;
          _notifBuy = d['notify_buy'] == 1;
          _notifSell = d['notify_sell'] == 1;
          _notifDca = d['notify_dca'] == 1;
          _notifErrors = d['notify_errors'] == 1;
          _chatIdCtrl.text = d['telegram_chat_id'] ?? '';
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load notification settings: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/notifications'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'notifications_enabled': _notifEnabled ? 1 : 0,
          'notify_buy': _notifBuy ? 1 : 0,
          'notify_sell': _notifSell ? 1 : 0,
          'notify_dca': _notifDca ? 1 : 0,
          'notify_errors': _notifErrors ? 1 : 0,
          'telegram_chat_id': _chatIdCtrl.text,
        }),
      );
      if (res.statusCode == 200) {
        _showSnack('Settings saved successfully', isSuccess: true);
      } else {
        _showSnack('Failed to save settings');
      }
    } catch (e) {
      _showSnack('Connection error');
    }
    setState(() => _isSaving = false);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isSuccess ? Colors.green : Colors.red));
  }

  Widget _switchTile(String title, bool value, Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(children: [Icon(icon, color: Colors.blue, size: 20), const SizedBox(width: 10), Text(title, style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontSize: 13))]),
      value: value,
      activeColor: accent,
      activeTrackColor: const Color(0xFF1e3a8a),
      onChanged: onChanged,
    );
  }


  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101722) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTranslations.t('settings.language'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0f172a), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildLangOption(ctx, 'en', 'English'),
              _buildLangOption(ctx, 'fr', 'Français'),
              _buildLangOption(ctx, 'ar', 'العربية'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLangOption(BuildContext ctx, String code, String label) {
    final isSelected = languageNotifier.value == code;
    final isDark = themeNotifier.value == ThemeMode.dark;
    return ListTile(
      onTap: () async {
        setState(() { languageNotifier.value = code; });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_language', code);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      title: Text(label, style: TextStyle(color: isSelected ? (isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)) : (isDark ? Colors.white : const Color(0xFF0f172a)), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle, color: isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(backgroundColor: cardBg, leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)), title: Text(AppTranslations.t('menu.settings'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold))),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.palette_outlined, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('settings.appearance'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dark_mode, color: accent, size: 20),
                        const SizedBox(width: 10),
                        Text(AppTranslations.t('settings.dark_mode'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Switch(
                      value: themeNotifier.value == ThemeMode.dark,
                      activeColor: accent,
                      activeTrackColor: const Color(0xFF1e3a8a),
                      onChanged: (v) {
                        setState(() {
                          themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                        });
                        // ننتظر 150 مللي ثانية ليرى المستخدم حركة الزر، ثم نعود للرئيسية مثل Flet
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Language Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.language, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('settings.language'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showLanguagePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)), borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageNotifier.value == 'ar'
                            ? 'العربية'
                            : (languageNotifier.value == 'fr' ? 'Français' : 'English'),
                          style: TextStyle(
                            color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: accent, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.telegram, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('support.telegram'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 10),
                Text(AppTranslations.t('settings.telegram_hint'), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 10),
                TextField(
                  controller: _chatIdCtrl,
                  style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                  decoration: InputDecoration(
                    hintText: AppTranslations.t('settings.chat_id'),
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38bdf8), foregroundColor: Colors.black), child: Text(AppTranslations.t('settings.copy_command'))),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), child: Text(AppTranslations.t('settings.save_chat_id'))),
                  ],
                ),
                const SizedBox(height: 8),
                Center(child: Text(AppTranslations.t('telegram.command_hint'), style: const TextStyle(color: Colors.grey, fontSize: 9))),
                Center(child: Text(AppTranslations.t('telegram.copy_command'), style: TextStyle(color: accent, fontSize: 10))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.notifications, color: accent, size: 20), const SizedBox(width: 8), Text(AppTranslations.t('settings.notifications'), style: TextStyle(color: accent, fontWeight: FontWeight.bold))]),
                Divider(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0)), height: 20),
                _switchTile(AppTranslations.t('settings.enable_notifications'), _notifEnabled, (v) => setState(() => _notifEnabled = v), Icons.notifications_active),
                _switchTile(AppTranslations.t('settings.buy_alerts'), _notifBuy, (v) => setState(() => _notifBuy = v), Icons.trending_up),
                _switchTile(AppTranslations.t('settings.sell_alerts'), _notifSell, (v) => setState(() => _notifSell = v), Icons.trending_down),
                _switchTile(AppTranslations.t('settings.dca_alerts'), _notifDca, (v) => setState(() => _notifDca = v), Icons.sync),
                _switchTile(AppTranslations.t('settings.error_alerts'), _notifErrors, (v) => setState(() => _notifErrors = v), Icons.error_outline),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppTranslations.t('settings.save_settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}


// ================= ACTIVE SESSIONS SCREEN =================
class ActiveSessionsScreen extends StatefulWidget {
  final List<dynamic> sessions;
  const ActiveSessionsScreen({super.key, required this.sessions});
  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);

  Future<void> _revokeSession(int sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/account/sessions/revoke'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': sessionId}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t('account.session_revoked')), backgroundColor: Colors.green));
           Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.t('account.revoke_failed')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(backgroundColor: cardBg, leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)), title: Text(AppTranslations.t('account.sessions_title'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.sessions.asMap().entries.map((entry) {
            int idx = entry.key;
            var s = entry.value;
            bool isCurrent = idx == 0; // Assume the first one is the current session
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isCurrent ? green : borderColor)),
              child: Row(
                children: [
                  Icon(isCurrent ? Icons.phone_android : Icons.phone_iphone, color: isCurrent ? green : Colors.grey, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isCurrent ? AppTranslations.t('account.current_session') : AppTranslations.t('account.other_session'), style: TextStyle(color: isCurrent ? green : (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a)), fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${DateTime.fromMillisecondsSinceEpoch((s['created_at'] * 1000).toInt())}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (!isCurrent)
                    TextButton(
                      onPressed: () => _revokeSession(s['id']),
                      child: Text(AppTranslations.t('account.revoke'), style: TextStyle(color: red)),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => _revokeSession(-1), // -1 means all others (we can implement this in backend later)
              style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
              child: Text(AppTranslations.t('account.revoke_all')),
            ),
          ),
        ],
      ),
    );
  }
}


// ================= REGISTER SCREEN =================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  bool _obscurePass = true;

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

  Future<void> _register() async {
    if (_usernameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = AppTranslations.t('auth.err_passwords_mismatch'));
      return;
    }

    setState(() { _isLoading = true; _error = ''; });

    try {
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      );
      
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (c) => OtpVerificationScreen(email: _emailCtrl.text.trim()),
          ));
        }
      } else {
        setState(() => _error = data['detail'] ?? AppTranslations.t('auth.err_register_failed'));
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('auth.register_link'), style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)), fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ac_unit, size: 60, color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
              const SizedBox(height: 10),
              Text(AppTranslations.t('auth.create_account'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2)))),
              const SizedBox(height: 40),
              
              TextField(
                controller: _usernameCtrl,
                style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                decoration: InputDecoration(
                  labelText: AppTranslations.t('account.username'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardBg,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _emailCtrl,
                style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                decoration: InputDecoration(
                  labelText: AppTranslations.t('support.email'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardBg,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                decoration: InputDecoration(
                  labelText: AppTranslations.t('auth.password'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardBg,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: (themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a))),
                decoration: InputDecoration(
                  labelText: AppTranslations.t('auth.confirm_password'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardBg,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ==========================================
// OTP VERIFICATION SCREEN (Added by Audit)
// ==========================================
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpCtrl = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter the OTP');
      return;
    }
    setState(() { _isLoading = true; _error = ''; });

    try {
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp': _otpCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified successfully! You can login now.'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(res.body);
        setState(() => _error = data['detail'] ?? 'Invalid OTP');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // ألوان ثابتة لتطابق التصميم الداكن
    const Color bgColor = Color(0xFF0B1120);
    const Color textColor = Colors.white;
    const Color accent = Color(0xFF00d9ff);
    const Color cardBg = Color(0xFF1e293b);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: const Text('Verify Email', style: TextStyle(color: textColor)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read, size: 80, color: accent),
            const SizedBox(height: 24),
            Text(
              'We sent a verification code to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter OTP',
                hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 1, fontSize: 16),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// SUBSCRIPTION SCREEN (Phase 5A — read-only)
// ============================================================
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic> _info = {};
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchSubscription();
  }

  Future<void> _fetchSubscription() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/subscription/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _info = jsonDecode(res.body) ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load subscription (HTTP ${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
      case 'trial':
        return const Color(0xFF10b981);
      case 'grace':
        return const Color(0xFFf59e0b);
      case 'exempt':
        return const Color(0xFFa78bfa);
      case 'expired':
      case 'cancelled':
        return const Color(0xFFef4444);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return AppTranslations.t('subscription.status_active');
      case 'trial': return AppTranslations.t('subscription.status_trial');
      case 'grace': return AppTranslations.t('subscription.status_grace');
      case 'expired': return AppTranslations.t('subscription.status_expired');
      case 'cancelled': return AppTranslations.t('subscription.status_cancelled');
      case 'exempt': return AppTranslations.t('subscription.status_exempt');
      default: return AppTranslations.t('subscription.status_none');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.t('subscription.title'),
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: accent),
            onPressed: _fetchSubscription,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error, style: TextStyle(color: textColor), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSubscription,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _info['has_subscription'] == true
                                ? Icons.workspace_premium
                                : Icons.card_membership,
                            size: 56,
                            color: _statusColor(_info['status']?.toString() ?? 'none'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusLabel(_info['status']?.toString() ?? 'none'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(_info['status']?.toString() ?? 'none'),
                            ),
                          ),
                          if (_info['plan_name'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${AppTranslations.t('subscription.plan_prefix')}: ${_info['plan_name']}',
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_info['has_subscription'] == true) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            _kvRow(AppTranslations.t('subscription.days_remaining'), _info['is_exempt'] == true ? AppTranslations.t('subscription.unlimited') : '${_info['days_left'] ?? 0}', textColor, accent),
                            Divider(color: borderColor, height: 24),
                            _kvRow(
                              AppTranslations.t('subscription.can_open_trades'),
                              _info['can_buy'] == true ? AppTranslations.t('common.yes') : AppTranslations.t('common.no'),
                              textColor,
                              _info['can_buy'] == true ? const Color(0xFF10b981) : const Color(0xFFef4444),
                            ),
                            if (_info['expires_at'] != null) ...[
                              Divider(color: borderColor, height: 24),
                              _kvRow(AppTranslations.t('subscription.expires_at'), _formatExpiry(_info['expires_at']), textColor, textColor),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_info['has_subscription'] != true ||
                        _info['status'] == 'expired' ||
                        _info['status'] == 'grace' ||
                        _info['status'] == 'cancelled')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.workspace_premium, color: accent, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              AppTranslations.t('subscription.subscribe_monthly'),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppTranslations.t('subscription.subscribe_monthly_desc'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (c) => const PaymentScreen()),
                                  );
                                  if (result == true) {
                                    _fetchSubscription();
                                  }
                                },
                                icon: const Icon(Icons.payment),
                                label: Text(AppTranslations.t('subscription.subscribe_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _kvRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor.withOpacity(0.7), fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  String _formatExpiry(dynamic ts) {
    if (ts == null) return 'N/A';
    final d = DateTime.fromMillisecondsSinceEpoch((double.parse(ts.toString()) * 1000).toInt());
    return '${d.day}/${d.month}/${d.year}';
  }
}


// ============================================================
// PAYMENT SCREEN (Phase 5B)
// ============================================================
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic> _wallet = {};
  List<dynamic> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  final _txHashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _txHashCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final headers = {'Authorization': 'Bearer $token'};

      final resWallet = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/subscription/wallet'),
        headers: headers,
      );
      final resPlans = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/subscription/plans'),
        headers: headers,
      );

      if (resWallet.statusCode == 200 && resPlans.statusCode == 200) {
        final walletData = jsonDecode(resWallet.body);
        final plansData = jsonDecode(resPlans.body);

        // فلترة الخطط المدفوعة فقط
        final allPlans = (plansData['plans'] as List? ?? []);
        final paidPlans = allPlans
            .where((p) => ((p['price_usdt'] ?? 0) as num) > 0)
            .toList();

        setState(() {
          _wallet = Map<String, dynamic>.from(walletData['wallet'] ?? {});
          _plans = paidPlans;
          if (_plans.isNotEmpty) {
            _selectedPlan = Map<String, dynamic>.from(_plans[0]);
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load payment info (wallet: ${resWallet.statusCode}, plans: ${resPlans.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyAddress() async {
    final addr = _wallet['address']?.toString() ?? '';
    if (addr.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: addr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied'), backgroundColor: Colors.green),
    );
  }

  Future<void> _submit() async {
    if (_selectedPlan == null) {
      setState(() => _error = 'Please select a plan');
      return;
    }
    if (_txHashCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter Transaction Hash');
      return;
    }

    setState(() { _isSubmitting = true; _error = ''; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/subscription/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'plan_id': _selectedPlan!['id'],
          'tx_hash': _txHashCtrl.text.trim(),
          'user_note': _noteCtrl.text.trim(),
          'method': 'binance_pay',
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment request submitted. Awaiting admin review.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(res.body);
        setState(() {
          _error = data['detail'] ?? 'Failed to submit payment';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppTranslations.t('payment.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Plan selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppTranslations.t('payment.select_plan'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      ..._plans.map((p) {
                        final isSelected = _selectedPlan?['id'] == p['id'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPlan = Map<String, dynamic>.from(p)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? accent.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? accent : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name']?.toString() ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('${p['duration_days']} ${AppTranslations.t('payment.days_suffix')}', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Text('\$${(p['price_usdt'] as num).toStringAsFixed(2)}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Wallet
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Text(AppTranslations.t('payment.send_payment_to'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _wallet['address']?.toString() ?? 'N/A',
                                style: TextStyle(color: textColor, fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy, color: accent, size: 18),
                              onPressed: _copyAddress,
                              tooltip: 'Copy',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppTranslations.t('payment.network_label')} (${_wallet['currency'] ?? 'USDT'})',
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // TX Hash
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppTranslations.t('payment.paste_tx_hash'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _txHashCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: AppTranslations.t('payment.tx_hash_hint'),
                          hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteCtrl,
                        style: TextStyle(color: textColor),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: AppTranslations.t('payment.note_hint'),
                          hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(AppTranslations.t('payment.submit_request'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}


// ============================================================
// PENDING PAYMENTS SCREEN (Phase 5C)
// ============================================================
class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});
  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  List<dynamic> _payments = [];
  bool _isLoading = true;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  Color get textColor => themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/payments/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() { _payments = jsonDecode(res.body)['payments'] ?? []; _isLoading = false; });
      } else {
        setState(() { _error = 'Failed: ${res.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _isLoading = false; });
    }
  }

  Future<void> _verify(int paymentId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Verify Payment?'),
        content: Text('Activate subscription for $username?\n\nOnly do this after confirming the payment in Binance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: green),
            child: const Text('Verify & Activate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _action('verify', paymentId, '');
  }

  Future<void> _reject(int paymentId, String username) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reject Payment from $username?'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason (required)', hintText: 'e.g., Wrong amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c, ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _action('reject', paymentId, reason);
  }

  Future<void> _action(String action, int paymentId, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/payments/$action'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'payment_id': paymentId, 'reason': reason}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment $action successful'), backgroundColor: green),
        );
        _fetch();
      } else {
        final d = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(d['detail'] ?? 'Failed'), backgroundColor: red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('admin.pending_title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: accent), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : _payments.isEmpty
                  ? Center(child: Text(AppTranslations.t('admin.no_pending'), style: TextStyle(color: textColor.withOpacity(0.6))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (c, i) {
                        final p = _payments[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment, color: accent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${p['username']} (ID: ${p['user_id']})',
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Text('\$${p['amount_usdt']}', style: TextStyle(color: green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _row(AppTranslations.t('admin.plan_label'), p['plan_name']?.toString() ?? '?'),
                              _row(AppTranslations.t('admin.method_label'), p['method']?.toString() ?? '?'),
                              _row(AppTranslations.t('admin.tx_hash_label'), p['tx_hash']?.toString() ?? '(none)'),
                              if (p['user_note'] != null && p['user_note'].toString().isNotEmpty)
                                _row(AppTranslations.t('admin.user_note_label'), p['user_note'].toString()),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _verify(p['id'], p['username']?.toString() ?? '?'),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: Text(AppTranslations.t('admin.verify')),
                                      style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _reject(p['id'], p['username']?.toString() ?? '?'),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: Text(AppTranslations.t('admin.reject')),
                                      style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
          Expanded(
            child: Text(value, style: TextStyle(color: textColor, fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WALLET SETTINGS SCREEN (Phase 5C)
// ============================================================
class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});
  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  Map<String, dynamic> _wallet = {};
  final _addrCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  Color get textColor => themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a);
  final Color green = const Color(0xFF10b981);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/subscription/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final w = jsonDecode(res.body)['wallet'] ?? {};
        setState(() {
          _wallet = Map<String, dynamic>.from(w);
          _addrCtrl.text = _wallet['address']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed: ${res.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _isLoading = false; });
    }
  }

  Future<void> _save() async {
    if (_addrCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Address cannot be empty');
      return;
    }
    if (_addrCtrl.text.toUpperCase().startsWith('PLACEHOLDER')) {
      setState(() => _error = 'Please enter a real Binance Pay ID');
      return;
    }

    setState(() { _isSaving = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/wallet/update'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'wallet_id': _wallet['id'], 'new_address': _addrCtrl.text.trim()}),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Wallet updated successfully'), backgroundColor: green),
        );
        Navigator.pop(context);
      } else {
        final d = jsonDecode(res.body);
        setState(() { _error = d['detail'] ?? 'Failed'; _isSaving = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('admin.wallet_settings'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Text(AppTranslations.t('admin.binance_pay_id'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addrCtrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: AppTranslations.t('admin.wallet_hint'),
                            hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                            filled: true,
                            fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.t('admin.wallet_desc'),
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(AppTranslations.t('admin.save_address'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


// ============================================================
// PERMANENT ASSETS SCREEN (Phase B)
// ============================================================
class PermanentAssetsScreen extends StatefulWidget {
  const PermanentAssetsScreen({super.key});

  @override
  State<PermanentAssetsScreen> createState() => _PermanentAssetsScreenState();
}

class _PermanentAssetsScreenState extends State<PermanentAssetsScreen> {
  List<dynamic> _assets = [];
  List<dynamic> _removed = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String _error = '';

  final _symbolCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final t = await _token();
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/permanent_assets'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _assets = data['assets'] ?? [];
          _removed = data['removed'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'HTTP ${res.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  Future<void> _add() async {
    String sym = _symbolCtrl.text.trim().toUpperCase();
    final reason = _reasonCtrl.text.trim();
    if (sym.isEmpty || reason.isEmpty) {
      _snack(AppTranslations.t('permanent.symbol_reason_required'), error: true);
      return;
    }
    // Accept bare symbols like BTC, ETH, BNB → auto-append /USDT
    if (!sym.contains('/')) {
      if (sym.endsWith('USDT') && sym.length > 4) {
        // User typed BTCUSDT (Binance style) → BTC/USDT
        sym = '${sym.substring(0, sym.length - 4)}/USDT';
      } else {
        // User typed BTC → BTC/USDT
        sym = '$sym/USDT';
      }
    }
    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/permanent_assets/add'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': sym, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _symbolCtrl.clear();
        _reasonCtrl.clear();
        _snack('$sym ${AppTranslations.t('permanent.added_success')}');
        _fetch();
      } else {
        final d = jsonDecode(res.body);
        _snack(d['detail'] ?? 'Failed to add', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _remove(String symbol) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppTranslations.t('permanent.remove_title').replaceAll('{symbol}', symbol)),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: AppTranslations.t('global.reason_required'),
            hintText: AppTranslations.t('permanent.remove_reason_hint'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(c, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/permanent_assets/remove'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': symbol, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _snack('$symbol removed');
        _fetch();
      } else {
        final d = jsonDecode(res.body);
        _snack(d['detail'] ?? 'Failed to remove', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFef4444) : const Color(0xFF10b981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc);
    final cardBg = isDark ? const Color(0xFF101722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final accent = isDark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
    const muted = Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppTranslations.t('permanent.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        titleTextStyle: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: accent), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ===== Add form =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_circle_outline, color: accent, size: 20),
                              const SizedBox(width: 8),
                              Text(AppTranslations.t('permanent.add_asset'), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _symbolCtrl,
                            style: TextStyle(color: textColor),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: AppTranslations.t('permanent.symbol'),
                              hintText: AppTranslations.t('permanent.symbol_hint'),
                              labelStyle: const TextStyle(color: muted),
                              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonCtrl,
                            style: TextStyle(color: textColor),
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: AppTranslations.t('permanent.reason'),
                              hintText: AppTranslations.t('permanent.reason_hint'),
                              labelStyle: const TextStyle(color: muted),
                              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF080d14) : const Color(0xFFf8fafc),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isBusy ? null : _add,
                              icon: const Icon(Icons.add),
                              label: Text(AppTranslations.t('permanent.add_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== Current assets =====
                    Text(
                      '${AppTranslations.t('permanent.your_assets')} (${_assets.length})',
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (_assets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Text(AppTranslations.t('permanent.no_assets'), style: const TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
                      )
                    else
                      ..._assets.map((a) {
                        final sym = a['symbol']?.toString() ?? '?';
                        final by = a['added_by']?.toString() ?? '?';
                        final reason = a['reason']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.push_pin, color: accent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(sym, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFef4444), size: 20),
                                    onPressed: _isBusy ? null : () => _remove(sym),
                                    tooltip: 'Remove',
                                  ),
                                ],
                              ),
                              Text('${AppTranslations.t('permanent.added_by')}: $by', style: const TextStyle(color: muted, fontSize: 11)),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('${AppTranslations.t('permanent.reason_label')}: $reason', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
                              ],
                            ],
                          ),
                        );
                      }),

                    // ===== Removed (history) =====
                    if (_removed.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        '${AppTranslations.t('permanent.recently_removed')} (${_removed.length})',
                        style: const TextStyle(color: muted, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ..._removed.reversed.map((a) {
                        final sym = a['symbol']?.toString() ?? '?';
                        final by = a['removed_by']?.toString() ?? '?';
                        final reason = a['removal_reason']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sym, style: const TextStyle(color: muted, fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.lineThrough)),
                              Text('${AppTranslations.t('permanent.removed_by')}: $by', style: const TextStyle(color: muted, fontSize: 10)),
                              if (reason.isNotEmpty)
                                Text('Reason: $reason', style: const TextStyle(color: muted, fontSize: 10)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
    );
  }
}


// ============================================================
// ADMIN PERMANENT ASSETS SCREEN (Phase 6C)
// ============================================================
class AdminPermanentAssetsScreen extends StatefulWidget {
  final int userId;
  final String username;
  const AdminPermanentAssetsScreen({super.key, required this.userId, required this.username});
  @override
  State<AdminPermanentAssetsScreen> createState() => _AdminPermanentAssetsScreenState();
}

class _AdminPermanentAssetsScreenState extends State<AdminPermanentAssetsScreen> {
  List<dynamic> _assets = [];
  List<dynamic> _removed = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String _error = '';

  final _symbolCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  Color get textColor => themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a);
  final Color muted = Colors.grey;
  final Color red = const Color(0xFFef4444);
  final Color green = const Color(0xFF10b981);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final t = await _token();
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/user/${widget.userId}/permanent_assets'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _assets = data['assets'] ?? [];
          _removed = data['removed'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'HTTP ${res.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  Future<void> _add() async {
    String sym = _symbolCtrl.text.trim().toUpperCase();
    final reason = _reasonCtrl.text.trim();
    if (sym.isEmpty || reason.isEmpty) {
      _snack(AppTranslations.t('permanent.symbol_reason_required'), error: true);
      return;
    }
    if (!sym.contains('/')) {
      sym = sym.endsWith('USDT') && sym.length > 4
          ? '${sym.substring(0, sym.length - 4)}/USDT'
          : '$sym/USDT';
    }
    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/user/${widget.userId}/permanent_assets/add'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': sym, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _symbolCtrl.clear();
        _reasonCtrl.clear();
        _snack('$sym added to user ${widget.username}');
        _fetch();
      } else {
        final d = jsonDecode(res.body);
        _snack(d['detail'] ?? 'Failed', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _remove(String symbol) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove $symbol?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'Admin justification',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(c, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/user/${widget.userId}/permanent_assets/remove'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': symbol, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _snack('$symbol removed');
        _fetch();
      } else {
        final d = jsonDecode(res.body);
        _snack(d['detail'] ?? 'Failed', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? red : green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text('Permanent Assets — ${widget.username}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [IconButton(icon: Icon(Icons.refresh, color: accent), onPressed: _fetch)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.add_circle_outline, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Text('Add for ${widget.username}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _symbolCtrl,
                            style: TextStyle(color: textColor),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Symbol',
                              hintText: 'BTC (or BTC/USDT)',
                              labelStyle: TextStyle(color: muted),
                              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                              filled: true,
                              fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonCtrl,
                            style: TextStyle(color: textColor),
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Reason',
                              hintText: 'Admin justification (e.g. user requested)',
                              labelStyle: TextStyle(color: muted),
                              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                              filled: true,
                              fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isBusy ? null : _add,
                              icon: const Icon(Icons.add),
                              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Current Assets (${_assets.length})', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_assets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Text(AppTranslations.t('permanent.no_assets'), style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
                      )
                    else
                      ..._assets.map((a) {
                        final sym = a['symbol']?.toString() ?? '?';
                        final by = a['added_by']?.toString() ?? '?';
                        final reason = a['reason']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.push_pin, color: accent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(sym, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: red, size: 20),
                                  onPressed: _isBusy ? null : () => _remove(sym),
                                  tooltip: 'Remove',
                                ),
                              ]),
                              Text('${AppTranslations.t('permanent.added_by')}: $by', style: TextStyle(color: muted, fontSize: 11)),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('${AppTranslations.t('permanent.reason_label')}: $reason', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
                              ],
                            ],
                          ),
                        );
                      }),
                    if (_removed.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Recently Removed (${_removed.length})', style: TextStyle(color: muted, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._removed.reversed.map((a) {
                        final sym = a['symbol']?.toString() ?? '?';
                        final by = a['removed_by']?.toString() ?? '?';
                        final reason = a['removal_reason']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: cardBg.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor.withOpacity(0.5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sym, style: TextStyle(color: muted, fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.lineThrough)),
                              Text('${AppTranslations.t('permanent.removed_by')}: $by', style: TextStyle(color: muted, fontSize: 10)),
                              if (reason.isNotEmpty) Text('${AppTranslations.t('permanent.removal_reason')}: $reason', style: TextStyle(color: muted, fontSize: 10)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
    );
  }
}


// ============================================================
// GLOBAL PERMANENT ASSETS (Admin)
// ============================================================
class GlobalPermanentAssetsScreen extends StatefulWidget {
  const GlobalPermanentAssetsScreen({super.key});
  @override
  State<GlobalPermanentAssetsScreen> createState() => _GlobalPermanentAssetsScreenState();
}

class _GlobalPermanentAssetsScreenState extends State<GlobalPermanentAssetsScreen> {
  List<dynamic> _assets = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String _error = '';
  final _symbolCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Color get cardBg => themeNotifier.value == ThemeMode.dark ? const Color(0xFF101722) : Colors.white;
  Color get borderColor => themeNotifier.value == ThemeMode.dark ? const Color(0xFF202d42) : const Color(0xFFe2e8f0);
  Color get accent => themeNotifier.value == ThemeMode.dark ? const Color(0xFF00d9ff) : const Color(0xFF0891b2);
  Color get textColor => themeNotifier.value == ThemeMode.dark ? Colors.white : const Color(0xFF0f172a);
  final Color muted = Colors.grey;
  final Color red = const Color(0xFFef4444);
  final Color green = const Color(0xFF10b981);
  final Color violet = const Color(0xFFa78bfa);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final t = await _token();
      final res = await http.get(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/global_permanent_assets'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _assets = jsonDecode(res.body)['assets'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'HTTP ${res.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  Future<void> _add() async {
    String sym = _symbolCtrl.text.trim().toUpperCase();
    final reason = _reasonCtrl.text.trim();
    if (sym.isEmpty || reason.isEmpty) {
      _snack(AppTranslations.t('permanent.symbol_reason_required'), error: true);
      return;
    }
    if (!sym.contains('/')) {
      sym = sym.endsWith('USDT') && sym.length > 4
          ? '${sym.substring(0, sym.length - 4)}/USDT'
          : '$sym/USDT';
    }
    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/global_permanent_assets/add'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': sym, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _symbolCtrl.clear();
        _reasonCtrl.clear();
        _snack('$sym ${AppTranslations.t('global.nominated_success')}');
        _fetch();
      } else {
        _snack(jsonDecode(res.body)['detail'] ?? 'Failed', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _remove(String symbol) async {
    final rc = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppTranslations.t('global.remove_title').replaceAll('{symbol}', symbol)),
        content: TextField(
          controller: rc,
          decoration: InputDecoration(labelText: AppTranslations.t('global.reason_required')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (rc.text.trim().isEmpty) return;
              Navigator.pop(c, rc.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final t = await _token();
      final res = await http.post(
        Uri.parse('https://ubuntu-4gb-hel1-2.tail7f4de4.ts.net:10000/api/admin/global_permanent_assets/remove'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'symbol': symbol, 'reason': reason}),
      );
      if (res.statusCode == 200) {
        _snack('$symbol removed from global nominations');
        _fetch();
      } else {
        _snack(jsonDecode(res.body)['detail'] ?? 'Failed', error: true);
      }
    } catch (e) {
      _snack(AppTranslations.t('permanent.connection_error'), error: true);
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? red : green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: accent), onPressed: () => Navigator.pop(context)),
        title: Text(AppTranslations.t('global.title'), style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        titleTextStyle: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [IconButton(icon: Icon(Icons.refresh, color: accent), onPressed: _fetch)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: violet.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: violet),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: violet, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppTranslations.t('global.info'),
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.add_circle_outline, color: violet, size: 20),
                            const SizedBox(width: 8),
                            Text(AppTranslations.t('global.nominate_asset'), style: TextStyle(color: violet, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _symbolCtrl,
                            style: TextStyle(color: textColor),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Symbol',
                              hintText: 'BTC (or BTC/USDT)',
                              labelStyle: TextStyle(color: muted),
                              filled: true,
                              fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonCtrl,
                            style: TextStyle(color: textColor),
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: AppTranslations.t('permanent.reason'),
                              hintText: AppTranslations.t('global.nominate_hint'),
                              labelStyle: TextStyle(color: muted),
                              filled: true,
                              fillColor: (themeNotifier.value == ThemeMode.dark ? const Color(0xFF080d14) : const Color(0xFFf8fafc)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isBusy ? null : _add,
                              icon: const Icon(Icons.add),
                              label: Text(AppTranslations.t('global.nominate_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: violet,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('${AppTranslations.t('global.currently_nominated')} (${_assets.length})', style: TextStyle(color: violet, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_assets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Text(AppTranslations.t('global.no_nominations'), style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
                      )
                    else
                      ..._assets.map((a) {
                        final sym = a['symbol']?.toString() ?? '?';
                        final by = a['added_by']?.toString() ?? '?';
                        final reason = a['reason']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.public, color: violet, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(sym, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: red, size: 20),
                                  onPressed: _isBusy ? null : () => _remove(sym),
                                  tooltip: 'Remove',
                                ),
                              ]),
                              Text('${AppTranslations.t('global.nominated_by')}: $by', style: TextStyle(color: muted, fontSize: 11)),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('${AppTranslations.t('permanent.reason_label')}: $reason', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}

