import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/call_model.dart';
import 'agora_call_flow_validator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AgoraValidationApp());
}

class AgoraValidationApp extends StatelessWidget {
  const AgoraValidationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Validation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AgoraValidationScreen(),
    );
  }
}

class AgoraValidationScreen extends StatefulWidget {
  const AgoraValidationScreen({Key? key}) : super(key: key);

  @override
  State<AgoraValidationScreen> createState() => _AgoraValidationScreenState();
}

class _AgoraValidationScreenState extends State<AgoraValidationScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isTestRunning = false;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _receiverIdController =
      TextEditingController(text: 'test-receiver-id');
  final TextEditingController _receiverNameController =
      TextEditingController(text: 'Test Receiver');
  CallType _selectedCallType = CallType.video;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isLoading = false;
      _isLoggedIn = user != null;
    });

    if (_isLoggedIn) {
      _log('Logged in as: ${FirebaseAuth.instance.currentUser?.email}');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use anonymous sign-in for testing
      await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
      _log(
          'Logged in anonymously with UID: ${FirebaseAuth.instance.currentUser?.uid}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _log('❌ Login failed: $e');
    }
  }

  Future<void> _runValidation() async {
    if (!_isLoggedIn) {
      _log('❌ You must be logged in to run the validation');
      return;
    }

    setState(() {
      _isTestRunning = true;
      _logs.clear();
      _log('Starting Agora call flow validation...');
    });

    try {
      // Create validator
      final validator = AgoraCallFlowValidator();

      // Set up log listener
      validator.logStream.listen((log) {
        _log(log);
      });

      // Run validation
      final result = await validator.validateCompleteFlow(
        receiverId: _receiverIdController.text,
        receiverName: _receiverNameController.text,
        callType: _selectedCallType,
      );

      // Show result
      _log(result
          ? '✅ TEST PASSED: All validation steps completed successfully'
          : '❌ TEST FAILED: See logs for details');

      // Print report
      final report = validator.report;
      _log('=== Test Report ===');
      _log('Test: ${report.testName}');
      _log('Status: ${report.success ? 'PASSED' : 'FAILED'}');
      _log('Duration: ${report.duration.inSeconds} seconds');

      // Print sub-tests
      _log('--- Sub-tests ---');
      for (final subTest in report.subTests) {
        _log('${subTest.success ? '✓' : '✗'} ${subTest.name}');
      }

      // Print failures
      if (report.failures.isNotEmpty) {
        _log('--- Failures ---');
        for (final failure in report.failures) {
          _log('• $failure');
        }
      }

      // Clean up
      validator.dispose();
    } catch (e) {
      _log('❌ Error running validation: $e');
    } finally {
      setState(() {
        _isTestRunning = false;
      });
    }
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Calling Flow Validation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isLoggedIn) ...[
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login (Anonymous)'),
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoggedIn) ...[
              Text('Logged in as: ${FirebaseAuth.instance.currentUser?.uid}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Test Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _receiverIdController,
                decoration: const InputDecoration(
                  labelText: 'Receiver User ID',
                  border: OutlineInputBorder(),
                  hintText: 'Enter the ID of the user to call',
                ),
                enabled: !_isTestRunning,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _receiverNameController,
                decoration: const InputDecoration(
                  labelText: 'Receiver Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter the name of the user to call',
                ),
                enabled: !_isTestRunning,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Call Type: '),
                  const SizedBox(width: 8),
                  DropdownButton<CallType>(
                    value: _selectedCallType,
                    onChanged: _isTestRunning
                        ? null
                        : (CallType? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCallType = newValue;
                              });
                            }
                          },
                    items: CallType.values.map((CallType type) {
                      return DropdownMenuItem<CallType>(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isTestRunning ? null : _runValidation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isTestRunning
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Running Validation...'),
                          ],
                        )
                      : const Text('Run Validation'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Validation Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final bool isError = log.contains('❌');
                      final bool isSuccess = log.contains('✅');
                      final bool isWarning = log.contains('⚠️');

                      Color? textColor;
                      if (isError) {
                        textColor = Colors.red;
                      } else if (isSuccess)
                        textColor = Colors.green;
                      else if (isWarning) textColor = Colors.orange;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isError || isSuccess || isWarning
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
