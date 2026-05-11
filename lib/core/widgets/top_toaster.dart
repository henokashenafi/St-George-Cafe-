import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class TopToaster {
  static void show(
    BuildContext context, 
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    toastification.show(
      context: context,
      title: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      autoCloseDuration: duration,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: isError ? Colors.redAccent : const Color(0xFFD4AF37),
      ),
      primaryColor: isError ? Colors.redAccent : const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: isError ? Colors.redAccent.withOpacity(0.5) : const Color(0xFFD4AF37).withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 5),
        )
      ],
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
    );
  }
}
