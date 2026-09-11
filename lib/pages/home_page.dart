import 'dart:async';

import 'package:flutter/material.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_service.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';
import 'library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final GlobalKey<LibraryPageState> _libraryKey =
      GlobalKey<LibraryPageState>();

  void _onNavigationChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      _libraryKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tomoBackground,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const _HomeContent(),
          LibraryPage(key: _libraryKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationChanged,
        backgroundColor: tomoCard,
        indicatorColor: tomoPink.withOpacity(0.16),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  String search = '';
  List<MangaItem> searchResults = [];
  bool searching = false;
  Timer? _searchDebounce;

  final MangaService _mangaService = MangaService();

  void _onSearchChanged(String value) {
    setState(() {
      search = value;
    });

    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        searching = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchManga(query),
    );
  }

  Future<void> _searchManga(String query) async {
    if (!mounted) return;

    setState(() {
      searching = true;
    });

    try {
      final results = await _mangaService.searchManga(query);

      if (!mounted || search.trim() != query) return;

      setState(() {
        searchResults = results;
        searching = false;
      });
    } catch (_) {
      if (!mounted || search.trim() != query) return;

      setState(() {
        searchResults = [];
        searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _openManga(MangaItem manga) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(manga: manga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = search.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 32),
                children: [
                  TextSpan(
                    text: 'TOM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: 'O',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: tomoPink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find your next manga',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search WeebCentral...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 21,
                ),
                filled: true,
                fillColor: tomoCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: tomoPink,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: tomoPink,
                      ),
                    )
                  : hasSearch && searchResults.isEmpty
                      ? const Center(
                          child: Text(
                            'No manga found.',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : hasSearch
                          ? GridView.builder(
                              cacheExtent: 500,
                              padding: const EdgeInsets.only(bottom: 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 18,
                                childAspectRatio: 0.61,
                              ),
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final manga = searchResults[index];

                                return RepaintBoundary(
                                  child: MangaCard(
                                    manga: manga,
                                    onTap: () => _openManga(manga),
                                  ),
                                );
                              },
                            )
                          : const _HomeEmptyState(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.search_rounded,
                size: 64,
                color: Colors.white24,
              ),
              SizedBox(height: 16),
              Text(
                'Search WeebCentral',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Search for a manga and open it to view its details and chapters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
