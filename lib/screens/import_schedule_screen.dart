import 'package:flutter/material.dart';
import '../data/schedule_import_bundle.dart';
import '../services/schedule_import_service.dart';

/// 临时导入页：把 tools/parse_schedule_import.py 生成的
/// scheduleImportBundle 写入当前登录账号的数据库。
/// 仅用于一次性补充《卡司排期汇总表》数据，导入完成后可删除此页。
class ImportScheduleScreen extends StatefulWidget {
  const ImportScheduleScreen({super.key});

  @override
  State<ImportScheduleScreen> createState() => _ImportScheduleScreenState();
}

class _ImportScheduleScreenState extends State<ImportScheduleScreen> {
  bool _isImporting = false;
  String? _result;

  int get _totalShows => scheduleImportBundle.length;

  int get _totalPerformances =>
      scheduleImportBundle.fold(0, (sum, s) => sum + s.performances.length);

  Future<void> _doImport() async {
    setState(() {
      _isImporting = true;
      _result = null;
    });

    try {
      final result = await ScheduleImportService.importBundle();
      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _result = '导入失败：$e';
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入卡司排期汇总'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本次将向当前账号补充：',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(Icons.theaters, '$_totalShows 个剧目'),
                    const SizedBox(height: 8),
                    _buildSummaryRow(Icons.event, '$_totalPerformances 场演出'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isImporting ? null : _doImport,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isImporting ? '导入中…' : '导入到管理台'),
                      ),
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _result!,
                        style: TextStyle(
                          color: _result!.startsWith('导入失败')
                              ? Theme.of(context).colorScheme.error
                              : const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scheduleImportBundle.length,
              itemBuilder: (context, index) {
                final show = scheduleImportBundle[index];
                return ListTile(
                  title: Text(show.name),
                  subtitle: Text(show.theater),
                  trailing: Text('${show.performances.length} 场'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFFB3B3B3))),
      ],
    );
  }
}
