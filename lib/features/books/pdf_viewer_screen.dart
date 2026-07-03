import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({super.key, required this.url, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  String? _error;
  bool _loading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  PDFViewController? _pdfCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _downloadAndLoad();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _downloadAndLoad() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/book_${widget.url.hashCode.abs()}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) setState(() => _localPath = file.path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load PDF: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Builder(builder: (context) {
        if (_loading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFE8896A)),
                SizedBox(height: 16),
                Text('Loading book…',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          );
        }
        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white38, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    setState(() { _loading = true; _error = null; });
                    _downloadAndLoad();
                  },
                  child: const Text('Retry',
                      style: TextStyle(color: Color(0xFFE8896A))),
                ),
              ],
            ),
          );
        }
        return PDFView(
          filePath: _localPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: _currentPage,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            if (mounted) setState(() => _totalPages = pages ?? 0);
          },
          onError: (error) {
            if (mounted) setState(() => _error = error.toString());
          },
          onPageError: (page, error) {},
          onViewCreated: (ctrl) => _pdfCtrl = ctrl,
          onPageChanged: (page, total) {
            if (mounted) {
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? 0;
              });
            }
          },
        );
      }),
    );
  }
}
