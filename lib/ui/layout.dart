part of '../main.dart';

/// All dimensions are logical pixels. Pages and overlays use the same breakpoints.
class WalletLayout {
  const WalletLayout(this.width);

  factory WalletLayout.of(BuildContext context) =>
      WalletLayout(MediaQuery.sizeOf(context).width);

  final double width;
  bool get mobile => width < 760;
  bool get wide => width >= 1100;
  bool get splitWelcome => width >= 1000;
  double get gutter => mobile ? 16 : (wide ? 32 : 24);
  double get navigationWidth => mobile ? 0 : (wide ? 216 : 72);
  double get controlHeight => mobile ? 48 : 44;
}

class WalletCard extends StatelessWidget {
  const WalletCard({
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });
  final WalletTheme theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.border),
    ),
    child: child,
  );
}

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({required this.theme, required this.onTap, super.key});
  final WalletTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '切换主题',
    onPressed: onTap,
    icon: Icon(
      theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      color: theme.muted,
    ),
  );
}

Future<T?> showWalletPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 480,
  bool dismissible = true,
  bool mobileFullscreen = false,
}) async {
  // Release any old text-input connection before attaching a new modal route.
  FocusManager.instance.primaryFocus?.unfocus();
  final mobile = WalletLayout.of(context).mobile;
  TransitionRoute<T>? panelRoute;
  Widget surface(BuildContext context) {
    panelRoute ??= ModalRoute.of<T>(context);
    final media = MediaQuery.of(context);
    final fullscreen = mobileFullscreen && WalletLayout.of(context).mobile;
    if (fullscreen) {
      return PopScope(
        canPop: dismissible,
        child: Dialog.fullscreen(
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(child: SizedBox.expand(child: builder(context))),
          ),
        ),
      );
    }
    final available =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight:
            available.clamp(0, double.infinity) *
            (WalletLayout.of(context).mobile ? .92 : .85),
      ),
      child: builder(context),
    );
    if (!WalletLayout.of(context).mobile) {
      return PopScope(
        canPop: dismissible,
        child: Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(width: width, child: content),
        ),
      );
    }
    return PopScope(
      canPop: dismissible,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(width: double.infinity, child: content),
          ),
        ),
      ),
    );
  }

  final T? result;
  if (mobile && !mobileFullscreen) {
    result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: surface,
    );
  } else {
    result = await showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: surface,
    );
  }
  // Navigator.pop's result resolves before the exit animation. Wait until the
  // old route and its text-input/selection overlays have actually been removed
  // before callers replace the underlying page or open another panel.
  await panelRoute?.completed;
  return result;
}

void closeWalletPanel<T>(BuildContext context, [T? result]) {
  FocusScope.of(context).unfocus();
  Navigator.pop<T>(context, result);
}

/// Shared overlay structure: fixed title and actions, independently scrolling body.
class WalletPanel extends StatelessWidget {
  const WalletPanel({
    required this.theme,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.canClose = true,
    this.scrollBody = true,
    this.expandBody = false,
    super.key,
  });
  final WalletTheme theme;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool canClose;
  final bool scrollBody;
  final bool expandBody;

  @override
  Widget build(BuildContext context) => Material(
    color: theme.surface,
    child: Column(
      mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canClose)
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => closeWalletPanel(context),
                  icon: Icon(Icons.close, color: theme.muted),
                ),
            ],
          ),
        ),
        Flexible(
          fit: expandBody ? FlexFit.tight : FlexFit.loose,
          child: scrollBody
              ? SingleChildScrollView(
                  key: const ValueKey('panel-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (subtitle != null) ...[
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: theme.muted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      child,
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: child,
                ),
        ),
        if (footer != null)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.border)),
            ),
            child: footer,
          ),
      ],
    ),
  );
}
