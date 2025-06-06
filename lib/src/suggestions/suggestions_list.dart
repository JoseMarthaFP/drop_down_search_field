import 'dart:async';
import 'dart:math';
import 'package:drop_down_search_field/drop_down_search_field.dart';
import 'package:drop_down_search_field/src/keyboard_suggestion_selection_notifier.dart';
import 'package:drop_down_search_field/src/should_refresh_suggestion_focus_index_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Renders all the suggestions using a ListView as default.  If
/// `layoutArchitecture` is specified, uses that instead.

class SuggestionsList<SuggestionsModel> extends StatefulWidget {
  final SuggestionsBox? suggestionsBox;
  final TextEditingController? controller;
  final bool getImmediateSuggestions;
  final SuggestionSelectionCallback<SuggestionsModel>? onSuggestionSelected;
  final SuggestionMultiSelectionCallback<SuggestionsModel>?
      onSuggestionMultiSelected;
  final SuggestionsCallback<SuggestionsModel>? suggestionsCallback;
  final ItemBuilder<SuggestionsModel>? itemBuilder;
  final IndexedWidgetBuilder? itemSeparatorBuilder;
  final LayoutArchitecture? layoutArchitecture;
  final ScrollController? scrollController;
  final SuggestionsBoxDecoration? decoration;
  final Duration? debounceDuration;
  final WidgetBuilder? loadingBuilder;
  final bool intercepting;
  final WidgetBuilder? noItemsFoundBuilder;
  final ErrorBuilder? errorBuilder;
  final AnimationTransitionBuilder? transitionBuilder;
  final Duration? animationDuration;
  final double? animationStart;
  final AxisDirection? direction;
  final bool? hideOnLoading;
  final bool? hideOnEmpty;
  final bool? hideOnError;
  final bool? keepSuggestionsOnLoading;
  final int? minCharsForSuggestions;
  final KeyboardSuggestionSelectionNotifier keyboardSuggestionSelectionNotifier;
  final ShouldRefreshSuggestionFocusIndexNotifier
      shouldRefreshSuggestionFocusIndexNotifier;
  final VoidCallback giveTextFieldFocus;
  final VoidCallback onSuggestionFocus;
  final KeyEventResult Function(FocusNode _, KeyEvent event) onKeyEvent;
  final bool hideKeyboardOnDrag;
  final bool displayAllSuggestionWhenTap;
  final PaginatedSuggestionsCallback<SuggestionsModel>?
      paginatedSuggestionsCallback;
  final bool isMultiSelectDropdown;
  final List<SuggestionsModel>? initiallySelectedItems;
  final SuggestionsBoxController? suggestionsBoxController;
  final Widget? textFieldWidget;

