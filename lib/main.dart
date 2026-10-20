import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
        scaffoldBackgroundColor: const Color(0xFF080d14),
        primaryColor: const Color(0xFF00d9ff),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101722),
          foregroundColor: Color(0xFF00d9ff),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

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
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['token'];
        String username = data['username'];

        // حفظ التوكن للمرات القادمة
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('username', username);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        setState(() { _errorMsg = 'Invalid credentials'; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error. Is API running?'; });
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
              const Text('TRANSPARENCY GO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff), letterSpacing: 2.0)),
              const SizedBox(height: 4),
              const Text('by smart solutions.py', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              if (_errorMsg.isNotEmpty) Text(_errorMsg, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF00d9ff),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  double _totalCapital = 0.0;
  double _binanceBalance = 0.0;
  List _positions = [];
  String _username = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() { _isLoading = true; _errorMsg = ''; });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      _username = prefs.getString('username') ?? 'User';

      if (token == null) {
        _logout();
        return;
      }

      final response = await http.get(
        Uri.parse('http://100.77.27.80:8553/api/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalCapital = (data['total_capital'] ?? 0).toDouble();
          _binanceBalance = (data['binance_balance'] ?? 0).toDouble();
          _positions = data['positions'] ?? [];
        });
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        setState(() { _errorMsg = 'Failed to load data'; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error. Is API running?'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchDashboardData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Welcome Card
                      Card(
                        color: const Color(0xFF101722),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome, $_username', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Capital', style: TextStyle(color: Colors.grey)),
                                  Text('\$${_totalCapital.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Free Balance', style: TextStyle(color: Colors.grey)),
                                  Text('\$${_binanceBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00d9ff))),
                      const SizedBox(height: 10),
                      _positions.isEmpty
                          ? const Center(child: Text('No open positions', style: TextStyle(color: Colors.grey)))
                          : Column(
                              children: _positions.map((pos) {
                                double pnl = (pos['pnl'] ?? 0).toDouble();
                                Color pnlColor = pnl >= 0 ? Colors.green : Colors.red;
                                return Card(
                                  color: const Color(0xFF101722),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(pos['symbol'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('${pnl > 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%', style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
    );
  }
}
