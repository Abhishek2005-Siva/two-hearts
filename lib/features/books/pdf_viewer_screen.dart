import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;

  /// Book id in the couple's `books` collection. When set, reading progress
  /// is synced (resume + partner position) and page notes are enabled.
  final String? bookId;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.bookId,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  String? _localPath;
  String? _error;
  bool _loading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  PDFViewController? _pdfCtrl;
  Timer? _progressDebounce;
  bool _resumeApplied = false;

  StreamSubscription<BookWish?>? _bookSub;
  StreamSubscription<List<BookNote>>? _notesSub;
  BookWish? _book;
  List<BookNote> _notes = [];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _watchBookData();
    _downloadAndLoad();
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _bookSub?.cancel();
    _notesSub?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _watchBookData() {
    final coupleId = ref.read(coupleIdProvider);
    final bookId = widget.bookId;
    if (coupleId == null || bookId == null) return;
    final fs = ref.read(firestoreServiceProvider);
    _bookSub = fs.watchBook(coupleId, bookId).listen((book) {
      if (!mounted || book == null) return;
      // Resume where I left off — only once, before the PDF renders.
      if (!_resumeApplied) {
        final mine = book.progressOf(_uid);
        if (mine != null && mine.page > 0) _currentPage = mine.page;
        _resumeApplied = true;
      }
      setState(() => _book = book);
    });
    _notesSub = fs.watchBookNotes(coupleId, bookId).listen((notes) {
      if (mounted) setState(() => _notes = notes);
    });
  }

  Future<void> _downloadAndLoad() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 401) {
        throw Exception(
            'Cloudinary is blocking PDF downloads (HTTP 401).\n\n'
            'Fix: log in to cloudinary.com → Settings → Security → '
            'enable "Allow delivery of PDF and ZIP files", then retry.');
      }
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/book_${widget.url.hashCode.abs()}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) setState(() => _localPath = file.path);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _saveProgress(int page, int total) {
    final coupleId = ref.read(coupleIdProvider);
    final bookId = widget.bookId;
    if (coupleId == null || bookId == null || total <= 0) return;
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 1), () {
      ref
          .read(firestoreServiceProvider)
          .updateBookProgress(coupleId, bookId, page, total)
          .ignore();
    });
  }

  List<BookNote> get _notesOnCurrentPage =>
      _notes.where((n) => n.page == _currentPage).toList();

  BookProgress? get _partnerProgress {
    final book = _book;
    final uid = _uid;
    if (book == null || uid == null) return null;
    for (final entry in book.progress.entries) {
      if (entry.key != uid) return entry.value;
    }
    return null;
  }

  Future<void> _showJumpToPage() async {
    final ctrl = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Go to page',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1 – $_totalPages',
            hintStyle: const TextStyle(color: Colors.white38),
          ),
          onSubmitted: (v) => Navigator.pop(dctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, int.tryParse(ctrl.text)),
            child: const Text('Go', style: TextStyle(color: Color(0xFFE8896A))),
          ),
        ],
      ),
    );
    if (page != null && page >= 1 && page <= _totalPages) {
      await _pdfCtrl?.setPage(page - 1);
    }
  }

  void _showNotesSheet() {
    final coupleId = ref.read(coupleIdProvider);
    final bookId = widget.bookId;
    if (coupleId == null || bookId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PageNotesSheet(
        page: _currentPage,
        notes: _notesOnCurrentPage,
        myUid: _uid,
        myName: ref.read(currentUserProvider).valueOrNull?.displayName,
        partnerName:
            ref.read(partnerUserProvider).valueOrNull?.displayName,
        onAdd: (text) {
          ref.read(firestoreServiceProvider).addBookNote(
                coupleId,
                bookId,
                BookNote(
                  id: const Uuid().v4(),
                  page: _currentPage,
                  authorId: _uid ?? '',
                  text: text,
                  createdAt: DateTime.now(),
                ),
              ).ignore();
        },
        onDelete: (noteId) {
          ref
              .read(firestoreServiceProvider)
              .deleteBookNote(coupleId, bookId, noteId)
              .ignore();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final partnerProgress = _partnerProgress;
    final noteCount = _notesOnCurrentPage.length;

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
          if (widget.bookId != null && !_loading && _error == null)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.sticky_note_2_outlined,
                      color: Colors.white70),
                  tooltip: 'Notes on this page',
                  onPressed: _showNotesSheet,
                ),
                if (noteCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8896A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$noteCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: _showJumpToPage,
                  child: Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.white38, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13, height: 1.5),
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
            ),
          );
        }
        final me = ref.watch(currentUserProvider).valueOrNull;
        final pageNotes = _notesOnCurrentPage;
        // Whose face to show on the popup — prefer the partner's note.
        final popupNote = pageNotes.isEmpty
            ? null
            : pageNotes.firstWhere((n) => n.authorId != _uid,
                orElse: () => pageNotes.first);
        return Stack(
          children: [
            PDFView(
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
                  _saveProgress(page ?? 0, total ?? 0);
                }
              },
            ),
            // Tap zones: left third = previous page, right third = next page
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.25,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _currentPage > 0
                    ? () => _pdfCtrl?.setPage(_currentPage - 1)
                    : null,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.25,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _totalPages > 0 && _currentPage < _totalPages - 1
                    ? () => _pdfCtrl?.setPage(_currentPage + 1)
                    : null,
              ),
            ),
            // Note popup: a little face peeks from the side when this page
            // has a note. Tap it to read.
            if (popupNote != null)
              Positioned(
                right: 10,
                top: MediaQuery.of(context).size.height * 0.3,
                child: GestureDetector(
                  onTap: _showNotesSheet,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE8896A), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE8896A)
                              .withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Builder(builder: (context) {
                      final isMine = popupNote.authorId == _uid;
                      final author = isMine ? me : partner;
                      return author?.avatarUrl != null
                          ? CircleAvatar(
                              radius: 20,
                              backgroundImage: CachedNetworkImageProvider(
                                  author!.avatarUrl!))
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFE8896A)
                                  .withValues(alpha: 0.25),
                              child: const Text('💌',
                                  style: TextStyle(fontSize: 16)),
                            );
                    }),
                  )
                      .animate(key: ValueKey('note-$_currentPage'))
                      .scale(
                          begin: Offset.zero,
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.elasticOut)
                      .then()
                      .shake(hz: 3, rotation: 0.04, duration: 500.ms),
                ),
              ),
            // Partner reading position chip
            if (partnerProgress != null &&
                partnerProgress.totalPages > 0 &&
                partnerProgress.page != _currentPage)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pdfCtrl?.setPage(partnerProgress.page),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFE8896A)
                                .withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded,
                              color: Color(0xFFE8896A), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${partner?.displayName.split(' ').first ?? 'Partner'} '
                            'is on page ${partnerProgress.page + 1} — tap to jump',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ── Page notes sheet ────────────────────────────────────────────────────────

