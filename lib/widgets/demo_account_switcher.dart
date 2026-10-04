import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../models/user.dart';

class DemoAccountSwitcherBar extends StatelessWidget {
  const DemoAccountSwitcherBar({super.key});

  @override
  Widget build(BuildContext meContext) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        User? current = provider.currentUser;
        List<User> users = provider.allUsers;

        return Container(
          color: Colors.deepPurple.shade900,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.shield_moon_outlined,
                color: Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Demo Mode:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: current?.id,
                    isDense: true,
                    dropdownColor: Colors.purple.shade900,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: users.map((u) {
                      String roleBadge = u.role == UserRole.admin
                          ? '👑 Admin'
                          : u.role == UserRole.creator
                          ? '📹 Creator'
                          : '🛍️ Viewer';
                      return DropdownMenuItem<String>(
                        value: u.id,
                        child: Text(
                          '${u.name} ($roleBadge)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newId) {
                      if (newId != null) {
                        provider.switchDemoUser(newId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Switched demo account to: ${provider.getUserById(newId)?.name}',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.restart_alt,
                  color: Colors.amber,
                  size: 20,
                ),
                tooltip: 'Reset Demo Data',
                onPressed: () {
                  _showResetDialog(context, provider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, AppStateProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Demo Data?'),
        content: const Text(
          'This will clear all created orders, posts, and withdrawals, restoring the app to its initial exam demo state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.resetDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demo data successfully reset!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
