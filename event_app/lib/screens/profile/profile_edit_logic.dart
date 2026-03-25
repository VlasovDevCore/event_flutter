import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../services/api_client.dart';

class ProfileEditLogic {
  /// Автоматически обрезает изображение в квадрат по центру
  static Future<Uint8List?> autoCropAvatarSquare(Uint8List bytes) async {
    final decodedCompleter = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => decodedCompleter.complete(img));
    final img = await decodedCompleter.future;

    final minSide = (img.width < img.height ? img.width : img.height)
        .toDouble();
    final srcLeft = (img.width.toDouble() - minSide) / 2.0;
    final srcTop = (img.height.toDouble() - minSide) / 2.0;

    const outputPx = 512;
    final src = ui.Rect.fromLTWH(srcLeft, srcTop, minSide, minSide);
    final dst = ui.Rect.fromLTWH(
      0,
      0,
      outputPx.toDouble(),
      outputPx.toDouble(),
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = true;

    canvas.save();
    // Просто квадратный crop по центру. Закругления будут только на UI.
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outputPx, outputPx);
    final data = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// Валидирует данные профиля
  /// Возвращает (isValid, errorMessage)
  static (bool, String?) validateProfile({
    required String username,
    required String displayName,
    required String bio,
  }) {
    if (username.isEmpty) {
      return (false, 'Никнейм не может быть пустым');
    }
    // Разрешаем: латиница, цифры, '.' и '_'.
    // Русские буквы и прочие символы запрещены.
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return (false, 'Только латиница, цифры и символы . или _');
    }
    if (username.length < 3 || username.length > 20) {
      return (false, 'Никнейм: 3–20 символов');
    }
    if (displayName.isNotEmpty && displayName.length > 40) {
      return (false, 'Имя: не больше 40 символов');
    }
    if (bio.length > 280) {
      return (false, 'О себе: не больше 280 символов');
    }
    return (true, null);
  }

  /// Проверяет, доступен ли логин на сервере
  /// Возвращает true если логин свободен, false если занят
  static Future<bool> checkUsernameAvailable(String username) async {
    if (username.isEmpty) return false;

    try {
      await ApiClient.instance.get(
        '/users/check-username?username=$username',
        withAuth: false,
      );
      // 200 OK означает логин свободен
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // 409 Conflict означает логин уже занят
        return false;
      }
      // Другие ошибки - считаем недоступным
      return false;
    } catch (_) {
      return false;
    }
  }
}
