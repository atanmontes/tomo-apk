import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';

class MangaCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    this.onRemove,
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
                if (onRemove != null)
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
                                      onRemove!();
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
