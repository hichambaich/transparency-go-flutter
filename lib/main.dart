import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transparency Go',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080d14),
        primaryColor: const Color(0xFF00d9ff),
      ),
      home: const AuthGate(),
    );
  }
}

// ================= HELPERS =================
String formatPrice(dynamic price) {
  if (price == null) return '0.00';
  double p = double.tryParse(price.toString()) ?? 0.0;
  if (p >= 1) return '\$${p.toStringAsFixed(2)}';
  if (p >= 0.01) return '\$${p.toStringAsFixed(4)}';
  return '\$${p.toStringAsFixed(6)}';
}

// ================= AUTH GATE (ROUTER) =================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _token;
  
  int _authScreen = 0;
  String _otpEmail = '';
  String _otpMode = '';

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

  void _goToScreen(int screen, {String email = '', String mode = ''}) {
    setState(() {
      _authScreen = screen;
      _otpEmail = email;
      _otpMode = mode;
    });
  }

  void _logout() {
    setState(() => _token = null);
    _goToScreen(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff))));
    
    if (_token != null) {
      return MainLayout(token: _token!, onLogout: _logout);
    }

    switch (_authScreen) {
      case 1: return RegisterScreen(onRegisterSuccess: (email) => _goToScreen(3, email: email, mode: 'verify'), onBack: () => _goToScreen(0));
      case 2: return ForgotPasswordScreen(onOtpSent: (email) => _goToScreen(3, email: email, mode: 'reset'), onBack: () => _goToScreen(0));
      case 3: return VerifyOtpScreen(email: _otpEmail, mode: _otpMode, onSuccess: () => _goToScreen(0), onBack: () => _goToScreen(0));
      default: return LoginScreen(onLoginSuccess: (token) => setState(() => _token = token), onRegister: () => _goToScreen(1), onForgot: () => _goToScreen(2));
    }
  }
}

