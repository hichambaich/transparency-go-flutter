import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// --- الألوان ---
const Color bgColor = Color(0xFF080d14);
const Color cardColor = Color(0xFF101722);
const Color accentColor = Color(0xFF00d9ff);
const Color borderColor = Color(0xFF202d42);
const Color textPrimary = Color(0xFFe2e8f0);
const Color textSecondary = Color(0xFF94a3b8);
const Color greenColor = Color(0xFF10b981);
const Color redColor = Color(0xFFef4444);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  String? email = prefs.getString('saved_email');
  String? password = prefs.getString('saved_password');
  
  runApp(TransparencyApp(initialToken: token, savedEmail: email, savedPassword: password));
}

class TransparencyApp extends StatelessWidget {
  final String? initialToken;
  final String? savedEmail;
  final String? savedPassword;
  const TransparencyApp({super.key, this.initialToken, this.savedEmail, this.savedPassword});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMARTWALLET',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        appBarTheme: const AppBarTheme(backgroundColor: bgColor, foregroundColor: accentColor),
        drawerTheme: const DrawerThemeData(backgroundColor: cardColor),
      ),
      home: initialToken != null && initialToken!.isNotEmpty
          ? const MainLayout()
          : LoginScreen(savedEmail: savedEmail, savedPassword: savedPassword),
    );
  }
}

// ==========================================
// 1. شاشة الدخول (Login)
// ==========================================
class LoginScreen extends StatefulWidget {
  final String? savedEmail;
  final String? savedPassword;
  const LoginScreen({super.key, this.savedEmail, this.savedPassword});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _rememberMe = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.savedEmail ?? '');
    _passwordController = TextEditingController(text: widget.savedPassword ?? '');
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final response = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'password': _passwordController.text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('username', data['username']);
        if (_rememberMe) {
          await prefs.setString('saved_email', _emailController.text.trim());
          await prefs.setString('saved_password', _passwordController.text);
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
      } else {
        setState(() { _errorMsg = 'Invalid credentials'; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❄️', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              const Text('TRANSPARENCY GO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 2.0)),
              const SizedBox(height: 4),
              const Text('by smart solutions.py', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 30),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Checkbox(value: _rememberMe, activeColor: accentColor, onChanged: (val) => setState(() => _rememberMe = val ?? true)),
                    const Text('Remember Me', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ]),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                    child: const Text('Forgot Password?', style: TextStyle(color: accentColor, fontSize: 12)),
                  )
                ],
              ),
              if (_errorMsg.isNotEmpty) Text(_errorMsg, style: const TextStyle(color: redColor)),
              const SizedBox(height: 10),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: accentColor, foregroundColor: Colors.black),
                child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                child: const Text("Don't have an account? Register", style: TextStyle(color: textSecondary)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// (شاشات Register, Verify, ForgotPassword بقيت كما هي لتوفير المساحة)
// سأقوم بدمجها في الكود الفعلي.

class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController(); final _user = TextEditingController(); final _pwd = TextEditingController(); bool _isLoading = false; String _msg = '';
  Future<void> _register() async {
    setState(() { _isLoading = true; _msg = ''; });
    try {
      final res = await http.post(Uri.parse('http://100.77.27.80:8553/api/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': _email.text.trim(), 'username': _user.text.trim(), 'password': _pwd.text}));
      if (res.statusCode == 200) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VerifyScreen(email: _email.text.trim())));
      else setState(() { _msg = jsonDecode(res.body)['detail']; });
    } catch (e) { setState(() { _msg = 'Connection error'; }); } finally { setState(() { _isLoading = false; }); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Register')), body: Padding(padding: const EdgeInsets.all(24.0), child: Column(children: [
      TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())), const SizedBox(height: 16),
      TextField(controller: _user, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())), const SizedBox(height: 16),
      TextField(controller: _pwd, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())), const SizedBox(height: 20),
      if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: redColor)),
      _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _register, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: accentColor, foregroundColor: Colors.black), child: const Text('CREATE ACCOUNT'))
    ])));
  }
}

