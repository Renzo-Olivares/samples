import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_editing_delta_history_manager.dart';

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
  late final TextEditingDeltaHistoryManager textEditingDeltaHistoryManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    textEditingDeltaHistoryManager = TextEditingDeltaHistoryManager.of(context);
  }

  @override
  TextInputConfiguration get textInputConfiguration => super.textInputConfiguration.copyWith(enableDeltaModel: true);

  TextEditingValue get _value => widget.controller.value;

  @override
  void userUpdateTextEditingValueWithDeltas(List<TextEditingDelta> deltas, SelectionChangedCause? cause) {
    TextEditingValue value = _value;

    for (final TextEditingDelta textEditingDelta in deltas) {
      value = textEditingDelta.apply(value);
    }

    if (value != _value) {
      textEditingDeltaHistoryManager
          .updateTextEditingDeltaHistoryOnInput(deltas);
    }

    super.userUpdateTextEditingValueWithDeltas(deltas, cause);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    TextEditingValue value = _value;

    for (final TextEditingDelta delta in textEditingDeltas) {
      value = delta.apply(value);
    }

    if (value == _value) {
      return;
    }
    
    updateEditingValue(value);

    textEditingDeltaHistoryManager
        .updateTextEditingDeltaHistoryOnInput(textEditingDeltas);
  }
}