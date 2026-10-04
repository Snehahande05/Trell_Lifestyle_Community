import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/review_and_verification.dart';

class CreatorVerificationScreen extends StatefulWidget {
  const CreatorVerificationScreen({super.key});

  @override
  State<CreatorVerificationScreen> createState() => _CreatorVerificationScreenState();
}

class _CreatorVerificationScreenState extends State<CreatorVerificationScreen> {
  final TextEditingController _categoryController = TextEditingController(text: 'Fashion & Beauty');
  final TextEditingController _socialLinkController = TextEditingController(text: 'https://instagram.com/my_creator_profile');
  final TextEditingController _reasonController = TextEditingController(text: 'Original lifestyle content creator with regular weekly uploads.');

  @override
  void dispose() {
    _categoryController.dispose();
    _socialLinkController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('User not selected', style: TextStyle(color: Colors.white))),
      );
    }

    final verificationApp = provider.currentCreatorVerification;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Creator Verification Badge', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: user.isVerifiedCreator
                    ? Colors.blue.shade900
                    : verificationApp != null
                        ? Colors.amber.shade900
                        : Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent),
              ),
              child: Row(
                children: [
                  Icon(
                    user.isVerifiedCreator ? Icons.verified : Icons.admin_panel_settings,
                    color: Colors.blueAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.isVerifiedCreator
                              ? 'Verified Creator Status: APPROVED ✔️'
                              : verificationApp != null
                                  ? 'Application Status: ${verificationApp.status.name.toUpperCase()}'
                                  : 'Not Verified Yet',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ordinary users cannot grant themselves verification badges. All applications require Admin Review.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!user.isVerifiedCreator && (verificationApp == null || verificationApp.status == VerificationStatus.rejected)) ...[
              const Text('Submit Verification Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Primary Content Category',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _socialLinkController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'External Portfolio / Social Link',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for Request',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  onPressed: () async {
                    await provider.submitVerification(
                      _categoryController.text.trim(),
                      _socialLinkController.text.trim(),
                      _reasonController.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Application submitted! Switch to Admin account to review.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.verified_user, color: Colors.white),
                  label: const Text('Submit Application for Admin Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
