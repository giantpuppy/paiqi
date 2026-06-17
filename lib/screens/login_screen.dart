import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/user_service.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginUserController = TextEditingController();
  final _loginPassController = TextEditingController();
  final _regUserController = TextEditingController();
  final _regPassController = TextEditingController();
  final _regPassConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = true;
  int _tabIndex = 0;
  List<LocalUser> _users = [];
  String? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await UserService.getAllUsers();
    final currentUser = await UserService.getCurrentUsername();
    setState(() {
      _users = users;
      // 如果只有一个用户，或当前记住的用户存在，默认选中并展示密码框
      if (users.length == 1) {
        _selectedUser = users.first.username;
      } else if (currentUser != null &&
          users.any((u) => u.username == currentUser)) {
        _selectedUser = currentUser;
      }
    });
  }

  Future<void> _loginSelected() async {
    if (_selectedUser == null) {
      _showMsg('请选择一个用户');
      return;
    }
    final password = _loginPassController.text;
    if (password.isEmpty) {
      _showMsg('请输入密码');
      return;
    }

    setState(() => _isLoading = true);
    final error = await UserService.login(_selectedUser!, password);
    setState(() => _isLoading = false);

    if (error != null) {
      _showMsg(error);
      return;
    }

    if (_rememberMe) {
      await UserService.setAutoLoginUser(_selectedUser!);
    }

    await DatabaseHelper.switchUser(_selectedUser!);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _register() async {
    final username = _regUserController.text.trim();
    final password = _regPassController.text;
    final confirm = _regPassConfirmController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMsg('请输入用户名和密码');
      return;
    }
    if (password != confirm) {
      _showMsg('两次密码不一致');
      return;
    }

    setState(() => _isLoading = true);
    final error = await UserService.register(username, password);
    setState(() => _isLoading = false);

    if (error != null) {
      _showMsg(error);
      return;
    }

    if (_rememberMe) {
      await UserService.setAutoLoginUser(username);
    }

    await DatabaseHelper.switchUser(username);

    if (mounted) {
      _showMsg('注册成功', isError: false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      });
    }
  }

  Future<void> _skipLogin() async {
    // 以 default 用户直接进入，使用现有数据
    await DatabaseHelper.switchUser('default');
    await UserService.setAutoLoginUser('default');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _showMsg(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFF54A45) : const Color(0xFF34D399),
      ),
    );
  }

  @override
  void dispose() {
    _loginUserController.dispose();
    _loginPassController.dispose();
    _regUserController.dispose();
    _regPassController.dispose();
    _regPassConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.8,
            colors: [
              Color(0xFF2D1B4E),
              Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 24),
                    const Text(
                      '排期助手',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '选择用户以继续',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A8F98),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_users.isNotEmpty) ...[
                      _buildUserList(),
                      const SizedBox(height: 24),
                    ],
                    _buildTabSwitch(),
                    const SizedBox(height: 24),
                    if (_tabIndex == 0 && _selectedUser != null)
                      _buildPasswordForm()
                    else if (_tabIndex == 0 && _users.isEmpty)
                      _buildDirectEntry()
                    else if (_tabIndex == 1)
                      _buildRegisterForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5BCD).withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/icon_source.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTabSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: '登录',
              isActive: _tabIndex == 0,
              onTap: () => setState(() {
                _tabIndex = 0;
                _selectedUser = null;
                _loginPassController.clear();
              }),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: '注册新用户',
              isActive: _tabIndex == 1,
              onTap: () => setState(() => _tabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '已有用户',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB3B3B3),
          ),
        ),
        const SizedBox(height: 12),
        ..._users.map((user) {
          final isSelected = _selectedUser == user.username;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() {
                _selectedUser = user.username;
                _tabIndex = 0;
                _loginPassController.clear();
              }),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6B5BCD).withValues(alpha: 0.15)
                      : const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6B5BCD)
                        : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6B5BCD).withValues(alpha: 0.2),
                      child: Text(
                        user.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B5BCD),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Color(0xFF6B5BCD), size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      children: [
        TextField(
          controller: _loginPassController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '$_selectedUser 的密码',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
          ),
          onSubmitted: (_) => _loginSelected(),
        ),
        _buildRememberMeRow(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginSelected,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _selectedUser = null;
            _loginPassController.clear();
          }),
          child: const Text('换其他用户'),
        ),
      ],
    );
  }

  Widget _buildDirectEntry() {
    return Column(
      children: [
        const Text(
          '还没有创建用户账号',
          style: TextStyle(color: Color(0xFF8A8F98)),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _skipLogin,
          child: const Text('直接开始使用（数据存本地）'),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          controller: _regUserController,
          decoration: const InputDecoration(
            labelText: '用户名',
            prefixIcon: Icon(Icons.person_outline, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码',
            prefixIcon: Icon(Icons.lock_outline, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _regPassConfirmController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '确认密码',
            prefixIcon: Icon(Icons.lock_outline, size: 20),
          ),
          onSubmitted: (_) => _register(),
        ),
        _buildRememberMeRow(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('注册'),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v ?? true),
              activeColor: const Color(0xFF6B5BCD),
              side: const BorderSide(color: Color(0xFF6B5BCD)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: const Text(
              '下次自动登录',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8F98)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6B5BCD) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : const Color(0xFF8A8F98),
          ),
        ),
      ),
    );
  }
}
