import 'package:flutter/material.dart';

// Simple date formatting helpers to avoid depending on the 'intl' package.
const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String formatMonthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
String formatWeekdayMonthDay(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1].substring(0, 3)} ${d.day}';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Mock data: Days that have captures
  final Set<int> _captureDays = {5, 12, 15, 22, 23};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatWeekdayMonthDay(_selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMonthYear(_focusedDay).toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2),
                  ),
                ],
              ),
            ),

            // 2. Custom Minimalist Calendar Grid
            _buildCalendarGrid(),

            const SizedBox(height: 32),

            // 3. Selected Day Details
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatWeekdayMonthDay(_selectedDay),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        Text(
                          _captureDays.contains(_selectedDay.day) ? "2 Captures" : "No Captures",
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_captureDays.contains(_selectedDay.day))
                      Expanded(child: _buildCaptureList())
                    else
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOffset = DateTime(_focusedDay.year, _focusedDay.month, 1).weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: daysInMonth + firstDayOffset,
        itemBuilder: (context, index) {
          if (index < firstDayOffset) return const SizedBox();
          
          final day = index - firstDayOffset + 1;
          final isSelected = _selectedDay.day == day;
          final hasCapture = _captureDays.contains(day);

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, day)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                shape: BoxShape.circle,
                border: hasCapture && !isSelected 
                    ? Border.all(color: const Color(0xFFE6D5B8), width: 2) 
                    : null,
              ),
              child: Center(
                child: Text(
                  "$day",
                  style: TextStyle(
                    color: isSelected ? Colors.white : (hasCapture ? Colors.black : Colors.grey[400]),
                    fontWeight: isSelected || hasCapture ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptureList() {
    return ListView.separated(
      itemCount: 2,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network("https://picsum.photos/seed/${index+20}/100", width: 60, height: 60, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Window Reflection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("14:20 • 320 LUX", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: Colors.grey[200], size: 64),
          const SizedBox(height: 16),
          const Text("No spatial records for this day", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}