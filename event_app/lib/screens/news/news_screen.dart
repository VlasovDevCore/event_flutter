// news_screen.dart
import 'package:flutter/material.dart';
import 'widget/news_card_widget.dart';
import 'models/news_item.dart';
import 'news_details_screen.dart';
import '../../services/api_client.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get(
        '/events/news',
        withAuth: true,
      );

      List<NewsItem> loadedNews = [];

      if (response is Map<String, dynamic>) {
        for (var value in response.values) {
          if (value is Map<String, dynamic>) {
            loadedNews.add(NewsItem.fromJson(value));
          }
        }
      }

      loadedNews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _news = loadedNews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить новости';
        _isLoading = false;
      });
    }
  }

  void _updateNewsItem(NewsItem updatedNews) {
    setState(() {
      final index = _news.indexWhere((news) => news.id == updatedNews.id);
      if (index != -1) {
        _news[index] = updatedNews;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(child: _buildBody()),
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color.fromARGB(157, 0, 0, 0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_news.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color.fromARGB(157, 0, 0, 0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.featured_play_list,
                size: 40,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет новостей',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Пока здесь пусто',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: Colors.white,
      backgroundColor: const Color(0xFF161616),
      child: CustomScrollView(
        slivers: [
          // Заголовок как sliver
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _buildBackButton(context),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Новости',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Кнопка обновления УДАЛЕНА
                ],
              ),
            ),
          ),
          // Список новостей
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return NewsCardWidget(
                news: _news[index],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NewsDetailsScreen(
                        news: _news[index],
                        onNewsUpdated: _updateNewsItem,
                      ),
                    ),
                  );
                },
              );
            }, childCount: _news.length),
          ),
          // Отступ снизу
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Container(
        width: 37,
        height: 37,
        decoration: BoxDecoration(
          color: const Color.fromARGB(157, 0, 0, 0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).maybePop(),
            splashColor: const Color.fromARGB(157, 0, 0, 0),
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
