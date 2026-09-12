import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';

class MangaCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;
  final VoidCallback? onLibraryToggle;
  final bool isInLibrary;
  final bool libraryBusy;
  final bool showAuthor;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    required this.onLibraryToggle,
    required this.isInLibrary,
    this.libraryBusy = false,
    this.showAuthor = true,
  });

  String get _authorText {
    if (manga.authors.isEmpty) {
      return 'Unknown author';
    }

    return manga.authors.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tomoCard,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              SizedBox(
                width: 70,
                height: 96,
                child: manga.cover.isEmpty
                    ? Container(
                        color: tomoBackground,
                        child: const Icon(
                          Icons.menu_book,
                          size: 34,
                          color: Colors.white24,
                        ),
                      )
                    : Image.network(
                        manga.cover,
                        width: 70,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth: (140 *
                                MediaQuery.devicePixelRatioOf(context) *
                                1.15)
                            .round(),
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: tomoBackground,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 30,
                              color: Colors.white24,
                            ),
                          );
                        },
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (showAuthor) ...[
                        const SizedBox(height: 6),
                        Text(
                          _authorText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: tomoPink,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: libraryBusy ? null : onLibraryToggle,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: libraryBusy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isInLibrary
                                  ? Icons.remove_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
