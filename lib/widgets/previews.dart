// Copyright (c) 2026 Pocket Project. All rights reserved.
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'user_avatar_widget.dart';

/// Interactive preview for the Glassmorphic Avatar component.
@Preview(name: 'Solar Wealth Avatar', group: 'Avatars')
Widget solarWealthAvatarPreview() => const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF131313),
        body: Center(
          child: UserAvatarWidget(
            avatarId: 'solar_wealth',
            size: 64,
          ),
        ),
      ),
    );

/// Interactive preview for transaction cash flow badge in dark theme.
@Preview(name: 'Expense Flow Badge - Dark', group: 'Badges')
Widget expenseFlowBadgePreview() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF131313),
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF5252).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Text(
              'Net -₹450.00',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );

/// Interactive preview for transaction cash flow badge in light theme.
@Preview(name: 'Income Flow Badge - Light', group: 'Badges')
Widget incomeFlowBadgePreview() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Text(
              'Net +₹1,500.00',
              style: TextStyle(
                color: Color(0xFF00C853),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
