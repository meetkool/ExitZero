import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/mock_interview.dart';
import '../../mock_interview_detail_page.dart'; // Import detail page
// Import InterviewsCard to reuse it or we can just inline the design if it's specific
import 'interviews_card.dart';
import '../../../widgets/bento_card.dart'; // For the container style if needed for empty state

class InterviewsCarousel extends StatefulWidget {
  final List<MockInterview> interviews;
  final VoidCallback onSeeAll;

  const InterviewsCarousel({
    super.key,
    required this.interviews,
    required this.onSeeAll,
  });

  @override
  State<InterviewsCarousel> createState() => _InterviewsCarouselState();
}

class _InterviewsCarouselState extends State<InterviewsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.interviews.isEmpty) {
      return BentoCard(
        height: 90,
        glassmorphism: false,
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Center(
          child: Text(
            'No upcoming interviews.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.interviews.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final interview = widget.interviews[index];
            final now = DateTime.now();
            final daysLeft = interview.dateTime.difference(now).inDays;
             // daysLeft might be 0 or negative if today.
             // User wants to see meetings *for today*.
             // So generic daysLeft logic might be weird if it says "0 days left".
             // Maybe show specific time or "Today"?
             // InterviewsCard takes `daysLeft`. Let's assume 0 is fine or we format it.
             
             // Format schedule string
             // e.g. "Thursday, 10:00 AM"
             // Using Intl would be better but keeping it simple/consistent with existing code.
             // We can use generic formatting.
             
            // We need to map MockInterview to standard InterviewsCard inputs
            // InterviewsCard expects: companyLetter, title, role, schedule, daysLeft
            
            return GestureDetector(
              onTap: widget.onSeeAll, // User said "clicks the wgth it opnes a wigth ... listed"
              child: InterviewsCard(
                companyLetter: interview.company.isNotEmpty ? interview.company[0].toUpperCase() : '?',
                title: interview.title,
                role: interview.role,
                schedule: _formatSchedule(interview.dateTime), // Helper method?
                daysLeft: daysLeft < 0 ? 0 : daysLeft, 
              ),
            );
          },
        ),
        
        // Page Indicators (Dots) if multiple
        if (widget.interviews.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.interviews.length, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? const Color(0xFF126782)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
          ),
        
        // Manual Slide Buttons (Arrows)
        if (widget.interviews.length > 1) ...[
          // Previous Button
           Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.5)),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
          
          // Next Button
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
      ], // Closes if
    ], // Closes children
    ); // Closes Stack

  }

  String _formatSchedule(DateTime date) {
    // Basic formatter. Ideally use Intl. 
    // "Thursday, 10:00 AM"
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[date.weekday - 1];
    
    // Time
    int hour = date.hour;
    final String amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    
    return '$weekday, $hour:$minute $amPm';
  }
}
