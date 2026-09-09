import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';

const Color tomoPink = Color(0xFFEC4899);
const Color tomoBackground = Color(0xFF09090B);
const Color tomoCard = Color(0xFF18181B);

class MangaItem {
  final String id;
  final String title;
  final String cover;
  final String url;

  MangaItem({
    required this.id,
    required this.title,
    required this.cover,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover': cover,
      'url': url,
    };
  }

  factory MangaItem.fromJson(Map<String, dynamic> json) {
    return MangaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class ChapterItem {
  final String id;
  final String title;
  final String url;

  ChapterItem({
    required this.id,
    required this.title,
    required this.url,
  });
}

void main() {
  runApp(const TomoApp());
}

class TomoApp extends StatelessWidget {
  const TomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOMO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: tomoBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tomoPink,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

    final data = library.map((manga) => manga.toJson()).toList();

    await prefs.setString(
      libraryKey,
      jsonEncode(data),
    );
  }

  Future<MangaItem> fetchManga(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/130.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,'
            '*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://weebcentral.com/',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral respondió HTTP ${response.statusCode}',
      );
    }

    final document = parser.parse(response.body);

    String title =
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim() ??
        '';

    if (title.contains('|')) {
      title = title.split('|').first.trim();
    }

    String cover = '';

    for (final image in document.querySelectorAll('img')) {
      final src = image.attributes['src'] ?? '';
      final dataSrc = image.attributes['data-src'] ?? '';

      final imageUrl = src.isNotEmpty ? src : dataSrc;

      if (imageUrl.contains('temp.compsci88.com/cover')) {
        cover = imageUrl;
        break;
      }
    }

    final uri = Uri.parse(url);
    final parts = uri.pathSegments;

    if (parts.length < 2 || parts[0] != 'series') {
      throw Exception('URL de serie inválida.');
    }

    final id = parts[1];

    return MangaItem(
      id: id,
      title: title.isEmpty ? 'Unknown manga' : title,
      cover: cover,
      url: 'https://weebcentral.com/series/$id',
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
      showError('Ese manga ya está en tu biblioteca.');
      return;
    }

    setState(() {
      adding = true;
    });