class VerifyScreen extends StatefulWidget { final String email; const VerifyScreen({super.key, required this.email}); @override State<VerifyScreen> createState() => _VerifyScreenState(); }
class _VerifyScreenState extends State<VerifyScreen> {
  final _otp = TextEditingController(); bool _isLoading = false; String _msg = '';
  Future<void> _verify() async {
    setState(() { _isLoading = true; _msg = ''; });
    try {
      final res = await http.post(Uri.parse('http://100.77.27.80:8553/api/verify_otp'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': widget.email, 'otp': _otp.text.trim()}));
      if (res.statusCode == 200) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      else setState(() { _msg = jsonDecode(res.body)['detail']; });
    } catch (e) { setState(() { _msg = 'Connection error'; }); } finally { setState(() { _isLoading = false; }); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Verify Email')), body: Padding(padding: const EdgeInsets.all(24.0), child: Column(children: [
      Text('Code sent to ${widget.email}', style: const TextStyle(color: textSecondary)), const SizedBox(height: 20),
      TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-Digit Code', border: OutlineInputBorder())), const SizedBox(height: 20),
      if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: redColor)),
      _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _verify, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: accentColor, foregroundColor: Colors.black), child: const Text('VERIFY'))
    ])));
  }
}

class ForgotPasswordScreen extends StatefulWidget { const ForgotPasswordScreen({super.key}); @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState(); }
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController(); final _otp = TextEditingController(); final _newPwd = TextEditingController(); bool _isLoading = false; bool _otpSent = false; String _msg = '';
  Future<void> _sendOtp() async {
    setState(() { _isLoading = true; _msg = ''; });
    try {
      final res = await http.post(Uri.parse('http://100.77.27.80:8553/api/forgot_password'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': _email.text.trim()}));
      if (res.statusCode == 200) setState(() { _otpSent = true; _msg = 'Code sent! Check your email.'; }); else setState(() { _msg = jsonDecode(res.body)['detail']; });
    } catch (e) { setState(() { _msg = 'Connection error'; }); } finally { setState(() { _isLoading = false; }); }
  }
  Future<void> _reset() async {
    setState(() { _isLoading = true; _msg = ''; });
    try {
      final res = await http.post(Uri.parse('http://100.77.27.80:8553/api/reset_password'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': _email.text.trim(), 'otp': _otp.text.trim(), 'new_password': _newPwd.text}));
      if (res.statusCode == 200) Navigator.pop(context); else setState(() { _msg = jsonDecode(res.body)['detail']; });
    } catch (e) { setState(() { _msg = 'Connection error'; }); } finally { setState(() { _isLoading = false; }); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Forgot Password')), body: Padding(padding: const EdgeInsets.all(24.0), child: Column(children: [
      TextField(controller: _email, enabled: !_otpSent, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())), const SizedBox(height: 16),
      if (_otpSent) ...[
        TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OTP Code', border: OutlineInputBorder())), const SizedBox(height: 16),
        TextField(controller: _newPwd, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
      ],
      const SizedBox(height: 20), if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: accentColor)),
      _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _otpSent ? _reset : _sendOtp, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: accentColor, foregroundColor: Colors.black), child: Text(_otpSent ? 'RESET PASSWORD' : 'SEND CODE'))
    ])));
  }
}

// ==========================================
// 5. الهيكل الرئيسي والقائمة الجانبية
// ==========================================
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String _username = '';

  final List<Widget> _pages = [
    const DashboardTab(),
    const ExploreTab(),
    const HistoryTab(),
    const AccountTab(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() { _username = prefs.getString('username') ?? 'User'; });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Dashboard', 'Explore Assets', 'History', 'My Account', 'Settings'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold))),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(decoration: const BoxDecoration(color: bgColor), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('❄️', style: TextStyle(fontSize: 40)), const SizedBox(height: 10),
            Text('Welcome, $_username', style: const TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ])),
          _buildDrawerItem(Icons.dashboard, titles[0], 0),
          _buildDrawerItem(Icons.explore, titles[1], 1),
          _buildDrawerItem(Icons.receipt_long, titles[2], 2),
          _buildDrawerItem(Icons.person, titles[3], 3),
          _buildDrawerItem(Icons.settings, titles[4], 4),
          const Divider(color: borderColor),
          ListTile(leading: const Icon(Icons.logout, color: redColor), title: const Text('Logout', style: TextStyle(color: redColor)), onTap: _logout),
        ]),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? accentColor : textSecondary),
      title: Text(title, style: TextStyle(color: isSelected ? accentColor : textPrimary)),
      selected: isSelected, selectedTileColor: bgColor,
      onTap: () { setState(() { _selectedIndex = index; }); Navigator.pop(context); },
    );
  }
}

