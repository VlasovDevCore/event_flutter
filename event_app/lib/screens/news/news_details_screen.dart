// news_details_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'models/news_item.dart';
import '../../services/api_client.dart';

class NewsDetailsScreen extends StatefulWidget {
  final NewsItem news;
  final Function(NewsItem)? onNewsUpdated;

  const NewsDetailsScreen({super.key, required this.news, this.onNewsUpdated});

  @override
  State<NewsDetailsScreen> createState() => _NewsDetailsScreenState();
}

class _NewsDetailsScreenState extends State<NewsDetailsScreen> {
  bool _isMarked = false;
  int _viewCount = 0;

  @override
  void initState() {
    super.initState();
    _viewCount = widget.news.viewCount;
    _markAsViewed();
  }

  Future<void> _markAsViewed() async {
    if (_isMarked) return;

    try {
      final response = await ApiClient.instance.post(
        '/events/news/${widget.news.id}/view',
        withAuth: true,
      );

      _isMarked = true;

      if (response is Map && response['view_count'] != null) {
        setState(() {
          _viewCount = response['view_count'] as int;
        });
      } else {
        setState(() {
          _viewCount++;
        });
      }

      final updatedNews = widget.news.copyWith(
        viewCount: _viewCount,
        isViewed: true,
      );
      widget.onNewsUpdated?.call(updatedNews);
    } catch (e) {
      print('Ошибка при отметке просмотра: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Изображение во всю ширину (без отступов)
                        // Изображение во всю ширину с закруглением снизу
                        if (widget.news.imageUrl != null &&
                            widget.news.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            child: Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.news.imageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 200,
                                    color: Colors.grey[900],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white54,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Container(
                                      height: 300,
                                      color: Colors.grey[900],
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              color: Colors.white54,
                                              size: 48,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Не удалось загрузить изображение',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Кнопка назад поверх картинки
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                        child: const Center(
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Контент с отступами
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Заголовок
                              Text(
                                widget.news.title,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Информация в одной строке: просмотры, дата, автор
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  // Просмотры
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_viewCount',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        ' просмотров',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Дата
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(widget.news.createdAt),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Автор (если есть)
                                  if (widget.news.authorName != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.news.authorName!,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Описание
                              Text(
                                widget.news.description,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 0.55,
            colors: [
              const Color.fromARGB(197, 29, 29, 29),
              const Color(0xFF161616),
            ],
            stops: const [0.1, 4.9],
          ),
        ),
      ),
    );
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
