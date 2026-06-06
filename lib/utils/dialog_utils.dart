import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppDialogs {
  AppDialogs._();

  static const Color bgColor = Colors.black;
  static const Color accentColor = Color(0xFFDA5597);

  static ShapeBorder get _shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _contentStyle = TextStyle(
    color: Colors.white70,
    fontSize: 16,
  );

  static const TextStyle _cancelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 16,
  );

  static const TextStyle _actionStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgColor,
        shape: _shape,
        title: Text(title, style: _titleStyle),
        content: Text(message, style: _contentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText, style: _cancelStyle),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor:
                  isDestructive ? Colors.red[400] : accentColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText, style: _actionStyle),
          ),
        ],
      ),
    );
  }

  static void showLoading() {
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      ),
      barrierDismissible: false,
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      builder: builder,
    );
  }

  static void showFormDialog({
    required Widget title,
    required Widget content,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: bgColor,
        shape: _shape,
        title: title,
        content: content,
        actions: actions,
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  static Widget styledFormAction({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : Text(text,
              style: const TextStyle(
                color: accentColor,
              )),
    );
  }

  static Widget styledCancelButton({String text = '取消'}) {
    return TextButton(
      onPressed: () => Get.back(),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}
