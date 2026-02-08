import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

/// Describes one item in the [BentoGrid].
///
/// Each item needs a unique [id] for tracking during reorder / resize.
/// [columnSpan] = 1 → half-width, 2 → full-width.
/// [height] is the grid-level height (the grid controls sizing, not the card).
class BentoGridItem {
  final String id;

  /// How many columns this item currently spans.
  final int columnSpan;

  /// Minimum and maximum allowed column spans (1 or 2).
  /// Use these to lock a card to full width or half width.
  final int minSpan;
  final int maxSpan;

  /// Initial height and min/max height bounds.
  final double height;
  final double minHeight;
  final double maxHeight;

  /// Whether this item can be resized at all.
  final bool resizable;

  /// The widget to render (usually a BentoCard).
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
  })  : assert(minSpan >= 1),
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

/// Interactive 2-column bento grid.
///
/// **How it works:**
/// 1. **Long press** any card → enter edit mode (cards jiggle, handles appear).
/// 2. **Drag** any card → reorder (adjacent items swap with animation).
/// 3. **Drag handles on any side / corner** → resize (snaps on release).
/// 4. **Double‑tap** a card → toggle half ↔ full width (if allowed).
/// 5. **Tap "Done"** or **tap empty space** → exit edit mode.
///
/// The parent should disable scrolling only while the grid is actively
/// dragging/resizing, otherwise the scroll steals the drag gesture.
class BentoGrid extends StatefulWidget {
  final List<BentoGridItem> items;
  final double spacing;
  final EdgeInsets padding;

  /// Called whenever edit mode is entered / exited.
  /// The parent should disable scrolling when `true`.
  final ValueChanged<bool>? onEditModeChanged;

  /// Called when a drag/resize gesture starts or ends.
  /// Use this to temporarily disable scrolling while interacting.
  final ValueChanged<bool>? onInteractionChanged;

  /// Emits the current layout (order, span, height) when it changes.
  final ValueChanged<List<BentoGridLayoutItem>>? onLayoutChanged;

  /// Called when the user taps "Reset" in edit mode.
  final VoidCallback? onResetRequested;

