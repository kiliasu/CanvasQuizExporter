import 'app_symbols.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../l10n/localizations.dart';
import 'action_controls.dart';
import 'app_theme.dart';

class QuestionCard extends StatefulWidget {
  final QuizQuestion question;
  final bool reducedMotion;
  final void Function(String message, {bool error}) notify;
  const QuestionCard({
    super.key,
    required this.question,
    required this.reducedMotion,
    required this.notify,
  });
  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  // SelectableText scrolls internally. Without its own PageStorage it would
  // restore (and overwrite) the overview list's scroll offset, so text in
  // cards built while scrolling slid into place.
  final _storage = PageStorageBucket();
  bool _copied = false;
  bool _pressed = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.question.plainText()));
      if (!mounted) return;
      _copyTimer?.cancel();
      setState(() => _copied = true);
      widget.notify(context.strings.copiedQuestion(widget.question.number));
      _copyTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _copied = false);
      });
    } on Object {
      if (mounted) widget.notify(context.strings.clipboardFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question, cs = Theme.of(context).colorScheme;
    final s = context.strings;
    final selected = q.options
            .where((o) => o.selected)
            .map((o) => o.text)
            .join(', '),
        correct = q.options
            .where((o) => o.correct)
            .map((o) => o.text)
            .join(', ');
    final reduced =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(_pressed ? 16 : 20);
    return AnimatedContainer(
      duration: Duration(milliseconds: reduced ? 0 : 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _copied ? cs.secondaryContainer : cs.surfaceContainerLow,
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _copy,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: radius,
          mouseCursor: WidgetStateMouseCursor.clickable,
          overlayColor: referenceStateLayer(cs.onSurface),
          child: PageStorage(
            bucket: _storage,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        q.number.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 22,
                          height: 28 / 22,
                          fontWeight: FontWeight.w700,
                          fontVariations: emphasized(22),
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.questionType(q.type),
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            letterSpacing: .5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _copyBadge(cs, s, reduced),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    q.text,
                    onTap: () {},
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      letterSpacing: .5,
                    ),
                  ),
                  ...q.images.map((im) => QuizPicture(image: im)),
                  for (var i = 0; i < q.options.length; i++)
                    _option(q.options[i], i, cs, s),
                  if (q.userAnswer != null && q.userAnswer != selected)
                    _answer(
                      q.userAnswer == q.correctAnswer
                          ? s.answerCorrect
                          : s.answer,
                      q.userAnswer!,
                      q.userAnswer == q.correctAnswer,
                      cs,
                    ),
                  if (q.correctAnswer != null &&
                      q.correctAnswer != correct &&
                      q.correctAnswer != q.userAnswer)
                    _answer(s.correctAnswer, q.correctAnswer!, true, cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _copyBadge(ColorScheme cs, Strings s, bool reduced) {
    final foreground = _copied ? cs.onPrimary : cs.onSurfaceVariant;
    return AnimatedScale(
      scale: _copied ? 1.08 : 1,
      duration: Duration(milliseconds: reduced ? 0 : 350),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduced ? 0 : 300),
        width: 88,
        height: 28,
        decoration: BoxDecoration(
          color: _copied ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Semantics(
          label: _copied ? s.copied : s.copyQuestion,
          button: true,
          child: GestureDetector(
            onTap: _copy,
            behavior: HitTestBehavior.opaque,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: reduced ? 0 : 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(
                        0,
                        child.key == const ValueKey(true) ? .28 : -.28,
                      ),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(_copied),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _copied ? AppSymbols.check : AppSymbols.contentCopy,
                      size: 16,
                      color: foreground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _copied ? s.copied : s.copy,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        letterSpacing: .5,
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(QuizOption o, int index, ColorScheme cs, Strings s) {
    final emphasized = o.correct || o.selected;
    final foreground = o.correct
        ? cs.onPrimaryContainer
        : o.selected
        ? cs.onSecondaryContainer
        : cs.onSurface;
    final markerLabel = [
      if (o.selected) s.selected,
      if (o.correct) s.correct,
    ].join(' · ');
    final markerStyle = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: .5,
      fontWeight: FontWeight.w500,
      color: foreground,
    );
    final marker = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(markerLabel, style: markerStyle),
        const SizedBox(width: 12),
        Icon(
          o.correct ? AppSymbols.checkCircle : AppSymbols.radioButtonChecked,
          fill: 1,
          size: 20,
          color: foreground,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: o.correct
              ? cs.primaryContainer
              : o.selected
              ? cs.secondaryContainer
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The markers move under the text rather than squeeze it below
            // 100 dp, which happens with longer (English) labels. The letter,
            // gaps and icon take 72 dp besides the marker label.
            final textWidth =
                constraints.maxWidth -
                72 -
                _textWidth(context, markerLabel, markerStyle);
            final inline = !emphasized || textWidth >= 100;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text(
                        optionLabel(index),
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: .1,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        o.text,
                        onTap: () {},
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: .25,
                          color: foreground,
                        ),
                      ),
                    ),
                    if (emphasized && inline) ...[
                      const SizedBox(width: 12),
                      marker,
                    ],
                  ],
                ),
                if (!inline)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: marker,
                  ),
                ...o.images.map(
                  (im) => Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: QuizPicture(image: im, captionColor: foreground),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _answer(String label, String value, bool correct, ColorScheme cs) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: correct ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                correct ? AppSymbols.checkCircle : AppSymbols.edit,
                fill: correct ? 1 : 0,
                size: 20,
                color: correct ? cs.onPrimaryContainer : cs.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w500,
                  color: (correct ? cs.onPrimaryContainer : cs.onSurface)
                      .withValues(alpha: .85),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  value,
                  onTap: () {},
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: .15,
                    fontWeight: FontWeight.w700,
                    fontVariations: emphasized(16),
                    color: correct ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A question image (16 dp corners, local-resource caption) or, with
/// [captionColor], an option image captioned in the option's colour.
class QuizPicture extends StatelessWidget {
  final QuizImage image;
  final Color? captionColor;
  const QuizPicture({super.key, required this.image, this.captionColor});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, option = captionColor != null;
    final s = context.strings;
    if (!image.available) {
      return Padding(
        padding: EdgeInsets.only(top: option ? 10 : 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                AppSymbols.imageNotSupported,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  image.alt,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: .25,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                s.onlineImage,
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
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: option ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(option ? 12 : 16),
            child: Material(
              color: option ? cs.surface : cs.surfaceContainerHighest,
              child: InkWell(
                onTap: () => _show(context),
                mouseCursor: WidgetStateMouseCursor.clickable,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: Image.memory(
                    image.bytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(s.imageUnavailable),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Row(
              children: [
                if (!option) ...[
                  Icon(AppSymbols.image, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    option ? image.alt : s.localImage(image.alt),
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: .4,
                      color: option
                          ? captionColor!.withValues(alpha: .85)
                          : cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ReferenceIconButton(
                  tooltip: s.viewFullImage,
                  onPressed: () => _show(context),
                  size: 32,
                  icon: AppSymbols.openInFull,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme, s = context.strings;
      final screen = MediaQuery.sizeOf(context);
      return Dialog(
        insetPadding: const EdgeInsets.all(56),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  image.alt,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                // Shrinks when the window is too short for the full height.
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: SizedBox(
                        width: double.infinity,
                        height: (screen.height - 300).clamp(120.0, 560.0),
                        child: InteractiveViewer(
                          minScale: .2,
                          maxScale: 5,
                          child: Center(
                            child: Image.memory(
                              image.bytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                        AppSymbols.shield,
                        size: 20,
                        color: cs.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.imageViewerNote(image.width, image.height),
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            letterSpacing: .25,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ReferenceButton(
                    variant: ReferenceButtonVariant.text,
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.close),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
