import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga/manga.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> {
  static const String libraryKey = 'tomo_library';

  List<MangaItem> library = [];
  bool loading = true;
  String search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(libraryKey);

    List<MangaItem> loaded = [];

    if (saved != null) {
      try {
        final List<dynamic> data = jsonDecode(saved);
        loaded = data
            .map((item) => MangaItem.fromJson(item))
            .toList();
      } catch (_) {
        loaded = [];
      }
    }

    if (!mounted) return;

    setState(() {
      library = loaded;
      loading = false;
    });
  }

  List<MangaItem> get filteredLibrary {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return library;
    }

    return library.where((manga) {
      return manga.title.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openManga(MangaItem manga) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(manga: manga),
      ),
    );

    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final mangas = filteredLibrary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  search = value;
                });
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search your library...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 21,
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
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: tomoPink,
                      ),
                    )
                  : library.isEmpty
                      ? const _EmptyLibrary()
                      : mangas.isEmpty
                          ? const Center(
                              child: Text(
                                'No manga found.',
                                style: TextStyle(
                                  color: Colors.white54,
                                ),
                              ),
                            )
                          : GridView.builder(
                              cacheExtent: 500,
                              padding: const EdgeInsets.only(bottom: 24),
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
                                    onTap: () => _openManga(manga),
                                  ),
                                );
                              },
                            ),
            ),
          ],
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
            children: const [
              Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: Colors.white24,
              ),
              SizedBox(height: 16),
              Text(
                'Your library is empty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Open a manga and tap the + button to save it here.',
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
