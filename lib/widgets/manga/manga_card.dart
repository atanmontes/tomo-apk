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
        Expanded(
          child: GestureDetector(
            onTap: onTap,
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