  const SuggestionsList({
    super.key,
    required this.suggestionsBox,
    this.controller,
    this.intercepting = false,
    this.getImmediateSuggestions = false,
    this.onSuggestionSelected,
    this.onSuggestionMultiSelected,
    this.suggestionsCallback,
    this.itemBuilder,
    this.itemSeparatorBuilder,
    this.layoutArchitecture,
    this.scrollController,
    this.decoration,
    this.debounceDuration,
    this.loadingBuilder,
    this.noItemsFoundBuilder,
    this.errorBuilder,
    this.transitionBuilder,
    this.animationDuration,
    this.animationStart,
    this.direction,
    this.hideOnLoading,
    this.hideOnEmpty,
    this.hideOnError,
    this.keepSuggestionsOnLoading,
    this.minCharsForSuggestions,
    required this.keyboardSuggestionSelectionNotifier,
    required this.shouldRefreshSuggestionFocusIndexNotifier,
    required this.giveTextFieldFocus,
    required this.onSuggestionFocus,
    required this.onKeyEvent,
    required this.hideKeyboardOnDrag,
    required this.displayAllSuggestionWhenTap,
    this.paginatedSuggestionsCallback,
    required this.isMultiSelectDropdown,
    this.initiallySelectedItems,
    required this.suggestionsBoxController,
    this.textFieldWidget,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SuggestionsListState<SuggestionsModel> createState() =>
      _SuggestionsListState<SuggestionsModel>();
}

class _SuggestionsListState<SuggestionsModel>
    extends State<SuggestionsList<SuggestionsModel>>
    with SingleTickerProviderStateMixin {
  Iterable<SuggestionsModel>? _suggestions;
  late bool _suggestionsValid;
  late VoidCallback _controllerListener;
  Timer? _debounceTimer;
  bool? _isLoading, _isQueued;
  bool _paginationLoading = false;
  Object? _error;
  AnimationController? _animationController;
  String? _lastTextValue;
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();
  List<FocusNode> _focusNodes = [];
  int _suggestionIndex = -1;
  int pageNumber = 0;
  final multiSelectSearchFieldFocus = FocusNode();

  _SuggestionsListState() {
    this._controllerListener = () {
      // If we came here because of a change in selected text, not because of
      // actual change in text
      if (widget.controller!.text == this._lastTextValue) return;

      this._lastTextValue = widget.controller!.text;

      this._debounceTimer?.cancel();
      if (widget.controller!.text.length < widget.minCharsForSuggestions!) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _suggestions = null;
            _suggestionsValid = true;
          });
        }
        return;
      } else {
        this._debounceTimer = Timer(widget.debounceDuration!, () async {
          if (this._debounceTimer!.isActive) return;
          if (_isLoading!) {
            _isQueued = true;
            return;
          }

          await this.invalidateSuggestions();
          while (_isQueued!) {
            _isQueued = false;
            await this.invalidateSuggestions();
          }
        });
      }
    };
  }

  @override
  void didUpdateWidget(SuggestionsList<SuggestionsModel> oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller!.addListener(this._controllerListener);
    _getSuggestions(widget.controller!.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sending empty text when it's true so, that they can see whole list
    _getSuggestions(
        widget.displayAllSuggestionWhenTap ? '' : widget.controller!.text);
  }

  @override
  void initState() {
    super.initState();

    this._animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    this._suggestionsValid = widget.minCharsForSuggestions! > 0 ? true : false;
    this._isLoading = false;
    this._isQueued = false;
    this._lastTextValue = widget.controller!.text;

    if (widget.getImmediateSuggestions) {
      this._getSuggestions(widget.controller!.text);
    }

    widget.controller!.addListener(this._controllerListener);

    widget.keyboardSuggestionSelectionNotifier.addListener(() {
      final suggestionsLength = _suggestions?.length;
      final event = widget.keyboardSuggestionSelectionNotifier.value;
      if (event == null || suggestionsLength == null) return;

      if (event == LogicalKeyboardKey.arrowDown &&
          _suggestionIndex < suggestionsLength - 1) {
        _suggestionIndex++;
      } else if (event == LogicalKeyboardKey.arrowUp && _suggestionIndex > -1) {
        _suggestionIndex--;
      }

      if (_suggestionIndex > -1 && _suggestionIndex < _focusNodes.length) {
        final focusNode = _focusNodes[_suggestionIndex];
        focusNode.requestFocus();
        widget.onSuggestionFocus();
      } else {
        widget.giveTextFieldFocus();
      }
    });

    widget.shouldRefreshSuggestionFocusIndexNotifier.addListener(() {
      if (_suggestionIndex != -1) {
        _suggestionIndex = -1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.paginatedSuggestionsCallback != null) {
        _scrollController.addListener(() async {
          if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent) {
            if (_isLoading ?? false) return;
            _isLoading = true;
            setState(() {
              _paginationLoading = true;
            });
            final olderLength = this._suggestions?.length;
            pageNumber += 1;
            await invalidateSuggestions();
            if (olderLength == this._suggestions?.length) {
              pageNumber -= 1;
            }
            if (mounted) {
              setState(() {
                _paginationLoading = false;
              });
            }
          }
        });
      }
    });
  }

  Future<void> invalidateSuggestions() async {
    _suggestionsValid = false;
    await _getSuggestions(widget.controller!.text);
  }

  Future<void> _getSuggestions(String suggestion) async {
    if (_suggestionsValid) return;
    _suggestionsValid = true;

    if (mounted) {
      setState(() {
        this._animationController!.forward(from: 1.0);

        this._isLoading = true;
        this._error = null;
      });

      Iterable<SuggestionsModel>? suggestions;
      Object? error;

      try {
        if (widget.paginatedSuggestionsCallback != null) {
          suggestions = await widget.paginatedSuggestionsCallback!(suggestion);
        } else {
          suggestions = await widget.suggestionsCallback!(suggestion);
        }
      } catch (e) {
        error = e;
      }

      if (mounted) {
        // if it wasn't removed in the meantime
        setState(() {
          double? animationStart = widget.animationStart;
          // allow suggestionsCallback to return null and not throw error here
          if (error != null || suggestions?.isEmpty == true) {
            animationStart = 1.0;
          }
          this._animationController!.forward(from: animationStart);

          this._error = error;
          this._isLoading = false;
          this._suggestions = suggestions;
          _focusNodes = List.generate(
            _suggestions?.length ?? 0,
            (index) => FocusNode(onKeyEvent: (focusNode, event) {
              return widget.onKeyEvent(focusNode, event);
            }),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController!.dispose();
    _debounceTimer?.cancel();
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEmpty =
        (this._suggestions?.isEmpty ?? true) && widget.controller!.text == "";
    if ((this._suggestions == null || isEmpty) &&
        this._isLoading == false &&
        this._error == null) {
      return Container();
    }

    Widget child;
    if (this._isLoading!) {
      if (widget.hideOnLoading!) {
        child = Container(height: 0);
      } else {
        child = createLoadingWidget();
      }
    } else if (this._error != null) {
      if (widget.hideOnError!) {
        child = Container(height: 0);
      } else {
        child = createErrorWidget();
      }
    } else if (this._suggestions!.isEmpty) {
      if (widget.hideOnEmpty!) {
        child = Container(height: 0);
      } else {
        child = createNoItemsFoundWidget();
      }
    } else {
      child = createSuggestionsWidget();
    }

    if (widget.isMultiSelectDropdown) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: widget.textFieldWidget,
          ),
          Flexible(child: child),
        ],
      );
    }

    final animationChild = widget.transitionBuilder != null
        ? widget.transitionBuilder!(context, child, this._animationController)
        : SizeTransition(
            axisAlignment: -1.0,
            sizeFactor: CurvedAnimation(
                parent: this._animationController!,
                curve: Curves.fastOutSlowIn),
            child: child,
          );

    BoxConstraints constraints;
    if (widget.decoration!.constraints == null) {
      constraints = BoxConstraints(
        maxHeight: widget.suggestionsBox!.maxHeight,
      );
    } else {
      double maxHeight = min(widget.decoration!.constraints!.maxHeight,
          widget.suggestionsBox!.maxHeight);
      constraints = widget.decoration!.constraints!.copyWith(
        minHeight: min(widget.decoration!.constraints!.minHeight, maxHeight),
        maxHeight: maxHeight,
      );
    }

    var container = PointerInterceptor(
        intercepting: widget.intercepting,
        child: Material(
          elevation: widget.decoration!.elevation,
          color: widget.decoration!.color,
          shape: widget.decoration!.shape,
          borderRadius: widget.decoration!.borderRadius,
          shadowColor: widget.decoration!.shadowColor,
          clipBehavior: widget.decoration!.clipBehavior,
          child: ConstrainedBox(
            constraints: constraints,
            child: animationChild,
          ),
        ));

    return container;
  }

  Widget createLoadingWidget() {
    Widget child;

    if (widget.keepSuggestionsOnLoading! && this._suggestions != null) {
      if (this._suggestions!.isEmpty) {
        child = createNoItemsFoundWidget();
      } else {
        child = createSuggestionsWidget();
      }
    } else {
      child = widget.loadingBuilder != null
          ? widget.loadingBuilder!(context)
          : const Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            );
    }

    return child;
  }

  Widget createErrorWidget() {
    return widget.errorBuilder != null
        ? widget.errorBuilder!(context, this._error)
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Error: ${this._error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
  }

  Widget createNoItemsFoundWidget() {
    return widget.noItemsFoundBuilder != null
        ? widget.noItemsFoundBuilder!(context)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No Items Found!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).disabledColor, fontSize: 18.0),
            ),
          );
  }

  Widget createSuggestionsWidget() {
    if (widget.layoutArchitecture == null) {
      return defaultSuggestionsWidget();
    } else {
      return customSuggestionsWidget();
    }
  }

  Widget defaultSuggestionsWidget() {
    Widget child = Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.zero,
          primary: false,
          shrinkWrap: true,
          keyboardDismissBehavior: widget.hideKeyboardOnDrag
              ? ScrollViewKeyboardDismissBehavior.onDrag
              : ScrollViewKeyboardDismissBehavior.manual,
          controller: _scrollController,
          reverse: widget.suggestionsBox!.direction == AxisDirection.down
              ? false
              : widget.suggestionsBox!.autoFlipListDirection,
          itemCount: this._suggestions!.length,
          itemBuilder: (BuildContext context, int index) {
            final suggestion = this._suggestions!.elementAt(index);
            final focusNode = _focusNodes[index];
            return TextFieldTapRegion(
              child: widget.isMultiSelectDropdown
                  ? StatefulBuilder(
                      builder: (context, setState) {
                        final isSelected = widget.initiallySelectedItems
                                ?.contains(suggestion) ??
                            false;
                        return CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: widget.itemBuilder!(context, suggestion),
                          value: isSelected,
                          onChanged: (bool? checked) {
                            // widget.controller?.text = widget.initiallySelectedItems
                            //         ?.map((e) => e.toString())
                            //         .join(', ') ??
                            //     '';
                            widget.onSuggestionMultiSelected!(
                                suggestion, checked ?? false);
                            setState(() {});
                          },
                        );
                      },
                    )
                  : InkWell(
                      focusColor: Theme.of(context).hoverColor,
                      focusNode: focusNode,
                      child: widget.itemBuilder!(context, suggestion),
                      onTap: () {
                        // * we give the focus back to the text field
                        widget.giveTextFieldFocus();

                        widget.onSuggestionSelected!(suggestion);
                      },
                    ),
            );
          },
          separatorBuilder: (BuildContext context, int index) =>
              widget.itemSeparatorBuilder?.call(context, index) ??
              const SizedBox.shrink(),
        ),
        if (_paginationLoading)
          const Align(
            alignment: Alignment.bottomCenter,
            child: CircularProgressIndicator(),
          ),
      ],
    );

    if (widget.decoration!.hasScrollbar) {
      child = MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Theme(
          data: ThemeData(
            scrollbarTheme: getScrollbarTheme(),
          ),
          child: Scrollbar(
            controller: _scrollController,
            child: child,
          ),
        ),
      );
    }

    child = TextFieldTapRegion(child: child);

    return child;
  }

  Widget customSuggestionsWidget() {
    Widget child = widget.layoutArchitecture!(
      List.generate(this._suggestions!.length, (index) {
        final suggestion = _suggestions!.elementAt(index);
        final focusNode = _focusNodes[index];

        return TextFieldTapRegion(
          child: widget.isMultiSelectDropdown
              ? StatefulBuilder(
                  builder: (context, setState) {
                    final isSelected = widget.controller?.text
                            .contains(suggestion.toString()) ??
                        false;
                    return CheckboxListTile(
                      title: widget.itemBuilder!(context, suggestion),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        // widget.controller?.text = widget.initiallySelectedItems
                        //         ?.map((e) => e.toString())
                        //         .join(', ') ??
                        //     '';
                        widget.onSuggestionMultiSelected!(
                            suggestion, checked ?? false);
                        setState(() {});
                      },
                    );
                  },
                )
              : InkWell(
                  focusColor: Theme.of(context).hoverColor,
                  focusNode: focusNode,
                  child: widget.itemBuilder!(context, suggestion),
                  onTap: () {
                    // * we give the focus back to the text field
                    widget.giveTextFieldFocus();

                    widget.onSuggestionSelected!(suggestion);
                  },
                ),
        );
      }),
      _scrollController,
    );

    if (widget.decoration!.hasScrollbar) {
      child = Theme(
        data: ThemeData(
          scrollbarTheme: getScrollbarTheme(),
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Scrollbar(
            controller: _scrollController,
            child: child,
          ),
        ),
      );
    }

    child = Stack(
      children: [
        child,
        if (_paginationLoading)
          const Align(
            alignment: Alignment.bottomCenter,
            child: CircularProgressIndicator(),
          ),
      ],
    );

    child = TextFieldTapRegion(child: child);

    return child;
  }

  ScrollbarThemeData? getScrollbarTheme() {
    return const ScrollbarThemeData().copyWith(
      thickness: WidgetStatePropertyAll(
          widget.decoration?.scrollBarDecoration?.thickness),
      thumbColor: WidgetStatePropertyAll(
          widget.decoration?.scrollBarDecoration?.thumbColor),
      radius: widget.decoration?.scrollBarDecoration?.radius,
      thumbVisibility: WidgetStatePropertyAll(
          widget.decoration?.scrollBarDecoration?.thumbVisibility),
      crossAxisMargin: widget.decoration?.scrollBarDecoration?.crossAxisMargin,
      mainAxisMargin: widget.decoration?.scrollBarDecoration?.mainAxisMargin,
      interactive: widget.decoration?.scrollBarDecoration?.interactive,
    );
  }
}
