import 'package:flutter/material.dart';

import '../../domain/entities/greeting.dart';

class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key, required this.greeting});

  final Greeting greeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greeting.message, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              greeting.createdAt.toLocal().toString(),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
