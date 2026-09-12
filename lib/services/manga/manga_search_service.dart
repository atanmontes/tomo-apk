import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

import '../../models/manga/manga.dart';

class MangaSearchFilters {
  final String sort;
  final String order;
  final String official;
  final String animeAdaptation;
  final String adultContent;
  final String status;
  final String type;
  final List<String> tags;

  const MangaSearchFilters({
    this.sort = 'Best Match',
    this.order = 'Ascending',
    this.official = 'Any',
    this.animeAdaptation = 'Any',
    this.adultContent = 'Any',
    this.status = 'Any',
    this.type = 'Any',
    this.tags = const [],
  });

  bool get hasFilters {
    return sort != 'Best Match' ||
        order != 'Ascending' ||
        official != 'Any' ||
        animeAdaptation != 'Any' ||
        adultContent != 'Any' ||
        status != 'Any' ||
        type != 'Any' ||
        tags.isNotEmpty;
  }
}

class MangaSearchService {
  static const _baseUrl = 'https://weebcentral.com';

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0.0.0 Safari/537.36';

  final http.Client _client = http.Client();

  Map<String, String> get _headers => const {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,'
            'image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://weebcentral.com/',
      };

  String _clean(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _absoluteUrl(String value) {
    if (value.isEmpty) return '';

    return Uri.parse(_baseUrl).resolve(value).toString();
  }

  String _valueByLabel(
    Element article,
    String wanted,
  ) {
    final target = wanted
        .toLowerCase()
        .replaceAll(':', '')
        .trim();

    for (final element in article.querySelectorAll('li')) {
      final strong = element.querySelector('strong');

      if (strong == null) continue;

      final label = _clean(strong.text)
          .toLowerCase()
          .replaceAll(':', '')
          .trim();

      if (label != target) continue;

      final text = _clean(
        element.text
            .replaceFirst(strong.text, ''),
      );

      return text.replaceFirst(
        RegExp(r'^:\s*'),
        '',
      );
    }

    return '';
  }

  bool _boolByLabel(
    Element article,
    String label,
  ) {
    final value = _valueByLabel(
      article,
      label,
    ).toLowerCase();

    return value == 'yes' ||
        value == 'true' ||
        value == 'si';
  }

  List<String> _linksByLabel(
    Element article,
    String wanted,
  ) {
    final target = wanted
        .toLowerCase()
        .replaceAll(':', '')
        .trim();

    for (final element in article.querySelectorAll('li')) {
      final strong = element.querySelector('strong');

      if (strong == null) continue;

      final label = _clean(strong.text)
          .toLowerCase()
          .replaceAll(':', '')
          .trim();

      if (label != target) continue;

      return element
          .querySelectorAll('a')
          .map((link) => _clean(link.text))
          .where((text) => text.isNotEmpty)
          .toList();
    }

    return [];
  }

  bool _matchesBool(
    String selected,
    bool actual,
  ) {
    if (selected == 'Any') return true;

    return selected == 'True' ? actual : !actual;
  }

  bool _matchesValue(
    String selected,
    String actual,
  ) {
    if (selected == 'Any') return true;

    return actual.toLowerCase() ==
        selected.toLowerCase();
  }

  bool _matchesTags(
    List<String> selected,
    List<String> actual,
  ) {
    if (selected.isEmpty) return true;

    final normalized = actual
        .map((tag) => tag.toLowerCase())
        .toSet();

    return selected.every(
      (tag) => normalized.contains(
        tag.toLowerCase(),
      ),
    );
  }

  Future<List<MangaItem>> searchManga(
    String query, {
    MangaSearchFilters filters =
        const MangaSearchFilters(),
  }) async {
    final uri = Uri.https(
      'weebcentral.com',
      '/search/data',
      {
        'limit': '32',
        'offset': '0',
        'text': query.trim(),
        'sort': filters.sort,
        'order': filters.order,
        'official': filters.official,
        'display_mode': 'Full Display',
      },
    );

    final response = await _client
        .get(
          uri,
          headers: _headers,
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

    final document = parser.parse(
      response.body,
    );

    final results = <MangaItem>[];
    final seen = <String>{};

    for (final article
        in document.querySelectorAll(
      'body > article',
    )) {
      final link = article.querySelector(
        'a[href*="/series/"]',
      );

      if (link == null) continue;

      final href = link.attributes['href'];

      if (href == null || href.trim().isEmpty) {
        continue;
      }

      final resultUrl = Uri.parse(
        _baseUrl,
      ).resolve(href).toString();

      final resultUri = Uri.tryParse(resultUrl);

      if (resultUri == null) continue;

      final seriesIndex =
          resultUri.pathSegments.indexOf('series');

      if (seriesIndex < 0 ||
          seriesIndex + 1 >=
              resultUri.pathSegments.length) {
        continue;
      }

      final id = resultUri.pathSegments[
          seriesIndex + 1];

      if (!seen.add(id)) continue;

      final detailsSection =
          article.querySelector(
        'section:nth-child(2)',
      );

      var title = _clean(
        detailsSection
                ?.querySelector('a.link')
                ?.text ??
            '',
      );

      if (title.isEmpty) {
        title = _clean(
          resultUri.pathSegments.last
              .replaceAll('-', ' '),
        );
      }

      if (title.isEmpty) continue;

      String cover = '';

      for (final image
          in article.querySelectorAll('img')) {
        final src =
            image.attributes['src'] ?? '';
        final dataSrc =
            image.attributes['data-src'] ?? '';

        final candidate = src.isNotEmpty
            ? src
            : dataSrc;

        if (candidate.contains(
          'temp.compsci88.com/cover',
        )) {
          cover = _absoluteUrl(candidate);
          break;
        }
      }

      if (cover.isEmpty) {
        for (final source
            in article.querySelectorAll('source')) {
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

          cover = _absoluteUrl(first);
          break;
        }
      }

      final authors = _linksByLabel(
        article,
        'Author(s)',
      );

      final tags = _linksByLabel(
        article,
        'Tag(s)',
      );

      final status = _valueByLabel(
        article,
        'Status',
      );

      final type = _valueByLabel(
        article,
        'Type',
      );

      final official = _boolByLabel(
        article,
        'Official Translation',
      );

      final anime = _boolByLabel(
        article,
        'Anime Adaptation',
      );

      final adult = _boolByLabel(
        article,
        'Adult Content',
      );

      if (!_matchesBool(
        filters.official,
        official,
      )) {
        continue;
      }

      if (!_matchesBool(
        filters.animeAdaptation,
        anime,
      )) {
        continue;
      }

      if (!_matchesBool(
        filters.adultContent,
        adult,
      )) {
        continue;
      }

      if (!_matchesValue(
        filters.status,
        status,
      )) {
        continue;
      }

      if (!_matchesValue(
        filters.type,
        type,
      )) {
        continue;
      }

      if (!_matchesTags(
        filters.tags,
        tags,
      )) {
        continue;
      }

      results.add(
        MangaItem(
          id: id,
          title: title,
          cover: cover,
          url: '$_baseUrl/series/$id',
          authors: authors,
          tags: tags,
          type: type,
          status: status,
          officialTranslation: official,
          animeAdaptation: anime,
          adultContent: adult,
        ),
      );
    }

    return results;
  }
}
