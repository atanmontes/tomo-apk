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
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
  'Referer': 'https://weebcentral.com/',
};

class MangaService {
  Future<MangaItem> fetchManga(String url) async {
    final response = await tomoHttpClient
        .get(
          Uri.parse(url),
          headers: tomoHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP ${response.statusCode}.',
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
        cover = Uri.parse(
          'https://weebcentral.com',
        ).resolve(imageUrl).toString();
        break;
      }
    }

    final uri = Uri.parse(url);
    final parts = uri.pathSegments;

    if (parts.length < 2 || parts[0] != 'series') {
      throw Exception('Invalid series URL.');
    }

    final id = parts[1];

    return MangaItem(
      id: id,
      title: title.isEmpty ? 'Unknown manga' : title,
      cover: cover,
      url: 'https://weebcentral.com/series/$id',
    );
  }

  Future<List<MangaItem>> searchManga(String query) async {
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
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP ${response.statusCode}.',
      );
    }

    final document = parser.parse(response.body);

    final results = <MangaItem>[];
    final seen = <String>{};

    // The search/data response returns the manga articles
    // directly, without the #search-results wrapper.
    final articles = document.querySelectorAll(
      'body > article',
    );

    for (final article in articles) {
      final link = article.querySelector(
        'section:first-child a[href*="/series/"]',
      );

      if (link == null) {
        continue;
      }

      final href = link.attributes['href'];

      if (href == null || href.trim().isEmpty) {
        continue;
      }

      final resultUrl = Uri.parse(
        'https://weebcentral.com',
      ).resolve(href).toString();

      final resultUri = Uri.tryParse(resultUrl);

      if (resultUri == null) {
        continue;
      }

      final seriesIndex =
          resultUri.pathSegments.indexOf('series');

      if (seriesIndex < 0 ||
          seriesIndex + 1 >= resultUri.pathSegments.length) {
        continue;
      }

      final id =
          resultUri.pathSegments[seriesIndex + 1];

      if (!seen.add(id)) {
        continue;
      }

      // The title is in the second section of each result.
      final detailsSection = article.querySelector(
        'section:nth-child(2)',
      );

      final titleElement = detailsSection?.querySelector(
        'span.tooltip a.link',
      );

      String title = titleElement?.text
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim() ??
          '';

      // Fallback: use the series URL's final segment if
      // the title selector ever changes.
      if (title.isEmpty) {
        title = resultUri.pathSegments.last
            .replaceAll('-', ' ')
            .trim();
      }

      if (title.isEmpty) {
        continue;
      }

      final imageElement = article.querySelector(
        'section:first-child img',
      );

      final src =
          imageElement?.attributes['src'] ??
          imageElement?.attributes['data-src'] ??
          '';

      final cover = src.isEmpty
          ? ''
          : Uri.parse(
              'https://weebcentral.com',
            ).resolve(src).toString();

      results.add(
        MangaItem(
          id: id,
          title: title,
          cover: cover,
          url: 'https://weebcentral.com/series/$id',
        ),
      );
    }

    return results;
  }

  Future<List<ChapterItem>> fetchChapters(String mangaId) async {
    final chaptersUrl =
        'https://weebcentral.com/series/$mangaId/full-chapter-list';

    final response = await tomoHttpClient
        .get(
          Uri.parse(chaptersUrl),
          headers: tomoHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final bodyPreview = response.body
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final preview = bodyPreview.length > 500
          ? bodyPreview.substring(0, 500)
          : bodyPreview;

      throw Exception(
        'HTTP ${response.statusCode}\n'
        'URL: $chaptersUrl\n'
        'Response size: ${response.bodyBytes.length} bytes\n\n'
        'Response:\n$preview',
      );
    }

    final document = parser.parse(response.body);
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

      if (!seen.add(chapterId)) {
        continue;
      }

      final titleSpan = element.querySelector('.grow span');

      final rawText =
          (titleSpan?.text.isNotEmpty == true
                  ? titleSpan!.text
                  : element.text)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      // Preserve the original chapter nomenclature from WeebCentral.
      // Examples: Chapter, Plot, No., Punch, Tomo, Capítulo, Special, etc.
      final title = rawText.isNotEmpty
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
          .compareTo(_chapterNumber(b.title));
    });

    return found;
  }

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
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'WeebCentral returned HTTP ${response.statusCode}.',
      );
    }

    final document = parser.parse(response.body);
    final foundImages = <String>[];
    final seen = <String>{};

    for (final image in document.querySelectorAll('img')) {
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

  double _chapterNumber(String title) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(title);

    return match == null
        ? double.infinity
        : double.tryParse(match.group(1)!) ??
            double.infinity;
  }
}