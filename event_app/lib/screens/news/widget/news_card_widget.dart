// widgets/news_card_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_item.dart';

class NewsCardWidget extends StatelessWidget {
  final NewsItem news;
  final VoidCallback onTap;

  const NewsCardWidget({super.key, required this.news, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: news.isViewed
                    ? Colors.transparent
                    : const Color.fromARGB(185, 255, 255, 255),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildImage(news.imageUrl!),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news.description,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatNumber(news.viewCount),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(news.createdAt),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          if (!news.isViewed) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.orange.withOpacity(0.3),
                                    Colors.red.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    // Функция для получения рабочего URL
    String getWorkingUrl(String originalUrl) {
      if (originalUrl.contains('samplelib.com')) {
        return 'https://picsum.photos/id/20/400/200';
      }
      return originalUrl;
    }

    final workingUrl = getWorkingUrl(url);

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: workingUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFF1E1E1E),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          print('Ошибка загрузки изображения: $url');
          print('Ошибка: $error');
          return Container(
            color: const Color(0xFF1E1E1E),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Нет изображения',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} г. назад';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} мес. назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'только что';
    }
  }
}
