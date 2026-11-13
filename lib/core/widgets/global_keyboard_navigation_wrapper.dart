import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent triggered when Enter is pressed inside an input field or form.
class SubmitOrNextFieldIntent extends Intent {
  const SubmitOrNextFieldIntent();
}

/// Global intent for scrolling up via Arrow Up / Page Up.
class GlobalScrollIntent extends Intent {
  final double direction; // -1 for up, 1 for down
  const GlobalScrollIntent(this.direction);
}

/// Global keyboard navigation & auto-submit wrapper.
/// - Allows Enter button to navigate to next field or trigger submit button.
/// - Allows Up/Down arrow keys to move focus between actionable widgets (fields/buttons/items)
///   or scroll when outside text input fields.
class GlobalKeyboardNavigationWrapper extends StatefulWidget {
  final Widget child;

  const GlobalKeyboardNavigationWrapper({
    super.key,
    required this.child,
  });

  @override
  State<GlobalKeyboardNavigationWrapper> createState() =>
      _GlobalKeyboardNavigationWrapperState();
}

class _GlobalKeyboardNavigationWrapperState
    extends State<GlobalKeyboardNavigationWrapper> {
  double _zoomScale = 1.0;
  double _baseScale = 1.0;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Check if Ctrl or Meta is held during wheel scroll
      final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrCmd) {
        setState(() {
          // Negative delta = scroll up = zoom in
          // Positive delta = scroll down = zoom out
          if (event.scrollDelta.dy < 0) {
            _zoomScale = (_zoomScale + 0.08).clamp(0.6, 3.0);
          } else if (event.scrollDelta.dy > 0) {
            _zoomScale = (_zoomScale - 0.08).clamp(0.6, 3.0);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitOrNextFieldIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitOrNextFieldIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const GlobalScrollIntent(1.0),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const GlobalScrollIntent(-1.0),
        LogicalKeySet(LogicalKeyboardKey.pageDown): const GlobalScrollIntent(3.0),
        LogicalKeySet(LogicalKeyboardKey.pageUp): const GlobalScrollIntent(-3.0),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SubmitOrNextFieldIntent: CallbackAction<SubmitOrNextFieldIntent>(
            onInvoke: (intent) => _handleSubmitOrNext(FocusManager.instance.primaryFocus),
          ),
          GlobalScrollIntent: CallbackAction<GlobalScrollIntent>(
            onInvoke: (intent) => _handleArrowScroll(intent, FocusManager.instance.primaryFocus),
          ),
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              onScaleStart: (details) {
                if (details.pointerCount >= 2) {
                  _baseScale = _zoomScale;
                }
              },
              onScaleUpdate: (details) {
                if (details.pointerCount >= 2) {
                  setState(() {
                    _zoomScale = (_baseScale * details.scale).clamp(0.6, 3.0);
                  });
                }
              },
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(_zoomScale),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles Enter key:
  /// - If inside a multiline textfield, lets default newline happen.
  /// - If inside an editable text field, attempts to find the primary Submit/Save button in the form
  ///   or moves focus to the next field if not the last one. If on the last field, executes the primary action / submits.
  void _handleSubmitOrNext(FocusNode? currentFocus) {
    if (currentFocus == null) return;

    final context = currentFocus.context;
    if (context == null) return;

    // If focused on an editable text input
    final editableTextState = context.findAncestorStateOfType<EditableTextState>();
    if (editableTextState != null) {
      // If the field is explicitly multiline (e.g., textarea / notes), allow normal Enter newline
      if (editableTextState.widget.maxLines != null && editableTextState.widget.maxLines! > 1) {
        return;
      }

      // Try moving focus forward to the next input or button
      final didMove = currentFocus.nextFocus();

      // If next focus lands on a button or could not advance (last field), try triggering form submission
      final newFocus = FocusManager.instance.primaryFocus;
      final newContext = newFocus?.context;

      // If it couldn't advance or advanced to a Save/Submit/Done button or same focus
      if (!didMove || newFocus == currentFocus || (newContext != null && _isSubmitButton(newContext))) {
        _triggerPrimaryAction(context);
      }
      return;
    }

    // If focused on a button or selectable item, simulate click
    if (_isClickable(context)) {
      _simulateTap(context);
    }
  }

  /// Handles Arrow Up / Down keys:
  /// - When inside a single-line or multi-line text field, lets default text cursor navigation happen.
  /// - When outside text editing, moves focus or scrolls active scrollable view up/down.
  void _handleArrowScroll(GlobalScrollIntent intent, FocusNode? currentFocus) {
    final context = currentFocus?.context;

    // If actively typing in a text field, preserve standard cursor movement
    if (context != null) {
      final editable = context.findAncestorStateOfType<EditableTextState>();
      if (editable != null) {
        // Allow text field cursor up/down
        return;
      }
    }

    // Outside text field:
    // First, try moving focus to previous/next interactive element in list/form
    if (currentFocus != null && currentFocus.hasFocus) {
      if (intent.direction > 0) {
        currentFocus.focusInDirection(TraversalDirection.down) || currentFocus.nextFocus();
      } else {
        currentFocus.focusInDirection(TraversalDirection.up) || currentFocus.previousFocus();
      }
    }

    // Also smoothly scroll any active Scrollable in context
    if (context != null) {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null && scrollable.position.hasPixels) {
        final double scrollAmount = 120.0 * intent.direction;
        final targetOffset = (scrollable.position.pixels + scrollAmount)
            .clamp(scrollable.position.minScrollExtent, scrollable.position.maxScrollExtent);
        scrollable.position.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  bool _isSubmitButton(BuildContext context) {
    final widget = context.widget;
    final widgetStr = widget.toString().toLowerCase();
    return widgetStr.contains('save') ||
        widgetStr.contains('submit') ||
        widgetStr.contains('done') ||
        widgetStr.contains('custombutton') ||
        widgetStr.contains('elevatedbutton') ||
        widgetStr.contains('filledbutton');
  }

  bool _isClickable(BuildContext context) {
    return context.widget is InkWell ||
        context.widget is GestureDetector ||
        context.widget is ElevatedButton ||
        context.widget is FilledButton ||
        context.widget is OutlinedButton ||
        context.widget is TextButton ||
        context.widget is IconButton;
  }

  void _simulateTap(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final center = renderObject.localToGlobal(renderObject.size.center(Offset.zero));
      GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: center));
      Future.delayed(const Duration(milliseconds: 50), () {
        GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: center));
      });
    }
  }

  void _triggerPrimaryAction(BuildContext context) {
    // Find the enclosing Form or Scaffold and locate an action button (Save/Submit)
    void searchAndClick(Element element) {
      final widget = element.widget;
      bool found = false;

      if (widget is ElevatedButton) {
        widget.onPressed?.call();
        found = true;
      } else if (widget is FilledButton) {
        widget.onPressed?.call();
        found = true;
      }

      if (!found) {
        element.visitChildren(searchAndClick);
      }
    }

    // Try finding the closest Form or Scaffold state
    final formState = context.findAncestorStateOfType<FormState>();
    if (formState != null && formState.context is Element) {
      // Validate form first
      if (formState.validate()) {
        (formState.context as Element).visitChildren(searchAndClick);
      }
      return;
    }

    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.context is Element) {
      (scaffold.context as Element).visitChildren(searchAndClick);
    }
  }
}

