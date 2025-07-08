import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/agora_call_test_report.dart';

class AgoraCallVerificationScreen extends StatefulWidget {
  const AgoraCallVerificationScreen({Key? key}) : super(key: key);

  @override
  State<AgoraCallVerificationScreen> createState() =>
      _AgoraCallVerificationScreenState();
}

class _AgoraCallVerificationScreenState
    extends State<AgoraCallVerificationScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isRunningTest = false;
  Map<String, dynamic>? _testReport;

  // Supabase function URL for token generation
  final String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  late AgoraCallTestReport _testReporter;

  @override
  void initState() {
    super.initState();
    _testReporter = AgoraCallTestReport(supabaseUrl: supabaseUrl);
    _testReporter.logStream.listen((log) {
      setState(() {
        _logs.add(log);
      });
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _testReporter.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to run this test')),
      );
      return;
    }

    setState(() {
      _isRunningTest = true;
      _logs.clear();
      _testReport = null;
    });

    try {
      final report = await _testReporter.runFullTest();
      setState(() {
        _testReport = report;
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _logs.add('❌ Error running test: $e');
        _isRunningTest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Call Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This screen runs a comprehensive test of the Agora calling system:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('1. Request token from Supabase Function'),
            const Text('2. Create call in Firestore as User A (caller)'),
            const Text('3. Simulate incoming call for User B (receiver)'),
            const Text('4. Initialize Agora engine and join channel'),
            const Text('5. Verify remote user joining and media streaming'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRunningTest ? null : _runTest,
              child: _isRunningTest
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Running Test...'),
                      ],
                    )
                  : const Text('Run Verification Test'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Test Logs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color textColor = Colors.black;

                    if (log.contains('❌')) {
                      textColor = Colors.red;
                    } else if (log.contains('✅')) {
                      textColor = Colors.green;
                    } else if (log.contains('⚠️')) {
                      textColor = Colors.orange;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_testReport != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Test Summary:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTestSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestSummary() {
    if (_testReport == null) return const SizedBox.shrink();

    final bool overallSuccess = _testReport!['overallSuccess'] == true;
    final summary = _testReport!['summary'] as Map<String, dynamic>;

    return Card(
      color: overallSuccess ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overallSuccess ? Icons.check_circle : Icons.error,
                  color: overallSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  overallSuccess ? 'All Tests Passed' : 'Some Tests Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: overallSuccess ? Colors.green : Colors.red,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Success Rate: ${summary['successRate']}'),
            Text(
                'Tests Passed: ${summary['passedTests']}/${summary['totalTests']}'),
            const SizedBox(height: 16),
            const Text(
              'Test Results by Section:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildSectionResults(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionResults() {
    if (_testReport == null) return [];

    final sections = _testReport!['sections'] as Map<String, dynamic>;
    final List<Widget> sectionWidgets = [];

    sections.forEach((section, data) {
      if (data is Map<String, dynamic> && data.containsKey('success')) {
        final bool success = data['success'] == true;

        sectionWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section,
                    style: TextStyle(
                      color:
                          success ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return sectionWidgets;
  }
}
