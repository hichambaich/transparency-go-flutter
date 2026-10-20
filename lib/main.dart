import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// --- الألوان ---
const Color bgColor = Color(0xFF080d14);
const Color cardColor = Color(0xFF101722);
const Color accentColor = Color(0xFF00d9ff);
const Color borderColor = Color(0xFF202d42);
const Color textPrimary = Color(0xFFe2e8f0);
const Color textSecondary = Color(0xFF94a3b8);
const Color greenColor = Color(0xFF10b981);
const Color redColor = Color(0xFFef4444);

void main() {
  runApp(const TransparencyApp());
}

class TransparencyApp extends StatelessWidget {
  const TransparencyApp({super.key});

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
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. شاشة الدخول (Login)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = '';

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
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              if (_errorMsg.isNotEmpty) Text(_errorMsg, style: const TextStyle(color: redColor)),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: accentColor, foregroundColor: Colors.black),
                child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. الهيكل الرئيسي والقائمة الجانبية (Main Layout & Drawer)
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
    const HistoryTab(),
    const ConnectBinanceTab(),
    const AccountTab(),
    const SettingsTab(),
    const SupportTab(),
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
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Dashboard', 'History', 'Connect Binance', 'My Account', 'Settings', 'Support'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: bgColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('❄️', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text('Welcome, $_username', style: const TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.dashboard, titles[0], 0),
            _buildDrawerItem(Icons.receipt_long, titles[1], 1),
            _buildDrawerItem(Icons.link, titles[2], 2),
            _buildDrawerItem(Icons.person, titles[3], 3),
            _buildDrawerItem(Icons.settings, titles[4], 4),
            _buildDrawerItem(Icons.help_outline, titles[5], 5),
            const Divider(color: borderColor),
            ListTile(
              leading: const Icon(Icons.logout, color: redColor),
              title: const Text('Logout', style: TextStyle(color: redColor)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? accentColor : textSecondary),
      title: Text(title, style: TextStyle(color: isSelected ? accentColor : textPrimary)),
      selected: isSelected,
      selectedTileColor: bgColor,
      onTap: () {
        setState(() { _selectedIndex = index; });
        Navigator.pop(context);
      },
    );
  }
}