// ================= LOGIN SCREEN =================
class LoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;
  final VoidCallback onRegister;
  final VoidCallback onForgot;
  const LoginScreen({super.key, required this.onLoginSuccess, required this.onRegister, required this.onForgot});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  bool _rememberMe = true;
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token']);
          await prefs.setString('user_id', data['user_id'].toString());
        }
        widget.onLoginSuccess(data['token']);
      } else {
        setState(() => _error = data['detail'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❄️', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              const Text('TRANSPARENCY GO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
              const SizedBox(height: 40),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                    Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? true), activeColor: const Color(0xFF00d9ff)),
                    const Text('Remember Me', style: TextStyle(fontSize: 12)),
                  ]),
                  TextButton(onPressed: widget.onForgot, child: const Text('Forgot Password?', style: TextStyle(color: Colors.grey))),
                ],
              ),
              if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onRegister,
                child: const Text("Don't have an account? Register", style: TextStyle(color: Color(0xFF00d9ff))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= REGISTER SCREEN =================
class RegisterScreen extends StatefulWidget {
  final Function(String) onRegisterSuccess;
  final VoidCallback onBack;
  const RegisterScreen({super.key, required this.onRegisterSuccess, required this.onBack});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Future<void> _register() async {
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _isLoading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email.text.trim(), 'username': _username.text.trim(), 'password': _pass.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        widget.onRegisterSuccess(_email.text.trim());
      } else {
        setState(() => _error = data['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
              const SizedBox(height: 30),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder())),
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_error, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= FORGOT PASSWORD SCREEN =================
class ForgotPasswordScreen extends StatefulWidget {
  final Function(String) onOtpSent;
  final VoidCallback onBack;
  const ForgotPasswordScreen({super.key, required this.onOtpSent, required this.onBack});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Future<void> _sendOtp() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/forgot_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email.text.trim()}),
      );
      if (res.statusCode == 200) {
        widget.onOtpSent(_email.text.trim());
      } else {
        setState(() => _error = jsonDecode(res.body)['detail'] ?? 'Error');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Reset Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
              const SizedBox(height: 10),
              const Text('Enter your email to receive a reset code.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_error, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('SEND CODE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= VERIFY OTP SCREEN =================
class VerifyOtpScreen extends StatefulWidget {
  final String email;
  final String mode;
  final VoidCallback onSuccess;
  final VoidCallback onBack;
  const VerifyOtpScreen({super.key, required this.email, required this.mode, required this.onSuccess, required this.onBack});
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otp = TextEditingController();
  final _newPass = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Future<void> _verify() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      if (widget.mode == 'verify') {
        final res = await http.post(
          Uri.parse('http://100.77.27.80:8553/api/verify_otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': widget.email, 'otp': _otp.text.trim()}),
        );
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email Verified! Please login.'), backgroundColor: Colors.green));
          widget.onSuccess();
        } else {
          setState(() => _error = 'Invalid OTP');
        }
      } else {
        final res = await http.post(
          Uri.parse('http://100.77.27.80:8553/api/reset_password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': widget.email, 'otp': _otp.text.trim(), 'new_password': _newPass.text}),
        );
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Reset! Please login.'), backgroundColor: Colors.green));
          widget.onSuccess();
        } else {
          setState(() => _error = 'Invalid OTP or password too short');
        }
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(widget.mode == 'verify' ? 'Verify Email' : 'Set New Password', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
              const SizedBox(height: 10),
              Text('Code sent to ${widget.email}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OTP Code', border: OutlineInputBorder())),
              if (widget.mode == 'reset') ...[
                const SizedBox(height: 16),
                TextField(controller: _newPass, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
              ],
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_error, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MAIN LAYOUT =================
class MainLayout extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;
  const MainLayout({super.key, required this.token, required this.onLogout});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('user_id'));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userId == '556';
    
    // القائمة الجديدة بعد إضافة الصفحات
    final List<Widget> screens = [
      DashboardScreen(token: widget.token, onLogout: widget.onLogout),
      HistoryScreen(token: widget.token),
      ExploreScreen(token: widget.token),
      AccountScreen(token: widget.token, onLogout: widget.onLogout),
      BinanceScreen(token: widget.token),          // صفحة ربط Binance
      TradingSettingsScreen(token: widget.token),  // صفحة إعدادات التداول
      SettingsScreen(token: widget.token),         // صفحة الإعدادات المحدثة
      SupportScreen(),
    ];
    
    if (isAdmin) screens.add(AdminPanelScreen(token: widget.token));

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Transparency Go'), backgroundColor: const Color(0xFF101722)),
      drawer: Drawer(
        backgroundColor: const Color(0xFF101722),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF080d14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('❄️', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text('Transparency Go', style: TextStyle(color: Color(0xFF00d9ff), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.dashboard, color: Color(0xFF00d9ff)), title: const Text('Dashboard'), selected: _selectedIndex == 0, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 0); }),
            ListTile(leading: const Icon(Icons.history, color: Colors.white), title: const Text('History'), selected: _selectedIndex == 1, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 1); }),
            ListTile(leading: const Icon(Icons.explore, color: Colors.white), title: const Text('Explore Assets'), selected: _selectedIndex == 2, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 2); }),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.person, color: Colors.white), title: const Text('My Account'), selected: _selectedIndex == 3, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 3); }),
            ListTile(leading: const Icon(Icons.link, color: Colors.amber), title: const Text('Connect Binance'), selected: _selectedIndex == 4, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 4); }),
            ListTile(leading: const Icon(Icons.candlestick_chart, color: Colors.blue), title: const Text('Trading Settings'), selected: _selectedIndex == 5, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 5); }),
            ListTile(leading: const Icon(Icons.settings, color: Colors.white), title: const Text('App Settings'), selected: _selectedIndex == 6, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 6); }),
            ListTile(leading: const Icon(Icons.support_agent, color: Colors.white), title: const Text('Support'), selected: _selectedIndex == 7, onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 7); }),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange), 
                title: const Text('Admin Panel', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)), 
                selected: _selectedIndex == 8, 
                onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 8); }
              ),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)), onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              await prefs.remove('user_id');
              widget.onLogout();
            }),
          ],
        ),
      ),
      body: screens[_selectedIndex],
    );
  }
}