    try {
      final manga = await fetchManga(url);

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
    library.removeWhere((item) => item.id == manga.id);

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
      return manga.title.toLowerCase().contains(query);
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
                    MediaQuery.of(context).viewInsets.bottom + 20,
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
                                fontWeight: FontWeight.bold,
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
                              Navigator.pop(sheetContext),
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

  @override
  Widget build(BuildContext context) {
    final mangas = filteredLibrary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TOMO',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: showAddMangaDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add manga',
          ),
          const SizedBox(width: 6),
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
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'My Library',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
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
                              onAdd: showAddMangaDialog,
                            )
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
                                  padding:
                                      const EdgeInsets.only(
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
                                  itemBuilder:
                                      (context, index) {
                                    final manga =
                                        mangas[index];

                                    return MangaCard(
                                      manga: manga,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MangaDetailPage(
                                              manga: manga,
                                            ),
                                          ),
                                        );
                                      },
                                      onRemove: () {
                                        removeManga(manga);
                                      },
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

class MangaCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: manga.cover.isEmpty
                        ? Container(
                            color: tomoCard,
                            child: const Icon(
                              Icons.menu_book,
                              size: 50,
                              color: Colors.white24,
                            ),
                          )
                        : Image.network(
                            manga.cover,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: tomoCard,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Colors.white24,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              backgroundColor: tomoCard,
                              title: const Text(
                                'Remove manga?',
                              ),
                              content: Text(
                                'Remove "${manga.title}" from your library?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    onRemove();
                                  },
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          manga.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class MangaDetailPage extends StatefulWidget {
  final MangaItem manga;

  const MangaDetailPage({
    super.key,
    required this.manga,
  });

  @override
  State<MangaDetailPage> createState() =>
      _MangaDetailPageState();
}

class _MangaDetailPageState
    extends State<MangaDetailPage> {
  List<ChapterItem> chapters = [];

  bool loadingChapters = true;
  String? chapterError;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  Future<void> loadChapters() async {
    setState(() {
      loadingChapters = true;
      chapterError = null;
    });

    try {
      // Construimos la URL usando únicamente el ID,
      // exactamente como lo hace PlayTorrio.
      final seriesUrl =
          'https://weebcentral.com/series/${widget.manga.id}';

      final chaptersUrl =
          '$seriesUrl/full-chapter-list';

      const userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/130.0.0.0 Safari/537.36';

      // Mismos headers básicos que utiliza PlayTorrio.
      final headers = {
        'User-Agent': userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,'
            '*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };

      // Primero cargamos la página principal de la serie.
      final seriesResponse = await http.get(
        Uri.parse(seriesUrl),
        headers: headers,
      );

      if (seriesResponse.statusCode != 200) {
        throw Exception(
          'WeebCentral respondió HTTP '
          '${seriesResponse.statusCode} al cargar la serie.',
        );
      }

      // Ahora pedimos la lista completa de capítulos.
      final chaptersResponse = await http.get(
        Uri.parse(chaptersUrl),
        headers: headers,
      );

      if (chaptersResponse.statusCode != 200) {
        final bodyPreview = chaptersResponse.body
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        final preview = bodyPreview.length > 500
            ? bodyPreview.substring(0, 500)
            : bodyPreview;

        throw Exception(
          'HTTP ${chaptersResponse.statusCode}\n'
          'URL: $chaptersUrl\n'
          'Tamaño de respuesta: '
          '${chaptersResponse.bodyBytes.length} bytes\n\n'
          'Respuesta:\n$preview',
        );
      }

      final document = parser.parse(
        chaptersResponse.body,
      );

      final found = <ChapterItem>[];
      final seen = <String>{};

      for (final element in document.querySelectorAll(
        'a[href*="/chapters/"]',
      )) {
        final href = element.attributes['href'];

        if (href == null || href.trim().isEmpty) {
          continue;
        }

        final chapterUrl = Uri.parse(
          'https://weebcentral.com',
        ).resolve(href).toString();

        final uri = Uri.tryParse(chapterUrl);

        if (uri == null) {
          continue;
        }

        final match = RegExp(
          r'/chapters/([^/]+)',
          caseSensitive: false,
        ).firstMatch(uri.path);

        if (match == null) {
          continue;
        }

        final chapterId = match.group(1)!;

        if (seen.contains(chapterId)) {
          continue;
        }

        seen.add(chapterId);

        final titleSpan = element.querySelector(
          '.grow span',
        );

        final rawText =
            (titleSpan?.text.isNotEmpty == true
                    ? titleSpan!.text
                    : element.text)
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

        final numberMatch = RegExp(
          r'(\d+(?:\.\d+)?)',
        ).firstMatch(rawText);

        final number = numberMatch?.group(1);

        final title = number != null
            ? 'Capítulo $number'
            : rawText.isNotEmpty
                ? rawText
                : 'Capítulo';

        found.add(
          ChapterItem(
            id: chapterId,
            title: title,
            url: chapterUrl,
          ),
        );
      }

      found.sort((a, b) {
        return _chapterNumber(a.title)
            .compareTo(_chapterNumber(b.title));
      });

      if (!mounted) return;

      setState(() {
        chapters = found;
        loadingChapters = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingChapters = false;
        chapterError = e.toString();
      });
    }
  }

  double _chapterNumber(String title) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(title);

    return match == null
        ? double.infinity
        : double.tryParse(match.group(1)!) ??
            double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: tomoPink,
          backgroundColor: tomoCard,
          onRefresh: loadChapters,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              30,
            ),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(18),
                  child: widget.manga.cover.isEmpty
                      ? Container(
                          width: 180,
                          height: 260,
                          color: tomoCard,
                          child: const Icon(
                            Icons.menu_book,
                            size: 60,
                            color: Colors.white24,
                          ),
                        )
                      : Image.network(
                          widget.manga.cover,
                          width: 180,
                          height: 260,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.manga.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Text(
                    'Chapters',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!loadingChapters &&
                      chapterError == null)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tomoPink.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${chapters.length}',
                        style: const TextStyle(
                          color: tomoPink,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (loadingChapters)
                Container(
                  padding:
                      const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tomoCard,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: tomoPink,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading chapters...',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              else if (chapterError != null)
                Container(
                  padding:
                      const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: tomoCard,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white38,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Could not load chapters.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapterError!,
                        textAlign:
                            TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: loadChapters,
                        child:
                            const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (chapters.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tomoCard,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'No chapters found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: tomoCard,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: chapters.length,
                    separatorBuilder:
                        (_, __) => const Divider(
                      height: 1,
                      color: Colors.white10,
                    ),
                    itemBuilder:
                        (context, index) {
                      final chapter =
                          chapters[index];

                      return InkWell(
                        onTap: () {
                          // El lector se conecta aquí
                          // en la siguiente etapa.
                        },
                        borderRadius:
                            BorderRadius.circular(18),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    BoxDecoration(
                                  color: tomoPink
                                      .withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  size: 19,
                                  color: tomoPink,
                                ),
                              ),
                              const SizedBox(
                                width: 13,
                              ),
                              Expanded(
                                child: Text(
                                  chapter.title,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color:
                                    Colors.white24,
                                size: 21,
                              ),
                            ],
                          ),
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