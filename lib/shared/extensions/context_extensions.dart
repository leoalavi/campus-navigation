import 'package:flutter/material.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';

/// Convenience extensions on [BuildContext] to reduce boilerplate.
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  void showSnackBar(String message, {bool isError = false}) {
    // Every transient notification goes through this helper, so styling it
    // here keeps ALL snackbars consistent and manually dismissible app-wide
    // (the auto-dismiss timeout still applies).
    //
    // The default snackbar surface is light in dark mode, which made the white
    // close icon invisible. Pin a dark surface (or red for errors) with white
    // text and a white × so the close affordance is always high-contrast in
    // both light and dark modes.
    final background = isError ? colorScheme.error : MqColors.charcoal800;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }
}
