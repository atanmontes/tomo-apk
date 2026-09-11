import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_service.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';
import 'manga/manga_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MangaService _mangaService = MangaService();
  static const String libraryKey = 'tomo_library';

  List<MangaItem> library = [];

  bool loading = true;
  bool adding = false;

  String search = '';

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

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();

    final data =
        library.map((manga) => manga.toJson()).toList();

    await prefs.setString(
      libraryKey,
      jsonEncode(data),
    );
  }

  Future<void> addManga(
    String input,
    BuildContext sheetContext,
  ) async {
    final url = input.trim();

    if (!url.contains('weebcentral.com/series/')) {
      showError(
        'Introduce una URL válida de una serie de WeebCentral.',
      );
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || uri.pathSegments.length < 2) {
      showError('La URL no parece ser válida.');
      return;
    }

    final id = uri.pathSegments[1];

    if (library.any((manga) => manga.id == id)) {
      showError(
        'Ese manga ya está en tu biblioteca.',
      );
      return;
    }

    setState(() {
      adding = true;
    });

    try {
      final manga =
          await _mangaService.fetchManga(url);

      library.insert(0, manga);

      await saveLibrary();

      if (!mounted) return;

      Navigator.of(sheetContext).pop();

      setState(() {
        adding = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        adding = false;
      });

      showError(
        'No se pudo obtener el manga.\n\n$e',
      );
    }
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tomoCard,
          title: const Text('TOMO'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: tomoPink),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeManga(MangaItem manga) async {
    library.removeWhere(
      (item) => item.id == manga.id,
    );

    await saveLibrary();

    if (mounted) {
      setState(() {});
    }
  }

  List<MangaItem> get filteredLibrary {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return library;
    }

    return library.where((manga) {
      return manga.title
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  void showAddMangaDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tomoCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isAdding = adding;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context)
                            .viewInsets
                            .bottom +
                        20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add manga',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste a WeebCentral series URL.',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    enabled: !isAdding,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText:
                          'https://weebcentral.com/series/...',
                      filled: true,
                      fillColor: tomoBackground,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: isAdding
                          ? null
                          : () async {
                              setSheetState(() {});

                              await addManga(
                                controller.text,
                                sheetContext,
                              );

                              if (mounted) {
                                setSheetState(() {});
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: tomoPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      child: isAdding
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Add manga',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: TextButton(
                      onPressed: isAdding
                          ? null
                          : () =>
                              Navigator.pop(
                                sheetContext,
                              ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MangaSearchPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mangas = filteredLibrary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 38),
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
        actions: [
          IconButton(
            onPressed: openSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: showAddMangaDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add manga',
          ),
          const SizedBox(width: 8),
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
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'My Library',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          search = value;
                        });
                      },
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
                    const SizedBox(height: 20),
                    Expanded(
                      child: library.isEmpty
                          ? _EmptyLibrary(
                              onAdd:
                                  showAddMangaDialog,
                            )
                          : mangas.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No manga found.',
                                    style: TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  cacheExtent: 500,
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 24,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 18,
                                    childAspectRatio:
                                        0.61,
                                  ),
                                  itemCount:
                                      mangas.length,
                                  itemBuilder:
                                      (context, index) {
                                    final manga =
                                        mangas[index];

                                    return RepaintBoundary(
                                      child: MangaCard(
                                        manga: manga,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MangaDetailPage(
                                                manga:
                                                    manga,
                                              ),
                                            ),
                                          );
                                        },
                                        onRemove: () {
                                          removeManga(
                                            manga,
                                          );
                                        },
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
  final VoidCallback onAdd;

  const _EmptyLibrary({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your library is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first manga to get started.',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add manga'),
            style: FilledButton.styleFrom(
              backgroundColor: tomoPink,
            ),
          ),
        ],
      ),
    );
  }
}