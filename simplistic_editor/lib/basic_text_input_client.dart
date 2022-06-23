import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'replacements.dart';
import 'text_editing_delta_history_manager.dart';
import 'toggle_buttons_state_manager.dart';

/// A basic text input client. An extension of [EditableText] meant to
/// send/receive information from the framework to the platform's text input plugin
/// and vice-versa by implementing [DeltaTextInputClient].
class BasicTextInputClient extends EditableText {
  BasicTextInputClient({
    super.key,
    required super.controller,
    required super.focusNode,
    required super.style,
    required super.cursorColor,
    required super.backgroundCursorColor,
    required super.selectionColor,
    required super.onSelectionChanged,
    required super.showSelectionHandles,
    super.maxLines = null,
  });

  @override
  BasicTextInputClientState createState() => BasicTextInputClientState();
}

class BasicTextInputClientState extends EditableTextState implements DeltaTextInputClient {
  late final ToggleButtonsStateManager toggleButtonStateManager;
  late final TextEditingDeltaHistoryManager textEditingDeltaHistoryManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    toggleButtonStateManager = ToggleButtonsStateManager.of(context);
    textEditingDeltaHistoryManager = TextEditingDeltaHistoryManager.of(context);
  }

  @override
  TextInputConfiguration get textInputConfiguration => super.textInputConfiguration.copyWith(enableDeltaModel: true);

  TextEditingValue get _value => widget.controller.value;
  set _value(TextEditingValue value) {
    widget.controller.value = value;
  }

  /// The last known [TextEditingValue] of the platform text input plugin.
  ///
  /// This value is updated when the platform text input plugin sends a new
  /// update via [updateEditingValue], or when [EditableText] calls
  /// [TextInputConnection.setEditingState] to overwrite the platform text input
  /// plugin's [TextEditingValue].
  ///
  /// Used in [_updateRemoteEditingValueIfNeeded] to determine whether the
  /// remote value is outdated and needs updating.
  TextEditingValue? _lastKnownRemoteTextEditingValue;

  @override
  void userUpdateTextEditingValueWithDeltas(List<TextEditingDelta> deltas, SelectionChangedCause? cause) {
    TextEditingValue value = _value;

    for (final TextEditingDelta textEditingDelta in deltas) {
      value = textEditingDelta.apply(value);

      if (widget.controller is ReplacementTextEditingController) {
        (widget.controller as ReplacementTextEditingController)
            .syncReplacementRanges(textEditingDelta);
      }
    }

    if (value != _value) {
      textEditingDeltaHistoryManager
          .updateTextEditingDeltaHistoryOnInput(deltas);
    }

    userUpdateTextEditingValue(value, cause);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    TextEditingValue value = _value;

    for (final TextEditingDelta delta in textEditingDeltas) {
      value = delta.apply(value);
    }

    _lastKnownRemoteTextEditingValue = value;

    if (value == _value) {
      // This is possible, for example, when the numeric keyboard is input,
      // the engine will notify twice for the same value.
      // Track at https://github.com/flutter/flutter/issues/65811
      return;
    }

    final bool selectionChanged =
        _value.selection.start != value.selection.start ||
            _value.selection.end != value.selection.end;
    textEditingDeltaHistoryManager
        .updateTextEditingDeltaHistoryOnInput(textEditingDeltas);

    _value = value;

    if (widget.controller is ReplacementTextEditingController) {
      for (final TextEditingDelta delta in textEditingDeltas) {
        (widget.controller as ReplacementTextEditingController)
            .syncReplacementRanges(delta);
      }
    }

    if (selectionChanged) {
      toggleButtonStateManager.updateToggleButtonsOnSelection(value.selection);
    }
  }
}