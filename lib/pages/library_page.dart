import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';
import '../../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';

enum _LibraryFilter {
  all,
  inProgress,
  notStarted,
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<MangaItem> library = [];
  Map<String, int> _readCounts = {};
  String search = '';
  _LibraryFilter _filter = _LibraryFilter.all;

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
        _readCounts = {};
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

      final counts = <String, int>{};

      for (final manga in loaded) {
        final saved = prefs.getStringList(
          'tomo_read_${manga.id}',
        );

        counts[manga.id] = saved?.length ?? 0;
      }

      if (!mounted) return;

      setState(() {
        library = loaded;
        _readCounts = counts;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        library = [];
        _readCounts = {};
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

      setState(() {
        _readCounts.remove(manga.id);
      });
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

  bool _hasProgress(MangaItem manga) {
    return (_readCounts[manga.id] ?? 0) > 0;
  }

  List<MangaItem> get filteredLibrary {
    final query = search.trim().toLowerCase();

    final result = library.where((manga) {
      if (_filter == _LibraryFilter.inProgress &&
          !_hasProgress(manga)) {
        return false;
      }

      if (_filter == _LibraryFilter.notStarted &&
          _hasProgress(manga)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final title = manga.title.toLowerCase();
      final authors = manga.authors.join(' ').toLowerCase();

      return title.contains(query) ||
          authors.contains(query);
    }).toList();

    result.sort((a, b) {
      final aProgress = _hasProgress(a);
      final bProgress = _hasProgress(b);

      if (aProgress != bProgress) {
        return aProgress ? -1 : 1;
      }

      return a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
    });

    return result;
  }

  String get _filterLabel {
    switch (_filter) {
      case _LibraryFilter.all:
        return 'All';
      case _LibraryFilter.inProgress:
        return 'In Progress';
      case _LibraryFilter.notStarted:
        return 'Not Started';
    }
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
        actions: [
          PopupMenuButton<_LibraryFilter>(
            tooltip: 'Filter library',
            icon: const Icon(
              Icons.filter_list_rounded,
              color: Colors.white70,
            ),
            color: tomoCard,
            initialValue: _filter,
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _LibraryFilter.all,
                child: Text('All'),
              ),
              PopupMenuItem(
                value: _LibraryFilter.inProgress,
                child: Text('In Progress'),
              ),
              PopupMenuItem(
                value: _LibraryFilter.notStarted,
                child: Text('Not Started'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8,
            ),
            child: Row(
              children: [
                Expanded(
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              8,
            ),
            child: Row(
              children: [
                Text(
                  _filterLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${mangas.length} manga',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
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
                                : 'Try a different search or filter.',
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
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
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
                          libraryBusy:
                              _libraryBusyIds.contains(manga.id),
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
