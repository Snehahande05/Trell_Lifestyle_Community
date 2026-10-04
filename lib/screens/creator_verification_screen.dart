import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../models/review_and_verification.dart';

/// CREATOR VERIFICATION SCREEN — Step 9
///
/// This screen allows creators to apply for a "Verified Creator" badge.
///
/// IMPORTANT LABELS (per exam brief):
///   - This is a project/demo admin verification, NOT external identity verification.
///   - The "Verified Creator" badge is distinct from "Verified Purchase" on reviews.
///   - Verification does NOT change commission rates or guarantee revenue-share eligibility.
///
/// VERIFICATION STATES:
///   notApplied → pending (on submission)
///   pending    → approved (admin approves)
///   pending    → rejected (admin rejects with mandatory reason)
///   rejected   → pending (creator may reapply — documented reapplication rule)
///   approved is terminal (revocation out of scope per brief)
class CreatorVerificationScreen extends StatefulWidget {
  const CreatorVerificationScreen({super.key});

  @override
  State<CreatorVerificationScreen> createState() =>
      _CreatorVerificationScreenState();
}

class _CreatorVerificationScreenState extends State<CreatorVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Fashion & Beauty',
  );
  final TextEditingController _socialLinkController = TextEditingController(
    text: 'https://instagram.com/my_creator_profile',
  );
  final TextEditingController _reasonController = TextEditingController(
    text: 'Original lifestyle content creator with regular weekly uploads.',
  );

  bool _isSubmitting = false;

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
        body: Center(
          child: Text(
            'User not selected',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final verificationApp = provider.currentCreatorVerification;
    final isApproved = user.isVerifiedCreator;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Creator Verification Badge',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ────────────────────────────────────────────────
            _buildStatusBanner(isApproved, verificationApp),
            const SizedBox(height: 16),

            // ── Demo disclaimer ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '⚠️ This is a project/demo admin verification, not an external identity check or government verification. '
                'The "Verified Creator" badge signals only that a demo admin has reviewed and approved the application. '
                'It does NOT change commission rates or guarantee revenue-share eligibility.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // ── Application form or status detail ────────────────────────────
            if (!isApproved &&
                (verificationApp == null ||
                    verificationApp.status == VerificationStatus.rejected ||
                    verificationApp.status ==
                        VerificationStatus.notApplied)) ...[
              _buildApplicationForm(context, provider, verificationApp),
            ] else if (!isApproved && verificationApp != null) ...[
              _buildStatusDetail(verificationApp),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isApproved, VerificationApplication? app) {
    Color bgColor;
    String statusText;
    IconData icon;

    if (isApproved) {
      bgColor = Colors.blue.shade900;
      statusText = 'Verified Creator Status: APPROVED ✔️';
      icon = Icons.verified;
    } else if (app?.status == VerificationStatus.pending) {
      bgColor = Colors.amber.shade900;
      statusText = 'Application Status: PENDING (under admin review)';
      icon = Icons.pending_actions;
    } else if (app?.status == VerificationStatus.rejected) {
      bgColor = Colors.red.shade900;
      statusText = 'Application Status: REJECTED — You may reapply';
      icon = Icons.cancel_outlined;
    } else {
      bgColor = Colors.grey.shade900;
      statusText = 'Not Verified Yet';
      icon = Icons.admin_panel_settings;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All applications require Admin Review. Regular users cannot self-grant badges.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (app?.submittedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Submitted: ${app!.submittedAt.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetail(VerificationApplication app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Application Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _detailRow('Category', app.category),
        _detailRow('Social Link', app.socialLink),
        _detailRow('Reason', app.reason),
        if (app.decidedAt != null)
          _detailRow(
            'Decision Date',
            app.decidedAt!.toLocal().toString().substring(0, 16),
          ),
        if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Text(
              'Rejection Reason: ${app.rejectionReason}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationForm(
    BuildContext context,
    AppStateProvider provider,
    VerificationApplication? prev,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prev?.status == VerificationStatus.rejected) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                'Your previous application was rejected. You may reapply with updated information.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          ],
          const Text(
            'Submit Verification Application',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          // Category field with validation
          TextFormField(
            controller: _categoryController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Primary Content Category *',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              helperText: 'e.g. Fashion & Beauty, Travel, Food',
              helperStyle: TextStyle(color: Colors.white38),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Category is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Social link field with validation
          TextFormField(
            controller: _socialLinkController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Portfolio / Social Profile Link *',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              helperText: 'URL to your public profile',
              helperStyle: TextStyle(color: Colors.white38),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'A social or portfolio link is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Reason field with validation
          TextFormField(
            controller: _reasonController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reason for Applying *',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              helperText: 'Describe your content and why you qualify',
              helperStyle: TextStyle(color: Colors.white38),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please provide a reason for your application';
              }
              if (val.trim().length < 10) {
                return 'Please provide a more detailed reason (min 10 characters)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () => _submitApplication(context, provider),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.verified_user, color: Colors.white),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : 'Submit Application for Admin Review',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitApplication(
    BuildContext context,
    AppStateProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.submitVerification(
        _categoryController.text.trim(),
        _socialLinkController.text.trim(),
        _reasonController.text.trim(),
      );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted! Switch to Admin account to review.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
