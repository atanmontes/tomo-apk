import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_service.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String libraryKey = 'tomo_library';

  List<MangaItem> library = [];
  bool loading = true;
  String search = '';
  List<MangaItem> searchResults = [];
  bool searching = false;
  Timer? _searchDebounce;
  final MangaService _mangaService = MangaService();

  @override
  void initState() {
    super.initState();
    loadLibrary();
  }

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(libraryKey);

    if (saved != null) {
      try {
        final List<dynamic> data = jsonDecode(saved);
        library = data
            .map((item) => MangaItem.fromJson(item))
            .toList();
      } catch (_) {
        library = [];
      }
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final data = library.map((manga) => manga.toJson()).toList();

    await prefs.setString(
      libraryKey,
      jsonEncode(data),
    );
  }

  Future<void> removeManga(MangaItem manga) async {
    library.removeWhere((item) => item.id == manga.id);
    await saveLibrary();

    if (!mounted) return;
    setState(() {});
  }

  List<MangaItem> get displayedManga {
    if (search.trim().isEmpty) {
      return library;
    }

    return searchResults;
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> openManga(MangaItem manga) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(manga: manga),
      ),
    );

    // The detail page can add a manga directly to SharedPreferences.
    // Reload when returning so the library updates immediately.
    await loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    final mangas = displayedManga;

    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: RichText(
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
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'My Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (library.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '${library.length} manga${library.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search manga...',
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
                          : search.trim().isNotEmpty && mangas.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No manga found.',
                                    style: TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                )
                              : search.trim().isEmpty && library.isEmpty
                                  ? const _EmptyLibrary()
                                  : GridView.builder(
                                  cacheExtent: 500,
                                  padding: const EdgeInsets.only(
                                    bottom: 24,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 18,
                                    childAspectRatio: 0.61,
                                  ),
                                  itemCount: mangas.length,
                                  itemBuilder: (context, index) {
                                    final manga = mangas[index];

                                    return RepaintBoundary(
                                      child: MangaCard(
                                        manga: manga,
                                        onTap: () => openManga(manga),
                                        onRemove: () => removeManga(manga),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -55),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your library is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a manga and tap "Add to library" to save it here.',
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
