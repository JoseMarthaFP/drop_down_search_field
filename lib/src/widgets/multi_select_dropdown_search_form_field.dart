import 'package:drop_down_search_field/drop_down_search_field.dart';
import 'package:flutter/material.dart';

class MultiSelectDropdownSearchFormField<T> extends FormField<List<T>> {
  final TextFieldConfiguration textFieldConfiguration;
  final void Function()? onReset;
  final List<SuggestionsModel> initiallySelectedItems;
  final SuggestionMultiSelectionCallback<SuggestionsModel>
      onMultiSuggestionSelected;
  final DropdownBoxConfiguration? dropdownBoxConfiguration;
  final ChipBuilder<SuggestionsModel>? chipBuilder;

  MultiSelectDropdownSearchFormField({
    super.key,
    List<T>? initialValue,
    bool getImmediateSuggestions = false,
    @Deprecated('Use autovalidateMode parameter which provides more specific '
        'behavior related to auto validation. '
        'This feature was deprecated after Flutter v1.19.0.')
    bool autovalidate = false,
    super.enabled,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
    super.onSaved,
    this.onReset,
    required this.initiallySelectedItems,
    required this.onMultiSuggestionSelected,
    this.dropdownBoxConfiguration,
    required this.chipBuilder,
    // super.validator,
    ErrorBuilder? errorBuilder,
    WidgetBuilder? noItemsFoundBuilder,
    WidgetBuilder? loadingBuilder,
    void Function(bool)? onSuggestionsBoxToggle,
    Duration debounceDuration = const Duration(milliseconds: 300),
    SuggestionsBoxDecoration suggestionsBoxDecoration =
        const SuggestionsBoxDecoration(),
    SuggestionsBoxController? suggestionsBoxController,
    required ItemBuilder<SuggestionsModel> itemBuilder,
    IndexedWidgetBuilder? itemSeparatorBuilder,
    LayoutArchitecture? layoutArchitecture,
    SuggestionsCallback<SuggestionsModel>? suggestionsCallback,
    PaginatedSuggestionsCallback<SuggestionsModel>?
        paginatedSuggestionsCallback,
    double suggestionsBoxVerticalOffset = 5.0,
    this.textFieldConfiguration = const TextFieldConfiguration(),
    AnimationTransitionBuilder? transitionBuilder,
    Duration animationDuration = const Duration(milliseconds: 500),
    double animationStart = 0.25,
    AxisDirection direction = AxisDirection.down,
    bool hideOnLoading = false,
    bool hideOnEmpty = false,
    bool hideOnError = false,
    bool hideSuggestionsOnKeyboardHide = true,
    bool intercepting = false,
    bool keepSuggestionsOnLoading = true,
    bool keepSuggestionsOnSuggestionSelected = false,
    bool autoFlipDirection = false,
    bool autoFlipListDirection = true,
    double autoFlipMinHeight = 64.0,
    bool hideKeyboard = false,
    int minCharsForSuggestions = 0,
    bool hideKeyboardOnDrag = false,
    bool displayAllSuggestionWhenTap = false,
    final ScrollController? scrollController,
  })  : assert(
            initialValue == null || textFieldConfiguration.controller == null,
            'Either initialValue or textFieldConfiguration.controller should be null, not both.'),
        assert(minCharsForSuggestions >= 0,
            'minCharsForSuggestions must be non-negative.'),
        super(
            initialValue: initialValue ?? [],
            builder: (FormFieldState<List<T>> field) {
              final MultiSelectDropdownSearchFormFieldState<T> state =
                  field as MultiSelectDropdownSearchFormFieldState<T>;

              return DropDownSearchField(
                getImmediateSuggestions: getImmediateSuggestions,
                transitionBuilder: transitionBuilder,
                errorBuilder: errorBuilder,
                noItemsFoundBuilder: noItemsFoundBuilder,
                loadingBuilder: loadingBuilder,
                debounceDuration: debounceDuration,
                suggestionsBoxDecoration: suggestionsBoxDecoration,
                suggestionsBoxController: suggestionsBoxController,
                textFieldConfiguration: textFieldConfiguration.copyWith(
                  decoration: textFieldConfiguration.decoration
                      .copyWith(errorText: state.errorText),
                  onChanged: (text) {
                    state.didChange(state.value);
                    textFieldConfiguration.onChanged?.call(text);
                  },
                  controller: state._effectiveController,
                ),
                suggestionsBoxVerticalOffset: suggestionsBoxVerticalOffset,
                initiallySelectedItems: initiallySelectedItems,
                onSuggestionMultiSelected: (suggestion, selected) {
                  state._handleSelection(suggestion);
                  onMultiSuggestionSelected(suggestion, selected);
                },
                onSuggestionsBoxToggle: onSuggestionsBoxToggle,
                itemBuilder: itemBuilder,
                itemSeparatorBuilder: itemSeparatorBuilder,
                layoutArchitecture: layoutArchitecture,
                suggestionsCallback: suggestionsCallback,
                paginatedSuggestionsCallback: paginatedSuggestionsCallback,
                animationStart: animationStart,
                animationDuration: animationDuration,
                direction: direction,
                hideOnLoading: hideOnLoading,
                hideOnEmpty: hideOnEmpty,
                hideOnError: hideOnError,
                hideSuggestionsOnKeyboardHide: hideSuggestionsOnKeyboardHide,
                keepSuggestionsOnLoading: keepSuggestionsOnLoading,
                keepSuggestionsOnSuggestionSelected:
                    keepSuggestionsOnSuggestionSelected,
                intercepting: intercepting,
                autoFlipDirection: autoFlipDirection,
                autoFlipListDirection: autoFlipListDirection,
                autoFlipMinHeight: autoFlipMinHeight,
                hideKeyboard: hideKeyboard,
                minCharsForSuggestions: minCharsForSuggestions,
                hideKeyboardOnDrag: hideKeyboardOnDrag,
                displayAllSuggestionWhenTap: displayAllSuggestionWhenTap,
                scrollController: scrollController,
                isMultiSelectDropdown: true,
                multiSelectDropdownBoxConfiguration: dropdownBoxConfiguration,
                chipBuilder: chipBuilder,
                // validator: validator,
              );
            });

