import 'package:flutter/material.dart';
import '../services/azure_credentials_validator.dart';

/// Page to validate Azure credentials before testing speech recognition
class CredentialsValidatorPage extends StatefulWidget {
  const CredentialsValidatorPage({super.key});

  @override
  State<CredentialsValidatorPage> createState() =>
      _CredentialsValidatorPageState();
}

class _CredentialsValidatorPageState extends State<CredentialsValidatorPage> {
  late TextEditingController _keyController;
  late TextEditingController _regionController;

  bool _isValidating = false;
  String? _validationResult;
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: '042a4ab3f8a0');
    _regionController = TextEditingController(text: 'eastus');
  }

  @override
  void dispose() {
    _keyController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _validateCredentials() async {
    setState(() {
      _isValidating = true;
      _validationResult = null;
      _isValid = null;
    });

    final key = _keyController.text.trim();
    final region = _regionController.text.trim();

    if (key.isEmpty) {
      setState(() {
        _isValid = false;
        _validationResult = '❌ Subscription key is empty';
        _isValidating = false;
      });
      return;
    }

    if (region.isEmpty) {
      setState(() {
        _isValid = false;
        _validationResult = '❌ Region is empty';
        _isValidating = false;
      });
      return;
    }

    try {
      final isValid =
          await AzureCredentialsValidator.validateCredentials(
        subscriptionKey: key,
        region: region,
      );

      setState(() {
        _isValid = isValid;
        _validationResult = isValid
            ? '✅ Credentials are VALID! You can now test speech recognition.'
            : '❌ Credentials validation FAILED. Check the key and region.';
        _isValidating = false;
      });
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationResult = '❌ Validation error: $e';
        _isValidating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure Credentials Validator'),
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
              // Instructions card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 How to get your credentials',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Go to Azure Portal (portal.azure.com)\n'
                        '2. Find your Speech resource\n'
                        '3. Click "Keys and Endpoint" in the left menu\n'
                        '4. Copy the subscription key (Key 1 or Key 2)\n'
                        '5. Copy the region (e.g., eastus, westus)\n'
                        '\n'
                        'Make sure your Speech resource is:\n'
                        '• In an active subscription\n'
                        '• Created in the correct region\n'
                        '• Using the Speech-to-Text API (not Translator)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Subscription Key Input
              Text(
                'Subscription Key',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  hintText: 'Paste your subscription key here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              // Region Input
              Text(
                'Region',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _regionController,
                decoration: InputDecoration(
                  hintText: 'e.g., eastus, westus, westeurope',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '💡 Region must be lowercase (e.g., \'eastus\' not \'EastUS\')',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              // Validation Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValidating ? null : _validateCredentials,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isValidating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Validate Credentials'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Validation Result
              if (_validationResult != null)
                Card(
                  color: _isValid == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _validationResult!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isValid == true
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                        if (_isValid == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () {
                                  // Navigate back with the validated credentials
                                  Navigator.of(context).pop({
                                    'subscriptionKey': _keyController.text,
                                    'region': _regionController.text,
                                  });
                                },
                                child: const Text('Use These Credentials'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // Troubleshooting section
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔧 Troubleshooting',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildTroubleshootItem(
                        'Unauthorized (401)',
                        'Invalid subscription key or key doesn\'t match region.\n'
                        'Copy the key again from Azure Portal.',
                      ),
                      const SizedBox(height: 8),
                      _buildTroubleshootItem(
                        'Forbidden (403)',
                        'Subscription may be expired or usage limit exceeded.\n'
                        'Check your billing and subscription status.',
                      ),
                      const SizedBox(height: 8),
                      _buildTroubleshootItem(
                        'Not Found (404)',
                        'Invalid region name.\n'
                        'Use lowercase region: eastus, westus, etc.',
                      ),
                      const SizedBox(height: 8),
                      _buildTroubleshootItem(
                        'Timeout',
                        'Check your internet connection.\n'
                        'Firewall might be blocking Azure services.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Print checklist button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    AzureCredentialsValidator.printCheckList();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Checklist printed to console (check debug output)')),
                    );
                  },
                  child: const Text('Print Validation Checklist'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTroubleshootItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }
}
