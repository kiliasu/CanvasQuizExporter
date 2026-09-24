import 'app_symbols.dart';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../domain/models.dart';
import '../l10n/localizations.dart';
import '../services/app_controller.dart';
import 'app_theme.dart';
import 'collapsible_panel.dart';
import 'motion.dart';
import 'reference_controls.dart';

/// Rail icons of the export formats.
const formatIcons = {
  'txt': AppSymbols.article,
  'pdf': AppSymbols.pictureAsPdf,
  'md': AppSymbols.markdown,
  'json': AppSymbols.dataObject,
  'jsonl': AppSymbols.viewList,
};

class SettingsPanel extends StatefulWidget {
  final AppController controller;

  /// Shows the minimize control in the header when provided.
  final VoidCallback? onCollapse;
  const SettingsPanel({super.key, required this.controller, this.onCollapse});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _advanced = false;
  AppController get c => widget.controller;
  void change(VoidCallback action) {
    action();
    c.settingsChanged();
  }

  Widget label(String text, {bool top = false, bool enabled = true}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top ? 4 : 0, 8, 0),
      child: AnimatedDefaultTextStyle(
        duration: Duration(milliseconds: c.settings.reducedMotion ? 0 : 200),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: enabled
              ? cs.onSurfaceVariant
              : cs.onSurface.withValues(alpha: .38),
        ),
        child: Text(text),
      ),
    );
  }

  Future<void> _pickOutput() async {
    try {
      final path = await getDirectoryPath();
      if (path != null && mounted) change(() => c.settings.outputPath = path);
    } on Object catch (e) {
      c.tell(c.strings.cannotChooseFolder(e), error: true);
    }
  }

  Future<void> _pickFont() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: c.strings.trueTypeFontType, extensions: ['ttf']),
        ],
      );
      if (file != null && mounted) {
        change(() => c.settings.fontPath = file.path);
      }
    } on Object catch (e) {
      c.tell(c.strings.cannotChooseFont(e), error: true);
    }
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 12),
              ReferenceSwitch(
                value: value,
                onChanged: onChanged,
                semanticLabel: title,
                reducedMotion: c.settings.reducedMotion,
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cfg = c.settings, cs = Theme.of(context).colorScheme;
    final s = context.strings;
    final duration = Duration(milliseconds: cfg.reducedMotion ? 0 : 500);
    const gap = SizedBox(height: 12);
    final pdfEnabled = cfg.formats.contains('pdf') || c.pdfMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            4,
            widget.onCollapse == null ? 8 : 0,
            4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.exportSettings,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.onCollapse != null)
                PaneToggleButton(
                  collapsed: false,
                  end: true,
                  tooltip: s.minimizeSettings,
                  onPressed: widget.onCollapse,
                  reducedMotion: cfg.reducedMotion,
                ),
            ],
          ),
        ),
        gap,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(right: 2),
            children: [
              label(s.fileFormats),
              gap,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final format in exportFormats)
                        ReferenceCheckbox(
                          key: ValueKey('format-$format'),
                          value: cfg.formats.contains(format),
                          label: s.formatName(format),
                          description: s.formatDescription(format),
                          height: 44,
                          reducedMotion: cfg.reducedMotion,
                          onChanged: (value) => change(
                            () => value
                                ? cfg.formats.add(format)
                                : cfg.formats.remove(format),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              gap,
              label(s.saveLocation, top: true),
              gap,
              ReferenceButtonGroup<bool>(
                key: const ValueKey('output-mode'),
                items: [
                  ReferenceSegment(value: false, label: s.besideSource),
                  ReferenceSegment(value: true, label: s.customFolder),
                ],
                selected: cfg.customOutput,
                onSelected: (value) => change(() => cfg.customOutput = value),
                reducedMotion: cfg.reducedMotion,
              ),
              MotionSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: cfg.customOutput
                    ? ReferenceReveal(
                        reducedMotion: cfg.reducedMotion,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SettingField(
                            key: const ValueKey('output-path'),
                            value: cfg.outputPath,
                            label: s.outputFolder,
                            onChanged: (v) => change(() => cfg.outputPath = v),
                            trailing: IconButton(
                              tooltip: s.chooseOutputFolder,
                              onPressed: _pickOutput,
                              icon: const Icon(AppSymbols.folderOpen),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              gap,
              Tooltip(
                message: s.saveImagesDetail,
                child: _switchRow(
                  s.saveImages,
                  cfg.copyAssets,
                  (v) => change(() => cfg.copyAssets = v),
                ),
              ),
              gap,
              label(s.filters, top: true),
              gap,
              SettingField(
                key: const ValueKey('filters'),
                value: cfg.filters,
                label: s.filtersLabel,
                hint: s.filtersHint,
                leadingIcon: AppSymbols.filterAlt,
                multiline: true,
                onChanged: (v) => change(() => cfg.filters = v),
              ),
              if (c.suggestions.isNotEmpty) ...[
                gap,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.repeatedSentences,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final hint in c.suggestions)
                            Tooltip(
                              message: hint.text,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 290,
                                ),
                                child: ReferenceChip(
                                  label:
                                      '${hint.text.length > 42 ? '${hint.text.substring(0, 42)}…' : hint.text} ×${hint.count}',
                                  icon: AppSymbols.add,
                                  selected: cfg.filterLines.any(
                                    (f) =>
                                        f.toLowerCase() ==
                                        hint.text.toLowerCase(),
                                  ),
                                  onPressed: () =>
                                      c.toggleSuggestion(hint.text),
                                  reducedMotion: cfg.reducedMotion,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              gap,
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('advanced-options'),
                  onTap: () => setState(() => _advanced = !_advanced),
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  overlayColor: referenceStateLayer(cs.onSurface),
                  child: SizedBox(
                    height: 72,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                      child: Row(
                        children: [
                          Icon(
                            AppSymbols.tune,
                            size: 24,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  s.moreOptions,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  s.moreOptionsSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          AnimatedRotation(
                            turns: _advanced ? .5 : 0,
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              AppSymbols.expandMore,
                              size: 24,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              MotionSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _advanced
                    ? ReferenceReveal(
                        reducedMotion: cfg.reducedMotion,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              label(s.fileNaming),
                              gap,
                              SettingField(
                                key: const ValueKey('name-template'),
                                value: cfg.nameTemplate,
                                label: s.nameTemplate,
                                hint: s.nameTemplateHint,
                                onChanged: (v) =>
                                    change(() => cfg.nameTemplate = v),
                              ),
                              gap,
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final v in nameVariables)
                                    ReferenceChip(
                                      label: '{$v}',
                                      reducedMotion: cfg.reducedMotion,
                                      onPressed: () => change(() {
                                        if (!cfg.nameTemplate.contains(
                                          '{$v}',
                                        )) {
                                          cfg.nameTemplate +=
                                              '${cfg.nameTemplate.isEmpty ? '' : '_'}{$v}';
                                        }
                                      }),
                                    ),
                                ],
                              ),
                              gap,
                              label(s.pdfPaper, top: true, enabled: pdfEnabled),
                              gap,
                              IgnorePointer(
                                ignoring: !pdfEnabled,
                                child: AnimatedOpacity(
                                  opacity: pdfEnabled ? 1 : .38,
                                  duration: Duration(
                                    milliseconds: cfg.reducedMotion ? 0 : 200,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ReferenceButtonGroup<String>(
                                        items: const [
                                          ReferenceSegment(
                                            value: 'letter',
                                            label: 'Letter',
                                          ),
                                          ReferenceSegment(
                                            value: 'a4',
                                            label: 'A4',
                                          ),
                                        ],
                                        selected: cfg.paper,
                                        onSelected: (v) =>
                                            change(() => cfg.paper = v),
                                        reducedMotion: cfg.reducedMotion,
                                      ),
                                      gap,
                                      SettingField(
                                        key: const ValueKey('pdf-font'),
                                        value: cfg.fontPath,
                                        label: s.customPdfFont,
                                        hint: s.customPdfFontHint,
                                        onChanged: (v) =>
                                            change(() => cfg.fontPath = v),
                                        trailing: IconButton(
                                          tooltip: s.chooseTtfFont,
                                          onPressed: _pickFont,
                                          icon: const Icon(
                                            AppSymbols.fontDownload,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              gap,
                              Tooltip(
                                message: s.diagnosticsDetail,
                                child: ReferenceCheckbox(
                                  label: s.diagnostics,
                                  value: cfg.diagnostics,
                                  reducedMotion: cfg.reducedMotion,
                                  onChanged:
                                      cfg.formats.contains('json') ||
                                          cfg.formats.contains('jsonl')
                                      ? (v) => change(() => cfg.diagnostics = v)
                                      : null,
                                ),
                              ),
                              gap,
                              ReferenceCheckbox(
                                label: s.openFolderWhenDone,
                                value: cfg.openOnFinish,
                                reducedMotion: cfg.reducedMotion,
                                onChanged: (v) =>
                                    change(() => cfg.openOnFinish = v),
                              ),
                              gap,
                              _switchRow(
                                s.reduceMotion,
                                cfg.reducedMotion,
                                (v) => change(() => cfg.reducedMotion = v),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        gap,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppSymbols.shield, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.privacyNote,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingField extends StatefulWidget {
  final String value, label;
  final String? hint;
  final bool multiline;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final IconData? leadingIcon;
  const SettingField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.hint,
    this.multiline = false,
    this.trailing,
    this.leadingIcon,
  });
  @override
  State<SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<SettingField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant SettingField old) {
    super.didUpdateWidget(old);
    if (_text.text != widget.value) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final floating = _focus.hasFocus || _text.text.isNotEmpty;
    final accent = _focus.hasFocus ? cs.primary : cs.onSurfaceVariant;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final left = widget.leadingIcon == null ? 16.0 : 52.0;
    final right = widget.trailing == null ? 16.0 : 52.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.text,
          child: GestureDetector(
            onTap: _focus.requestFocus,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(left, 24, right, 8),
                    child: Semantics(
                      label: widget.label,
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        onChanged: widget.onChanged,
                        minLines: 1,
                        maxLines: widget.multiline ? 4 : 1,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: Duration(milliseconds: reduced ? 0 : 350),
                    curve: Curves.easeOutCubic,
                    top: floating ? 8 : 16,
                    left: left,
                    right: right,
                    child: IgnorePointer(
                      child: AnimatedDefaultTextStyle(
                        duration: Duration(milliseconds: reduced ? 0 : 350),
                        curve: Curves.easeOutCubic,
                        style:
                            (floating
                                    ? Theme.of(context).textTheme.bodySmall!
                                    : Theme.of(context).textTheme.bodyLarge!)
                                .copyWith(color: accent),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (widget.leadingIcon != null)
                    Positioned(
                      left: 12,
                      top: 16,
                      child: Icon(
                        widget.leadingIcon,
                        size: 24,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (widget.trailing != null)
                    Positioned(
                      right: 4,
                      top: 8,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: widget.trailing!,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: reduced ? 0 : 200),
                      height: _focus.hasFocus ? 2 : 1,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              widget.hint!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
