import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';
import '../../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<MangaItem> library = [];
  String search = '';

  final Set<String> _libraryBusyIds = <String>{};

  @override
  void initState() {
    super.initState();
    loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tomo_library');

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;

      setState(() {
        library = [];
      });

      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      final loaded = decoded
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        library = [];
      });
    }
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

  Future<void> _toggleLibrary(MangaItem manga) async {
    if (_libraryBusyIds.contains(manga.id)) {
      return;
    }

    setState(() {
      _libraryBusyIds.add(manga.id);
    });

    try {
      library.removeWhere(
        (item) => item.id == manga.id,
      );

      await _saveLibrary();

      if (!mounted) return;

      setState(() {});
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

    await loadLibrary();
  }

  List<MangaItem> get filteredLibrary {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return library;
    }

    return library.where((manga) {
      final title = manga.title.toLowerCase();

      final authors = manga.authors
          .join(' ')
          .toLowerCase();

      return title.contains(query) ||
          authors.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mangas = filteredLibrary;

    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: tomoBackground,
        elevation: 0,
        title: const Text(
          'My Library',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  search = value;
                });
              },
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Search your library...',
                hintStyle: const TextStyle(
                  color: Colors.white38,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white54,
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            search = '';
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
              ),
            ),
          ),
          Expanded(
            child: mangas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            library.isEmpty
                                ? Icons.menu_book_rounded
                                : Icons.search_off_rounded,
                            size: 54,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            library.isEmpty
                                ? 'Your library is empty'
                                : 'No manga found',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            library.isEmpty
                                ? 'Search for a manga on Home and tap the + button to save it here.'
                                : 'Try a different search.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24,
                    ),
                    cacheExtent: 500,
                    itemCount: mangas.length,
                    separatorBuilder: (_, __) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final manga = mangas[index];

                      return RepaintBoundary(
                        child: MangaCard(
                          manga: manga,
                          onTap: () => _openManga(manga),
                          onLibraryToggle: () {
                            _toggleLibrary(manga);
                          },
                          isInLibrary: true,
                          libraryBusy: _libraryBusyIds.contains(
                            manga.id,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}