import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';

const String tomoUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/130.0.0.0 Safari/537.36';

final http.Client tomoHttpClient = http.Client();

Map<String, String> get tomoHeaders => const {
      'User-Agent': tomoUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,'
          'image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': 'https://weebcentral.com/',
    };

class MangaService {
  String _clean(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _absoluteUrl(String url) {
    if (url.isEmpty) return '';

    return Uri.parse(
      'https://weebcentral.com',
    ).resolve(url).toString();
  }

  // --------------------------------------------------
  // METADATA HELPERS
  // --------------------------------------------------

  List<String> _extractLinksByLabel(
    Document document,
    String label,
  ) {
    final target = _clean(label).toLowerCase();

    // WeebCentral coloca los campos de metadata
    // dentro de elementos que suelen tener opacity-70.
    //
    // IMPORTANTE:
    // No usamos element.text completo para decidir qué
    // links pertenecen al campo, porque un contenedor
    // padre puede contener TODOS los metadatos.
    //
    // Primero buscamos elementos cuyo propio texto
    // comience con la etiqueta y que tengan enlaces.
    for (final element
        in document.querySelectorAll('div.opacity-70')) {
      final directText = element.nodes
          .whereType<Text>()
          .map((node) => node.data ?? '')
          .join(' ');

      final cleanedDirectText = _clean(directText);
      final lowerDirectText =
          cleanedDirectText.toLowerCase();

      if (!lowerDirectText.startsWith(target)) {
        continue;
      }

      final links = element.children
          .where(
            (child) => child.localName == 'a',
          )
          .map<String>(
            (child) => _clean(child.text),
          )
          .where(
            (text) => text.isNotEmpty,
          )
          .toList();

      if (links.isNotEmpty) {
        return links;
      }
    }

    // --------------------------------------------------
    // FALLBACK
    // --------------------------------------------------
    //
    // Si la estructura cambia, buscamos cualquier
    // elemento que tenga la etiqueta en su texto
    // directo y tomamos solamente sus enlaces directos.
    //
    for (final element
        in document.querySelectorAll('*')) {
      final directText = element.nodes
          .whereType<Text>()
          .map((node) => node.data ?? '')
          .join(' ');

      final cleanedDirectText = _clean(directText);
      final lowerDirectText =
          cleanedDirectText.toLowerCase();

      if (!lowerDirectText.startsWith(target)) {
        continue;
      }

      final links = element.children
          .where(
            (child) => child.localName == 'a',
          )
          .map<String>(
            (child) => _clean(child.text),
          )
          .where(
            (text) => text.isNotEmpty,
          )
          .toList();

      if (links.isNotEmpty) {
        return links;
      }
    }

    return [];
  }

  String _extractValueByLabel(
    Document document,
    String label,
  ) {
    final target = label.toLowerCase();

    for (final element
        in document.querySelectorAll('*')) {
      final text = _clean(element.text);
      final lowerText = text.toLowerCase();

      if (!lowerText.startsWith(target)) {
        continue;
      }

      final value = text.substring(label.length).trim();

      if (value.isEmpty) {
        continue;
      }

      return _clean(
        value.replaceFirst(
          RegExp(r'^:\s*'),
          '',
        ),
      );
    }

    return '';
  }

  bool _extractBoolByLabel(
    Document document,
    String label,
  ) {
    final value = _extractValueByLabel(
      document,
      label,
    ).toLowerCase();

    return value == 'yes' ||
        value == 'true' ||
        value == 'si';
  }

  String _extractDescription(
    Document document,
  ) {
    for (final element
        in document.querySelectorAll('*')) {
      if (_clean(element.text).toLowerCase() !=
          'description') {
        continue;
      }

      final next = element.nextElementSibling;

      if (next != null) {
        final description = _clean(next.text);

        if (description.isNotEmpty &&
            description.toLowerCase() !=
                'description') {
          return description;
        }
      }
    }

    return '';
  }

  String _extractCover(
    Document document,
  ) {
    // Primero buscamos imágenes normales.
    for (final image
        in document.querySelectorAll('img')) {
      final src =
          image.attributes['src'] ?? '';

      final dataSrc =
          image.attributes['data-src'] ?? '';

      final candidate =
          src.isNotEmpty ? src : dataSrc;

      if (candidate.contains(
        'temp.compsci88.com/cover',
      )) {
        return _absoluteUrl(candidate);
      }
    }

    // Si no encontramos ninguna, buscamos
    // source/srcset.
    for (final source
        in document.querySelectorAll('source')) {
      final srcSet =
          source.attributes['srcset'] ?? '';

      if (!srcSet.contains(
        'temp.compsci88.com/cover',
      )) {
        continue;
      }

      final first = srcSet
          .split(',')
          .first
          .trim()
          .split(' ')
          .first;

      if (first.isNotEmpty) {
        return _absoluteUrl(first);
      }
    }

    return '';
  }

  // --------------------------------------------------
  // FETCH MANGA DETAILS
  // --------------------------------------------------

  Future<MangaItem> fetchManga(
    String url,
  ) async {
    final response = await tomoHttpClient
        .get(
          Uri.parse(url),
          headers: tomoHeaders,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP '
        '${response.statusCode}.',
      );
    }

    final document =
        parser.parse(response.body);

    String title =
        document.querySelector('h1')?.text.trim() ??
            document
                .querySelector('title')
                ?.text
                .trim() ??
            '';

    if (title.contains('|')) {
      title = title.split('|').first.trim();
    }

    final cover = _extractCover(document);

    final uri = Uri.parse(url);
    final parts = uri.pathSegments;

    if (parts.length < 2 ||
        parts[0] != 'series') {
      throw Exception(
        'Invalid series URL.',
      );
    }

    final id = parts[1];

    // --------------------------------------------------
    // AUTHORS
    // --------------------------------------------------

    final authors = _extractLinksByLabel(
      document,
      'Author(s):',
    );

    // --------------------------------------------------
    // TAGS
    // --------------------------------------------------

    final tags = _extractLinksByLabel(
      document,
      'Tags(s):',
    );

    // --------------------------------------------------
    // BASIC INFORMATION
    // --------------------------------------------------

    final type = _extractValueByLabel(
      document,
      'Type:',
    );

    final status = _extractValueByLabel(
      document,
      'Status:',
    );

    final released = _extractValueByLabel(
      document,
      'Released:',
    );

    final officialTranslation =
        _extractBoolByLabel(
      document,
      'Official Translation:',
    );

    final animeAdaptation =
        _extractBoolByLabel(
      document,
      'Anime Adaptation:',
    );

    final adultContent =
        _extractBoolByLabel(
      document,
      'Adult Content:',
    );

    final description =
        _extractDescription(document);

    return MangaItem(
      id: id,
      title: title.isEmpty
          ? 'Unknown manga'
          : title,
      cover: cover,
      url:
          'https://weebcentral.com/series/$id',
      description: description,
      authors: authors,
      tags: tags,
      type: type,
      status: status,
      released: released,
      officialTranslation:
          officialTranslation,
      animeAdaptation:
          animeAdaptation,
      adultContent:
          adultContent,
    );
  }

