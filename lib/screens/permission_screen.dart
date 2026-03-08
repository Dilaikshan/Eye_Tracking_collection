import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:eye_tracking_collection/screens/language_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  static const routeName = '/permissions';

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {

  // Permission states
  PermissionStatus _cameraStatus  = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;

  // Firebase state
  bool   _firebaseChecking = false;
  bool?  _firebaseOk;
  String _firebaseMessage  = '';

  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final camera = await Permission.camera.status;
    setState(() => _cameraStatus = camera);
  }

  Future<void> _requestAll() async {
    setState(() => _checking = true);

    // 1. Camera
    final camera = await Permission.camera.request();
    setState(() => _cameraStatus = camera);

    // 2. Storage (version-aware)
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 33) {
        await Permission.photos.request();
        final media = await Permission.videos.request();
        setState(() => _storageStatus = media);
      } else {
        final storage = await Permission.storage.request();
        setState(() => _storageStatus = storage);
      }
    }

    // 3. Firebase ping
    await _checkFirebase();

    setState(() => _checking = false);
  }

  Future<void> _checkFirebase() async {
    setState(() {
      _firebaseChecking = true;
      _firebaseMessage  = 'Checking Firebase connection...';
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('_health')
          .doc('ping_${DateTime.now().millisecondsSinceEpoch}');

      await docRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ok',
        'app': 'eye_tracking_collection',
      });

      final snap = await docRef.get();
      await docRef.delete();

      setState(() {
        _firebaseOk      = snap.exists;
        _firebaseMessage = snap.exists
            ? 'Firebase connected ✅'
            : 'Firebase: read failed ⚠️';
        _firebaseChecking = false;
      });
    } catch (e) {
      setState(() {
        _firebaseOk      = false;
        _firebaseMessage = 'Firebase offline ⚠️ (data will sync later)\n$e';
        _firebaseChecking = false;
      });
    }
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);
    if (mounted) {
      Navigator.pushReplacementNamed(
          context, LanguageSelectionScreen.routeName);
    }
  }

  Widget _permissionTile(
      String title, String reason, PermissionStatus status) {
    final IconData icon;
    final Color color;
    final String label;

    if (status.isGranted) {
      icon  = Icons.check_circle;
      color = Colors.green;
      label = 'Granted';
    } else if (status.isDenied) {
      icon  = Icons.cancel;
      color = Colors.red;
      label = 'Denied';
    } else {
      icon  = Icons.hourglass_empty;
      color = Colors.orange;
      label = 'Pending';
    }

    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold,
              color: Colors.white)),
      subtitle: Text(reason,
          style: const TextStyle(color: Colors.white70)),
      trailing: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _cameraStatus.isGranted;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.remove_red_eye_outlined,
                  size: 72, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text('Assistive Eye Tracking',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text('Research — SEU/IS/19/ICT/047',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // ── Permission tiles ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _permissionTile(
                      'Camera',
                      'Required to track eye movements via front camera',
                      _cameraStatus,
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _permissionTile(
                      'Storage',
                      'Required to export research data as CSV',
                      _storageStatus,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Firebase status card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    _firebaseChecking
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            _firebaseOk == null
                                ? Icons.cloud_outlined
                                : (_firebaseOk!
                                    ? Icons.cloud_done
                                    : Icons.cloud_off),
                            color: _firebaseOk == null
                                ? Colors.grey
                                : (_firebaseOk!
                                    ? Colors.green
                                    : Colors.orange),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _firebaseOk == null
                            ? 'Firebase: not checked yet'
                            : _firebaseMessage,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Buttons ───────────────────────────────────────────────────
              if (_cameraStatus.isPermanentlyDenied)
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                  onPressed: () => openAppSettings(),
                )
              else if (!_cameraStatus.isGranted)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    onPressed: _checking ? null : _requestAll,
                    child: _checking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Grant Permissions',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),

              if (canProceed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    onPressed: _proceed,
                    child: const Text('Continue to App',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

