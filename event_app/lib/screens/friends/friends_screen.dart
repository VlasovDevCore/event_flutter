import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../profile/profile_screen.dart';
import 'add_friend_screen.dart';
import 'widgets/friends_tab.dart';
import 'widgets/requests_tab.dart';

/// Экран «Мои друзья»: входящие заявки и кнопка «Добавить в друзья».
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _friends = [];
  final Map<String, Map<String, bool>> _requestRelations = {};
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final requests = await client.getList(
        '/friends/requests',
        withAuth: true,
      );
      final friends = await client.getList('/friends', withAuth: true);
      setState(() {
        _requests = requests
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _friends = friends
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _requestRelations.clear();
      });

      for (final r in _requests) {
        final fromUserId = r['from_user_id'] as String?;
        if (fromUserId == null || fromUserId.isEmpty) continue;
        try {
          final rel = await client.get(
            '/friends/relationship/$fromUserId',
            withAuth: true,
          );
          if (!mounted) return;
          setState(() {
            _requestRelations[fromUserId] = {
              'isFollowing': rel['isFollowing'] == true,
              'isFriends': rel['isFriends'] == true,
            };
          });
        } catch (_) {}
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleSubscribeBack(String toUserId) async {
    try {
      final rel = _requestRelations[toUserId];
      final isFollowing = rel?['isFollowing'] == true;
      if (isFollowing) {
        await ApiClient.instance.post(
          '/friends/unsubscribe',
          body: {'toUserId': toUserId},
          withAuth: true,
        );
      } else {
        await ApiClient.instance.post(
          '/friends/subscribe',
          body: {'toUserId': toUserId},
          withAuth: true,
        );
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                _buildHeader(),
                _buildTabBar(),
                Expanded(child: _buildBody()),
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
            radius: 1.15,
            colors: [
              const Color.fromARGB(255, 255, 251, 8), // Яркий коралловый
              const Color(0xFF161616), // Ярко-желтый
            ],
            stops: const [0.1, 0.9],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Комьюнити',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
          _buildAddFriendButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
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

  Widget _buildAddFriendButton() {
    return Container(
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
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddFriendScreen()),
            );
            _load();
          },
          splashColor: const Color.fromARGB(157, 0, 0, 0),
          highlightColor: const Color.fromARGB(157, 0, 0, 0),
          child: const Center(
            child: Icon(Icons.person_add, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 40, // Уменьшаем высоту контейнера
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13, // Уменьшаем шрифт
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13, // Уменьшаем шрифт
        ),
        dividerColor: Colors.transparent,
        // Убираем hover эффект
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory, // Убираем splash эффект
        tabs: [
          Tab(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 16), // Уменьшаем иконку
                SizedBox(width: 6), // Уменьшаем отступ
                Text('Друзья'),
              ],
            ),
          ),
          Tab(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 16), // Уменьшаем иконку
                SizedBox(width: 6), // Уменьшаем отступ
                Text('Подписчики'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        RefreshIndicator(
          onRefresh: _load,
          color: Colors.white,
          backgroundColor: const Color(0xFF1E1E1E),
          child: FriendsTab(friends: _friends),
        ),
        RefreshIndicator(
          onRefresh: _load,
          color: Colors.white,
          backgroundColor: const Color(0xFF1E1E1E),
          child: RequestsTab(
            requests: _requests,
            requestRelations: _requestRelations,
            onToggleSubscribe: _toggleSubscribeBack,
          ),
        ),
      ],
    );
  }
}