// ==========================================
// 3. صفحة لوحة التحكم (Dashboard)
// ==========================================
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = true;
  String _errorMsg = '';
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { _data = jsonDecode(response.body); });
      } else {
        setState(() { _errorMsg = 'Failed to load data'; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Color _pnlColor(dynamic val) => (val as num) >= 0 ? greenColor : redColor;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMsg.isNotEmpty) return Center(child: Text(_errorMsg, style: const TextStyle(color: redColor)));

    final capital = _data['capital'] ?? {};
    final stats = _data['stats'] ?? {};
    final risk = _data['risk'] ?? {};
    final List positions = _data['positions'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Exchange & Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Capital', style: TextStyle(color: textSecondary)),
              Text('\$${capital['total']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Free Balance', style: TextStyle(color: textSecondary)),
              Text('\$${capital['free']}', style: const TextStyle(fontSize: 16, color: textPrimary)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('ROI', style: TextStyle(color: textSecondary)),
              Text('${capital['roi_pct']}%', style: TextStyle(fontSize: 14, color: _pnlColor(capital['roi_pct'] ?? 0))),
            ]),
          ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildStatCard('Closed Trades', '${stats['closed_trades']}', Icons.receipt_long, accentColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Profit Trades', '${stats['profit_trades']}', Icons.emoji_events, greenColor)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildStatCard('Win Rate', '${stats['win_rate']}%', Icons.percent, greenColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Realized PnL', '\$${stats['realized_pnl']}', Icons.account_balance_wallet, _pnlColor(stats['realized_pnl'] ?? 0))),
          ]),
          const SizedBox(height: 16),
          _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Capital Exposure', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('${risk['exposure_pct']}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: greenColor)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (risk['exposure_pct'] ?? 0) / 100,
              backgroundColor: borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(greenColor),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text('Positions Value: \$${risk['positions_value']}', style: const TextStyle(fontSize: 12, color: textSecondary)),
          ])),
          const SizedBox(height: 20),
          const Text('Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
          const SizedBox(height: 10),
          ...positions.map((p) {
            return _buildCard(
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(p['symbol'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${(p['pnl'] as num) > 0 ? '+' : ''}${(p['pnl'] as num).toStringAsFixed(2)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _pnlColor(p['pnl']))),
                  ]),
                  const Divider(color: borderColor),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('Entry: \$${(p['entry'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: textSecondary))),
                    Expanded(child: Text('Value: \$${(p['value'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: accentColor), textAlign: TextAlign.right)),
                  ]),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ==========================================
// 4. صفحة السجل (History)
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
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoading = true; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/history'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() { _trades = jsonDecode(response.body)['trades'] ?? []; });
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_trades.isEmpty) return const Center(child: Text('No history found', style: TextStyle(color: textSecondary)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trades.length,
      itemBuilder: (context, index) {
        final t = _trades[index];
        final pnl = (t['realized_profit_usdt'] ?? 0).toDouble();
        final isWin = pnl >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['symbol'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${isWin ? '+' : ''}\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: isWin ? greenColor : redColor, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 5. صفحة ربط Binance (Connect Binance)
// ==========================================
class ConnectBinanceTab extends StatefulWidget {
  const ConnectBinanceTab({super.key});
  @override
  State<ConnectBinanceTab> createState() => _ConnectBinanceTabState();
}

class _ConnectBinanceTabState extends State<ConnectBinanceTab> {
  final _apiController = TextEditingController();
  final _secretController = TextEditingController();
  final _labelController = TextEditingController(text: 'Default');
  bool _isLoading = false;
  bool _isConnected = false;
  String _maskedKey = '';
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.get(Uri.parse('http://100.77.27.80:8553/api/binance/status'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _isConnected = data['connected'];
          _maskedKey = data['masked'] ?? '';
        });
      }
    } catch (e) {}
  }

  Future<void> _connect() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/binance/connect'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'api_key': _apiController.text.trim(), 'secret': _secretController.text.trim(), 'label': _labelController.text.trim()}),
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected Successfully!'), backgroundColor: greenColor));
        _checkStatus();
      } else {
        setState(() { _errorMsg = jsonDecode(res.body)['detail']; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _disconnect() async {
    setState(() { _isLoading = true; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      await http.post(Uri.parse('http://100.77.27.80:8553/api/binance/disconnect'), headers: {'Authorization': 'Bearer $token'});
      _checkStatus();
    } catch (e) {}
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _buildCard(child: Column(children: [
          const Icon(Icons.check_circle, color: greenColor, size: 60),
          const SizedBox(height: 10),
          const Text('Binance Connected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('API Key: $_maskedKey', style: const TextStyle(color: textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _disconnect,
            style: ElevatedButton.styleFrom(backgroundColor: redColor),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          )
        ]))
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Connect Binance API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
        const SizedBox(height: 16),
        TextField(controller: _apiController, decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _secretController, obscureText: true, decoration: const InputDecoration(labelText: 'Secret Key', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        if (_errorMsg.isNotEmpty) Text(_errorMsg, style: const TextStyle(color: redColor)),
        ElevatedButton(
          onPressed: _isLoading ? null : _connect,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: accentColor, foregroundColor: Colors.black),
          child: _isLoading ? const CircularProgressIndicator() : const Text('Connect & Start Bot', style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ]))
    ]);
  }
}

// ==========================================
// 6. صفحة حسابي (Account)
// ==========================================
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  bool _isLoading = true;
  Map<String, dynamic> _user = {};
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();
  String _msg = '';
  Color _msgColor = redColor;

  @override
  void initState() {
    super.initState();
    _fetchAccount();
  }

  Future<void> _fetchAccount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.get(Uri.parse('http://100.77.27.80:8553/api/account'), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) setState(() { _user = jsonDecode(response.body); });
    } catch (e) {} finally { setState(() { _isLoading = false; }); }
  }

  Future<void> _changePassword() async {
    if (_newPwd.text != _confirmPwd.text) {
      setState(() { _msg = 'Passwords do not match'; _msgColor = redColor; });
      return;
    }
    setState(() { _msg = 'Processing...'; _msgColor = textSecondary; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/account/change_password'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'current_password': _oldPwd.text, 'new_password': _newPwd.text}),
      );
      if (res.statusCode == 200) {
        setState(() { _msg = 'Password changed successfully!'; _msgColor = greenColor; });
        _oldPwd.clear(); _newPwd.clear(); _confirmPwd.clear();
      } else {
        setState(() { _msg = jsonDecode(res.body)['detail']; _msgColor = redColor; });
      }
    } catch (e) {
      setState(() { _msg = 'Connection error'; _msgColor = redColor; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: Column(children: [
        const CircleAvatar(radius: 40, backgroundColor: accentColor, child: Icon(Icons.person, size: 50, color: bgColor)),
        const SizedBox(height: 10),
        Text(_user['username'] ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(_user['email'] ?? 'email@example.com', style: const TextStyle(color: textSecondary)),
      ])),
      const SizedBox(height: 16),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
        const SizedBox(height: 16),
        TextField(controller: _oldPwd, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _newPwd, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _confirmPwd, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Text(_msg, style: TextStyle(color: _msgColor, fontSize: 12)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _changePassword,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: accentColor, foregroundColor: Colors.black),
          child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ]))
    ]);
  }
}

// ==========================================
// 7. صفحة الإعدادات (Settings)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _isArabic = true;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: Column(children: [
        SwitchListTile(title: const Text('Dark Mode'), value: _darkMode, activeColor: accentColor, onChanged: (val) => setState(() => _darkMode = val)),
        const Divider(color: borderColor),
        SwitchListTile(title: const Text('Notifications'), value: _notifications, activeColor: accentColor, onChanged: (val) => setState(() => _notifications = val)),
        const Divider(color: borderColor),
        SwitchListTile(title: const Text('العربية / English'), value: _isArabic, activeColor: accentColor, onChanged: (val) => setState(() => _isArabic = val)),
      ]))
    ]);
  }
}

// ==========================================
// 8. صفحة الدعم (Support)
// ==========================================
class SupportTab extends StatelessWidget {
  const SupportTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contact Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
        const SizedBox(height: 10),
        const ListTile(leading: Icon(Icons.email, color: accentColor), title: Text('transparancygo@gmail.com')),
        const ListTile(leading: Icon(Icons.telegram, color: accentColor), title: Text('@TransparencyGoSupport_bot')),
      ]))
    ]);
  }
}

// --- Widgets مساعدة ---
Widget _buildCard({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
    child: child,
  );
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: textSecondary), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 12, color: textSecondary))]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}
