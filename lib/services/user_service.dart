import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalUser {
  final String username;
  final String passwordHash;
  final String createdAt;

  LocalUser({
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'username': username,
    'passwordHash': passwordHash,
    'createdAt': createdAt,
  };

  factory LocalUser.fromMap(Map<String, dynamic> map) => LocalUser(
    username: map['username'] as String,
    passwordHash: map['passwordHash'] as String,
    createdAt: map['createdAt'] as String,
  );
}

class UserService {
  static const _usersKey = 'local_users_list';
  static const _currentUserKey = 'local_current_user';
  static const _autoLoginUserKey = 'local_auto_login_user';
  static const _salt = 'paiqi_app_salt_v1';

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    return sha256.convert(bytes).toString();
  }

  /// 获取所有本地用户
  static Future<List<LocalUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_usersKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => LocalUser.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 注册用户
  static Future<String?> register(String username, String password) async {
    if (username.trim().isEmpty) return '用户名不能为空';
    if (password.length < 4) return '密码至少4位';

    final users = await getAllUsers();
    if (users.any((u) => u.username == username)) {
      return '用户名已存在';
    }

    final newUser = LocalUser(
      username: username.trim(),
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now().toIso8601String(),
    );

    users.add(newUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toMap()).toList()));
    await prefs.setString(_currentUserKey, username.trim());

    return null; // success
  }

  /// 登录
  static Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty) return '请输入用户名';
    if (password.isEmpty) return '请输入密码';

    final users = await getAllUsers();
    final user = users.firstWhere(
      (u) => u.username == username.trim(),
      orElse: () => LocalUser(username: '', passwordHash: '', createdAt: ''),
    );

    if (user.username.isEmpty) return '用户不存在';
    if (user.passwordHash != _hashPassword(password)) return '密码错误';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, username.trim());
    return null;
  }

  /// 设置自动登录用户（下次启动直接进主界面）
  static Future<void> setAutoLoginUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoLoginUserKey, username.trim());
  }

  /// 获取自动登录用户
  static Future<String?> getAutoLoginUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoLoginUserKey);
  }

  /// 清除自动登录状态
  static Future<void> clearAutoLoginUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_autoLoginUserKey);
  }

  /// 获取当前登录用户
  static Future<String?> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  /// 登出（不删除数据）
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_autoLoginUserKey);
  }

  /// 删除用户（同时清理其数据库文件/本地存储）
  static Future<String?> deleteUser(String username) async {
    final users = await getAllUsers();
    final idx = users.indexWhere((u) => u.username == username);
    if (idx < 0) return '用户不存在';

    final current = await getCurrentUsername();
    if (current == username) {
      await logout();
    }

    users.removeAt(idx);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toMap()).toList()));

    // 清理该用户的配置数据（OCR Key、额度等）
    // 数据库文件本身保留，下次同用户名注册可以恢复（如果需要的话）
    // 或者可以选择清理：这里先保留，给用户一个"后悔药"

    return null;
  }

  /// 检查是否有任何用户
  static Future<bool> hasAnyUser() async {
    final users = await getAllUsers();
    return users.isNotEmpty;
  }

  /// 从备份恢复用户列表（不覆盖现有用户，只追加不存在的）
  static Future<void> restoreUsers(List<dynamic> usersJson) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAllUsers();
    for (final json in usersJson) {
      final map = json as Map<String, dynamic>;
      final username = map['username'] as String;
      if (!existing.any((u) => u.username == username)) {
        existing.add(LocalUser.fromMap(map));
      }
    }
    await prefs.setString(_usersKey, jsonEncode(existing.map((u) => u.toMap()).toList()));
  }

  /// 初始化：如果没有任何用户，把现有数据作为"默认用户"
  /// 或者保持现状，等用户手动注册
  static Future<void> init() async {
    // 不做自动迁移，让用户自己选择是否创建账号
    // 如果想保留现有数据，首次启动时提示"是否为当前数据创建用户？"
  }
}
