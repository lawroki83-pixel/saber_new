import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/i18n/strings.g.dart';

/// A dialog that lets the user jump straight to a given page
/// and bookmark pages so that they can return to them later.
///
/// This is aimed at long notes — for example a long PDF that has been
/// imported into Saber — where scrolling from the first page to the
/// last page is impractical.
class PageJumpDialog extends StatefulWidget {
  new({
    super.key,
    required this.coreInfo,
    required this.currentPageIndex,
    required this.goToPage,
    required this.onBookmarksChanged,
  });

  final EditorCoreInfo coreInfo;

  /// The page that is currently centred on screen.
  final int currentPageIndex;

  /// Scrolls the canvas to the given page index.
  final void Function(int pageIndex) goToPage;

  /// Called after the user edits the bookmarks in this dialog.
  ///
  /// The editor uses this to trigger an autosave.
  final VoidCallback onBookmarksChanged;

  /// Shows this dialog.
  static Future<void> show({
    required BuildContext context,
    required EditorCoreInfo coreInfo,
    required int currentPageIndex,
    required void Function(int pageIndex) goToPage,
    required VoidCallback onBookmarksChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PageJumpDialog(
        coreInfo: coreInfo,
        currentPageIndex: currentPageIndex,
        goToPage: goToPage,
        onBookmarksChanged: onBookmarksChanged,
      ),
    );
  }

  @override
  State<PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<PageJumpDialog> {
  final pageNumberController = TextEditingController();
  final pageNumberFieldKey = GlobalKey<FormState>();

  /// A local copy of [EditorCoreInfo.bookmarks]. It is written back to the
  /// note when the user confirms the dialog, so that pressing Cancel
  /// leaves the note untouched.
  late final List<int> bookmarks = List<int>.of(widget.coreInfo.bookmarks);

  int get pageCount => widget.coreInfo.pages.length;

  int get currentPageNumber => widget.currentPageIndex + 1;

  List<int> get sortedBookmarks => bookmarks.toList()..sort();

  bool get isCurrentPageBookmarked => bookmarks.contains(
    widget.currentPageIndex,
  );

  @override
  void initState() {
    super.initState();
    pageNumberController.text = '$currentPageNumber';
  }

  @override
  void dispose() {
    pageNumberController.dispose();
    super.dispose();
  }

  void removeBookmark(int pageIndex) {
    setState(() => bookmarks.remove(pageIndex));
  }

  void toggleCurrentBookmark() {
    setState(() {
      if (isCurrentPageBookmarked) {
        bookmarks.remove(widget.currentPageIndex);
      } else {
        bookmarks.add(widget.currentPageIndex);
      }
    });
  }

  /// Jumps to the page the user typed, without closing the dialog.
  void jumpToTypedPage() {
    if (!(pageNumberFieldKey.currentState?.validate() ?? false)) return;

    final page = int.tryParse(pageNumberController.text.trim());
    if (page == null) return;

    widget.goToPage(page - 1);
  }

  void saveAndClose() {
    final changed =
        bookmarks.length != widget.coreInfo.bookmarks.length ||
        !bookmarks.every(widget.coreInfo.bookmarks.contains);

    if (changed) {
      widget.coreInfo.bookmarks
        ..clear()
        ..addAll(bookmarks);
      widget.onBookmarksChanged();
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final sorted = sortedBookmarks;

    return AdaptiveAlertDialog(
      title: Text(t.editor.pageJump.title),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                t.editor.pageJump.currentPage(
                  page: currentPageNumber,
                  totalPages: pageCount,
                ),
              ),
              const SizedBox.square(dimension: 12),

              // ── 跳转到指定页码 ──
              Form(
                key: pageNumberFieldKey,
                child: TextFormField(
                  controller: pageNumberController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: t.editor.pageJump.pageNumber,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: t.editor.pageJump.jump,
                      onPressed: jumpToTypedPage,
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return t.editor.pageJump.enterPageNumber;
                    }
                    final page = int.tryParse(text);
                    if (page == null || page < 1 || page > pageCount) {
                      return t.editor.pageJump.pageOutOfRange;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => jumpToTypedPage(),
                ),
              ),
              const SizedBox.square(dimension: 12),

              // ── 为当前页添加 / 移除书签 ──
              OutlinedButton.icon(
                onPressed: toggleCurrentBookmark,
                icon: Icon(
                  isCurrentPageBookmarked
                      ? Icons.bookmark_remove
                      : Icons.bookmark_add,
                ),
                label: Text(
                  isCurrentPageBookmarked
                      ? t.editor.pageJump.removeBookmark
                      : t.editor.pageJump.addBookmark,
                ),
              ),
              const SizedBox.square(dimension: 16),

              // ── 书签列表 ──
              Text(
                sorted.isEmpty
                    ? t.editor.pageJump.noBookmarks
                    : (sorted.length == 1
                          ? t.editor.pageJump.bookmarkCountOne
                          : t.editor.pageJump.bookmarkCount(
                              n: sorted.length,
                            )),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              // 使用 Column 而非嵌套的 ListView，
              // 避免把滚动行为嵌套在 SingleChildScrollView 里。
              for (final pageIndex in sorted)
                ListTile(
                  contentPadding: .zero,
                  dense: true,
                  leading: const Icon(Icons.bookmark),
                  title: Text(t.editor.pageJump.pageN(page: pageIndex + 1)),
                  onTap: () {
                    widget.goToPage(pageIndex);
                    Navigator.of(context).pop();
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: t.editor.pageJump.removeBookmark,
                    onPressed: () => removeBookmark(pageIndex),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text(t.common.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoDialogAction(
          child: Text(t.common.done),
          onPressed: saveAndClose,
        ),
      ],
    );
  }
}
