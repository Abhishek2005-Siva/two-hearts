import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'archive_search_service.dart';

/// Search & pick a free, legal movie/TV/documentary from the Internet
/// Archive's public-domain + Creative Commons catalog. Pops with
/// (videoUrl, title) when a playable file is found, same shape as the
/// "Play from a link" dialog, so the caller just feeds it into the
/// existing Movie Night `_start()` flow.
class ArchiveSearchScreen extends StatefulWidget {
  const ArchiveSearchScreen({super.key});

  @override
  State<ArchiveSearchScreen> createState() => _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends State<ArchiveSearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  bool _searching = false;
  bool _resolving = false;
  String? _error;
  List<ArchiveItem> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    final id = ++_requestId;
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ArchiveSearchService.search(q);
      if (!mounted || id != _requestId) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = "Couldn't search Archive.org:\n$e");
    } finally {
      if (mounted && id == _requestId) setState(() => _searching = false);
    }
  }

  Future<void> _pick(ArchiveItem item) async {
    setState(() => _resolving = true);
    try {
      final url = await ArchiveSearchService.bestVideoUrl(item.identifier);
      if (!mounted) return;
      if (url == null) {
        setState(() => _resolving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '"${item.title}" doesn\'t have a playable video file — try another result.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      Navigator.of(context).pop((url, item.title));
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Couldn't load that title: $e"),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text('Free classics',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  'Public-domain & Creative Commons films from the Internet '
                  'Archive — free and legal, mostly older or independent '
                  'titles rather than recent releases.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onChanged,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search a movie or show title…',
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_resolving) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchCtrl.text.trim().isEmpty
              ? 'Type a title to search ♡'
              : 'No matches — try a different title',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _pick(item),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.cardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(width: 56, height: 56, color: AppColors.bgCardLight),
                      errorWidget: (_, _, _) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.bgCardLight,
                        child: const Icon(Icons.movie_creation_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.year != null
                              ? '${item.title} (${item.year})'
                              : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