class _PageNotesSheet extends StatefulWidget {
  final int page;
  final List<BookNote> notes;
  final String? myUid;
  final String? myName;
  final String? partnerName;
  final void Function(String text) onAdd;
  final void Function(String noteId) onDelete;

  const _PageNotesSheet({
    required this.page,
    required this.notes,
    required this.myUid,
    required this.myName,
    required this.partnerName,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<_PageNotesSheet> createState() => _PageNotesSheetState();
}

class _PageNotesSheetState extends State<_PageNotesSheet> {
  final _ctrl = TextEditingController();
  late List<BookNote> _notes;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.notes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    setState(() {
      _notes.add(BookNote(
        id: 'local',
        page: widget.page,
        authorId: widget.myUid ?? '',
        text: text,
        createdAt: DateTime.now(),
      ));
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Notes on page ${widget.page + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _notes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No notes here yet.\nLeave one for them to find ♡',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final note = _notes[i];
                        final isMine = note.authorId == widget.myUid;
                        final author = isMine
                            ? (widget.myName?.split(' ').first ?? 'You')
                            : (widget.partnerName?.split(' ').first ??
                                'Partner');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFFE8896A)
                                    .withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMine
                                  ? const Color(0xFFE8896A)
                                      .withValues(alpha: 0.35)
                                  : Colors.white12,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    author,
                                    style: const TextStyle(
                                        color: Color(0xFFE8896A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM d, h:mm a')
                                        .format(note.createdAt),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10),
                                  ),
                                  const Spacer(),
                                  if (isMine && note.id != 'local')
                                    GestureDetector(
                                      onTap: () {
                                        widget.onDelete(note.id);
                                        setState(() => _notes.removeAt(i));
                                      },
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white38,
                                          size: 16),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note.text,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Leave a note on this page…',
                      hintStyle: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8896A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
