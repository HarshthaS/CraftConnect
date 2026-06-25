// lib/widgets/order_timeline.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTimeline extends StatelessWidget {
  final String status;
  final Map<String, dynamic>? timeline;
  final bool showCancelled;

  const OrderTimeline({
    Key? key,
    required this.status,
    this.timeline,
    this.showCancelled = true,
  }) : super(key: key);

  static const List<String> _steps = [
    'placed',
    'accepted',
    'packed',
    'shipped',
    'delivered',
    'completed',
  ];

  static const Map<String, IconData> _icons = {
    'placed': Icons.shopping_bag,
    'accepted': Icons.check_circle,
    'packed': Icons.inbox,
    'shipped': Icons.local_shipping,
    'delivered': Icons.home,
    'completed': Icons.verified,
    'cancelled': Icons.cancel,
  };

  String _titleFor(String step) {
    switch (step) {
      case 'placed':
        return 'Placed';
      case 'accepted':
        return 'Accepted by Artisan';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return step;
    }
  }

  bool _isStepDone(String step, String current) {
    final order = _steps;
    final idxStep = order.indexOf(step);
    final idxCur = order.indexOf(current);
    if (idxCur == -1) {

      return step == 'placed' && current == 'placed';
    }
    return idxStep <= idxCur;
  }

  String? _fmtTime(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    }
    try {
      final dt = DateTime.parse(ts.toString());
      return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (e) {
      return ts.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = status.toLowerCase();
    final steps = List<String>.from(_steps);

    final isCancelled = current == 'cancelled';
    if (isCancelled && showCancelled) {
      steps.add('cancelled');
    }

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        final done = isCancelled ? (s == 'placed') : _isStepDone(s, current);
        final icon = _icons[s] ?? Icons.circle;
        final ts = timeline != null ? timeline![s] : null;
        final timeLabel = _fmtTime(ts);

        final showLine = i != steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done ? Colors.green : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: done
                          ? [
                        BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 6,
                            spreadRadius: 1)
                      ]
                          : null,
                    ),
                    child: Icon(icon, color: done ? Colors.white : Colors.black54, size: 18),
                  ),
                  if (showLine)
                    Container(
                      width: 2,
                      height: 68,
                      color: done ? Colors.green : Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleFor(s),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: done ? Colors.black : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (timeLabel != null)
                        Text(
                          timeLabel,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        )
                      else
                        Text(
                          done ? "Pending timestamp..." : "Pending",
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
