import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/i18n/strings.g.dart';

class PageJumpDialog extends StatefulWidget {
  new({
    super.key,
    required this.coreInfo,
    required this.currentPageIndex,
    required this.goToPage,
    required this.onBookmarksChanged,
  });

  final EditorCoreInfo coreInfo;
  final int currentPageIndex;
  final void Function(int pageIndex) goToPage;
  final VoidCallback onBookmarksChanged;

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

  late int currentPageIndex = widget.currentPageIndex;

  bool justSaved = false;

  int get pageCount => widget.coreInfo.pages.length;

  int get currentPageNumber => currentPageIndex + 1;

  List<int> get bookmarks => widget.coreInfo.bookmarks;

  List<int> get sortedBookmarks => bookmarks.toList()..sort();

  bool get isCurrentPageBookmarked => bookmarks.contains(currentPageIndex);

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

  void jumpToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageCount) return;

    setState(() {
      currentPageIndex = pageIndex;
      pageNumberController.text = '${pageIndex + 1}';
    });
    widget.goToPage(pageIndex);
  }

  void applyChange(void Function() change) {
    setState(() {
      change();
      justSaved = true;
    });
    widget.onBookmarksChanged();
  }

  void removeBookmark(int pageIndex) {
    applyChange(() => bookmarks.remove(pageIndex));
  }

  void toggleCurrentBookmark() {
    applyChange(() {
      if (isCurrentPageBookmarked) {
        bookmarks.remove(currentPageIndex);
      } else {
        bookmarks.add(currentPageIndex);
      }
    });
  }

  void jumpToTypedPage() {
    if (!(pageNumberFieldKey.currentState?.validate() ?? false)) return;

    final page = int.tryParse(pageNumberController.text.trim());
    if (page == null) return;

    jumpToPage(page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final sorted = sortedBookmarks;
    final listHeight = MediaQuery.sizeOf(context).height * 0.32;

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
              FilledButton.icon(
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
              const SizedBox.square(dimension: 8),
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
              Text(
                sorted.isEmpty
                    ? t.editor.pageJump.noBookmarks
                    : (sorted.length == 1
                          ? t.editor.pageJump.bookmarkCountOne
                          : t.editor.pageJump.bookmarkCount(n: sorted.length)),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              if (sorted.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final pageIndex = sorted[index];
                      final isCurrent = pageIndex == currentPageIndex;
                      return ListTile(
                        contentPadding: .zero,
                        dense: true,
                        leading: Icon(
                          isCurrent ? Icons.bookmark : Icons.bookmark_border,
                          color: isCurrent ? colorScheme.primary : null,
                        ),
                        title: Text(
                          t.editor.pageJump.pageN(page: pageIndex + 1),
                        ),
                        onTap: () => jumpToPage(pageIndex),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: t.editor.pageJump.removeBookmark,
                          onPressed: () => removeBookmark(pageIndex),
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