  // --------------------------------------------------
  // SEARCH
  // --------------------------------------------------

  Future<List<MangaItem>> searchManga(
    String query,
  ) async {
    final text = query.trim();

    if (text.isEmpty) {
      return [];
    }

    final uri = Uri.https(
      'weebcentral.com',
      '/search/data',
      {
        'limit': '32',
        'offset': '0',
        'text': text,
        'sort': 'Best Match',
        'order': 'Ascending',
        'official': 'Any',
        'display_mode': 'Full Display',
      },
    );

    final response = await tomoHttpClient
        .get(
          uri,
          headers: tomoHeaders,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP '
        '${response.statusCode}.',
      );
    }

    final document =
        parser.parse(response.body);

    final results = <MangaItem>[];
    final seen = <String>{};

    final articles = document.querySelectorAll(
      'body > article',
    );

    for (final article in articles) {
      final link = article.querySelector(
        'a[href*="/series/"]',
      );

      if (link == null) {
        continue;
      }

      final href =
          link.attributes['href'];

      if (href == null ||
          href.trim().isEmpty) {
        continue;
      }

      final resultUrl = Uri.parse(
        'https://weebcentral.com',
      ).resolve(href).toString();

      final resultUri =
          Uri.tryParse(resultUrl);

      if (resultUri == null) {
        continue;
      }

      final seriesIndex =
          resultUri.pathSegments.indexOf(
        'series',
      );

      if (seriesIndex < 0 ||
          seriesIndex + 1 >=
              resultUri.pathSegments.length) {
        continue;
      }

      final id =
          resultUri.pathSegments[
              seriesIndex + 1];

      if (!seen.add(id)) {
        continue;
      }

      // --------------------------------------------------
      // TITLE
      // --------------------------------------------------

      final detailsSection =
          article.querySelector(
        'section:nth-child(2)',
      );

      String title = '';

      final titleElement =
          detailsSection?.querySelector(
        'a.link',
      );

      if (titleElement != null) {
        title = _clean(
          titleElement.text,
        );
      }

      if (title.isEmpty) {
        title = _clean(
          resultUri.pathSegments.last
              .replaceAll('-', ' '),
        );
      }

      if (title.isEmpty) {
        continue;
      }

      // --------------------------------------------------
      // COVER
      // --------------------------------------------------

      String cover = '';

      for (final image
          in article.querySelectorAll('img')) {
        final src =
            image.attributes['src'] ?? '';

        final dataSrc =
            image.attributes['data-src'] ?? '';

        final candidate =
            src.isNotEmpty
                ? src
                : dataSrc;

        if (candidate.contains(
          'temp.compsci88.com/cover',
        )) {
          cover = candidate;
          break;
        }
      }

      if (cover.isEmpty) {
        for (final source
            in article.querySelectorAll(
          'source',
        )) {
          final srcSet =
              source.attributes['srcset'] ?? '';

          if (!srcSet.contains(
            'temp.compsci88.com/cover',
          )) {
            continue;
          }

          cover = srcSet
              .split(',')
              .first
              .trim()
              .split(' ')
              .first;

          break;
        }
      }

      if (cover.isNotEmpty) {
        cover = _absoluteUrl(cover);
      }

      // --------------------------------------------------
      // TAGS
      // --------------------------------------------------

      final tags = <String>[];

      for (final element
          in article.querySelectorAll('*')) {
        final directText = element.nodes
            .whereType<Text>()
            .map(
              (node) => node.data ?? '',
            )
            .join(' ');

        final text =
            _clean(directText);

        final lowerText =
            text.toLowerCase();

        if (!lowerText.startsWith(
              'tag(s):',
            ) &&
            !lowerText.startsWith(
              'tags(s):',
            )) {
          continue;
        }

        for (final child
            in element.children) {
          if (child.localName != 'a') {
            continue;
          }

          final value =
              _clean(child.text);

          if (value.isNotEmpty &&
              !tags.contains(value)) {
            tags.add(value);
          }
        }

        if (tags.isNotEmpty) {
          break;
        }
      }

      // --------------------------------------------------
      // RESULT
      // --------------------------------------------------

      results.add(
        MangaItem(
          id: id,
          title: title,
          cover: cover,
          url:
              'https://weebcentral.com/series/$id',
          tags: tags,
        ),
      );
    }