// ==========================================
// 6. صفحة الاستكشاف (Explore Tab - Phase 2)
// ==========================================
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: ListTile(
        leading: const Icon(Icons.search, color: accentColor),
        title: const Text('Search Asset', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Look up any symbol'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
      )),
      const SizedBox(height: 16),
      _buildCard(child: ListTile(
        leading: const Icon(Icons.public, color: greenColor),
        title: const Text('Active Universe', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Currently approved assets'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveUniverseScreen())),
      )),
    ]);
  }
}

// ==========================================
// 7. صفحة البحث (Search Screen - Phase 2)
// ==========================================
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  Future<void> _search() async {
    if (_searchCtrl.text.isEmpty) return;
    setState(() { _isLoading = true; _result = null; });
    try {
      String sym = _searchCtrl.text.trim().toUpperCase();
      if (!sym.contains('/')) sym = '$sym/USDT';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.get(Uri.parse('http://100.77.27.80:8553/api/search?symbol=$sym'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) setState(() { _result = jsonDecode(res.body); });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Asset')),
      body: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [
        TextField(controller: _searchCtrl, decoration: const InputDecoration(labelText: 'Symbol (e.g. BTC)', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search)), onSubmitted: (_) => _search()),
        const SizedBox(height: 20),
        if (_isLoading) const CircularProgressIndicator(),
        if (_result != null) ...[
          _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_result!['symbol'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
            const Divider(color: borderColor),
            if (_result!['asset'] != null) ...[
              Text('Status: ${_result!['asset']['status']}', style: const TextStyle(color: greenColor)),
              Text('Confidence: ${_result!['asset']['confidence_score']}'),
              Text('Health: ${_result!['asset']['health_score']}'),
            ] else const Text('Asset not found in Active Universe', style: TextStyle(color: orangeColor)),
          ]))
        ]
      ])),
    );
  }
}

// ==========================================
// 8. صفحة الأصول النشطة (Active Universe Screen - Phase 2)
// ==========================================
class ActiveUniverseScreen extends StatefulWidget {
  const ActiveUniverseScreen({super.key});
  @override
  State<ActiveUniverseScreen> createState() => _ActiveUniverseScreenState();
}

class _ActiveUniverseScreenState extends State<ActiveUniverseScreen> {
  bool _isLoading = true;
  List _assets = [];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.get(Uri.parse('http://100.77.27.80:8553/api/active_universe'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) setState(() { _assets = jsonDecode(res.body)['assets'] ?? []; });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Universe')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assets.length,
        itemBuilder: (context, index) {
          final a = _assets[index];
          return _buildCard(child: Row(children: [
            const Icon(Icons.public, color: greenColor),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['symbol'], style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('CS: ${a['confidence_score']} | HS: ${a['health_score']}', style: const TextStyle(fontSize: 10, color: textSecondary)),
            ])
          ]));
        },
      ),
    );
  }
}

// ==========================================
// 9. صفحة السجل (History Tab) - محدثة لتفتح التفاصيل
// ==========================================
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  bool _isLoading = true;
  List _trades = [];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try { SharedPreferences prefs = await SharedPreferences.getInstance(); String? token = prefs.getString('token');
      final r = await http.get(Uri.parse('http://100.77.27.80:8553/api/history'), headers: {'Authorization': 'Bearer $token'});
      if (r.statusCode == 200) setState(() { _trades = jsonDecode(r.body)['trades'] ?? []; });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: _trades.length, itemBuilder: (c, i) {
      final t = _trades[i]; final pnl = (t['realized_profit_usdt'] ?? 0).toDouble(); final isWin = pnl >= 0;
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TradeDetailScreen(symbol: t['symbol']))),
        child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t['symbol'] ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Text('${isWin ? '+' : ''}\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: isWin ? greenColor : redColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8), const Icon(Icons.chevron_right, size: 16, color: textSecondary)
          ])
        ])),
      );
    });
  }
}

