import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../screens/chat/direct_chat_screen.dart';

class RelationshipButtons extends StatefulWidget {
  final String userId;
  final String title;
  final bool isFollowing;
  final bool canMessage;
  final bool isUserBlocked;
  final VoidCallback onFollowingChanged;

  const RelationshipButtons({
    required this.userId,
    required this.title,
    required this.isFollowing,
    required this.canMessage,
    required this.isUserBlocked,
    required this.onFollowingChanged,
  });

  @override
  State<RelationshipButtons> createState() => _RelationshipButtonsState();
}

class _RelationshipButtonsState extends State<RelationshipButtons> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(RelationshipButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
  }

  Future<void> _handleFollowToggle() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isFollowing) {
        await ApiClient.instance.post(
          '/friends/unsubscribe',
          body: {'toUserId': widget.userId},
          withAuth: true,
        );
      } else {
        await ApiClient.instance.post(
          '/friends/subscribe',
          body: {'toUserId': widget.userId},
          withAuth: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
      });
      widget.onFollowingChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: widget.isUserBlocked ? 0.5 : 1.0,
            child: FilledButton(
              onPressed: widget.isUserBlocked ? null : _handleFollowToggle,
              style: FilledButton.styleFrom(
                backgroundColor: _isFollowing
                    ? const Color.fromARGB(255, 44, 44, 44)
                    : const Color.fromARGB(255, 0, 122, 255),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                disabledBackgroundColor: _isFollowing
                    ? const Color.fromARGB(255, 44, 44, 44)
                    : const Color.fromARGB(255, 0, 122, 255),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFollowing ? Icons.person_remove : Icons.person_add,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_isFollowing ? 'Отписаться' : 'Подписаться'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Opacity(
            opacity: widget.isUserBlocked ? 0.5 : 1.0,
            child: FilledButton(
              onPressed: widget.canMessage
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            userId: widget.userId,
                            title: widget.title,
                          ),
                        ),
                      );
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 44, 44, 44),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                disabledBackgroundColor: const Color.fromARGB(255, 44, 44, 44),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 18),
                  SizedBox(width: 8),
                  Text('Сообщение'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
