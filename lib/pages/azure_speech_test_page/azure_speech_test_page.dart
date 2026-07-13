import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/azure_speech_service.dart';
import '../credentials_validator_page.dart';

/// Test page for Azure Speech Recognition.
/// This page allows testing the azure_stt_flutter package independently
/// from the existing speech_to_text implementation.
class AzureSpeechTestPage extends StatefulWidget {
  const AzureSpeechTestPage({super.key});

  @override
  State<AzureSpeechTestPage> createState() => _AzureSpeechTestPageState();
}

class _AzureSpeechTestPageState extends State<AzureSpeechTestPage> {
  late AzureSpeechService _azureSpeechService;

  // Azure credentials (provided by user)
  static const String _subscriptionKey = '042a4ab3f8a0';
  static const String _region = 'eastus';
  static const String _endpoint =
      'https://api.cognitive.microsofttranslator.com';

  @override
  void initState() {
    super.initState();
    _azureSpeechService = AzureSpeechService();
    _initializeAzureSpeech();
  }

  Future<void> _initializeAzureSpeech() async {
    // Initialize with subscription key and region
    await _azureSpeechService.initialize(
      subscriptionKey: _subscriptionKey,
      region: _region,
      endpoint: _endpoint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AzureSpeechService>.value(
      value: _azureSpeechService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Azure Speech Recognition Test'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Validator button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CredentialsValidatorPage(),
                        ),
                      );
                      if (result != null && mounted) {
                        // Credentials validated and returned
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Credentials validated! Re-initializing...'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Validate Credentials First'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusSection(),
                const SizedBox(height: 24),
                _buildConfigurationSection(),
                const SizedBox(height: 24),
                _buildResultsSection(),
                const SizedBox(height: 24),
                _buildControlsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Consumer<AzureSpeechService>(
      builder: (context, service, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: service.isAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      service.isAvailable
                          ? 'Azure Speech Ready'
                          : 'Azure Speech Not Ready',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: service.isAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (service.status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${service.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildConfigItem('Region', _region),
            const SizedBox(height: 8),
            _buildConfigItem('Endpoint', _endpoint),
            const SizedBox(height: 8),
            _buildConfigItem(
              'Subscription Key (Active)',
              _subscriptionKey.replaceAll(RegExp('.'), '*'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '💡 Using subscription key from eastus region',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.blue.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    return Consumer<AzureSpeechService>(
      builder: (context, service, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (service.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Error',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.error!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Finalized text box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Finalized Text',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.finalizedText.isEmpty
                              ? 'Waiting for confirmed text...'
                              : service.finalizedText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Intermediate text box (live hypothesis)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Live Hypothesis',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.intermediateText.isEmpty
                              ? 'Real-time text appears here...'
                              : service.intermediateText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (service.detectedLanguage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🌐 Detected Language: ${service.detectedLanguage}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsSection() {
    return Consumer<AzureSpeechService>(
      builder: (context, service, _) {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: service.isAvailable && !service.isListening
                    ? () {
                        service.startListening();
                      }
                    : null,
                icon: service.isListening
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.mic),
                label: Text(
                  service.isListening ? 'Listening...' : 'Start Recognition',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: service.isListening
                    ? () {
                        service.stopListening();
                      }
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  service.clearText();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Results'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _azureSpeechService.dispose();
    super.dispose();
  }
}
