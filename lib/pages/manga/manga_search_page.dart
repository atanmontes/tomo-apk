import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../services/manga/manga_service.dart';
import '../../theme/tomo_theme.dart';
import 'manga_detail_page.dart';

class MangaSearchPage extends StatefulWidget {
  const MangaSearchPage({super.key});

  @override
  State<MangaSearchPage> createState() => _MangaSearchPageState();
}

class _MangaSearchPageState extends State<MangaSearchPage> {
  final MangaService _mangaService = MangaService();
  final TextEditingController _controller =
      TextEditingController();

  List<MangaItem> results = [];

  bool loading = false;
  String? error;
  String lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> searchManga() async {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        results = [];
        error = null;
        lastQuery = '';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
      lastQuery = query;
    });

    try {
      final found = await _mangaService.searchManga(query);

      if (!mounted) return;

      setState(() {
        results = found;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        results = [];
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> openManga(MangaItem manga) async {
    try {
      final fullManga =
          await _mangaService.fetchManga(manga.url);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MangaDetailPage(
            manga: fullManga,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load manga details:\n$e',
          ),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Search',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction:
                          TextInputAction.search,
                      onSubmitted: (_) => searchManga(),
                      decoration: InputDecoration(
                        hintText: 'Search manga...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: tomoCard,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: FilledButton(
                      onPressed:
                          loading ? null : searchManga,
                      style: FilledButton.styleFrom(
                        backgroundColor: tomoPink,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.search,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: tomoPink,
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.white24,
              ),
              const SizedBox(height: 14),
              const Text(
                'Search failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: searchManga,
                style: FilledButton.styleFrom(
                  backgroundColor: tomoPink,
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (lastQuery.isEmpty) {
      return const Center(
        child: Text(
          'Search WeebCentral for manga.',
          style: TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No manga found for "$lastQuery".',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final manga = results[index];

        return _SearchResultCard(
          manga: manga,
          onTap: () => openManga(manga),
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.manga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTags = manga.tags.take(4).toList();

    return Material(
      color: tomoCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 88,
                  height: 128,
                  child: manga.cover.isEmpty
                      ? Container(
                          color: tomoBackground,
                          child: const Icon(
                            Icons.menu_book_outlined,
                            color: Colors.white24,
                            size: 34,
                          ),
                        )
                      : Image.network(
                          manga.cover,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return Container(
                              color: tomoBackground,
                              child: const Icon(
                                Icons
                                    .broken_image_outlined,
                                color: Colors.white24,
                                size: 34,
                              ),
                            );
                          },
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visibleTags.isNotEmpty)
                        Text(
                          visibleTags.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        )
                      else
                        const Text(
                          'No tags available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}