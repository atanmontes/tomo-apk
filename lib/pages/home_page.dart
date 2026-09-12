import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_search_service.dart';
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
  Key _homeKey = UniqueKey();

  void _onNavigationChanged(int index) {
    if (index == 0 && _selectedIndex == 0) {
      setState(() {
        _homeKey = UniqueKey();
      });
      return;
    }

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
        children: [
          _HomeContent(key: _homeKey),
          const LibraryPage(),
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
  const _HomeContent({super.key});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  List<MangaItem> library = [];
  List<MangaItem> latestManga = [];
  List<MangaItem> searchResults = [];

  String search = '';
  bool searching = false;
  bool loadingLatest = false;

  Timer? _searchDebounce;

  final TextEditingController _searchController =
      TextEditingController();

  final Set<String> _libraryBusyIds = <String>{};
  final MangaService _mangaService = MangaService();
  final MangaSearchService _searchService = MangaSearchService();

  MangaSearchFilters _searchFilters = const MangaSearchFilters();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    if (!mounted) return;

    setState(() {
      loadingLatest = true;
    });

    try {
      final results = await _searchService.searchManga(
        '',
        filters: const MangaSearchFilters(
          sort: 'Latest Updates',
          order: 'Descending',
        ),
      );

      if (!mounted) return;

      setState(() {
        latestManga = results.take(12).toList();
        loadingLatest = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        latestManga = [];
        loadingLatest = false;
      });
    }
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
      final results = await _searchService.searchManga(
        query,
        filters: _searchFilters,
      );

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

  Future<void> _openSearchFilters() async {
    final selected = await showModalBottomSheet<MangaSearchFilters>(
      context: context,
      backgroundColor: tomoCard,
      isScrollControlled: true,
      builder: (_) {
        return _SearchFiltersSheet(
          initial: _searchFilters,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _searchFilters = selected;
    });

    if (search.trim().isNotEmpty) {
      _searchDebounce?.cancel();
      await _searchManga(search.trim());
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
    return library.any((item) => item.id == manga.id);
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
        library.removeWhere((item) => item.id == manga.id);
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
        builder: (_) => MangaDetailPage(manga: manga),
      ),
    );

    await _loadLibrary();
  }

  Future<void> _clearSearch() async {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      search = '';
      searchResults = [];
      searching = false;
      _searchFilters = const MangaSearchFilters();
    });

    await _loadLatest();
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
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                              onPressed: _clearSearch,
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
                ),
                const SizedBox(width: 8),
                Material(
                  color: tomoCard,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _openSearchFilters,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 50,
                      height: 52,
                      child: Icon(
                        Icons.tune_rounded,
                        color: _searchFilters.hasFilters
                            ? tomoPink
                            : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: tomoPink,
                      ),
                    )
                  : hasSearch
                      ? searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'No manga found.',
                                style: TextStyle(
                                  color: Colors.white54,
                                ),
                              ),
                            )
                          : ListView.separated(
                              cacheExtent: 500,
                              padding: const EdgeInsets.only(
                                bottom: 24,
                              ),
                              itemCount: searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final manga = searchResults[index];

                                return RepaintBoundary(
                                  child: MangaCard(
                                    manga: manga,
                                    onTap: () => _openManga(manga),
                                    isInLibrary: _isInLibrary(manga),
                                    libraryBusy:
                                        _libraryBusyIds.contains(manga.id),
                                    onLibraryToggle: () {
                                      _toggleLibrary(manga);
                                    },
                                    showAuthor: false,
                                  ),
                                );
                              },
                            )
                      : _HomeContentSections(
                          latestManga: latestManga,
                          loadingLatest: loadingLatest,
                          library: library,
                          isInLibrary: _isInLibrary,
                          libraryBusy: (id) =>
                              _libraryBusyIds.contains(id),
                          onOpen: _openManga,
                          onLibraryToggle: _toggleLibrary,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContentSections extends StatelessWidget {
  final List<MangaItem> latestManga;
  final List<MangaItem> library;
  final bool loadingLatest;
  final bool Function(MangaItem) isInLibrary;
  final bool Function(String) libraryBusy;
  final Future<void> Function(MangaItem) onOpen;
  final Future<void> Function(MangaItem) onLibraryToggle;

  const _HomeContentSections({
    required this.latestManga,
    required this.library,
    required this.loadingLatest,
    required this.isInLibrary,
    required this.libraryBusy,
    required this.onOpen,
    required this.onLibraryToggle,
  });

  @override
  Widget build(BuildContext context) {
    final continueReading = library.take(6).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (continueReading.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Continue Reading',
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 185,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: continueReading.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final manga = continueReading[index];

                return _HomeMangaTile(
                  manga: manga,
                  onTap: () => onOpen(manga),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        const _SectionTitle(
          title: 'Latest Updates',
          icon: Icons.update_rounded,
        ),
        const SizedBox(height: 10),
        if (loadingLatest)
          const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            ),
          )
        else if (latestManga.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No updates available right now.',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ...latestManga.map(
            (manga) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RepaintBoundary(
                child: MangaCard(
                  manga: manga,
                  onTap: () => onOpen(manga),
                  isInLibrary: isInLibrary(manga),
                  libraryBusy: libraryBusy(manga.id),
                  onLibraryToggle: () => onLibraryToggle(manga),
                  showAuthor: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: tomoPink, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HomeMangaTile extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;

  const _HomeMangaTile({
    required this.manga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 105,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 105,
              height: 145,
              child: manga.cover.isEmpty
                  ? Container(
                      color: tomoCard,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white24,
                        size: 34,
                      ),
                    )
                  : Image.network(
                      manga.cover,
                      width: 105,
                      height: 145,
                      fit: BoxFit.cover,
                      cacheWidth: 260,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: tomoCard,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white24,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFiltersSheet extends StatefulWidget {
  final MangaSearchFilters initial;

  const _SearchFiltersSheet({
    required this.initial,
  });

  @override
  State<_SearchFiltersSheet> createState() =>
      _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late String sort = widget.initial.sort;
  late String order = widget.initial.order;
  late String official = widget.initial.official;
  late String anime = widget.initial.animeAdaptation;
  late String adult = widget.initial.adultContent;
  late String status = widget.initial.status;
  late String type = widget.initial.type;
  late Set<String> tags = {...widget.initial.tags};

  static const sorts = [
    'Best Match',
    'Alphabet',
    'Popularity',
    'Subscribers',
    'Recently Added',
    'Latest Updates',
  ];

  static const tagsList = [
    'Action',
    'Adult',
    'Adventure',
    'Comedy',
    'Doujinshi',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Gender Bender',
    'Harem',
    'Hentai',
    'Historical',
    'Horror',
    'Isekai',
    'Josei',
    'Lolicon',
    'Martial Arts',
    'Mature',
    'Mecha',
    'Mystery',
    'Psychological',
    'Romance',
    'School Life',
    'Sci-fi',
    'Seinen',
    'Shotacon',
    'Shoujo',
    'Shoujo Ai',
    'Shounen',
    'Shounen Ai',
    'Slice of Life',
    'Smut',
    'Sports',
    'Supernatural',
    'Tragedy',
    'Yaoi',
    'Yuri',
    'Other',
  ];

  void _apply() {
    Navigator.pop(
      context,
      MangaSearchFilters(
        sort: sort,
        order: order,
        official: official,
        animeAdaptation: anime,
        adultContent: adult,
        status: status,
        type: type,
        tags: tags.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Search Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        sort = 'Best Match';
                        order = 'Ascending';
                        official = 'Any';
                        anime = 'Any';
                        adult = 'Any';
                        status = 'Any';
                        type = 'Any';
                        tags.clear();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FilterDropdown(
                label: 'Sort',
                value: sort,
                values: sorts,
                onChanged: (value) => setState(() => sort = value),
              ),
              _FilterDropdown(
                label: 'Order',
                value: order,
                values: const ['Ascending', 'Descending'],
                onChanged: (value) => setState(() => order = value),
              ),
              _FilterDropdown(
                label: 'Official Translation',
                value: official,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => official = value),
              ),
              _FilterDropdown(
                label: 'Anime Adaptation',
                value: anime,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => anime = value),
              ),
              _FilterDropdown(
                label: 'Adult Content',
                value: adult,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => adult = value),
              ),
              _FilterDropdown(
                label: 'Series Status',
                value: status,
                values: const [
                  'Any',
                  'Ongoing',
                  'Complete',
                  'Hiatus',
                  'Canceled',
                ],
                onChanged: (value) => setState(() => status = value),
              ),
              _FilterDropdown(
                label: 'Series Type',
                value: type,
                values: const [
                  'Any',
                  'Manga',
                  'Manhwa',
                  'Manhua',
                  'OEL',
                ],
                onChanged: (value) => setState(() => type = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tagsList.map((tag) {
                  final selected = tags.contains(tag);

                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          tags.add(tag);
                        } else {
                          tags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: tomoPink,
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: tomoCard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: tomoBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}
