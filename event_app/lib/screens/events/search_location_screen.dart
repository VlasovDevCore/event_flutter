import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SearchLocationScreen extends StatefulWidget {
  const SearchLocationScreen({super.key});

  @override
  State<SearchLocationScreen> createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await http
            .get(
              Uri.parse(
                'https://nominatim.openstreetmap.org/search'
                '?q=${Uri.encodeComponent(query)}'
                '&format=json'
                '&accept-language=ru'
                '&addressdetails=1'
                '&limit=10',
              ),
              headers: {'User-Agent': 'EventApp/1.0'},
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && mounted) {
          final List data = jsonDecode(response.body);
          setState(() => _suggestions = data.cast<Map<String, dynamic>>());
        }
      } catch (e) {
        print('Ошибка поиска: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка поиска, попробуйте позже')),
          );
        }
        setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _controller.text.trim().isNotEmpty;
    final bool hasResults = _suggestions.isNotEmpty;
    final bool showEmptyState = hasQuery && !_isLoading && !hasResults;
    final bool showStartState = !hasQuery && !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель с кнопкой назад и заголовком
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  Tooltip(
                    message: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
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
                          onTap: () => Navigator.of(context).pop(),
                          splashColor: const Color.fromARGB(157, 0, 0, 0),
                          highlightColor: const Color.fromARGB(157, 0, 0, 0),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Поиск места',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Поле поиска
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(157, 0, 0, 0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Поиск улицы, города...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _suggestions = []);
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            // Состояния
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Поиск...',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : showStartState
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/friends/zoom-dynamic-color.png',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Начните вводить название',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : showEmptyState
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/events/map-pin-dynamic-color.png',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ничего не найдено',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Попробуйте изменить запрос',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final name = item['display_name'] ?? 'Без названия';

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context, {
                              'lat': double.parse(item['lat']),
                              'lon': double.parse(item['lon']),
                              'name': name,
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getShortName(name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getCityFromAddress(name),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Нижний текст атрибуции
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.grey.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortName(String fullName) {
    final parts = fullName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return fullName;
  }

  String _getCityFromAddress(String fullName) {
    final parts = fullName.split(',');
    if (parts.length >= 3) {
      return parts[2].trim();
    }
    return '';
  }
}
