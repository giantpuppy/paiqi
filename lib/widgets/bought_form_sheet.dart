import 'package:flutter/material.dart';
import '../models/ticket.dart';

/// 标记为「已买」时弹出的购票信息录入表单。
///
/// 返回 `Ticket?`：用户点击保存且至少填了一项时返回非空 Ticket；
/// 点击跳过或返回时返回 `null`，调用方只更新状态即可。
class BoughtFormSheet extends StatefulWidget {
  final int performanceId;

  const BoughtFormSheet({
    super.key,
    required this.performanceId,
  });

  @override
  State<BoughtFormSheet> createState() => _BoughtFormSheetState();
}

class _BoughtFormSheetState extends State<BoughtFormSheet> {
  final _seatController = TextEditingController();
  final _priceController = TextEditingController();
  final _actualPriceController = TextEditingController();

  @override
  void dispose() {
    _seatController.dispose();
    _priceController.dispose();
    _actualPriceController.dispose();
    super.dispose();
  }

  Ticket? _buildTicket() {
    final seat = _seatController.text.trim().isNotEmpty
        ? _seatController.text.trim()
        : null;
    final price = double.tryParse(_priceController.text.trim());
    final actualPrice = double.tryParse(_actualPriceController.text.trim());

    if (seat == null && price == null && actualPrice == null) {
      return null;
    }
    return Ticket(
      performanceId: widget.performanceId,
      seat: seat,
      price: price,
      actualPrice: actualPrice,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '补充购票信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _seatController,
                  decoration: _inputDecoration('座位', '如：1区/层-3排-5号', Icons.event_seat_outlined),
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('票面价格', '如：580', Icons.confirmation_number_outlined),
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _actualPriceController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('实付价格', '如：480', Icons.payments_outlined),
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('跳过'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, _buildTicket()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34D399),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white54),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF34D399), width: 1),
      ),
    );
  }
}

/// 便捷函数：显示 BoughtFormSheet 并返回 Ticket?。
Future<Ticket?> showBoughtFormSheet(BuildContext context, {required int performanceId}) {
  return showModalBottomSheet<Ticket?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BoughtFormSheet(performanceId: performanceId),
  );
}
