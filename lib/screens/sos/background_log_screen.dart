import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_service.dart' show kSosBgLogKey, uploadBackgroundLog;

/// Debug screen that surfaces the background SOS diagnostic log
/// (`kSosBgLogKey`) captured by the background isolate. Lets you review,
/// copy, clear and manually re-upload the captured values.
class BackgroundLogScreen extends StatefulWidget {
  const BackgroundLogScreen({super.key});

  @override
  State<BackgroundLogScreen> createState() => _BackgroundLogScreenState();
}

class _BackgroundLogScreenState extends State<BackgroundLogScreen> {
  static const Color _brand = Color(0xFFCB30E0);

  List<String> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(kSosBgLogKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _entries.join('\n')));
    _toast('Copied ${_entries.length} entries to clipboard');
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear log?'),
        content: const Text('This deletes the captured background entries on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSosBgLogKey);
    await _load();
    _toast('Background log cleared');
  }

  Future<void> _upload() async {
    final prefs = await SharedPreferences.getInstance();
    final int sosId = prefs.getInt('current_sos_id') ?? 0;
    final String? token = prefs.getString('auth_token');
    if (sosId <= 0 || token == null || token.isEmpty) {
      _toast('No active server session to upload to');
      return;
    }
    _toast('Uploading…');
    await uploadBackgroundLog(sosId, token);
    await _load();
    _toast('Upload attempted — see latest log entry for result');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _colorFor(String line) {
    if (line.contains('❌')) return Colors.red.shade700;
    if (line.contains('⚠️')) return Colors.orange.shade800;
    if (line.contains('✅') || line.contains('🎙️')) return Colors.green.shade700;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    // Newest first for quick scanning.
    final reversed = _entries.reversed.toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text('Background Logs (${_entries.length})'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy),
            onPressed: _entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: _entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: _entries.isEmpty ? null : _upload,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Upload to server'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    'No background entries yet.\nStart an SOS to capture values.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: reversed.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final line = reversed[i];
                      return SelectableText(
                        line,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontFamily: 'monospace',
                          color: _colorFor(line),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
