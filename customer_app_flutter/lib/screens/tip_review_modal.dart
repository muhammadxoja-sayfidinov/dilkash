import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class TipReviewModal extends StatefulWidget {
  final int orderId;
  final String orderNumber;

  const TipReviewModal({
    Key? key,
    required this.orderId,
    required this.orderNumber,
  }) : super(key: key);

  static void show(BuildContext context, int orderId, String orderNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TipReviewModal(orderId: orderId, orderNumber: orderNumber),
    );
  }

  @override
  State<TipReviewModal> createState() => _TipReviewModalState();
}

class _TipReviewModalState extends State<TipReviewModal> {
  int _rating = 5;
  double _tipAmount = 5000.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  final List<double> _tipOptions = [0, 5000, 10000, 20000];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService.submitTipAndReview(
        orderId: widget.orderId,
        tipAmount: _tipAmount,
        rating: _rating,
        review: _reviewController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Katta rahmat! Sizning bahoyingiz qabul qilindi.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'uz_UZ');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),

          Text(
            'Buyurtma #${widget.orderNumber} Bahosi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Xizmat va taomlarimiz sifatini baholang',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 16),

          // Star Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                iconSize: 36,
                icon: Icon(
                  starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _rating = starIndex),
              );
            }),
          ),

          const SizedBox(height: 18),

          // Courier Tip Options
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🛵 Kuryerga choychaqa (Ixtiyoriy):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _tipOptions.map((tip) {
              final isSelected = _tipAmount == tip;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _tipAmount = tip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber.shade600 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.amber.shade700 : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tip == 0 ? '0' : currencyFormatter.format(tip),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.black : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Review input
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Izoh yoki fikringizni yozib qoldiring...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Yuborish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