    return results;
  }

  // --------------------------------------------------
  // CHAPTERS
  // --------------------------------------------------

  Future<List<ChapterItem>> fetchChapters(
    String mangaId,
  ) async {
    final chaptersUrl =
        'https://weebcentral.com/series/'
        '$mangaId/full-chapter-list';

    final response = await tomoHttpClient
        .get(
          Uri.parse(chaptersUrl),
          headers: tomoHeaders,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      final bodyPreview = response.body
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final preview =
          bodyPreview.length > 500
              ? bodyPreview.substring(0, 500)
              : bodyPreview;

      throw Exception(
        'HTTP ${response.statusCode}\n'
        'URL: $chaptersUrl\n'
        'Response size: '
        '${response.bodyBytes.length} bytes\n\n'
        'Response:\n$preview',
      );
    }

    final document =
        parser.parse(response.body);

    final found = <ChapterItem>[];
    final seen = <String>{};

    for (final element
        in document.querySelectorAll(
      'a[href*="/chapters/"]',
    )) {
      final href =
          element.attributes['href'];

      if (href == null ||
          href.trim().isEmpty) {
        continue;
      }

      final chapterUrl = Uri.parse(
        'https://weebcentral.com',
      ).resolve(href).toString();

      final uri =
          Uri.tryParse(chapterUrl);

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

      final chapterId =
          match.group(1)!;

      if (!seen.add(chapterId)) {
        continue;
      }

      final titleSpan =
          element.querySelector(
        '.grow span',
      );

      final rawText =
          (titleSpan?.text.isNotEmpty ==
                  true
              ? titleSpan!.text
              : element.text)
              .replaceAll(
                RegExp(r'\s+'),
                ' ',
              )
              .trim();

      final title =
          rawText.isNotEmpty
              ? rawText
              : 'Chapter';

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
          .compareTo(
        _chapterNumber(b.title),
      );
    });

    return found;
  }

  // --------------------------------------------------
  // CHAPTER IMAGES
  // --------------------------------------------------

  Future<List<String>> fetchChapterImages(
    String chapterId,
  ) async {
    final url =
        'https://weebcentral.com/chapters/'
        '$chapterId'
        '/images?is_prev=False'
        '&current_page=1'
        '&reading_style=long_strip';

    final response = await tomoHttpClient
        .get(
          Uri.parse(url),
          headers: tomoHeaders,
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP '
        '${response.statusCode}.',
      );
    }

    final document =
        parser.parse(response.body);

    final foundImages = <String>[];
    final seen = <String>{};

    for (final image
        in document.querySelectorAll('img')) {
      final src =
          image.attributes['src'] ??
          image.attributes['data-src'] ??
          '';

      if (src.isEmpty) {
        continue;
      }

      final imageUrl = Uri.parse(
        'https://weebcentral.com',
      ).resolve(src).toString();

      if (imageUrl.contains('/static/') ||
          imageUrl.contains('brand')) {
        continue;
      }

      if (seen.add(imageUrl)) {
        foundImages.add(imageUrl);
      }
    }

    return foundImages;
  }

  // --------------------------------------------------
  // CHAPTER NUMBER
  // --------------------------------------------------

  double _chapterNumber(
    String title,
  ) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(title);

    return match == null
        ? double.infinity
        : double.tryParse(
              match.group(1)!,
            ) ??
            double.infinity;
  }
}