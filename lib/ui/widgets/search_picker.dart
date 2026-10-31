import 'package:flutter/material.dart';
import '../../data/models/national_identity.dart';

/// Shows all choices on focus, then filters as the user types.
class SearchPicker<T> extends StatefulWidget {
  final List<T> options;
  final String Function(T) label;
  final String Function(T)? searchText;
  final String hint;
  final ValueChanged<T> onSelected;
  final VoidCallback? onCleared;
  const SearchPicker({
    super.key,
    required this.options,
    required this.label,
    required this.hint,
    required this.onSelected,
    this.searchText,
    this.onCleared,
  });
  @override
  State<SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<SearchPicker<T>> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus) setState(() => _open = true);
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = normalizeSearch(_controller.text);
    final options = widget.options
        .where(
          (o) => normalizeSearch(
            (widget.searchText ?? widget.label)(o),
          ).contains(term),
        )
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          onTap: () => setState(() => _open = true),
          onChanged: (_) {
            setState(() => _open = true);
            widget.onCleared?.call();
          },
          decoration: InputDecoration(
            labelText: widget.hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: () {
                _focus.requestFocus();
                setState(() => _open = !_open);
              },
            ),
          ),
        ),
        if (_open)
          Material(
            elevation: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا توجد نتائج'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return ListTile(
                          title: Text(widget.label(option)),
                          onTap: () {
                            _controller.text = widget.label(option);
                            setState(() => _open = false);
                            _focus.unfocus();
                            widget.onSelected(option);
                          },
                        );
                      },
                    ),
            ),
          ),
      ],
    );
  }
}