// ================= SETTINGS SCREEN (Merged with API) =================
class SettingsScreen extends StatefulWidget {
  final String token;
  const SettingsScreen({super.key, required this.token});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _notifEnabled = true;
  bool _notifyBuy = true;
  bool _notifySell = true;
  bool _notifyDca = true;
  bool _notifyErrors = true;
  final _chatIdCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/notifications'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _notifEnabled = data['notifications_enabled'] == 1;
          _notifyBuy = data['notify_buy'] == 1;
          _notifySell = data['notify_sell'] == 1;
          _notifyDca = data['notify_dca'] == 1;
          _notifyErrors = data['notify_errors'] == 1;
          _chatIdCtrl.text = data['telegram_chat_id'] ?? '';
        });
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await http.post(
        Uri.parse('http://100.77.27.80:8553/api/notifications'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'notifications_enabled': _notifEnabled ? 1 : 0,
          'notify_buy': _notifyBuy ? 1 : 0,
          'notify_sell': _notifySell ? 1 : 0,
          'notify_dca': _notifyDca ? 1 : 0,
          'notify_errors': _notifyErrors ? 1 : 0,
          'telegram_chat_id': _chatIdCtrl.text.trim(),
        }),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!'), backgroundColor: Colors.green));
    } catch (e) { print(e); }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              children: [
                SwitchListTile(title: const Text('Enable All Notifications'), value: _notifEnabled, activeColor: const Color(0xFF00d9ff), onChanged: (v) => setState(() => _notifEnabled = v)),
                const Divider(color: Color(0xFF202d42)),
                SwitchListTile(title: const Text('Buy Alerts'), value: _notifyBuy, activeColor: const Color(0xFF00d9ff), onChanged: (v) => setState(() => _notifyBuy = v)),
                SwitchListTile(title: const Text('Sell Alerts'), value: _notifySell, activeColor: const Color(0xFF00d9ff), onChanged: (v) => setState(() => _notifySell = v)),
                SwitchListTile(title: const Text('DCA Alerts'), value: _notifyDca, activeColor: const Color(0xFF00d9ff), onChanged: (v) => setState(() => _notifyDca = v)),
                SwitchListTile(title: const Text('Error Alerts'), value: _notifyErrors, activeColor: const Color(0xFF00d9ff), onChanged: (v) => setState(() => _notifyErrors = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Telegram Integration', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
                const SizedBox(height: 8),
                const Text('Enter your Telegram Chat ID to receive notifications.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(controller: _chatIdCtrl, decoration: const InputDecoration(labelText: 'Chat ID', border: OutlineInputBorder())),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 45,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
              child: _isSaving ? const CircularProgressIndicator() : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TRADING SETTINGS SCREEN =================
class TradingSettingsScreen extends StatefulWidget {
  final String token;
  const TradingSettingsScreen({super.key, required this.token});
  @override
  State<TradingSettingsScreen> createState() => _TradingSettingsScreenState();
}

class _TradingSettingsScreenState extends State<TradingSettingsScreen> {
  bool _isLoading = true;
  final _tradeSizeCtrl = TextEditingController();
  final _maxPosCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/trading/settings'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _tradeSizeCtrl.text = data['trade_size_usdt'].toString();
          _maxPosCtrl.text = data['max_open_positions'].toString();
        });
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await http.post(
        Uri.parse('http://100.77.27.80:8553/api/trading/settings'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'trade_size_usdt': double.tryParse(_tradeSizeCtrl.text) ?? 10.0,
          'max_open_positions': int.tryParse(_maxPosCtrl.text) ?? 5,
        }),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trading Settings Saved!'), backgroundColor: Colors.green));
    } catch (e) { print(e); }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trading Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              children: [
                TextField(controller: _tradeSizeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Trade Size (USDT)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _maxPosCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Open Positions', border: OutlineInputBorder())),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 45,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
              child: _isSaving ? const CircularProgressIndicator() : const Text('SAVE TRADING SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= BINANCE SCREEN =================
class BinanceScreen extends StatefulWidget {
  final String token;
  const BinanceScreen({super.key, required this.token});
  @override
  State<BinanceScreen> createState() => _BinanceScreenState();
}

class _BinanceScreenState extends State<BinanceScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  String _connectedLabel = '';
  
  final _apiKeyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/binance/status'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _isConnected = data['connected'] == true;
          if (_isConnected) _connectedLabel = data['label'] ?? 'Default';
        });
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _connect() async {
    if (_apiKeyCtrl.text.isEmpty || _secretCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/binance/connect'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': _apiKeyCtrl.text.trim(),
          'secret': _secretCtrl.text.trim(),
          'label': _labelCtrl.text.trim().isEmpty ? 'Default' : _labelCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        _checkStatus();
        _apiKeyCtrl.clear();
        _secretCtrl.clear();
        _labelCtrl.clear();
      }
    } catch (e) { print(e); }
    setState(() => _isSaving = false);
  }

  Future<void> _disconnect() async {
    setState(() => _isSaving = true);
    try {
      await http.post(
        Uri.parse('http://100.77.27.80:8553/api/binance/disconnect'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      _checkStatus();
    } catch (e) { print(e); }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Binance Integration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
          const SizedBox(height: 20),
          if (_isConnected) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10b981))),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10b981), size: 50),
                  const SizedBox(height: 10),
                  const Text('Connected Successfully!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10b981))),
                  const SizedBox(height: 5),
                  Text('Label: $_connectedLabel', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 45,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _disconnect,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: _isSaving ? const CircularProgressIndicator() : const Text('Disconnect Binance', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
              child: Column(
                children: [
                  TextField(controller: _apiKeyCtrl, decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: _secretCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Secret Key', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: 'Label (Optional)', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 45,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _connect,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
                      child: _isSaving ? const CircularProgressIndicator() : const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// ================= SUPPORT SCREEN =================
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.email, color: Color(0xFF00d9ff)), SizedBox(width: 10), Text('Email Us', style: TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                const Text('transparancygo@gmail.com', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                const Row(children: [Icon(Icons.telegram, color: Color(0xFF00d9ff)), SizedBox(width: 10), Text('Telegram', style: TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                const Text('@TransparencyGoSupport_bot', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FAQ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
                const SizedBox(height: 12),
                _buildFaqItem('How do I connect Binance?', 'Go to Connect Binance from the menu and enter your API keys.'),
                _buildFaqItem('When will I receive my profits?', 'Profits are automatically reinvested. You can withdraw at any time from Binance.'),
                _buildFaqItem('Is my money safe?', 'We never store your funds. All trading happens directly on your Binance account.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(a, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
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
  List<FlSpot> _chartSpots = [];
  String _errorMsg = '';
  
  final Color bgColor = const Color(0xFF080d14);
  final Color cardBg = const Color(0xFF101722);
  final Color borderColor = const Color(0xFF202d42);
  final Color accent = const Color(0xFF00d9ff);
  final Color green = const Color(0xFF10b981);
  final Color red = const Color(0xFFef4444);
  final Color gold = const Color(0xFFf0b90b);

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/dashboard'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _data = jsonDecode(res.body));
        _fetchChart();
      } else if (res.statusCode == 401) {
        widget.onLogout(); 
      } else {
        setState(() => _errorMsg = 'Failed to load data');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Connection error');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchChart() async {
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/trend_history?period=1d'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final points = jsonDecode(res.body)['points'] as List;
        List<FlSpot> spots = [];
        for (int i = 0; i < points.length; i++) {
          double val = double.tryParse(points[i][1].toString()) ?? 0.0;
          if (val > 0) { 
            spots.add(FlSpot(i.toDouble(), val));
          }
        }
        setState(() => _chartSpots = spots);
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));
    if (_errorMsg.isNotEmpty) return Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)));

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildExchangeCard(),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildPositionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeCard() {
    final capital = _data['capital'] ?? {};
    final total = (capital['total'] ?? 0.0).toDouble();
    final free = (capital['free'] ?? 0.0).toDouble();

    double minY = 0;
    double maxY = 100;
    if (_chartSpots.isNotEmpty) {
      minY = _chartSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = _chartSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      double diff = maxY - minY;
      if (diff == 0) diff = 1;
      minY -= diff * 0.1;
      maxY += diff * 0.1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exchange & Balances', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL CAPITAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('\$${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accent)),
                ],
              ),
              SizedBox(
                width: 120, height: 50,
                child: _chartSpots.isEmpty
                  ? const Center(child: Text('No Chart Data', style: TextStyle(fontSize: 10, color: Colors.grey)))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_chartSpots.length - 1).toDouble(),
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _chartSpots,
                            isCurved: true,
                            color: accent,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: accent.withOpacity(0.1)),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: gold),
              const SizedBox(width: 6),
              const Text('Binance', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              Text('Balance \$${free.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _data['stats'] ?? {};
    return Row(
      children: [
        Expanded(child: _statCard('Closed Trades', '${stats['closed_trades'] ?? 0}', Icons.receipt_long, Colors.grey)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Win Rate', '${stats['win_rate'] ?? 0}%', Icons.emoji_events, green)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsList() {
    final positions = _data['positions'] as List? ?? [];
    if (positions.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No open positions', style: TextStyle(color: Colors.grey))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('POSITIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...positions.map((p) {
          final pnl = (p['pnl'] ?? 0.0).toDouble();
          final pnlColor = pnl >= 0 ? green : red;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: pnlColor, width: 3),
                top: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%', style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Color(0xFF202d42), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entry: ${formatPrice(p['entry'])}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Value: \$${(p['value'] ?? 0.0).toStringAsFixed(2)}', style: TextStyle(fontSize: 10, color: accent)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// ================= HISTORY SCREEN =================
class HistoryScreen extends StatefulWidget {
  final String token;
  const HistoryScreen({super.key, required this.token});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _trades = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/history'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _trades = jsonDecode(res.body)['trades'] ?? []);
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));
    if (_trades.isEmpty) return const Center(child: Text('No closed trades yet', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _trades.length,
      itemBuilder: (context, index) {
        final t = _trades[index];
        final pnl = (t['realized_profit_usdt'] ?? 0.0).toDouble();
        final isWin = pnl >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202d42)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['symbol'] ?? 'UNKNOWN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Closed at: ${t['last_action'] != null ? DateTime.fromMillisecondsSinceEpoch((t['last_action'] * 1000).toInt()).toString().substring(0, 16) : 'N/A'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Text(
                '${isWin ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                style: TextStyle(color: isWin ? const Color(0xFF10b981) : const Color(0xFFef4444), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= EXPLORE SCREEN =================
class ExploreScreen extends StatefulWidget {
  final String token;
  const ExploreScreen({super.key, required this.token});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isLoading = true;
  List<dynamic> _assets = [];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/active_universe'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _assets = jsonDecode(res.body)['assets'] ?? []);
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));
    if (_assets.isEmpty) return const Center(child: Text('No active assets found', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final a = _assets[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202d42)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 16, backgroundColor: const Color(0xFF080d14), child: Text((a['symbol'] ?? '?').toString().substring(0, 1), style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['symbol'] ?? 'UNKNOWN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('CS: ${a['confidence_score']?.toStringAsFixed(2) ?? 'N/A'} | HS: ${a['health_score']?.toStringAsFixed(2) ?? 'N/A'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        );
      },
    );
  }
}

// ================= ACCOUNT SCREEN =================
class AccountScreen extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;
  const AccountScreen({super.key, required this.token, required this.onLogout});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _user = {};
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String _msg = '';
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _fetchAccount();
  }

  Future<void> _fetchAccount() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/account'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _user = jsonDecode(res.body));
      } else if (res.statusCode == 401) {
        widget.onLogout();
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _changePassword() async {
    if (_oldPwdCtrl.text.isEmpty || _newPwdCtrl.text.isEmpty || _confirmPwdCtrl.text.isEmpty) {
      setState(() => _msg = 'Please fill all fields');
      return;
    }
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      setState(() => _msg = 'New passwords do not match!');
      return;
    }

    setState(() { _isChanging = true; _msg = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/account/change_password'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'current_password': _oldPwdCtrl.text, 'new_password': _newPwdCtrl.text}),
      );
      if (res.statusCode == 200) {
        setState(() => _msg = 'Password changed successfully!');
        _oldPwdCtrl.clear();
        _newPwdCtrl.clear();
        _confirmPwdCtrl.clear();
      } else {
        setState(() => _msg = 'Error: ${jsonDecode(res.body)['detail']}');
      }
    } catch (e) {
      setState(() => _msg = 'Connection error');
    }
    setState(() => _isChanging = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00d9ff)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF101722), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF202d42))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Username: ${_user['username'] ?? '...'}', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text('Email: ${_user['email'] ?? '...'}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          
          TextField(
            controller: _oldPwdCtrl,
            obscureText: _obscureOld,
            decoration: InputDecoration(
              labelText: 'Current Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _newPwdCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _confirmPwdCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          if (_msg.isNotEmpty) Text(_msg, style: TextStyle(color: _msg.contains('success') ? Colors.green : Colors.red)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _isChanging ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00d9ff), foregroundColor: Colors.black),
              child: _isChanging ? const CircularProgressIndicator() : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= ADMIN PANEL SCREEN =================
class AdminPanelScreen extends StatefulWidget {
  final String token;
  const AdminPanelScreen({super.key, required this.token});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/admin/users'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _users = jsonDecode(res.body)['users'] ?? []);
      }
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleBot(int uid) async {
    try {
      final res = await http.post(
        Uri.parse('http://100.77.27.80:8553/api/admin/toggle_bot/$uid'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        _fetchUsers();
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.orange));
    if (_users.isEmpty) return const Center(child: Text('No users found', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        final isRunning = u['is_running'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202d42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${u['username']} (ID: ${u['id']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRunning ? const Color(0xFF10b981).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isRunning ? 'RUNNING' : 'STOPPED',
                      style: TextStyle(color: isRunning ? const Color(0xFF10b981) : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(u['email'] ?? 'N/A', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Balance: \$${u['balance']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () => _toggleBot(u['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning ? Colors.red : const Color(0xFF10b981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(isRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