  @override
  MultiSelectDropdownSearchFormFieldState<T> createState() =>
      MultiSelectDropdownSearchFormFieldState<T>();
}

class MultiSelectDropdownSearchFormFieldState<T>
    extends FormFieldState<List<T>> {
  TextEditingController? _controller;

  TextEditingController? get _effectiveController =>
      widget.textFieldConfiguration.controller ?? _controller;

  @override
  MultiSelectDropdownSearchFormField<T> get widget =>
      super.widget as MultiSelectDropdownSearchFormField<T>;

  @override
  void initState() {
    super.initState();
    if (widget.textFieldConfiguration.controller == null) {
      _controller = TextEditingController();
    } else {
      widget.textFieldConfiguration.controller!
          .addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(MultiSelectDropdownSearchFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textFieldConfiguration.controller !=
        oldWidget.textFieldConfiguration.controller) {
      oldWidget.textFieldConfiguration.controller
          ?.removeListener(_handleControllerChanged);
      widget.textFieldConfiguration.controller
          ?.addListener(_handleControllerChanged);

      if (oldWidget.textFieldConfiguration.controller != null &&
          widget.textFieldConfiguration.controller == null) {
        _controller = TextEditingController.fromValue(
            oldWidget.textFieldConfiguration.controller!.value);
      }
      if (widget.textFieldConfiguration.controller != null) {
        setValue([widget.textFieldConfiguration.controller!.text as T]);
        if (oldWidget.textFieldConfiguration.controller == null) {
          _controller = null;
        }
      }
    }
  }

  @override
  void dispose() {
    widget.textFieldConfiguration.controller
        ?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    setState(() {
      _effectiveController!.text = '';
      if (widget.onReset != null) {
        widget.onReset!();
      }
    });
  }

  void _handleControllerChanged() {
    // ignore: unrelated_type_equality_checks
    if (_effectiveController!.text != value) {
      didChange([_effectiveController!.text as T]);
    }
  }

  void _handleSelection(SuggestionsModel suggestion) {
    setState(() {
      if (value!.contains(suggestion)) {
        value!.remove(suggestion);
      } else {
        value!.add(suggestion.data);
      }
    });
    didChange(value);
  }
}
