import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class DataViewerScreen extends StatefulWidget {
  const DataViewerScreen({super.key});

  static const String routeName = '/data-viewer';

  @override
  State<DataViewerScreen> createState() => _DataViewerScreenState();
}

class _DataViewerScreenState extends State<DataViewerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isExporting = false;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _exportToCSV(
      String sessionId, Map<String, dynamic> sessionData) async {
    setState(() => _isExporting = true);

    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return;
      }

      // Get all sample chunks
      final samplesSnapshot = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('samples')
          .orderBy('chunkIndex')
          .get();

      // Prepare CSV content
      final csvBuffer = StringBuffer();

      // CSV Header
      csvBuffer.writeln('Timestamp,Mode,Color Label,Target X,Target Y,'
          'MediaPipe Left Iris X,MediaPipe Left Iris Y,MediaPipe Right Iris X,MediaPipe Right Iris Y,'
          'MediaPipe Left Eye Open,MediaPipe Right Eye Open,MediaPipe Confidence,'
          'MLKit Gaze X,MLKit Gaze Y,MLKit Head Euler X,MLKit Head Euler Y,MLKit Head Euler Z,'
          'MLKit Left Eye Open,MLKit Right Eye Open,MLKit Confidence,'
          'Azure Gaze X,Azure Gaze Y,Azure Pupil Left X,Azure Pupil Left Y,Azure Pupil Right X,Azure Pupil Right Y,'
          'Overall Confidence,Speed Label,Participant Name,Participant Age,Blindness Type');

      // Process each chunk
      for (final chunkDoc in samplesSnapshot.docs) {
        final chunkData = chunkDoc.data();
        final samples = chunkData['samples'] as List<dynamic>? ?? [];

        for (final sample in samples) {
          final s = sample as Map<String, dynamic>;

          // Extract data safely
          final timestamp =
              s['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
          final mode = s['mode'] ?? '';
          final colorLabel = s['colorLabel'] ?? '';
          final target = s['target'] as Map<String, dynamic>? ?? {};
          final targetX = target['x'] ?? 0.0;
          final targetY = target['y'] ?? 0.0;

          // MediaPipe data
          final mediapipe = s['mediapipe'] as Map<String, dynamic>? ?? {};
          final mpLeftIris =
              mediapipe['leftIrisCenter'] as Map<String, dynamic>? ?? {};
          final mpRightIris =
              mediapipe['rightIrisCenter'] as Map<String, dynamic>? ?? {};
          final mpLeftX = mpLeftIris['x'] ?? 0.0;
          final mpLeftY = mpLeftIris['y'] ?? 0.0;
          final mpRightX = mpRightIris['x'] ?? 0.0;
          final mpRightY = mpRightIris['y'] ?? 0.0;
          final mpLeftOpen = mediapipe['leftEyeOpen'] ?? false;
          final mpRightOpen = mediapipe['rightEyeOpen'] ?? false;
          final mpConfidence = mediapipe['confidence'] ?? 0.0;

          // MLKit data
          final mlkit = s['mlkit'] as Map<String, dynamic>? ?? {};
          final mlGaze = mlkit['gazeEstimate'] as Map<String, dynamic>? ?? {};
          final mlGazeX = mlGaze['x'] ?? 0.0;
          final mlGazeY = mlGaze['y'] ?? 0.0;
          final mlHead =
              mlkit['headEulerAngles'] as Map<String, dynamic>? ?? {};
          final mlHeadX = mlHead['x'] ?? 0.0;
          final mlHeadY = mlHead['y'] ?? 0.0;
          final mlHeadZ = mlHead['z'] ?? 0.0;
          final mlLeftOpen = mlkit['leftEyeOpen'] ?? false;
          final mlRightOpen = mlkit['rightEyeOpen'] ?? false;
          final mlConfidence = mlkit['confidence'] ?? 0.0;

          // Azure data
          final azure = s['azure'] as Map<String, dynamic>? ?? {};
          final azGaze = azure['gazeOrigin'] as Map<String, dynamic>? ?? {};
          final azGazeX = azGaze['x'] ?? 0.0;
          final azGazeY = azGaze['y'] ?? 0.0;
          final azPupilLeft = azure['pupilLeft'] as Map<String, dynamic>? ?? {};
          final azPupilRight =
              azure['pupilRight'] as Map<String, dynamic>? ?? {};
          final azPupilLeftX = azPupilLeft['x'] ?? 0.0;
          final azPupilLeftY = azPupilLeft['y'] ?? 0.0;
          final azPupilRightX = azPupilRight['x'] ?? 0.0;
          final azPupilRightY = azPupilRight['y'] ?? 0.0;

          final overallConfidence = s['overallConfidence'] ?? 0.0;
          final speedLabel = s['speedLabel'] ?? '';

          // Write CSV row
          csvBuffer.writeln('$timestamp,$mode,$colorLabel,$targetX,$targetY,'
              '$mpLeftX,$mpLeftY,$mpRightX,$mpRightY,'
              '$mpLeftOpen,$mpRightOpen,$mpConfidence,'
              '$mlGazeX,$mlGazeY,$mlHeadX,$mlHeadY,$mlHeadZ,'
              '$mlLeftOpen,$mlRightOpen,$mlConfidence,'
              '$azGazeX,$azGazeY,$azPupilLeftX,$azPupilLeftY,$azPupilRightX,$azPupilRightY,'
              '$overallConfidence,$speedLabel,'
              '${sessionData['participantProfile']?['name'] ?? ''},'
              '${sessionData['participantProfile']?['age'] ?? ''},'
              '${sessionData['participantProfile']?['blindnessType'] ?? ''}');
        }
      }

      // Save to file
      final directory = await getExternalStorageDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eye_tracking_${sessionId}_$timestamp.csv';
      final file = File('${directory!.path}/$fileName');

      await file.writeAsString(csvBuffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to: ${file.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collected Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('sessions')
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data?.docs ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Text('No data collected yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final data = session.data() as Map<String, dynamic>;
              final profile =
                  data['participantProfile'] as Map<String, dynamic>? ?? {};

              final startTime = data['startTime'] as Timestamp?;
              final startTimeStr = startTime != null
                  ? DateFormat('MMM dd, yyyy HH:mm').format(startTime.toDate())
                  : 'Unknown';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    profile['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$startTimeStr\n'
                    '${profile['blindnessType'] ?? 'Unknown'} | '
                    'Samples: ${data['totalSamples'] ?? 0}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Age', '${profile['age'] ?? 'N/A'}'),
                          _buildInfoRow(
                              'Dominant Eye', profile['dominantEye'] ?? 'N/A'),
                          _buildInfoRow('Vision Acuity',
                              '${profile['visionAcuity'] ?? 'N/A'}/10'),
                          _buildInfoRow('Wears Glasses',
                              profile['wearsGlasses'] == true ? 'Yes' : 'No'),
                          _buildInfoRow(
                              'Language', profile['languageCode'] ?? 'N/A'),
                          _buildInfoRow('Status', data['status'] ?? 'Unknown'),
                          _buildInfoRow('Session ID', session.id),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting
                                  ? null
                                  : () => _exportToCSV(session.id, data),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download),
                              label: Text(_isExporting
                                  ? 'Exporting...'
                                  : 'Export to CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
