import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/manga/manga_service.dart';
import '../../theme/tomo_theme.dart';

class MangaReaderPage extends StatefulWidget {
  final MangaItem manga;
  final ChapterItem chapter;
  final List<ChapterItem> chapters;

  const MangaReaderPage({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapters,
  });

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  final MangaService _mangaService = MangaService();
  static const String _readPrefix = 'tomo_read_';
  static const String _pagePrefix = 'tomo_page_';
  static const String _lastPrefix = 'tomo_last_';

  List<String> images = [];
  bool loading = true;
  String? error;
  int currentPage = 0;

  late ChapterItem activeChapter;
  late final PageController pageController;

  SharedPreferences? _prefs;
  Set<String> readChapters = <String>{};
  Timer? _saveTimer;
  bool progressLoading = true;

  String get _readKey => '$_readPrefix${widget.manga.id}';

  String _pageKey(String chapterId) =>
      '$_pagePrefix${widget.manga.id}_$chapterId';

  String get _lastKey => '$_lastPrefix${widget.manga.id}';

  @override
  void initState() {
    super.initState();
    activeChapter = widget.chapter;
    pageController = PageController();
    _loadProgressAndChapter();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadProgressAndChapter() async {
    final prefs = await _preferences;
    final savedRead = prefs.getStringList(_readKey) ?? <String>[];
    final savedPage = prefs.getInt(_pageKey(activeChapter.id)) ?? 0;

    if (!mounted) return;

    setState(() {
      readChapters = savedRead.toSet();
      currentPage = savedPage;
      progressLoading = false;
    });

    await prefs.setString(_lastKey, activeChapter.id);
    await loadImages(initialPage: savedPage);
  }

  void _scheduleSaveProgress() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () async {
      if (images.isEmpty) return;

      final prefs = await _preferences;
      await prefs.setInt(
        _pageKey(activeChapter.id),
        currentPage,
      );
      await prefs.setString(_lastKey, activeChapter.id);
    });
  }

  Future<void> _saveProgressNow() async {
    _saveTimer?.cancel();
    if (images.isEmpty) return;

    final prefs = await _preferences;
    await prefs.setInt(
      _pageKey(activeChapter.id),
      currentPage,
    );
    await prefs.setString(_lastKey, activeChapter.id);
  }

  Future<void> _markChapterAsRead(String chapterId) async {
    final updated = <String>{...readChapters, chapterId};
    readChapters = updated;

    final prefs = await _preferences;
    await prefs.setStringList(
      _readKey,
      updated.toList(),
    );

    if (mounted) setState(() {});
  }

  Future<void> loadImages({int initialPage = 0}) async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final foundImages = await _mangaService.fetchChapterImages(
        activeChapter.id,
      );

      if (foundImages.isEmpty) {
        throw Exception(
          'No se encontraron páginas en este capítulo.',
        );
      }

      final safePage = initialPage.clamp(
        0,
        foundImages.length - 1,
      );

      if (!mounted) return;

      setState(() {
        images = foundImages;
        currentPage = safePage;
        loading = false;
        error = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !pageController.hasClients) return;

        pageController.jumpToPage(safePage);
        _precacheNearbyPages(safePage);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _precacheNearbyPages(int page) {
    if (!mounted || images.isEmpty) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (screenWidth * pixelRatio * 1.25).round();

    // Prioriza la siguiente página para que el gesto de pasar se sienta inmediato.
    final candidates = <int>{page + 1};

    // También deja lista la anterior cuando ya estamos más avanzados.
    if (page > 0) {
      candidates.add(page - 1);
    }

    for (final index in candidates) {
      if (index < 0 || index >= images.length) continue;

      final provider = ResizeImage(
        NetworkImage(images[index]),
        width: cacheWidth,
      );

      precacheImage(provider, context);
    }
  }

  void goToPage(int page) {
    if (page < 0 ||
        page >= images.length ||
        !pageController.hasClients) {
      return;
    }

    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  int get _activeChapterIndex {
    return widget.chapters.indexWhere(
      (chapter) => chapter.id == activeChapter.id,
    );
  }

  ChapterItem? get _previousChapter {
    final index = _activeChapterIndex;
    if (index <= 0) return null;
    return widget.chapters[index - 1];
  }

  ChapterItem? get _nextChapter {
    final index = _activeChapterIndex;
    if (index < 0 ||
        index >= widget.chapters.length - 1) {
      return null;
    }
    return widget.chapters[index + 1];
  }

  Future<void> _openChapter(ChapterItem chapter) async {
    if (chapter.id == activeChapter.id) return;

    await _saveProgressNow();
    if (!mounted) return;

    final prefs = await _preferences;
    final savedPage = prefs.getInt(_pageKey(chapter.id)) ?? 0;

    setState(() {
      activeChapter = chapter;
      currentPage = savedPage;
      images = [];
      loading = true;
      error = null;
    });

    await prefs.setString(_lastKey, chapter.id);
    await loadImages(initialPage: savedPage);
  }

  Future<void> _goToPreviousChapter() async {
    final chapter = _previousChapter;
    if (chapter == null) return;
    await _openChapter(chapter);
  }

  Future<void> _goToNextChapter() async {
    final chapter = _nextChapter;
    if (chapter == null) return;

    await _markChapterAsRead(activeChapter.id);
    await _openChapter(chapter);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 4,
        leading: IconButton(
          onPressed: () {
            _saveProgressNow();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.manga.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              activeChapter.title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _saveProgressNow();
              Navigator.pop(context);
            },
            tooltip: 'Volver a capítulos',
            icon: const Icon(Icons.list_alt_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: progressLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            )
          : loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: tomoPink,
                  ),
                )
              : error != null
                  ? _ReaderError(
                      message: error!,
                      onRetry: () {
                        loadImages(initialPage: currentPage);
                      },
                    )
                  : images.isEmpty
                      ? const Center(
                          child: Text(
                            'No pages found.',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : _buildPageMode(),
    );
  }

  Widget _buildPageMode() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 88),
          child: PageView.builder(
            controller: pageController,
            itemCount: images.length,
            physics: const NeverScrollableScrollPhysics(),
            allowImplicitScrolling: true,
          onPageChanged: (index) {
            if (currentPage == index) return;

            setState(() {
              currentPage = index;
            });

            _scheduleSaveProgress();
            _precacheNearbyPages(index);

            // Llegar a la última página significa que el capítulo terminó.
            if (index == images.length - 1) {
              _markChapterAsRead(activeChapter.id);
            }
          },
          itemBuilder: (context, index) {
            final cacheWidth =
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context) *
                        1.25)
                    .round();

            return Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  images[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: cacheWidth,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(
                        color: tomoPink,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white24,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            );
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 80,
          child: _ReaderControls(
            leftLabel: 'Anterior',
            rightLabel: 'Siguiente',
            centerText:
                'Página ${currentPage + 1} de ${images.length}',
            onPrevious: currentPage > 0
                ? () => goToPage(currentPage - 1)
                : (_previousChapter != null ? _goToPreviousChapter : null),
            onNext: currentPage < images.length - 1
                ? () => goToPage(currentPage + 1)
                : (_nextChapter != null ? _goToNextChapter : null),
            isChapterBoundary: currentPage == 0 || currentPage == images.length - 1,
            previousChapterTitle: _previousChapter?.title,
            nextChapterTitle: _nextChapter?.title,
          ),
        ),
      ],
    );
  }
}

class _ReaderControls extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final String centerText;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool isChapterBoundary;
  final String? previousChapterTitle;
  final String? nextChapterTitle;

  const _ReaderControls({
    required this.leftLabel,
    required this.rightLabel,
    required this.centerText,
    required this.onPrevious,
    required this.onNext,
    this.isChapterBoundary = false,
    this.previousChapterTitle,
    this.nextChapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: tomoCard.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: leftLabel,
            icon: const Icon(
              Icons.chevron_left,
            ),
            color: onPrevious == null
                ? Colors.white12
                : Colors.white,
          ),
          Expanded(
            child: Center(
              child: Text(
                centerText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: rightLabel,
            icon: const Icon(
              Icons.chevron_right,
            ),
            color: onNext == null
                ? Colors.white12
                : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReaderError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load chapter.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: tomoPink,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}