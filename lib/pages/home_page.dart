import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void _onNavigationChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tomoBackground,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _HomeContent(),
          LibraryPage(),
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
  List<MangaItem> library = [];
  String search = '';
  List<MangaItem> searchResults = [];
  bool searching = false;

  Timer? _searchDebounce;

  final TextEditingController _searchController =
      TextEditingController();

  final Set<String> _libraryBusyIds = <String>{};

  final MangaService _mangaService = MangaService();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

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

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('tomo_library');

    if (saved == null) {
      return;
    }

    try {
      final List<dynamic> data = jsonDecode(saved);

      final loaded = data
          .map(
            (item) => MangaItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        library = loaded;
      });
    } catch (_) {}
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'tomo_library',
      jsonEncode(
        library.map((manga) => manga.toJson()).toList(),
      ),
    );
  }

  bool _isInLibrary(MangaItem manga) {
    return library.any(
      (item) => item.id == manga.id,
    );
  }

  Future<void> _toggleLibrary(MangaItem manga) async {
    if (_libraryBusyIds.contains(manga.id)) {
      return;
    }

    setState(() {
      _libraryBusyIds.add(manga.id);
    });

    try {
      if (_isInLibrary(manga)) {
        library.removeWhere(
          (item) => item.id == manga.id,
        );
      } else {
        final fullManga = await _mangaService.fetchManga(
          manga.url,
        );

        library.insert(0, fullManga);
      }

      await _saveLibrary();
    } catch (_) {
      // Keep the current library unchanged if the request fails.
    } finally {
      if (!mounted) return;

      setState(() {
        _libraryBusyIds.remove(manga.id);
      });
    }
  }

  Future<void> _openManga(MangaItem manga) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(
          manga: manga,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = search.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 32,
                ),
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
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search WeebCentral...',
                hintStyle: const TextStyle(
                  color: Colors.white38,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 21,
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();

                          setState(() {
                            search = '';
                            searchResults = [];
                            searching = false;
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        splashRadius: 20,
                      )
                    : null,
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
                          ? ListView.separated(
                              cacheExtent: 500,
                              padding: const EdgeInsets.only(
                                bottom: 24,
                              ),
                              itemCount: searchResults.length,
                              separatorBuilder: (_, __) {
                                return const SizedBox(
                                  height: 10,
                                );
                              },
                              itemBuilder: (context, index) {
                                final manga =
                                    searchResults[index];

                                return RepaintBoundary(
                                  child: MangaCard(
                                    manga: manga,
                                    onTap: () {
                                      _openManga(manga);
                                    },
                                    isInLibrary:
                                        _isInLibrary(manga),
                                    libraryBusy:
                                        _libraryBusyIds
                                            .contains(manga.id),
                                    onLibraryToggle: () {
                                      _toggleLibrary(manga);
                                    },
                                    showAuthor: false,
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
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
          ),
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