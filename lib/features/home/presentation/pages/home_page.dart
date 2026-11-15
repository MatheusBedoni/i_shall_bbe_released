import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../controllers/home_state.dart';
import '../widgets/greeting_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final HomeController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadGreeting();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return Center(
            child: switch (widget.controller.state) {
              HomeInitial() => const SizedBox.shrink(),
              HomeLoading() => const CircularProgressIndicator(),
              HomeLoaded(:final greeting) => GreetingCard(greeting: greeting),
              HomeError(:final message) => _ErrorView(
                  message: message,
                  onRetry: widget.controller.loadGreeting,
                ),
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}