// ==========================================
// 10. صفحة تفاصيل الصفقة (Trade Detail - Phase 2)
// ==========================================
class TradeDetailScreen extends StatefulWidget {
  final String symbol;
  const TradeDetailScreen({super.key, required this.symbol});
  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _trade;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.get(Uri.parse('http://100.77.27.80:8553/api/trade_detail?symbol=${widget.symbol}'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) setState(() { _trade = jsonDecode(res.body)['trade']; });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.symbol)),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _trade == null ? const Center(child: Text('Trade not found')) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(child: Column(children: [
            Text('Net PnL: \$${_trade!['realized_profit_usdt']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: (_trade!['realized_profit_usdt'] ?? 0) >= 0 ? greenColor : redColor)),
            const Divider(color: borderColor),
            Text('Entry: \$${_trade!['entry']}'),
            Text('Exit: \$${_trade!['sell_price']}'),
            Text('Qty: ${_trade!['executed_qty']}'),
          ]))
        ],
      ),
    );
  }
}

// (باقي الصفحات Account, Settings, _buildCard, _buildStatCard كما هي)

Widget _buildCard({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: child);
Widget _buildStatCard(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 16, color: textSecondary), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 12, color: textSecondary))]), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]));

class DashboardTab extends StatefulWidget { const DashboardTab({super.key}); @override State<DashboardTab> createState() => _DashboardTabState(); }
class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = true; Map<String, dynamic> _data = {};
  @override void initState() { super.initState(); _fetchData(); }
  Future<void> _fetchData() async {
    setState(() { _isLoading = true; });
    try { SharedPreferences prefs = await SharedPreferences.getInstance(); String? token = prefs.getString('token');
      final response = await http.get(Uri.parse('http://100.77.27.80:8553/api/dashboard'), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) setState(() { _data = jsonDecode(response.body); });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }
  Color _pnlColor(dynamic val) => (val as num) >= 0 ? greenColor : redColor;
  @override Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final capital = _data['capital'] ?? {}; final stats = _data['stats'] ?? {}; final List positions = _data['positions'] ?? [];
    return RefreshIndicator(onRefresh: _fetchData, child: ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Exchange & Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Capital', style: TextStyle(color: textSecondary)), Text('\$${capital['total']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor))]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Free Balance', style: TextStyle(color: textSecondary)), Text('\$${capital['free']}', style: const TextStyle(fontSize: 16, color: textPrimary))]),
      ])),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _buildStatCard('Closed Trades', '${stats['closed_trades']}', Icons.receipt_long, accentColor)), const SizedBox(width: 10), Expanded(child: _buildStatCard('Profit Trades', '${stats['profit_trades']}', Icons.emoji_events, greenColor))]),
      const SizedBox(height: 16),
      const Text('Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
      ...positions.map((p) => _buildCard(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(p['symbol'], style: const TextStyle(fontWeight: FontWeight.bold)), Text('${(p['pnl'] as num).toStringAsFixed(2)}%', style: TextStyle(color: _pnlColor(p['pnl'])))]),
        const Divider(color: borderColor),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Entry: \$${(p['entry'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: textSecondary)), Text('Value: \$${(p['value'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: accentColor))]),
      ]))).toList()
    ]));
  }
}

class AccountTab extends StatefulWidget { const AccountTab({super.key}); @override State<AccountTab> createState() => _AccountTabState(); }
class _AccountTabState extends State<AccountTab> { @override Widget build(BuildContext context) => const Center(child: Text('Account Settings (Phase 1)', style: TextStyle(color: textSecondary))); }
class SettingsTab extends StatefulWidget { const SettingsTab({super.key}); @override State<SettingsTab> createState() => _SettingsTabState(); }
class _SettingsTabState extends State<SettingsTab> { @override Widget build(BuildContext context) => const Center(child: Text('App Settings (Phase 1)', style: TextStyle(color: textSecondary))); }

