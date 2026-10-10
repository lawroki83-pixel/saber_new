import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/i18n/strings.g.dart';

/// A dialog that lets the user jump straight to a given page and manage
/// bookmarks — add, rename, jump to and delete — without leaving the editor.
class PageJumpDialog extends StatefulWidget {
  new({
    super.key,
    required this.coreInfo,
    required this.currentPageUtil,
    required this.transformationController,
    required this.goToPage,
    required this.onBookmarksChanged,
  });

  final EditorCoreInfo coreInfo;

  /// Returns the page index currently centred on screen.
  final int Function() currentPageUtil;

  /// The canvas transform. Listening to it keeps this dialog in sync with
  /// the page the user is looking at.
  final TransformationController transformationController;

  /// Scrolls the canvas to the given page index.
  final void Function(int pageIndex) goToPage;

  /// Called whenever the bookmarks change, so the editor can autosave.
  final VoidCallback onBookmarksChanged;

  static Future<void> show({
    required BuildContext context,
    required EditorCoreInfo coreInfo,
    required int Function() currentPageUtil,
    required TransformationController transformationController,
    required void Function(int pageIndex) goToPage,
    required VoidCallback onBookmarksChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PageJumpDialog(
        coreInfo: coreInfo,
        currentPageUtil: currentPageUtil,
        transformationController: transformationController,
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

  /// Set after a change, so the dialog can show a short "saved" hint.
  bool justSaved = false;

  /// The page the user last jumped to through this dialog.
  int? lastTouchedPageIndex;

  int get pageCount => widget.coreInfo.pages.length;

  /// The page the canvas is currently showing.
  int get currentPageIndex {
    final index = widget.currentPageUtil();
    if (index < 0) return 0;
    if (pageCount == 0) return 0;
    if (index >= pageCount) return pageCount - 1;
    return index;
  }

  int get currentPageNumber => currentPageIndex + 1;

  List<EditorBookmark> get bookmarks => widget.coreInfo.bookmarks;

  /// A defensive, sorted copy of [bookmarks].
  List<EditorBookmark> get sortedBookmarks =>
      List<EditorBookmark>.of(bookmarks)
        ..sort(
          (EditorBookmark a, EditorBookmark b) =>
              a.pageIndex.compareTo(b.pageIndex),
        );

  EditorBookmark? get currentBookmark =>
      widget.coreInfo.bookmarkAt(currentPageIndex);

  @override
  void initState() {
    super.initState();
    pageNumberController.text = '$currentPageNumber';
    widget.transformationController.addListener(onCanvasMoved);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(onCanvasMoved);
    pageNumberController.dispose();
    super.dispose();
  }

  void onCanvasMoved() {
    if (!mounted) return;

    // 不要在用户正把"另一个页码"输进输入框时覆盖它
    final fieldIsValid = pageNumberFieldKey.currentState?.validate() ?? false;
    if (!fieldIsValid) return;

    final newText = '${currentPageIndex + 1}';
    if (pageNumberController.text == newText) return;

    setState(() => pageNumberController.text = newText);
  }

  /// Jumps to a page and remembers it for highlighting.
  void jumpToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageCount) return;

    lastTouchedPageIndex = pageIndex;
    widget.goToPage(pageIndex);
    setState(() => pageNumberController.text = '${pageIndex + 1}');
  }

  /// Writes a change to the note straight away and asks the editor to autosave.
  void applyChange(void Function() change) {
    setState(() {
      change();
      justSaved = true;
    });
    widget.coreInfo.bookmarks.sort(
      (EditorBookmark a, EditorBookmark b) =>
          a.pageIndex.compareTo(b.pageIndex),
    );
    widget.onBookmarksChanged();
  }

  void toggleCurrentBookmark() {
    final page = currentPageIndex;
    applyChange(() {
      final existing = widget.coreInfo.bookmarkAt(page);
      if (existing != null) {
        widget.coreInfo.bookmarks.remove(existing);
      } else {
        widget.coreInfo.bookmarks.add(EditorBookmark(pageIndex: page));
      }
    });
  }

  void removeBookmark(EditorBookmark bookmark) {
    applyChange(() => widget.coreInfo.bookmarks.remove(bookmark));
  }

  /// Opens a small dialog to give the bookmark a name.
  Future<void> renameBookmark(EditorBookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.editor.pageJump.renameBookmark),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t.editor.pageJump.bookmarkName,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: Text(t.common.done),
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null) return;
    applyChange(() {
      final trimmed = newName.trim();
      bookmark.name = trimmed.isEmpty ? null : trimmed;
    });
  }

  void jumpToTypedPage() {
    if (!(pageNumberFieldKey.currentState?.validate() ?? false)) return;

    final page = int.tryParse(pageNumberController.text.trim());
    if (page == null) return;

    jumpToPage(page - 1);
  }

  /// The label shown for a bookmark: its name if it has one,
  /// otherwise the page number.
  String bookmarkLabel(EditorBookmark bookmark) {
    final name = bookmark.name;
    if (name != null && name.isNotEmpty) {
      return '${t.editor.pageJump.pageN(page: bookmark.pageIndex + 1)} · $name';
    }
    return t.editor.pageJump.pageN(page: bookmark.pageIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final sorted = sortedBookmarks;
    final listHeight = MediaQuery.sizeOf(context).height * 0.34;
    final onThisPage = currentBookmark != null;

    return AdaptiveAlertDialog(
      title: Text(t.editor.pageJump.title),
      content: SizedBox(
        width: 340,
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
              FilledButton.icon(
                onPressed: toggleCurrentBookmark,
                icon: Icon(
                  onThisPage ? Icons.bookmark_remove : Icons.bookmark_add,
                ),
                label: Text(
                  onThisPage
                      ? t.editor.pageJump.removeBookmark
                      : t.editor.pageJump.addBookmark,
                ),
              ),
              const SizedBox.square(dimension: 8),

              // 立即保存后的反馈
              if (justSaved)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox.square(dimension: 6),
                    Text(
                      t.editor.pageJump.saved,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              const SizedBox.square(dimension: 12),

              // ── 书签面板 ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sorted.isEmpty
                          ? t.editor.pageJump.noBookmarks
                          : (sorted.length == 1
                                ? t.editor.pageJump.bookmarkCountOne
                                : t.editor.pageJump.bookmarkCount(
                                    n: sorted.length,
                                  )),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (sorted.isNotEmpty)
                    Text(
                      t.editor.pageJump.tapToJump,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              if (sorted.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final bookmark = sorted[index];
                      final isCurrent = bookmark.pageIndex == currentPageIndex;
                      final isLastTouched =
                          bookmark.pageIndex == lastTouchedPageIndex;
                      return ListTile(
                        contentPadding: .zero,
                        dense: true,
                        leading: Icon(
                          isCurrent ? Icons.bookmark : Icons.bookmark_border,
                          color: isCurrent ? colorScheme.primary : null,
                        ),
                        title: Text(
                          bookmarkLabel(bookmark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isCurrent
                              ? TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                        subtitle: isLastTouched
                            ? Text(
                                t.editor.pageJump.justVisited,
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                        // 跳转但不关闭，方便连着翻几个书签
                        onTap: () => jumpToPage(bookmark.pageIndex),
                        trailing: Row(
                          mainAxisSize: .min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: t.editor.pageJump.renameBookmark,
                              onPressed: () => renameBookmark(bookmark),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: t.editor.pageJump.removeBookmark,
                              onPressed: () => removeBookmark(bookmark),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text(t.common.done),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
