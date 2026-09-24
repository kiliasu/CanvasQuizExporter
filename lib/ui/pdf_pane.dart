import 'app_symbols.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../l10n/localizations.dart';
import '../services/app_controller.dart';
import 'action_controls.dart';

class PdfPane extends StatefulWidget {
  final AppController controller;
  final Widget? footerLeading;
  const PdfPane({super.key, required this.controller, this.footerLeading});
  @override
  State<PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<PdfPane> {
  PdfDocument? _document;
  String? _error;

  /// [_page] is the requested page; [_shown] stays on screen until the
  /// requested page has rendered, so paging never flashes a blank sheet.
  int _page = 1, _shown = 1, _request = 0, _revision = -1;

  /// Mounted pages whose image is ready; neighbors render ahead offstage.
  final _rendered = <int>{};
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PdfPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_revision != widget.controller.revision) _reload();
  }

  void _reload() {
    _revision = widget.controller.revision;
    _debounce?.cancel();
    final request = ++_request;
    _loading = true;
    _error = null;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final bytes = await widget.controller.previewPdf();
        if (!mounted || request != _request) return;
        await pdfrxFlutterInitialize();
        if (!mounted || request != _request) return;
        final doc = await PdfDocument.openData(
          bytes,
          sourceName: 'quiz-preview.pdf',
        );
        if (!mounted || request != _request) {
          await doc.dispose();
          return;
        }
        final previous = _document;
        setState(() {
          _document = doc;
          _page = _shown = 1;
          _rendered.clear();
          _loading = false;
        });
        await previous?.dispose();
      } on Object catch (e) {
        if (mounted && request == _request) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _request++;
    _debounce?.cancel();
    _document?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(int page) => setState(() {
    _page = page;
    if (_rendered.contains(page)) _show(page);
  });

  void _show(int page) {
    _shown = page;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Called while a page view builds with its image; swaps in the requested
  /// page on the next frame if it was still rendering when requested.
  void _pageRendered(int page) {
    if (!_rendered.add(page) || page != _page || page == _shown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && page == _page && _rendered.contains(page)) {
        setState(() => _show(page));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, s = context.strings;
    final doc = _document;
    final pageLabel = _loading
        ? s.generatingPreview
        : doc == null
        ? s.previewUnavailable
        : s.pageOf(
            _page,
            doc.pages.length,
            widget.controller.settings.paper == 'a4' ? 'A4' : 'Letter',
          );
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(color: cs.surfaceContainer, child: _preview(cs)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              if (widget.footerLeading != null) ...[
                widget.footerLeading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, size) => Tooltip(
                    message: pageLabel,
                    child: Text(
                      size.maxWidth >= 160
                          ? pageLabel
                          : _loading
                          ? '…'
                          : doc == null
                          ? '—'
                          : '$_page/${doc.pages.length}',
                      semanticsLabel: pageLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        letterSpacing: .1,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _pageButton(
                s.previousPage,
                AppSymbols.chevronLeft,
                !_loading && doc != null && _page > 1
                    ? () => _go(_page - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              _pageButton(
                s.nextPage,
                AppSymbols.chevronRight,
                !_loading && doc != null && _page < doc.pages.length
                    ? () => _go(_page + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageButton(String tooltip, IconData icon, VoidCallback? onPressed) =>
      ReferenceIconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        tonal: true,
        icon: icon,
      );

  Widget _preview(ColorScheme cs) {
    final s = context.strings;
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(s.generatingPdfPreview),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppSymbols.errorOutline, color: cs.error),
              const SizedBox(height: 12),
              SelectableText(_error!),
              const SizedBox(height: 12),
              ReferenceButton(
                variant: ReferenceButtonVariant.text,
                onPressed: () => setState(_reload),
                child: Text(s.retry),
              ),
            ],
          ),
        ),
      );
    }
    final doc = _document!;
    final sheet = doc.pages[_shown - 1];
    // The shown page, the requested one and both neighbors stay mounted;
    // only the shown page is painted.
    final mountedPages = {
      _shown,
      _page,
      _page - 1,
      _page + 1,
    }.where((page) => page >= 1 && page <= doc.pages.length).toSet();
    _rendered.retainAll(mountedPages);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 32).clamp(0.0, 620.0);
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: width * sheet.height / sheet.width,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 3,
                      spreadRadius: 1,
                      offset: Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final number in mountedPages)
                      Offstage(
                        key: ValueKey((doc, number)),
                        offstage: number != _shown,
                        child: PdfPageView(
                          document: doc,
                          pageNumber: number,
                          decorationBuilder: (context, size, page, image) {
                            if (image != null) _pageRendered(number);
                            return Align(
                              child: AspectRatio(
                                aspectRatio: size.width / size.height,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(color: Colors.white),
                                    ?image,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
