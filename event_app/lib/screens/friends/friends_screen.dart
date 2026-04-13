import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/api_client.dart';
import 'add_friend_screen.dart';
import 'widgets/friends_tab.dart';
import 'widgets/requests_tab.dart';
import '../auth/verify_email_code_screen.dart';

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

  Future<bool?> _showVerifyEmailGate(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Center(
                child: Image.asset(
                  'assets/avatar/at-dynamic-color.png',
                  width: 54,
                  height: 54,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Подтвердите email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Чтобы искать людей и добавлять в друзья, подтвердите почту кодом из письма.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFFAAABB0),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const VerifyEmailCodeScreen(),
                      ),
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop(ok == true);
                  },
                  child: const Text('Подтвердить email'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF222222)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Пока нет'),
              ),
            ],
          ),
        );
      },
    );
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
            final status = (Hive.box('authBox').get('status') as int?) ?? 1;
            if (status == 0) {
              final ok = await _showVerifyEmailGate(context);
              if (ok != true) return;
            }
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
      padding: const EdgeInsets.all(2), // Padding для обводки
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          dividerColor: Colors.transparent,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          tabs: [
            Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 16),
                    SizedBox(width: 6),
                    Text('Друзья'),
                  ],
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, size: 16),
                    SizedBox(width: 6),
                    Text('Подписчики'),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          backgroundColor: const Color(0xFF161616),
          child: FriendsTab(friends: _friends),
        ),
        RefreshIndicator(
          onRefresh: _load,
          color: Colors.white,
          backgroundColor: const Color(0xFF161616),
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
