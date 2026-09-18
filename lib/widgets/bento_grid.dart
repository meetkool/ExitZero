import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

/// Describes one item in the [BentoGrid].
class BentoGridItem {
  final String id;
  final int columnSpan;
  final int minSpan;
  final int maxSpan;
  final double height;
  final double minHeight;
  final double maxHeight;
  final bool resizable;
  final Widget card;

  const BentoGridItem({
    required this.id,
    this.columnSpan = 1,
    this.minSpan = 1,
    this.maxSpan = 2,
    this.height = 150,
    this.minHeight = 80,
    this.maxHeight = 300,
    this.resizable = true,
    required this.card,
  }) : assert(minSpan >= 1),
       assert(maxSpan <= 2),
       assert(minSpan <= maxSpan);
}

/// Serializable layout state for persistence.
class BentoGridLayoutItem {
  final String id;
  final int columnSpan;
  final double height;

  const BentoGridLayoutItem({
    required this.id,
    required this.columnSpan,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'span': columnSpan,
    'height': height,
  };

  factory BentoGridLayoutItem.fromJson(Map<String, dynamic> json) {
    return BentoGridLayoutItem(
      id: json['id'] as String,
      columnSpan: (json['span'] as num).toInt(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

// ─── Internal types ──────────────────────────────────────────────────────────

class _Item {
  final String id;
  double height;
  int columnSpan;
  final int minSpan;
  final int maxSpan;
  final double minHeight;
  final double maxHeight;
  final bool resizable;
  final Widget card;

  _Item.from(BentoGridItem i)
    : id = i.id,
      height = i.height,
      columnSpan = i.columnSpan.clamp(i.minSpan, i.maxSpan).toInt(),
      minSpan = i.minSpan,
      maxSpan = i.maxSpan,
      minHeight = i.minHeight,
      maxHeight = i.maxHeight,
      resizable = i.resizable,
      card = i.card;
}

class _Rect {
  final double left, top, width, height;
  _Rect(this.left, this.top, this.width, this.height);
  Offset get center => Offset(left + width / 2, top + height / 2);
}

class _Layout {
  final List<_Rect> rects;
  final double totalHeight;
  _Layout(this.rects, this.totalHeight);
}

/// A pan recognizer that claims the gesture the instant a finger lands.
///
/// A plain [PanGestureRecognizer] only wins after ~36px of movement
/// (`kPanSlop`), while the enclosing scroll view's vertical drag recognizer
/// wins after ~18px (`kTouchSlop`). On a vertical swipe the scrollable
/// therefore always won and the card never lifted. Accepting up front removes
/// the race entirely, so a grip or resize handle responds immediately and the
/// page cannot steal the drag.
class _EagerPanRecognizer extends PanGestureRecognizer {
  _EagerPanRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

enum _ResizeHandle {
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// ─── Layout algorithm ────────────────────────────────────────────────────────

_Layout _computeLayout(List<_Item> items, double w, double gap) {
  final rects = <_Rect>[];
  final half = (w - gap) / 2;
  double y = 0;
  int i = 0;

  while (i < items.length) {
    if (items[i].columnSpan >= 2) {
      rects.add(_Rect(0, y, w, items[i].height));
      y += items[i].height + gap;
      i++;
    } else if (i + 1 < items.length && items[i + 1].columnSpan == 1) {
      final lh = items[i].height;
      final rh = items[i + 1].height;
      rects.add(_Rect(0, y, half, lh));
      rects.add(_Rect(half + gap, y, half, rh));
      y += max(lh, rh) + gap;
      i += 2;
    } else {
      rects.add(_Rect(0, y, half, items[i].height));
      y += items[i].height + gap;
      i++;
    }
  }

  return _Layout(rects, y > 0 ? y - gap : 0);
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class BentoGrid extends StatefulWidget {
  final List<BentoGridItem> items;
  final double spacing;
  final EdgeInsets padding;
  final ValueChanged<bool>? onEditModeChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final ValueChanged<List<BentoGridLayoutItem>>? onLayoutChanged;
  final VoidCallback? onResetRequested;
  final int layoutVersion;

  const BentoGrid({
    super.key,
    required this.items,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onEditModeChanged,
    this.onInteractionChanged,
    this.onLayoutChanged,
    this.onResetRequested,
    this.layoutVersion = 0,
  });

  @override
  State<BentoGrid> createState() => _BentoGridState();
}

class _BentoGridState extends State<BentoGrid> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late List<_Item> _items;
  bool _editMode = false;
  late AnimationController _jiggle;

  // Drag
  int? _dragIdx;
  Offset _dragDelta = Offset.zero;
  Offset _lastGlobal = Offset.zero;

  // Resize
  int? _resizeIdx;
  _ResizeHandle? _resizeHandle;
  _Rect? _resizeStartRect;
  double _resizeStartGY = 0;
  double _resizeStartGX = 0;
  int? _resizePendingSpan;
  _Rect? _resizePreview;

  // Interaction
  bool _interactionActive = false;

  /// Drives edge auto-scroll while a card is being dragged.
  Timer? _autoScroll;

  /// Measures where cards actually sit on screen, for scroll anchoring.
  final GlobalKey _stackKey = GlobalKey();

  // Cache
  double _gridW = 0;
  double _gap = 0;
  _Layout? _layout;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _syncItems();
    _jiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Slightly faster jiggle
      lowerBound: -1,
      upperBound: 1,
    );
  }

  @override
  void didUpdateWidget(BentoGrid old) {
    super.didUpdateWidget(old);
    if (widget.layoutVersion != old.layoutVersion) {
      _syncItems();
      return;
    }
    if (!_editMode && widget.items.length != _items.length) {
      _syncItems();
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _jiggle.dispose();
    super.dispose();
  }

  void _syncItems() {
    _items = widget.items.map(_Item.from).toList();
  }

  void _setInteractionActive(bool active) {
    if (_interactionActive == active) return;
    _interactionActive = active;
    widget.onInteractionChanged?.call(active);
  }

  void _emitLayout() {
    if (widget.onLayoutChanged == null) return;
    final layout = _items
        .map(
          (e) => BentoGridLayoutItem(
            id: e.id,
            columnSpan: e.columnSpan,
            height: e.height,
          ),
        )
        .toList(growable: false);
    widget.onLayoutChanged!(layout);
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  /// Where card [i] currently sits on screen, or null if we cannot measure.
  double? _cardGlobalTop(int i) {
    final box = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final layout = _layout;
    if (layout == null || i < 0 || i >= layout.rects.length) return null;
    return box.localToGlobal(Offset.zero).dy + layout.rects[i].top;
  }

  /// The card sitting nearest the top of the viewport.
  int? _topmostVisibleIndex() {
    final box = _stackKey.currentContext?.findRenderObject();
    final layout = _layout;
    if (box is! RenderBox || !box.hasSize || layout == null) return null;
    if (layout.rects.isEmpty) return null;

    final originY = box.localToGlobal(Offset.zero).dy;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    final viewTop = viewport is RenderBox
        ? viewport.localToGlobal(Offset.zero).dy
        : 0.0;

    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < layout.rects.length; i++) {
      final d = (originY + layout.rects[i].top - viewTop).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Keeps card [index] visually still across a layout change.
  ///
  /// Entering edit mode widens every gap and inserts the header, which pushes
  /// cards down by a growing amount — far enough that the card you just
  /// grabbed could slide off the bottom of the screen. Measure the card
  /// before the change, measure it again after the frame, and take the
  /// difference out of the scroll offset.
  void _anchorAround(int? index) {
    if (index == null) return;
    final before = _cardGlobalTop(index);
    if (before == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = _cardGlobalTop(index);
      final scrollable = Scrollable.maybeOf(context);
      if (after == null || scrollable == null) return;

      final delta = after - before;
      if (delta.abs() < 1) return;

      final pos = scrollable.position;
      final target = (pos.pixels + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() < 1) return;
      pos.jumpTo(target);
    });
  }

  void _enterEdit({int? anchorIndex}) {
    if (_editMode) return;
    _anchorAround(anchorIndex ?? _topmostVisibleIndex());
    HapticFeedback.mediumImpact(); // Distinct buzz when entering edit mode
    _jiggle.repeat(reverse: true);
    setState(() => _editMode = true);
    widget.onEditModeChanged?.call(true);
  }

  void _exitEdit() {
    if (!_editMode) return;
    _anchorAround(_topmostVisibleIndex());
    _stopAutoScroll();
    _jiggle
      ..stop()
      ..value = 0;
    setState(() {
      _editMode = false;
      _dragIdx = null;
      _resizeIdx = null;
      _resizeHandle = null;
      _resizeStartRect = null;
      _resizePendingSpan = null;
      _resizePreview = null;
    });
    _setInteractionActive(false);
    widget.onEditModeChanged?.call(false);
  }

  // ── Drag (pan gesture — only active in edit mode) ──────────────────────────

  void _startDrag(int i, Offset globalPosition) {
    // If we are already dragging something else, ignore new touches
    if (!_editMode || _dragIdx != null || _resizeIdx != null) return;

    // Strong vibration to indicate selection ("Zig")
    HapticFeedback.mediumImpact();

    _setInteractionActive(true);
    setState(() {
      _dragIdx = i;
      _dragDelta = Offset.zero;
      _lastGlobal = globalPosition;
    });
    _startAutoScroll();
  }

  void _dragStart(int i, DragStartDetails d) {
    _startDrag(i, d.globalPosition);
  }

  void _dragUpdate(DragUpdateDetails d) {
    _lastGlobal = d.globalPosition;
    _dragUpdateWithDelta(d.delta);
  }

  void _dragUpdateWithDelta(Offset delta) {
    if (_dragIdx == null || _layout == null) return;
    _dragDelta += delta;
    _maybeReorder();
    setState(() {});
  }

  /// How much closer a slot must be than the card's own before we commit to it.
  ///
  /// Comparing raw distances makes a card parked on a boundary flip back and
  /// forth every frame; requiring the target to be clearly nearer gives the
  /// move a dead zone and keeps it steady.
  static const double _reorderHysteresis = 0.65;

  /// Moves the dragged card to whichever slot its centre is now closest to.
  ///
  /// The previous version only ever compared against the immediate neighbours,
  /// so crossing several slots took one deliberate centre-crossing each.
  void _maybeReorder() {
    if (_dragIdx == null || _layout == null) return;
    final from = _dragIdx!;
    final myRect = _layout!.rects[from];
    final centre = Offset(
      myRect.center.dx + _dragDelta.dx,
      myRect.center.dy + _dragDelta.dy,
    );

    final double homeDist = (myRect.center - centre).distance;

    int best = from;
    double bestDist = double.infinity;
    for (int j = 0; j < _items.length; j++) {
      if (j == from) continue;
      final d = (_layout!.rects[j].center - centre).distance;
      if (d < bestDist) {
        bestDist = d;
        best = j;
      }
    }

    if (best == from) return;
    if (bestDist > homeDist * _reorderHysteresis) return;
    _moveTo(best);
  }

  void _moveTo(int target) {
    final from = _dragIdx!;
    final oldRect = _layout!.rects[from];

    // Lift the card out and drop it in at the target index, so the cards in
    // between shift along by one instead of teleporting past each other.
    final item = _items.removeAt(from);
    _items.insert(target, item);

    final nl = _computeLayout(_items, _gridW, _gap);
    final newRect = nl.rects[target];

    // Keep the card under the finger across the reflow.
    _dragDelta += Offset(
      oldRect.left - newRect.left,
      oldRect.top - newRect.top,
    );
    _dragIdx = target;
    _layout = nl;
    HapticFeedback.selectionClick();
    _emitLayout();
  }

  // ── Edge auto-scroll ───────────────────────────────────────────────────────

  void _startAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickAutoScroll(),
    );
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  /// Creeps the page while a dragged card is held near the top or bottom edge.
  ///
  /// Dragging locks the enclosing scroll view, so without this a card could
  /// never travel further than one screen.
  void _tickAutoScroll() {
    if (!mounted || _dragIdx == null) return;

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;

    const double zone = 100;
    const double maxSpeed = 14;

    double v = 0;
    if (_lastGlobal.dy < top + zone) {
      v = -maxSpeed * ((top + zone - _lastGlobal.dy) / zone).clamp(0.0, 1.0);
    } else if (_lastGlobal.dy > bottom - zone) {
      v = maxSpeed * ((_lastGlobal.dy - (bottom - zone)) / zone).clamp(0.0, 1.0);
    }
    if (v == 0) return;

    final pos = scrollable.position;
    final target = (pos.pixels + v).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    final applied = target - pos.pixels;
    if (applied.abs() < 0.01) return;

    pos.jumpTo(target);

    // The grid slid under a stationary finger, so shift the card by the same
    // amount to keep it pinned to the touch point.
    _dragDelta += Offset(0, applied);
    _maybeReorder();
    setState(() {});
  }

  void _dragEnd(DragEndDetails d) {
    _dragFinish();
  }

  void _dragFinish() {
    _stopAutoScroll();
    if (_dragIdx != null) {
      // Feedback on drop
      HapticFeedback.lightImpact();
    }
    _setInteractionActive(false);
    setState(() {
      _dragIdx = null;
      _dragDelta = Offset.zero;
    });
  }

  void _longPressStart(int i, LongPressStartDetails d) {
    _enterEdit(anchorIndex: i);
    _startDrag(i, d.globalPosition);
  }

  void _bodyDragStart(int i, DragStartDetails d) {
    _startDrag(i, d.globalPosition);
  }

  /// A horizontal recognizer reports only the x component in `delta`, so the
  /// movement is recomputed from the global position — otherwise a card
  /// picked up by swiping sideways could never be moved up or down.
  void _bodyDragUpdate(DragUpdateDetails d) {
    if (_dragIdx == null) return;
    final delta = d.globalPosition - _lastGlobal;
    _lastGlobal = d.globalPosition;
    _dragUpdateWithDelta(delta);
  }

  /// Releases any interaction still believed to be in progress.
  ///
  /// Called on every raw pointer-up, so the grid cannot stay latched into a
  /// drag or resize if a recognizer disappeared before reporting its end.
  void _releaseIfStuck() {
    if (_dragIdx != null) _dragFinish();
    if (_resizeIdx != null) _resEnd(DragEndDetails());
  }

  /// A long press can be cancelled without ever reporting an end. Without
  /// this the grid would sit in a drag that never finishes.
  void _longPressCancel() {
    if (_dragIdx != null) _dragFinish();
  }

  void _longPressMove(LongPressMoveUpdateDetails d) {
    if (_dragIdx == null) return;
    final delta = d.globalPosition - _lastGlobal;
    _lastGlobal = d.globalPosition;
    _dragUpdateWithDelta(delta);
  }

  void _longPressEnd(LongPressEndDetails d) {
    _dragFinish();
  }

  // ── Resize ─────────────────────────────────────────────────────────────────

  bool _hasTop(_ResizeHandle h) =>
      h == _ResizeHandle.top ||
      h == _ResizeHandle.topLeft ||
      h == _ResizeHandle.topRight;

  bool _hasBottom(_ResizeHandle h) =>
      h == _ResizeHandle.bottom ||
      h == _ResizeHandle.bottomLeft ||
      h == _ResizeHandle.bottomRight;

  bool _hasLeft(_ResizeHandle h) =>
      h == _ResizeHandle.left ||
      h == _ResizeHandle.topLeft ||
      h == _ResizeHandle.bottomLeft;

  bool _hasRight(_ResizeHandle h) =>
      h == _ResizeHandle.right ||
      h == _ResizeHandle.topRight ||
      h == _ResizeHandle.bottomRight;

  void _resStart(int i, _ResizeHandle handle, DragStartDetails d) {
    HapticFeedback.mediumImpact();
    _setInteractionActive(true);
    setState(() {
      _resizeIdx = i;
      _resizeHandle = handle;
      _resizeStartRect = _layout?.rects[i];
      _resizeStartGY = d.globalPosition.dy;
      _resizeStartGX = d.globalPosition.dx;
      _resizePendingSpan = null;
      _resizePreview = null;
    });
  }

  void _resUpdate(DragUpdateDetails d) {
    if (_resizeIdx == null || _resizeHandle == null) return;
    final it = _items[_resizeIdx!];
    final start = _resizeStartRect;
    if (start == null) return;

    final dx = d.globalPosition.dx - _resizeStartGX;
    final dy = d.globalPosition.dy - _resizeStartGY;

    final half = (_gridW - _gap) / 2;
    final minW = it.minSpan == 2 ? _gridW : half;
    final maxW = it.maxSpan == 2 ? _gridW : half;

    double newLeft = start.left;
    double newTop = start.top;
    double newWidth = start.width;
    double newHeight = start.height;

    // Vertical resize
    if (_hasTop(_resizeHandle!)) {
      newHeight = (start.height - dy).clamp(it.minHeight, it.maxHeight);
      newTop = start.top + (start.height - newHeight);
    } else if (_hasBottom(_resizeHandle!)) {
      newHeight = (start.height + dy).clamp(it.minHeight, it.maxHeight);
      newTop = start.top;
    }

    // Horizontal resize
    if (_hasLeft(_resizeHandle!)) {
      newWidth = (start.width - dx).clamp(minW, maxW);
      newLeft = start.left + (start.width - newWidth);
    } else if (_hasRight(_resizeHandle!)) {
      newWidth = (start.width + dx).clamp(minW, maxW);
      newLeft = start.left;
    }

    newLeft = newLeft.clamp(0.0, _gridW - newWidth);
    newTop = newTop.clamp(0.0, double.infinity);

    it.height = newHeight;

    if (_hasLeft(_resizeHandle!) || _hasRight(_resizeHandle!)) {
      final spanThreshold = (half + _gridW) / 2;
      final desiredSpan = newWidth >= spanThreshold ? 2 : 1;
      _resizePendingSpan = desiredSpan.clamp(it.minSpan, it.maxSpan).toInt();
    }

    _resizePreview = _Rect(newLeft, newTop, newWidth, newHeight);
    setState(() {});
  }

  void _resEnd(DragEndDetails _) {
    if (_resizeIdx != null) {
      final it = _items[_resizeIdx!];
      it.height = (it.height / 8).round() * 8.0;
      it.height = it.height.clamp(it.minHeight, it.maxHeight);
      if (_resizePendingSpan != null) {
        it.columnSpan = _resizePendingSpan!;
      }
      _emitLayout();
    }
    setState(() {
      _resizeIdx = null;
      _resizeHandle = null;
      _resizeStartRect = null;
      _resizePendingSpan = null;
      _resizePreview = null;
    });
    _setInteractionActive(false);
  }

  // ── Span toggle ────────────────────────────────────────────────────────────

  void _toggleSpan(int i) {
    HapticFeedback.lightImpact();
    setState(() {
      final item = _items[i];
      if (item.minSpan == item.maxSpan) return;
      item.columnSpan = item.columnSpan == item.maxSpan
          ? item.minSpan
          : item.maxSpan;
    });
    _emitLayout();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        _gridW = box.maxWidth - widget.padding.horizontal;
        _gap = _editMode ? widget.spacing + 20 : widget.spacing;
        _layout = _computeLayout(_items, _gridW, _gap);

        return Listener(
          // Backstop. A gesture recognizer can be disposed mid-gesture by a
          // rebuild that changes which callbacks are present, and then its end
          // callback never arrives — leaving the grid stuck in a drag with
          // scrolling pinned and no way for the user to recover. A raw
          // pointer-up always arrives, so it releases the grid regardless of
          // what happened to the recognizers.
          onPointerUp: (_) => _releaseIfStuck(),
          onPointerCancel: (_) => _releaseIfStuck(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _editMode ? _exitEdit : null,
            child: Padding(
              padding: widget.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: _editMode
                        ? _buildEditHeader()
                        : const SizedBox.shrink(),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _layout!.totalHeight,
                    child: Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      children: [
                        if (_dragIdx != null) _dropPlaceholder(ctx),
                        for (int i = 0; i < _items.length; i++)
                          if (i != _dragIdx) _positioned(i),
                        if (_dragIdx != null) _positioned(_dragIdx!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditHeaderRow(),
          const SizedBox(height: 8),
          Text(
            'Drag the handle at the top of a card to move it.\n'
            'Pull a white corner dot to resize. Double-tap to change width.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditHeaderRow() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'EDIT LAYOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 2,
            ),
          ),
          Row(
            children: [
              if (widget.onResetRequested != null)
                GestureDetector(
                  onTap: widget.onResetRequested,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (widget.onResetRequested != null) const SizedBox(width: 8),
              GestureDetector(
                onTap: _exitEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
    );
  }

  Widget _positioned(int i) {
    final baseRect = _layout!.rects[i];
    final r = i == _resizeIdx && _resizePreview != null
        ? _resizePreview!
        : baseRect;
    final dragging = i == _dragIdx;
    double l = r.left, t = r.top;
    if (dragging) {
      l += _dragDelta.dx;
      t += _dragDelta.dy;
    }

    final child = _cardWidget(i, dragging, r.width, r.height);

    if (dragging || i == _resizeIdx) {
      return Positioned(
        key: ValueKey(_items[i].id),
        left: l,
        top: t,
        width: r.width,
        height: r.height,
        child: child,
      );
    }

    return AnimatedPositioned(
      key: ValueKey(_items[i].id),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: l,
      top: t,
      width: r.width,
      height: r.height,
      child: child,
    );
  }

  /// Dashed outline marking the slot the dragged card will drop into.
  Widget _dropPlaceholder(BuildContext context) {
    final r = _layout!.rects[_dragIdx!];
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DashedSlotPainter(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _cardWidget(int i, bool dragging, double cardW, double cardH) {
    final item = _items[i];
    Widget inner = SizedBox.expand(child: item.card);

    // Block the card's own buttons while arranging.
    if (_editMode) inner = AbsorbPointer(child: inner);

    final double handleBox = _handleBox(cardW, cardH);

    Widget c = inner;

    // Card plus its chrome. Keeping the handles in here — inside the
    // transforms applied below — means the dots stay glued to the card's
    // visible edge and stay touchable where they are drawn. Previously the
    // handles sat outside the scale, so on a shrunken card they floated off
    // the corner and you had to press where the dot was not.
    if (_editMode) {
      c = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: inner),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (i == _resizeIdx)
            Positioned.fill(
              child: IgnorePointer(child: Center(child: _sizeChip(i))),
            ),
          ..._buildResizeHandles(i, item, handleBox),
          _grip(i, _hasHandles(i, item) ? handleBox : 8.0),
        ],
      );
    }

    // Jiggle, but never the card in hand.
    if (_editMode && !dragging) {
      c = AnimatedBuilder(
        animation: _jiggle,
        builder: (_, ch) {
          final a = (_jiggle.value + (i % 3 - 1) * 0.35) * 0.006;
          return Transform.rotate(angle: a, child: ch);
        },
        child: c,
      );
    }

    final bool isInactive = _dragIdx != null && !dragging;

    // Only the card in hand transforms. The others used to be desaturated,
    // faded to 0.4 and shrunk to 0.92 all at once, which made the board hard
    // to read mid-drag; a single gentle fade is enough to show what is lifted.
    c = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      transform: dragging
          ? Matrix4.diagonal3Values(1.04, 1.04, 1.0)
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ]
            : [],
      ),
      child: c,
    );

    c = AnimatedOpacity(
      opacity: isInactive ? 0.7 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: c,
    );

    // Gestures.
    //
    // One detector for both modes, on purpose. When the long-press handlers
    // lived only on a non-edit branch, entering edit mode rebuilt the card
    // with a different set of callbacks and disposed the
    // LongPressGestureRecognizer in the middle of the gesture — so
    // onLongPressEnd never arrived, _dragFinish never ran, and the grid was
    // left believing a drag was still in progress: every other card dimmed,
    // the scroll view pinned, and the auto-scroll timer running forever.
    // Keeping the same callbacks present in both modes lets the element and
    // its recognizer survive the switch.
    //
    // The card body still has no pan recognizer, which is what leaves plain
    // drags to the scroll view. Long-press holds still before it fires, so it
    // coexists with scrolling; the grip and corners claim their gesture
    // immediately for anyone who does not want to wait.
    c = GestureDetector(
      behavior: _editMode
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      onLongPressStart: (d) => _longPressStart(i, d),
      onLongPressMoveUpdate: _longPressMove,
      onLongPressEnd: _longPressEnd,
      onLongPressCancel: _longPressCancel,
      // Swallow taps in edit mode so touching a card does not dismiss it;
      // only empty space and Done do that.
      onTap: _editMode ? () {} : null,
      onDoubleTap: _editMode && item.minSpan != item.maxSpan
          ? () => _toggleSpan(i)
          : null,
      // A third way to pick a card up: swipe it sideways from anywhere on the
      // card. Vertical is spoken for by the scroll view, but horizontal is
      // free in edit mode, so this costs nothing and means you do not have to
      // find the grip or wait out a long press.
      //
      // Only in edit mode: outside it, a card-wide horizontal recognizer
      // would fight the interviews carousel for its swipes.
      onHorizontalDragStart: _editMode ? (d) => _bodyDragStart(i, d) : null,
      onHorizontalDragUpdate: _editMode ? _bodyDragUpdate : null,
      onHorizontalDragEnd: _editMode ? _dragEnd : null,
      onHorizontalDragCancel: _editMode ? _longPressCancel : null,
      child: c,
    );

    return c;
  }

  /// Live size readout while resizing, so the 8px height snap and the
  /// half/full width snap are visible rather than a surprise on release.
  Widget _sizeChip(int i) {
    final item = _items[i];
    final span = _resizePendingSpan ?? item.columnSpan;
    final h = _resizePreview?.height ?? item.height;
    final snapped = (h / 8).round() * 8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${span >= 2 ? 'Full' : 'Half'} width  ·  ${snapped}px',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// The move handle. A labelled grip reads as "pull me" in a way that corner
  /// dots — which look like rivets in this card style — never did.
  /// The move handle: a full-width strip across the top of the card.
  ///
  /// The whole strip is the target, not just the pill drawn in it — the pill
  /// alone was a 76px sliver and far too easy to miss. It insets by the
  /// corner-handle size so it never competes with a resize dot.
  Widget _grip(int i, double inset) {
    return Positioned(
      top: 0,
      left: inset,
      right: inset,
      height: 46,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerPanRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
                () => _EagerPanRecognizer(debugOwner: this),
                (r) {
                  r.onStart = (d) => _dragStart(i, d);
                  r.onUpdate = _dragUpdate;
                  r.onEnd = _dragEnd;
                  // Not `_dragIdx == i`: reordering reassigns _dragIdx as the
                  // card travels, so comparing against the captured index
                  // would skip cleanup and leave the card stuck lifted with
                  // the auto-scroll timer still running.
                  r.onCancel = () {
                    if (_dragIdx != null) _dragFinish();
                  };
                },
              ),
        },
        child: Center(
          child: Container(
            width: 64,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
            ),
            child: Icon(
              Icons.drag_handle,
              size: 17,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }

  /// Whether this card shows resize corners at all.
  bool _hasHandles(int i, _Item item) {
    if (!item.resizable) return false;
    // The card in hand is being moved, not resized.
    if (_dragIdx == i) return false;
    return item.minSpan != item.maxSpan || item.minHeight != item.maxHeight;
  }

  /// Corner target size: 48dp where the card is big enough, shrinking only
  /// when the top and bottom pair would otherwise collide.
  double _handleBox(double cardW, double cardH) =>
      min(48.0, min(cardH * 0.45, cardW * 0.45)).clamp(32.0, 48.0);

  List<Widget> _buildResizeHandles(int i, _Item item, double box) {
    if (!_hasHandles(i, item)) return const [];

    // Corners only. Eight handles on a 90px card meant the edge and corner
    // targets physically overlapped, so which one you got was pot luck. Four
    // corners cover both axes on their own — the width and height clamps in
    // _resUpdate pin whichever axis this card does not allow.
    return [
      _cornerHandle(i, _ResizeHandle.topLeft, box, top: 0, left: 0),
      _cornerHandle(i, _ResizeHandle.topRight, box, top: 0, right: 0),
      _cornerHandle(i, _ResizeHandle.bottomLeft, box, bottom: 0, left: 0),
      _cornerHandle(i, _ResizeHandle.bottomRight, box, bottom: 0, right: 0),
    ];
  }

  Widget _cornerHandle(
    int i,
    _ResizeHandle handle,
    double box, {
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      width: box,
      height: box,
      child: RawGestureDetector(
        // Opaque, not translucent. Translucent let the same touch fall through
        // to the card underneath, putting two pan recognizers in the arena at
        // once — which is why a corner sometimes resized and sometimes
        // dragged the whole card.
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerPanRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
                () => _EagerPanRecognizer(debugOwner: this),
                (r) {
                  r.onDown = (_) => HapticFeedback.selectionClick();
                  r.onStart = (d) => _resStart(i, handle, d);
                  r.onUpdate = _resUpdate;
                  r.onEnd = _resEnd;
                },
              ),
        },
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded outline used to show where a dragged card will land.
class _DashedSlotPainter extends CustomPainter {
  final Color color;
  const _DashedSlotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    final source = Path()..addRRect(rrect);
    final dashes = Path();
    for (final metric in source.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final next = min(d + 10.0, metric.length);
        dashes.addPath(metric.extractPath(d, next), Offset.zero);
        d = next + 7;
      }
    }

    canvas.drawPath(
      dashes,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) => old.color != color;
}
