import '../../services/api_client.dart';

String? resolveAvatarUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final v = raw.trim();
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  if (v.startsWith('/')) return '${ApiClient.baseUrl}$v';
  return '${ApiClient.baseUrl}/$v';
}
