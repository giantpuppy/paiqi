import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/actor.dart';
import '../models/show.dart';
import '../services/user_service.dart';
import '../utils/data_backup.dart';
import '../utils/page_transitions.dart';
import '../widgets/charts/chart_theme.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'monthly_workbench_screen.dart';
import 'ocr_settings_screen.dart';
import 'add_show_screen.dart';
import 'import_schedule_screen.dart';
import 'show_management_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _currentUser;
  bool _isLoading = true;
  List<Show> _shows = [];
  List<Actor> _actors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await UserService.getCurrentUsername();
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final actors = await db.getAllActors();
    setState(() {
      _currentUser = user;
      _shows = shows;
      _actors = actors;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final actors = await db.getAllActors();
    if (mounted) {
      setState(() {
        _shows = shows;
        _actors = actors;
      });
    }
  }

  Future<void> _resetAllShowsToManagement() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '重置到管理台',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '将所有剧目移出排期流，回到管理台。\n\n这些剧目将不再出现在月历和排期流中，但数据会保留，之后可以重新导入排期流。',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8A8F98))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置', style: TextStyle(color: Color(0xFFF54A45))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    var updatedCount = 0;
    for (final show in shows) {
      if (show.isInScheduleFlow) {
        await db.updateShow(show.copyWith(isInScheduleFlow: false));
        updatedCount++;
      }
    }

    // 同时把所有场次的排期流状态重置为 0
    final performances = await db.getAllPerformances();
    for (final perf in performances) {
      if (perf.isInScheduleFlow) {
        await db.updatePerformance(perf.copyWith(isInScheduleFlow: false));
      }
    }

    await _refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 $updatedCount 个剧目移回管理台'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await UserService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _handleImport() async {
    final result = await DataBackup.importFromJson();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result ?? '已取消')),
    );
    if (result == '导入成功' && mounted) {
      // 导入可能切换了数据库，回到首页刷新
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 账户管理
                _buildSectionHeader('账户'),
                _buildManageCard(
                  icon: Icons.account_circle,
                  title: '当前用户',
                  subtitle: _currentUser ?? '未登录',
                  trailing: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('退出登录'),
                  ),
                ),
                const SizedBox(height: 16),

                // 管理入口
                _buildSectionHeader('管理'),
                _buildManageCard(
                  icon: Icons.theaters,
                  title: '我的剧目',
                  subtitle: '${_shows.length} 项',
                  onTap: _showShowsSheet,
                ),
                const SizedBox(height: 8),
                _buildManageCard(
                  icon: Icons.grid_view,
                  title: '月度管理',
                  subtitle: '按月查看剧目海报墙',
                  onTap: _openMonthlyWorkbench,
                ),
                const SizedBox(height: 8),
                _buildManageCard(
                  icon: Icons.people,
                  title: '演员名单',
                  subtitle: '${_actors.length} 项',
                  onTap: _showActorsSheet,
                ),
                const SizedBox(height: 16),

                // Web Demo 下隐藏识别与数据管理入口，避免误操作破坏演示数据
                if (!kIsWeb) ...[
                  // OCR 识别设置
                  _buildSectionHeader('识别'),
                  _buildManageCard(
                    icon: Icons.document_scanner,
                    title: 'OCR 识别设置',
                    subtitle: '配置百度 OCR API Key',
                    onTap: () => Navigator.push(
                      context,
                      SlideFadeRoute(page: const OcrSettingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 数据备份与恢复
                  _buildSectionHeader('数据'),
                  _buildManageCard(
                    icon: Icons.download,
                    title: '导出备份',
                    subtitle: 'JSON 格式',
                    onTap: () async {
                      await DataBackup.exportToJson();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('备份已下载')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildManageCard(
                    icon: Icons.upload,
                    title: '导入恢复',
                    subtitle: '选择 JSON 备份文件',
                    onTap: _handleImport,
                  ),
                  const SizedBox(height: 8),
                  _buildManageCard(
                    icon: Icons.playlist_remove,
                    title: '重置所有剧目到管理台',
                    subtitle: '所有剧目移出排期流，回到管理台',
                    onTap: _resetAllShowsToManagement,
                  ),
                  const SizedBox(height: 8),
                  _buildManageCard(
                    icon: Icons.playlist_add,
                    title: '导入卡司排期汇总',
                    subtitle: '补充 13 个剧目 / 65 场演出',
                    onTap: () => Navigator.push(
                      context,
                      SlideFadeRoute(page: const ImportScheduleScreen()),
                    ).then((_) => _refresh()),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8A8F98),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildManageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Color(0xFF8A8F98))
                : null),
        onTap: onTap,
      ),
    );
  }

  void _openMonthlyWorkbench() {
    final now = DateTime.now();
    Navigator.push(
      context,
      SlideFadeRoute(
        page: MonthlyWorkbenchScreen(year: now.year, month: now.month),
      ),
    ).then((_) => _refresh());
  }

  void _showShowsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '我的剧目',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          SlideFadeRoute(page: const AddShowScreen()),
                        ).then((_) => _refresh());
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _shows.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无剧目',
                          style: TextStyle(color: ChartTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _shows.length,
                        itemBuilder: (context, index) {
                          final show = _shows[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                show.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(show.name),
                            subtitle: show.theater != null
                                ? Text(show.theater!)
                                : null,
                            trailing: kIsWeb
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red[300]),
                                    onPressed: () => _deleteShow(show.id!),
                                  ),
                            onTap: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                SlideFadeRoute(
                                  page: ShowManagementScreen(showId: show.id!),
                                ),
                              );
                              if (result == true) _refresh();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteShow(int showId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除剧目将同时删除其所有场次记录，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      final perfs = await db.getPerformancesByShowId(showId);
      for (final p in perfs) {
        await db.deleteCastMembersByPerformanceId(p.id!);
        await db.deletePerformance(p.id!);
      }
      await db.deleteShow(showId);
      _refresh();
    }
  }

  void _showActorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '演员名单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _actors.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无演员',
                          style: TextStyle(color: ChartTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _actors.length,
                        itemBuilder: (context, index) {
                          final actor = _actors[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(
                                actor.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                            title: Text(actor.name),
                            subtitle: actor.note != null
                                ? Text(actor.note!)
                                : null,
                            trailing: kIsWeb
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red[300]),
                                    onPressed: () => _deleteActor(actor.id!),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteActor(int actorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定从演员列表中删除吗？不会影响已有场次记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteActor(actorId);
      _refresh();
    }
  }
}
