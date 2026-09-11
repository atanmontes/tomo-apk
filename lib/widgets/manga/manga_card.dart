import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';

class MangaCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.73,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
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
                      cacheWidth: (220 *
                              MediaQuery.devicePixelRatioOf(context) *
                              1.15)
                          .round(),
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
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
        ),
        const SizedBox(height: 8),
        // The title lives in a fixed two-line area so it can never
        // change the position or size of the cover above it.
        SizedBox(
          height: 40,
          child: Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
