import 'app_symbols.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../domain/models.dart';
import '../l10n/localizations.dart';
import '../services/app_controller.dart';
import '../services/window_close_handler.dart';
import 'app_theme.dart';
import 'action_controls.dart';
import 'collapsible_panel.dart';
import 'reference_controls.dart';
import 'pdf_pane.dart';
import 'progress_indicators.dart';
import 'question_card.dart';
import 'settings_panel.dart';
import 'motion.dart';
import 'reference_toast.dart';

class Workspace extends StatefulWidget {
  final AppController controller;
  final bool nativeWindow;
  const Workspace({
    super.key,
    required this.controller,
    this.nativeWindow = true,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  AppController get c => widget.controller;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _paletteTimer, _copyTimer;
  final _toastKey = GlobalKey<ReferenceToastState>();
  final _viewSwitchKey = GlobalKey(debugLabel: 'preview-mode');
  bool _dragOver = false, _colorsOpen = false, _fullCopied = false;
  late final WindowCloseHandler _windowClose;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _windowClose = WindowCloseHandler(
      controller: c,
      confirmClose: _confirmClose,
    );
    if (widget.nativeWindow) windowManager.addListener(_windowClose);
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    if (widget.nativeWindow) windowManager.removeListener(_windowClose);
    _paletteTimer?.cancel();
    _copyTimer?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_search.text != c.query) _search.text = c.query;
    setState(() {});
    if (c.notification.isNotEmpty) {
      final message = c.notification, error = c.notificationError;
      c.notification = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toastKey.currentState?.show(message, error: error);
      });
    }
  }

  Future<bool> _confirmClose() async {
    if (!mounted) return false;
    final s = context.strings;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.exportRunning),
            content: Text(s.exportRunningDetail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.keepExporting),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.stopAndClose),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _addFiles() async {
    if (c.busy) return;
    try {
      final files = await openFiles(
        acceptedTypeGroups: [
          XTypeGroup(
            label: c.strings.htmlPagesType,
            extensions: ['html', 'htm'],
          ),
        ],
      );
      if (mounted && files.isNotEmpty) {
        await c.addPaths(files.map((f) => f.path).toList());
      }
    } on Object catch (e) {
      c.tell(c.strings.cannotChoosePages(e), error: true);
    }
  }

  Future<void> _addFolder() async {
    if (c.busy) return;
    try {
      final folder = await getDirectoryPath();
      if (mounted && folder != null) await c.addPaths([folder]);
    } on Object catch (e) {
      c.tell(c.strings.cannotChooseFolder(e), error: true);
    }
  }

  Future<void> _copyAll() async {
    final doc = c.document;
    if (doc == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: doc.plainText()));
    } on Object {
      c.tell(c.strings.clipboardFailed, error: true);
      return;
    }
    if (!mounted) return;
    _copyTimer?.cancel();
    setState(() => _fullCopied = true);
    c.tell(c.strings.copiedAllQuestions(doc.questions.length));
    _copyTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _fullCopied = false);
    });
  }

  Future<void> _copyPaths() async {
    final paths = c.chosenResults.toList();
    try {
      await Clipboard.setData(ClipboardData(text: paths.join('\n')));
      c.tell(c.strings.copiedPaths(paths.length));
    } on Object {
      c.tell(c.strings.clipboardFailed, error: true);
    }
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme, s = context.strings;
      return AlertDialog(
        title: Text(s.helpTitle),
        scrollable: true,
        content: SizedBox(
          width: 512,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _helpStep('01', s.helpSaveTitle, s.helpSaveDetail),
              const SizedBox(height: 16),
              _helpStep('02', s.helpCheckTitle, s.helpCheckDetail),
              const SizedBox(height: 16),
              _helpStep('03', s.helpExportTitle, s.helpExportDetail),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppSymbols.warningAmber,
                      size: 20,
                      color: cs.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.helpPrivacy,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.helpShortcuts,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ReferenceButton(
            variant: ReferenceButtonVariant.text,
            onPressed: () => Navigator.pop(context),
            child: Text(s.getStarted),
          ),
        ],
      );
    },
  );

  Widget _helpStep(String number, String title, String detail) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 22,
              height: 28 / 22,
              fontWeight: FontWeight.w700,
              fontVariations: emphasized(22),
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: .25,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _log() => showDialog<void>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme, s = context.strings;
      return AlertDialog(
        title: Text(s.exportLog),
        scrollable: true,
        content: SizedBox(
          width: 512,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.logMayContainPaths,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    c.logs.isEmpty ? s.noExportsYet : c.logs.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: ['Noto Sans SC'],
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ReferenceButton(
            variant: ReferenceButtonVariant.text,
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      );
    },
  );

  /// A parsed page is on screen (not being read again).
  bool get _showData => c.document != null && c.current?.parsing != true;

  void _toggleQueue() {
    c.settings.queueCollapsed = !c.settings.queueCollapsed;
    c.layoutChanged();
  }

  void _toggleSettings() {
    c.settings.settingsCollapsed = !c.settings.settingsCollapsed;
    c.layoutChanged();
  }

  void _delete() {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return;
    }
    c.removeCurrent();
  }

  Widget _panel(
    Widget child, {
    Color? color,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Material(
    color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _addFiles,
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          shift: true,
        ): _addFolder,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            c.export(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          c.setView(false);
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.f1): _help,
        const SingleActivator(LogicalKeyboardKey.delete): _delete,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DropTarget(
                enable: !c.busy,
                onDragEntered: (_) => setState(() => _dragOver = true),
                onDragExited: (_) => setState(() => _dragOver = false),
                onDragDone: (detail) {
                  setState(() => _dragOver = false);
                  c.addPaths(detail.files.map((f) => f.path).toList());
                },
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CollapsibleColumn(
                              collapsed: c.settings.queueCollapsed,
                              width: 300,
                              reducedMotion: c.settings.reducedMotion,
                              child: AnimatedContainer(
                                duration: Duration(
                                  milliseconds: c.settings.reducedMotion
                                      ? 0
                                      : 130,
                                ),
                                foregroundDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _dragOver
                                        ? cs.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: _panel(
                                  CollapsibleContent(
                                    collapsed: c.settings.queueCollapsed,
                                    minWidth: 268,
                                    reducedMotion: c.settings.reducedMotion,
                                    rail: _queueRail(),
                                    child: _queue(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _preview()),
                            const SizedBox(width: 24),
                            CollapsibleColumn(
                              collapsed: c.settings.settingsCollapsed,
                              width: 340,
                              reducedMotion: c.settings.reducedMotion,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: AnimatedOpacity(
                                      opacity: c.busy ? .5 : 1,
                                      duration: Duration(
                                        milliseconds: c.settings.reducedMotion
                                            ? 0
                                            : 200,
                                      ),
                                      child: IgnorePointer(
                                        ignoring: c.busy,
                                        child: _panel(
                                          CollapsibleContent(
                                            collapsed:
                                                c.settings.settingsCollapsed,
                                            minWidth: 308,
                                            reducedMotion:
                                                c.settings.reducedMotion,
                                            rail: _settingsRail(),
                                            child: SettingsPanel(
                                              controller: c,
                                              onCollapse: _toggleSettings,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_showData &&
                                      !c.settings.settingsCollapsed) ...[
                                    const SizedBox(height: 12),
                                    ReferenceReveal(
                                      reducedMotion: c.settings.reducedMotion,
                                      child: _copyPanel(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    MotionSize(
                      duration: Duration(
                        milliseconds: c.settings.reducedMotion ? 0 : 500,
                      ),
                      curve: Curves.easeOutCubic,
                      child: c.resultsOpen
                          ? _results()
                          : const SizedBox.shrink(),
                    ),
                    _footer(),
                  ],
                ),
              ),
              ReferenceToast(key: _toastKey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyPanel() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    // Keeps its layout while the settings column grows back from the rail.
    return _panel(
      MinWidthBox(
        minWidth: 308,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    s.copy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    s.copyPanelSummary(c.document!.questions.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      letterSpacing: .4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ReferenceButton(
              key: const ValueKey('copy-all'),
              fullWidth: true,
              variant: _fullCopied
                  ? ReferenceButtonVariant.filled
                  : ReferenceButtonVariant.tonal,
              onPressed: _copyAll,
              icon: _fullCopied ? AppSymbols.check : AppSymbols.contentCopy,
              child: Text(_fullCopied ? s.copiedAll : s.copyAll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
        child: Row(
          children: [
            Text(
              'Canvas Quiz Exporter',
              style: TextStyle(
                fontSize: 22,
                height: 28 / 22,
                fontWeight: FontWeight.w700,
                fontVariations: emphasized(22),
              ),
            ),
            const Spacer(),
            Text(
              'v$appVersion',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: .5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            _palette(),
            const SizedBox(width: 12),
            ReferenceIconButton(
              tooltip: c.settings.dark ? s.switchToLight : s.switchToDark,
              onPressed: () {
                c.settings.dark = !c.settings.dark;
                c.settingsChanged();
              },
              icon: c.settings.dark
                  ? AppSymbols.lightMode
                  : AppSymbols.darkMode,
            ),
            const SizedBox(width: 12),
            _languageMenu(),
            const SizedBox(width: 12),
            ReferenceIconButton(
              tooltip: s.helpTooltip,
              onPressed: _help,
              icon: AppSymbols.helpOutline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageMenu() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainer),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      menuChildren: [
        // Each language is listed in its own language.
        for (final (value, label) in [
          ('system', s.systemLanguage),
          ('zh', '中文'),
          ('en', 'English'),
        ])
          MenuItemButton(
            key: ValueKey('language-$value'),
            style: const ButtonStyle(
              mouseCursor: WidgetStateMouseCursor.clickable,
            ),
            leadingIcon: SizedBox.square(
              dimension: 24,
              child: c.settings.language == value
                  ? const Icon(AppSymbols.check, size: 20)
                  : null,
            ),
            onPressed: () => c.setLanguage(value),
            child: Text(label),
          ),
      ],
      builder: (context, menu, _) => ReferenceIconButton(
        key: const ValueKey('language-menu'),
        tooltip: s.language,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: AppSymbols.translate,
      ),
    );
  }

  void _schedulePaletteClose(int milliseconds) {
    _paletteTimer?.cancel();
    _paletteTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (mounted) setState(() => _colorsOpen = false);
    });
  }

  Widget _palette() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return MouseRegion(
      onEnter: (_) => _paletteTimer?.cancel(),
      onExit: (_) => _schedulePaletteClose(900),
      child: AnimatedContainer(
        duration: Duration(milliseconds: c.settings.reducedMotion ? 0 : 200),
        decoration: BoxDecoration(
          color: _colorsOpen ? cs.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: MotionSize(
          duration: Duration(milliseconds: c.settings.reducedMotion ? 0 : 500),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: s.colorScheme,
                child: IconButton(
                  onPressed: () {
                    _paletteTimer?.cancel();
                    setState(() => _colorsOpen = !_colorsOpen);
                  },
                  icon: AnimatedScale(
                    scale: _colorsOpen ? .85 : 1,
                    duration: Duration(
                      milliseconds: c.settings.reducedMotion ? 0 : 350,
                    ),
                    curve: referenceSpatialCurve,
                    child: _colorDot(cs, false, trigger: true),
                  ),
                ),
              ),
              if (_colorsOpen) ...[
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.only(left: 2, right: 6),
                  color: cs.outlineVariant,
                ),
                for (final (i, name) in colorSchemes.indexed)
                  ReferenceReveal(
                    delay: Duration(milliseconds: i * 30),
                    horizontal: true,
                    reducedMotion: c.settings.reducedMotion,
                    child: Tooltip(
                      message: s.schemeName(name),
                      child: Semantics(
                        selected: c.settings.scheme == name,
                        child: IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 38,
                            height: 36,
                          ),
                          style: const ButtonStyle(
                            fixedSize: WidgetStatePropertyAll(Size(38, 36)),
                            minimumSize: WidgetStatePropertyAll(Size(38, 36)),
                          ),
                          onPressed: () {
                            c.settings.scheme = name;
                            c.settingsChanged();
                            _schedulePaletteClose(650);
                          },
                          icon: _colorDot(
                            referenceColors(c.settings.dark, name),
                            c.settings.scheme == name,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(
    ColorScheme colors,
    bool selected, {
    bool trigger = false,
  }) => AnimatedContainer(
    duration: Duration(milliseconds: c.settings.reducedMotion ? 0 : 350),
    curve: Curves.easeOutCubic,
    width: selected
        ? 28
        : trigger
        ? 24
        : 22,
    height: selected
        ? 28
        : trigger
        ? 24
        : 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? colors.primary : colors.outline.withValues(alpha: .4),
        width: selected ? 2 : 1,
      ),
      boxShadow: selected
          ? [
              BoxShadow(color: colors.surfaceContainerHigh, spreadRadius: 2),
              BoxShadow(color: colors.primary, spreadRadius: 4),
            ]
          : null,
    ),
    // Keep the hard diagonal split out of DecorationTween: gradient lerp
    // merges duplicate stops, even during unrelated settings rebuilds.
    child: ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary,
              colors.primary,
              colors.surfaceContainerHighest,
              colors.surfaceContainerHighest,
            ],
            stops: const [0, .5, .5, 1],
          ),
        ),
        child: selected
            ? Icon(AppSymbols.check, size: 14, color: colors.onPrimary)
            : const SizedBox.expand(),
      ),
    ),
  );

  Widget _queue() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
          child: Row(
            children: [
              Text(
                s.pagesPanel,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .15,
                ),
              ),
              const SizedBox(width: 8),
              ReferenceCountBadge(
                label: '${c.entries.length}',
                active: c.entries.isNotEmpty,
                reducedMotion: c.settings.reducedMotion,
              ),
              const Spacer(),
              PaneToggleButton(
                collapsed: false,
                tooltip: s.minimizePages,
                onPressed: _toggleQueue,
                reducedMotion: c.settings.reducedMotion,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReferenceButton(
                key: const ValueKey('add-files'),
                fullWidth: true,
                variant: ReferenceButtonVariant.tonal,
                onPressed: c.busy ? null : _addFiles,
                icon: AppSymbols.add,
                child: Text(s.addPages),
              ),
            ),
            const SizedBox(width: 8),
            ReferenceIconButton(
              tonal: true,
              tooltip: s.addFolder,
              onPressed: c.busy ? null : _addFolder,
              icon: AppSymbols.folderOpen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: CustomScrollView(
              slivers: [
                SliverList.builder(
                  itemCount: c.entries.length,
                  itemBuilder: (context, index) => ReferenceReveal(
                    key: ValueKey(c.entries[index].path),
                    reducedMotion: c.settings.reducedMotion,
                    child: _queueItem(c.entries[index]),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppSymbols.placeItem,
                            size: 28,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            c.entries.isEmpty
                                ? s.dropHintEmpty
                                : s.dropHintMore,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              letterSpacing: .4,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            c.entries.isEmpty ? s.queueHintEmpty : s.queueHint,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: .4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ReferenceButton(
              variant: ReferenceButtonVariant.text,
              onPressed: c.busy || c.current == null ? null : c.removeCurrent,
              icon: AppSymbols.deleteOutline,
              child: Text(s.removeSelected),
            ),
            ReferenceButton(
              variant: ReferenceButtonVariant.text,
              onPressed: c.busy || c.entries.isEmpty ? null : c.clear,
              child: Text(s.clearAll),
            ),
          ],
        ),
      ],
    );
  }

  Widget _queueItem(QueueEntry entry) {
    final cs = Theme.of(context).colorScheme, selected = entry == c.current;
    final failed = entry.error != null, s = context.strings;
    return Material(
      color: selected
          ? (failed ? cs.errorContainer : cs.secondaryContainer)
          : Colors.transparent,
      child: InkWell(
        onTap: () => c.select(entry),
        mouseCursor: WidgetStateMouseCursor.clickable,
        overlayColor: referenceStateLayer(failed ? cs.error : cs.onSurface),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                entry.parsing
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        failed
                            ? AppSymbols.errorOutline
                            : AppSymbols.description,
                        size: 24,
                        color: failed ? cs.error : cs.onSurfaceVariant,
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: .5,
                          color: failed ? cs.error : cs.onSurface,
                        ),
                      ),
                      Text(
                        entry.parsing
                            ? s.entryReading
                            : failed
                            ? s.entryUnreadable
                            : entry.document == null
                            ? s.entryWaiting
                            : '${s.questions(entry.document!.questions.length)}${entry.document!.course.isEmpty ? '' : ' · ${entry.document!.course}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: .25,
                          color: failed ? cs.error : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _queueRail() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return Column(
      children: [
        PaneToggleButton(
          collapsed: true,
          tooltip: s.expandPages,
          onPressed: _toggleQueue,
          reducedMotion: c.settings.reducedMotion,
        ),
        const SizedBox(height: 12),
        ReferenceCountBadge(
          label: '${c.entries.length}',
          active: c.entries.isNotEmpty,
          rail: true,
          reducedMotion: c.settings.reducedMotion,
        ),
        const SizedBox(height: 12),
        ReferenceIconButton(
          tonal: true,
          tooltip: s.addPages,
          onPressed: c.busy ? null : _addFiles,
          icon: AppSymbols.add,
        ),
        const SizedBox(height: 12),
        ReferenceIconButton(
          tonal: true,
          tooltip: s.addFolder,
          onPressed: c.busy ? null : _addFolder,
          icon: AppSymbols.folderOpen,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: c.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final entry = c.entries[index], selected = entry == c.current;
              final failed = entry.error != null;
              return Center(
                child: entry.parsing
                    ? Tooltip(
                        message: entry.name,
                        child: const SizedBox.square(
                          dimension: 40,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ReferenceRailButton(
                        key: ValueKey('rail:${entry.path}'),
                        icon: failed
                            ? AppSymbols.errorOutline
                            : AppSymbols.description,
                        tooltip: entry.name,
                        active: selected,
                        background: selected
                            ? (failed
                                  ? cs.errorContainer
                                  : cs.secondaryContainer)
                            : Colors.transparent,
                        foreground: failed
                            ? cs.error
                            : selected
                            ? cs.onSecondaryContainer
                            : cs.onSurfaceVariant,
                        onPressed: () => c.select(entry),
                        reducedMotion: c.settings.reducedMotion,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _settingsRail() {
    final cs = Theme.of(context).colorScheme, cfg = c.settings;
    final s = context.strings;
    Widget toggle(
      String label,
      IconData icon,
      bool on,
      VoidCallback flip, {
      Key? key,
    }) => ReferenceRailButton(
      key: key,
      icon: icon,
      tooltip: label,
      active: on,
      toggle: true,
      background: on ? cs.secondary : cs.secondaryContainer,
      foreground: on ? cs.onSecondary : cs.onSecondaryContainer,
      onPressed: () {
        flip();
        c.settingsChanged();
      },
      reducedMotion: cfg.reducedMotion,
    );
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              PaneToggleButton(
                collapsed: true,
                end: true,
                tooltip: s.expandSettings,
                onPressed: _toggleSettings,
                reducedMotion: cfg.reducedMotion,
              ),
              const SizedBox(height: 12),
              ReferenceCountBadge(
                label: '${cfg.formats.length}',
                rail: true,
                reducedMotion: cfg.reducedMotion,
              ),
              for (final format in exportFormats) ...[
                const SizedBox(height: 12),
                toggle(
                  key: ValueKey('rail-format-$format'),
                  s.formatName(format),
                  formatIcons[format]!,
                  cfg.formats.contains(format),
                  () => cfg.formats.contains(format)
                      ? cfg.formats.remove(format)
                      : cfg.formats.add(format),
                ),
              ],
              const SizedBox(height: 12),
              toggle(
                s.saveImages,
                AppSymbols.image,
                cfg.copyAssets,
                () => cfg.copyAssets = !cfg.copyAssets,
              ),
              const Spacer(),
              if (_showData) ...[
                const SizedBox(height: 12),
                ReferenceIconButton(
                  key: const ValueKey('rail-copy-all'),
                  tonal: !_fullCopied,
                  filled: _fullCopied,
                  tooltip: s.copyAll,
                  onPressed: _copyAll,
                  icon: _fullCopied ? AppSymbols.check : AppSymbols.contentCopy,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    final doc = c.document, cs = Theme.of(context).colorScheme;
    final s = context.strings;
    final parsing = c.current?.parsing == true,
        failed = c.current?.error != null;
    final badgeForeground = parsing
        ? cs.onSurfaceVariant
        : failed
        ? cs.onErrorContainer
        : doc != null
        ? cs.onSecondaryContainer
        : cs.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(
                s.preview,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .15,
                ),
              ),
              const Spacer(),
              ReferenceIconButton(
                tooltip: s.reloadPage,
                onPressed: c.busy || c.current == null || parsing
                    ? null
                    : c.refresh,
                icon: AppSymbols.refresh,
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: Duration(
                  milliseconds: c.settings.reducedMotion ? 0 : 200,
                ),
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: parsing
                      ? cs.surfaceContainerHighest
                      : failed
                      ? cs.errorContainer
                      : doc != null
                      ? cs.secondaryContainer
                      : cs.surfaceContainerHighest,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      parsing
                          ? AppSymbols.hourglassTop
                          : failed
                          ? AppSymbols.error
                          : doc != null
                          ? AppSymbols.checkCircle
                          : AppSymbols.schedule,
                      size: 18,
                      fill: 1,
                      color: badgeForeground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      parsing
                          ? s.statusReading
                          : failed
                          ? s.statusNeedsCheck
                          : doc == null
                          ? s.statusWaiting
                          : doc.questions.isEmpty
                          ? s.statusNoQuestions
                          : s.statusParsed,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .1,
                        color: badgeForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (parsing)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReferenceLoadingIndicator(
                    size: 64,
                    contained: true,
                    reducedMotion: c.settings.reducedMotion,
                    semanticsLabel: s.loading,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.readingPage,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.extracting(p.basename(c.current!.path)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: .25,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (doc == null)
          Expanded(child: _empty())
        else ...[
          // Switching pages shows the new content at once: no entrance
          // motion for the header, question cards or PDF pages.
          Tooltip(
            message: doc.title,
            child: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 32,
                height: 1.25,
                fontWeight: FontWeight.w500,
                fontVariations: emphasized(32, weight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (doc.course.isNotEmpty)
                ReferenceChip(label: doc.course, icon: AppSymbols.school),
              ReferenceChip(
                label: s.questions(doc.questions.length),
                icon: AppSymbols.quiz,
              ),
              if (c.settings.filterLines.isNotEmpty)
                ReferenceChip(
                  label: s.filtered(c.removedCount),
                  selected: true,
                  onPressed: c.busy
                      ? null
                      : () {
                          c.settings.filters = '';
                          c.settingsChanged();
                        },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: TextField(
              key: const ValueKey('question-search'),
              controller: _search,
              focusNode: _searchFocus,
              onChanged: c.setQuery,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                letterSpacing: .5,
              ),
              decoration: InputDecoration(
                hintText: s.searchQuestions,
                fillColor: cs.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(AppSymbols.search, color: cs.onSurface),
                ),
                suffixIcon: c.query.isEmpty
                    ? null
                    : ReferenceIconButton(
                        tooltip: s.clearSearch,
                        onPressed: () => c.setQuery(''),
                        icon: AppSymbols.close,
                      ),
              ),
            ),
          ),
          if (doc.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppSymbols.warningAmber,
                    size: 20,
                    color: cs.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message: doc.warnings.join('\n'),
                      child: Text(
                        doc.warnings.take(3).join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: c.pdfMode
                ? PdfPane(
                    key: ValueKey(doc.sourcePath),
                    controller: c,
                    footerLeading: _viewSwitch(),
                  )
                : c.visibleQuestions.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        c.query.trim().isEmpty
                            ? s.noPreviewQuestions
                            : s.noMatchingQuestions,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: .5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    key: PageStorageKey('${doc.sourcePath}:${c.query}'),
                    padding: const EdgeInsets.only(right: 4),
                    itemCount: c.visibleQuestions.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => QuestionCard(
                      key: ValueKey(
                        '${doc.sourcePath}:${c.visibleQuestions[index].number}',
                      ),
                      question: c.visibleQuestions[index],
                      notify: c.tell,
                      reducedMotion: c.settings.reducedMotion,
                    ),
                  ),
          ),
          if (!c.pdfMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  _viewSwitch(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, size) => Text(
                        size.maxWidth < 140
                            ? s.questionsShort(c.visibleQuestions.length)
                            : s.questionsAllShown(c.visibleQuestions.length),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .1,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _viewSwitch() => ReferenceButtonGroup<bool>(
    key: _viewSwitchKey,
    expanded: false,
    height: 32,
    reducedMotion: c.settings.reducedMotion,
    items: [
      ReferenceSegment(
        value: false,
        label: context.strings.overview,
        icon: AppSymbols.viewAgenda,
      ),
      ReferenceSegment(
        value: true,
        label: context.strings.pdfPages,
        icon: AppSymbols.pictureAsPdf,
      ),
    ],
    selected: c.pdfMode,
    onSelected: c.setView,
  );

  Widget _empty() {
    final cs = Theme.of(context).colorScheme, error = c.current?.error;
    final s = context.strings;
    final shapeColor = error == null ? cs.tertiaryContainer : cs.errorContainer;
    return LayoutBuilder(
      builder: (context, size) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ReferenceReveal(
                  reducedMotion: c.settings.reducedMotion,
                  child: SizedBox.square(
                    dimension: 120,
                    child: Stack(
                      children: [
                        for (final position in [
                          Alignment.topLeft,
                          Alignment.topRight,
                          Alignment.bottomLeft,
                          Alignment.bottomRight,
                        ])
                          Align(
                            alignment: position,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: shapeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: shapeColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            error == null
                                ? AppSymbols.fileOpen
                                : AppSymbols.brokenImage,
                            size: 48,
                            color: error == null
                                ? cs.onTertiaryContainer
                                : cs.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  error == null ? s.emptyTitle : s.cannotReadPage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    height: 36 / 28,
                    fontWeight: FontWeight.w500,
                    fontVariations: emphasized(28, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    error == null ? s.emptyDetail : s.cannotReadDetail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      letterSpacing: .5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    // 520 dp of text plus padding.
                    constraints: const BoxConstraints(maxWidth: 552),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppSymbols.errorOutline,
                          size: 20,
                          color: cs.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: SelectableText(
                            error,
                            style: TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              letterSpacing: .25,
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ReferenceButton(
                        height: 56,
                        onPressed: _addFiles,
                        icon: AppSymbols.add,
                        child: Text(s.addFirstPage),
                      ),
                      ReferenceButton(
                        height: 56,
                        variant: ReferenceButtonVariant.text,
                        onPressed: _help,
                        icon: AppSymbols.helpOutline,
                        child: Text(s.userGuide),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.emptyShortcuts,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    s.exportedFiles,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReferenceCountBadge(
                    label: '${c.results.length}',
                    reducedMotion: c.settings.reducedMotion,
                  ),
                  const Spacer(),
                  Text(
                    s.resultsHint,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: .4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReferenceIconButton(
                    tooltip: s.hideResults,
                    onPressed: () {
                      c.resultsOpen = false;
                      c.changed();
                    },
                    icon: AppSymbols.expandMore,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: LayoutBuilder(
                  builder: (context, size) {
                    final columns = ((size.maxWidth + 4) / 304).floor().clamp(
                      1,
                      8,
                    );
                    return SizedBox(
                      height: c.results.isEmpty
                          ? 56
                          : (((c.results.length / columns).ceil() * 76) - 4)
                                .clamp(72, 132)
                                .toDouble(),
                      child: c.results.isEmpty
                          ? Center(
                              child: Text(
                                s.noFilesCreated,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 72,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                  ),
                              itemCount: c.results.length,
                              itemBuilder: (_, index) {
                                final path = c.results[index],
                                    selected = c.selectedResults.contains(path),
                                    format = p
                                        .extension(path)
                                        .replaceFirst('.', '')
                                        .toLowerCase();
                                // Exports are format files or *_assets folders.
                                final (icon, kind) = switch (format) {
                                  'txt' => (AppSymbols.article, 'TXT'),
                                  'pdf' => (AppSymbols.pictureAsPdf, 'PDF'),
                                  'md' => (AppSymbols.markdown, 'MD'),
                                  'json' || 'jsonl' => (
                                    AppSymbols.dataObject,
                                    format.toUpperCase(),
                                  ),
                                  _ => (AppSymbols.folder, s.assetsKind),
                                };
                                return GestureDetector(
                                  onDoubleTap: () => c.openResult(path),
                                  onPanStart: (_) => c.dragResults(path),
                                  child: Material(
                                    color: selected
                                        ? cs.secondaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => c.toggleResult(path),
                                      mouseCursor:
                                          WidgetStateMouseCursor.clickable,
                                      overlayColor: referenceStateLayer(
                                        cs.onSurface,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          24,
                                          8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              icon,
                                              size: 24,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.basename(path),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      height: 1.5,
                                                      letterSpacing: .5,
                                                      color: cs.onSurface,
                                                    ),
                                                  ),
                                                  Text(
                                                    p.dirname(path),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      height: 20 / 14,
                                                      letterSpacing: .25,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              kind,
                                              style: TextStyle(
                                                fontSize: 11,
                                                height: 16 / 11,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: .5,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                ReferenceButton(
                  variant: ReferenceButtonVariant.text,
                  onPressed: c.results.isEmpty ? null : c.openOutputs,
                  icon: AppSymbols.folderOpen,
                  child: Text(s.openOutputFolder),
                ),
                ReferenceButton(
                  variant: ReferenceButtonVariant.text,
                  onPressed: c.results.isEmpty ? null : _copyPaths,
                  icon: AppSymbols.contentCopy,
                  child: Text(
                    c.selectedResults.isEmpty
                        ? s.copyFilePaths
                        : s.copyPaths(c.selectedResults.length),
                  ),
                ),
                ReferenceButton(
                  variant: ReferenceButtonVariant.text,
                  onPressed: _log,
                  icon: AppSymbols.receiptLong,
                  child: Text(s.viewLog),
                ),
              ],
            ),
          ],
        ),
        color: cs.surfaceContainer,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      ),
    );
  }

  Widget _footer() {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    final enabled = c.canExport;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.status.isNotEmpty
                      ? c.status
                      : c.entries.isEmpty
                      ? s.readyToStart
                      : c.settings.formats.isEmpty
                      ? s.chooseAFormat
                      : s.queueSummary(
                          c.validCount,
                          c.settings.formats.length,
                          c.entries.length - c.validCount,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: .25,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ReferenceLinearProgress(
                  value: c.busy
                      ? (c.total == 0 ? null : c.done / c.total)
                      : c.results.isEmpty
                      ? 0
                      : 1,
                  wavy: c.busy,
                  reducedMotion: c.settings.reducedMotion,
                ),
              ],
            ),
          ),
          if (!c.resultsOpen && c.logs.isNotEmpty) ...[
            const SizedBox(width: 16),
            ReferenceButton(
              variant: ReferenceButtonVariant.text,
              onPressed: () {
                c.resultsOpen = true;
                c.changed();
              },
              icon: AppSymbols.history,
              child: Text(s.exportedFiles),
            ),
          ],
          if (c.busy) ...[
            const SizedBox(width: 24),
            ReferenceButton(
              height: 56,
              variant: ReferenceButtonVariant.outlined,
              onPressed: c.cancelling ? null : c.cancel,
              icon: AppSymbols.stop,
              child: Text(c.cancelling ? s.cancelling : s.cancel),
            ),
          ],
          const SizedBox(width: 24),
          AnimatedOpacity(
            opacity: enabled ? 1 : .38,
            duration: Duration(
              milliseconds: c.settings.reducedMotion ? 0 : 200,
            ),
            child: _ExportSplitButton(controller: c),
          ),
        ],
      ),
    );
  }
}

class _ExportSplitButton extends StatefulWidget {
  final AppController controller;
  const _ExportSplitButton({required this.controller});
  @override
  State<_ExportSplitButton> createState() => _ExportSplitButtonState();
}

class _ExportSplitButtonState extends State<_ExportSplitButton> {
  final _menu = MenuController();
  final _toggleFocus = FocusNode();
  bool _open = false;

  @override
  void didUpdateWidget(covariant _ExportSplitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_menu.isOpen && !widget.controller.canExport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _menu.close();
      });
    }
  }

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, cs = Theme.of(context).colorScheme;
    final s = context.strings;
    final reduced =
        c.settings.reducedMotion || MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduced ? 0 : 350);
    final canExportSelected =
        c.canExport && c.current?.document != null && c.current?.error == null;
    final source = canExportSelected ? c.current!.name : '';
    final name = source.length > 18 ? '${source.substring(0, 18)}…' : source;
    final label = name.isEmpty ? s.exportSelectedNone : s.exportSelected(name);
    final textStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w500,
      letterSpacing: .15,
      color: cs.onPrimary,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final menuWidth = painter.width + 72;
    painter.dispose();
    final baseStyle = referenceButtonStyle(height: 56).copyWith(
      animationDuration: duration,
      backgroundColor: WidgetStatePropertyAll(cs.primary),
      foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)
            ? cs.onPrimary.withValues(alpha: .1)
            : states.contains(WidgetState.hovered)
            ? cs.onPrimary.withValues(alpha: .08)
            : Colors.transparent,
      ),
      splashFactory: NoSplash.splashFactory,
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(EdgeInsets.fromLTRB(16, 0, 20, 0)),
    );
    return MenuAnchor(
      controller: _menu,
      childFocusNode: _toggleFocus,
      consumeOutsideTap: true,
      clipBehavior: Clip.none,
      // The selected-page action sits 8 dp above the split button.
      alignmentOffset: Offset(-menuWidth - 16, -80),
      style: const MenuStyle(
        alignment: Alignment.topRight,
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
      onOpen: () => setState(() => _open = true),
      onClose: () {
        if (mounted) setState(() => _open = false);
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: reduced ? 0 : 500),
            curve: referenceSpatialCurve,
            builder: (context, value, child) => Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - value)),
                child: Transform.scale(scale: .9 + .1 * value, child: child),
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: MenuItemButton(
                key: const ValueKey('export-selected'),
                autofocus: true,
                onPressed: canExportSelected
                    ? () => c.export(selectedOnly: true)
                    : null,
                style: baseStyle.copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? cs.onSurface.withValues(alpha: .12)
                        : cs.primary,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? cs.onSurface.withValues(alpha: .38)
                        : cs.onPrimary,
                  ),
                  fixedSize: WidgetStatePropertyAll(Size(menuWidth, 56)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.fromLTRB(16, 0, 24, 0),
                  ),
                  shape: WidgetStateProperty.resolveWith(
                    (states) => RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        states.contains(WidgetState.pressed) ? 12 : 28,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppSymbols.fileDownload, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: textStyle.copyWith(
                        color: canExportSelected
                            ? cs.onPrimary
                            : cs.onSurface.withValues(alpha: .38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => SizedBox(
        height: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              key: const ValueKey('export-all'),
              onPressed: c.canExport
                  ? () {
                      controller.close();
                      c.export();
                    }
                  : null,
              style: baseStyle.copyWith(
                shape: WidgetStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(
                        states.contains(WidgetState.pressed) ? 12 : 28,
                      ),
                      right: const Radius.circular(4),
                    ),
                  ),
                ),
              ),
              icon: const Icon(AppSymbols.fileDownload),
              label: Text(
                c.validCount > 0 ? s.exportAllCount(c.validCount) : s.exportAll,
              ),
            ),
            const SizedBox(width: 2),
            Semantics(
              expanded: _open,
              child: IconButton(
                key: const ValueKey('export-menu-toggle'),
                focusNode: _toggleFocus,
                tooltip: s.moreExportOptions,
                onPressed: c.canExport
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                style: baseStyle.copyWith(
                  fixedSize: const WidgetStatePropertyAll(Size.square(56)),
                  minimumSize: const WidgetStatePropertyAll(Size.square(56)),
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  shape: WidgetStateProperty.resolveWith(
                    (states) => RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(_open ? 28 : 4),
                        right: Radius.circular(
                          _open
                              ? 28
                              : states.contains(WidgetState.pressed)
                              ? 12
                              : 28,
                        ),
                      ),
                    ),
                  ),
                ),
                icon: AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: duration,
                  curve: referenceSpatialCurve,
                  child: const Icon(AppSymbols.keyboardArrowDown, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
