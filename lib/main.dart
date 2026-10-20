import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// --- الألوان الأساسية (مطابقة لـ Flet) ---
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        appBarTheme: const AppBarTheme(backgroundColor: bgColor, foregroundColor: accentColor),
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
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
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
// 2. لوحة التحكم (Dashboard)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      if (token == null) { _logout(); return; }

      final response = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { _data = jsonDecode(response.body); });
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        setState(() { _errorMsg = 'Failed to load data'; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  // دالة مساعدة لتنسيق الألوان
  Color _pnlColor(double val) => val >= 0 ? greenColor : redColor;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMsg.isNotEmpty) return Scaffold(body: Center(child: Text(_errorMsg, style: const TextStyle(color: redColor))));

    // استخراج البيانات
    final capital = _data['capital'] ?? {};
    final stats = _data['stats'] ?? {};
    final risk = _data['risk'] ?? {};
    final List positions = _data['positions'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
          IconButton(icon: const Icon(Icons.logout, color: redColor), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- بطاقة الرصيد ---
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exchange & Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Capital', style: TextStyle(color: textSecondary)),
                      Text('\$${capital['total']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Free Balance', style: TextStyle(color: textSecondary)),
                      Text('\$${capital['free']}', style: const TextStyle(fontSize: 16, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ROI', style: TextStyle(color: textSecondary)),
                      Text('${capital['roi_pct']}%', style: TextStyle(fontSize: 14, color: _pnlColor(capital['roi_pct'] ?? 0))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- إحصائيات (Stats Grid) ---
            Row(
              children: [
                Expanded(child: _buildStatCard('Closed Trades', '${stats['closed_trades']}', Icons.receipt_long, accentColor)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Profit Trades', '${stats['profit_trades']}', Icons.emoji_events, greenColor)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildStatCard('Win Rate', '${stats['win_rate']}%', Icons.percent, greenColor)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Realized PnL', '\$${stats['realized_pnl']}', Icons.account_balance_wallet, _pnlColor(stats['realized_pnl'] ?? 0))),
              ],
            ),
            const SizedBox(height: 16),

            // --- التعرض (Exposure) ---
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Capital Exposure', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('${risk['exposure_pct']}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: greenColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (risk['exposure_pct'] ?? 0) / 100,
                    backgroundColor: borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(greenColor),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text('Positions Value: \$${risk['positions_value']}', style: const TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- المراكز (Positions) ---
            const Text('Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
            const SizedBox(height: 10),
            ...positions.map((p) {
              return _buildCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p['symbol'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${p['pnl'] > 0 ? '+' : ''}${(p['pnl'] as double).toStringAsFixed(2)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _pnlColor(p['pnl']))),
                      ],
                    ),
                    const Divider(color: borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Entry: \$${(p['entry'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: textSecondary))),
                        Expanded(child: Text('Value: \$${(p['value'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: accentColor), textAlign: TextAlign.right)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // --- Widgets مساعدة للتصميم ---
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: textSecondary),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