  /// Increment to force the grid to resync its internal state.
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

class _BentoGridState extends State<BentoGrid>
    with TickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 400),
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
        .map((e) => BentoGridLayoutItem(
              id: e.id,
              columnSpan: e.columnSpan,
              height: e.height,
            ))
        .toList(growable: false);
    widget.onLayoutChanged!(layout);
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEdit() {
    if (_editMode) return;
    HapticFeedback.mediumImpact();
    _jiggle.repeat(reverse: true);
    setState(() => _editMode = true);
    widget.onEditModeChanged?.call(true);
  }

  void _exitEdit() {
    if (!_editMode) return;
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
    if (!_editMode || _dragIdx != null || _resizeIdx != null) return;
    HapticFeedback.lightImpact();
    _setInteractionActive(true);
    setState(() {
      _dragIdx = i;
      _dragDelta = Offset.zero;
      _lastGlobal = globalPosition;
    });
  }

  void _dragStart(int i, DragStartDetails d) {
    _startDrag(i, d.globalPosition);
  }

  void _dragUpdate(DragUpdateDetails d) {
    _dragUpdateWithDelta(d.delta);
  }

  void _dragUpdateWithDelta(Offset delta) {
    if (_dragIdx == null || _layout == null) return;
    _dragDelta += delta;

    final myRect = _layout!.rects[_dragIdx!];
    final cx = myRect.center.dx + _dragDelta.dx;
    final cy = myRect.center.dy + _dragDelta.dy;

    // ── Check swap with NEXT item ──
    if (_dragIdx! + 1 < _items.length) {
      final nr = _layout!.rects[_dragIdx! + 1];
      final sameRow = (myRect.top - nr.top).abs() < 5;
      if (sameRow ? cx > nr.center.dx : cy > nr.center.dy) {
        _swapWith(_dragIdx! + 1);
        setState(() {});
        return;
      }
    }

    // ── Check swap with PREV item ──
    if (_dragIdx! > 0) {
      final pr = _layout!.rects[_dragIdx! - 1];
      final sameRow = (myRect.top - pr.top).abs() < 5;
      if (sameRow ? cx < pr.center.dx : cy < pr.center.dy) {
        _swapWith(_dragIdx! - 1);
        setState(() {});
        return;
      }
    }

    setState(() {});
  }

  void _swapWith(int target) {
    final oldRect = _layout!.rects[_dragIdx!];

    // Swap items
    final temp = _items[_dragIdx!];
    _items[_dragIdx!] = _items[target];
    _items[target] = temp;

    // Recalculate layout
    final nl = _computeLayout(_items, _gridW, _gap);
    final newRect = nl.rects[target];

    // Adjust delta so the dragged card doesn't visually jump
    _dragDelta += Offset(
      oldRect.left - newRect.left,
      oldRect.top - newRect.top,
    );
    _dragIdx = target;
    _layout = nl;
    HapticFeedback.selectionClick();
    _emitLayout();
  }

  void _dragEnd(DragEndDetails d) {
    _dragFinish();
  }

  void _dragFinish() {
    _setInteractionActive(false);
    setState(() {
      _dragIdx = null;
      _dragDelta = Offset.zero;
    });
  }

  void _longPressStart(int i, LongPressStartDetails d) {
    _enterEdit();
    _startDrag(i, d.globalPosition);
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

  // ── Resize (handles on all sides) ──────────────────────────────────────────

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

    // Keep within grid bounds
    newLeft = newLeft.clamp(0.0, _gridW - newWidth);
    newTop = newTop.clamp(0.0, double.infinity);

    // Apply height immediately so other rows can shift.
    it.height = newHeight;

    // Decide pending span based on preview width (snaps on release).
    if (_hasLeft(_resizeHandle!) || _hasRight(_resizeHandle!)) {
      final spanThreshold = (half + _gridW) / 2;
      final desiredSpan = newWidth >= spanThreshold ? 2 : 1;
      _resizePendingSpan =
          desiredSpan.clamp(it.minSpan, it.maxSpan).toInt();
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
      item.columnSpan =
          item.columnSpan == item.maxSpan ? item.minSpan : item.maxSpan;
    });
    _emitLayout();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      _gridW = box.maxWidth - widget.padding.horizontal;
      // Spread cards apart in edit mode so resize handles don't overlap
      _gap = _editMode ? widget.spacing + 20 : widget.spacing;
      _layout = _computeLayout(_items, _gridW, _gap);

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _editMode ? _exitEdit : null,
        child: Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Edit-mode header ──
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: _editMode ? _buildEditHeader() : const SizedBox.shrink(),
              ),

              // ── Grid ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _layout!.totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < _items.length; i++)
                      if (i != _dragIdx) _positioned(i),
                    if (_dragIdx != null) _positioned(_dragIdx!),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Edit header (EDIT LAYOUT / Done) ──

  Widget _buildEditHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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
              if (widget.onResetRequested != null)
                const SizedBox(width: 8),
              GestureDetector(
                onTap: _exitEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
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
      ),
    );
  }

  // ── Position each card inside the Stack ──

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

    final child = _cardWidget(i, dragging);

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

  // ── Build one card ──

  Widget _cardWidget(int i, bool dragging) {
    final item = _items[i];

    // Card content
    Widget c = SizedBox.expand(child: item.card);
    if (_editMode) c = AbsorbPointer(child: c);

    // Jiggle (not while dragging this card)
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

    // Drag visual (scale + shadow)
    c = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: dragging
          ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
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

    // ── Gesture handling ──
    // Normal mode  → long press enters edit mode (card taps still work).
    // Edit mode    → pan to drag-reorder (scroll is disabled by parent).
    if (_editMode) {
      c = GestureDetector(
        onTap: () {}, // consume tap so it doesn't exit edit
        onDoubleTap:
            item.minSpan == item.maxSpan ? null : () => _toggleSpan(i),
        onPanStart: (d) => _dragStart(i, d),
        onPanUpdate: _dragUpdate,
        onPanEnd: _dragEnd,
        child: c,
      );
    } else {
      c = GestureDetector(
        onLongPressStart: (d) => _longPressStart(i, d),
        onLongPressMoveUpdate: _longPressMove,
        onLongPressEnd: _longPressEnd,
        child: c,
      );
    }

    // ── Edit-mode overlays ──
    if (_editMode) {
      c = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: c),

          // Border
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
          // ── Resize handles (all sides) ──
          ..._buildResizeHandles(i, item),
        ],
      );
    }

    return c;
  }

  List<Widget> _buildResizeHandles(int i, _Item item) {
    if (!item.resizable) return const [];

    final allowHorizontal = item.minSpan != item.maxSpan;
    final allowVertical = item.minHeight != item.maxHeight;

    return [
      // Edges
      if (allowVertical) _edgeHandle(i, _ResizeHandle.top, Alignment.topCenter),
      if (allowVertical)
        _edgeHandle(i, _ResizeHandle.bottom, Alignment.bottomCenter),
      if (allowHorizontal)
        _edgeHandle(i, _ResizeHandle.left, Alignment.centerLeft),
      if (allowHorizontal)
        _edgeHandle(i, _ResizeHandle.right, Alignment.centerRight),

      // Corners (both directions)
      if (allowHorizontal && allowVertical) ...[
        _cornerHandle(i, _ResizeHandle.topLeft, Alignment.topLeft),
        _cornerHandle(i, _ResizeHandle.topRight, Alignment.topRight),
        _cornerHandle(i, _ResizeHandle.bottomLeft, Alignment.bottomLeft),
        _cornerHandle(i, _ResizeHandle.bottomRight, Alignment.bottomRight),
      ],
    ];
  }

  Widget _edgeHandle(int i, _ResizeHandle handle, Alignment alignment) {
    final bool horizontal =
        handle == _ResizeHandle.top || handle == _ResizeHandle.bottom;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (d) => _resStart(i, handle, d),
        onPanUpdate: _resUpdate,
        onPanEnd: _resEnd,
        child: SizedBox(
          width: horizontal ? 44 : 20,
          height: horizontal ? 20 : 44,
          child: Center(
            child: Container(
              width: horizontal ? 26 : 4,
              height: horizontal ? 4 : 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cornerHandle(int i, _ResizeHandle handle, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (d) => _resStart(i, handle, d),
        onPanUpdate: _resUpdate,
        onPanEnd: _resEnd,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
