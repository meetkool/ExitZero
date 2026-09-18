import 'dart:async';
import 'dart:math';
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
}

class _Layout {
  final List<_Rect> rects;
  final double totalHeight;
  _Layout(this.rects, this.totalHeight);
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

/// Moving and resizing, built on Flutter's own drag layer.
///
/// Earlier versions hand-rolled pan recognizers on the cards and lost every
/// fight with the enclosing scroll view over who owned the touch.
/// [LongPressDraggable] avoids that fight by construction: it uses the
/// delayed multi-drag recognizer built for dragging inside a scrollable — the
/// same one [ReorderableListView] uses — and it renders the lifted card in
/// the app's Overlay, above everything, following the finger in screen
/// coordinates. Nothing has to be refereed, and nothing depends on the card's
/// own hit box once the lift happens.
///
/// Resizing is kept out of that contest entirely: a card has to be tapped
/// first, and while one is selected the page stops scrolling, so the handles
/// are the only thing a drag can mean. The lock hangs off visible state — a
/// highlighted card, with Done on screen — rather than the lifetime of a
/// gesture, so it can always be undone by tapping.
class _BentoGridState extends State<BentoGrid> with TickerProviderStateMixin {
  late List<_Item> _items;
  bool _editMode = false;
  late AnimationController _jiggle;

  final GlobalKey _stackKey = GlobalKey();

  /// Card showing resize handles, if any. Scrolling is frozen while set.
  int? _selected;

  /// Card currently lifted, and the slot it is hovering over.
  int? _lifted;
  int? _hover;

  // Resize session.
  double _resizeStartHeight = 0;
  int _resizeStartSpan = 1;
  Offset _resizeStartGlobal = Offset.zero;

  // Edge auto-scroll while a card is lifted.
  Timer? _autoScroll;
  Offset _lastDragGlobal = Offset.zero;

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
      duration: const Duration(milliseconds: 300),
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
    _autoScroll?.cancel();
    _jiggle.dispose();
    super.dispose();
  }

  void _syncItems() {
    _items = widget.items.map(_Item.from).toList();
    if (_selected != null && _selected! >= _items.length) _selected = null;
  }

  void _emitLayout() {
    if (widget.onLayoutChanged == null) return;
    widget.onLayoutChanged!(
      _items
          .map(
            (e) => BentoGridLayoutItem(
              id: e.id,
              columnSpan: e.columnSpan,
              height: e.height,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Scrolling is frozen only while a card is selected for resizing.
  void _setScrollLocked(bool locked) {
    widget.onInteractionChanged?.call(locked);
  }

  // ── Keeping a card visually still across a layout change ───────────────────

  double? _cardGlobalTop(int i) {
    final box = _stackKey.currentContext?.findRenderObject();
    final layout = _layout;
    if (box is! RenderBox || !box.hasSize) return null;
    if (layout == null || i < 0 || i >= layout.rects.length) return null;
    return box.localToGlobal(Offset.zero).dy + layout.rects[i].top;
  }

  int? _topmostVisibleIndex() {
    final layout = _layout;
    final box = _stackKey.currentContext?.findRenderObject();
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

  void _anchor(int? from, [int? to]) {
    if (from == null) return;
    final before = _cardGlobalTop(from);
    if (before == null) return;
    final target = to ?? from;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = _cardGlobalTop(target);
      final scrollable = Scrollable.maybeOf(context);
      if (after == null || scrollable == null) return;

      final delta = after - before;
      if (delta.abs() < 1) return;

      final pos = scrollable.position;
      final dest = (pos.pixels + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((dest - pos.pixels).abs() < 1) return;
      pos.jumpTo(dest);
    });
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEdit() {
    if (_editMode) return;
    _anchor(_topmostVisibleIndex());
    HapticFeedback.mediumImpact();
    _jiggle.repeat(reverse: true);
    setState(() => _editMode = true);
    widget.onEditModeChanged?.call(true);
  }

  void _exitEdit() {
    if (!_editMode) return;
    _anchor(_selected ?? _topmostVisibleIndex());
    _jiggle
      ..stop()
      ..value = 0;
    _setScrollLocked(false);
    setState(() {
      _editMode = false;
      _selected = null;
      _lifted = null;
      _hover = null;
    });
    widget.onEditModeChanged?.call(false);
  }

  void _select(int? i) {
    HapticFeedback.selectionClick();
    _setScrollLocked(i != null);
    setState(() => _selected = i);
  }

  // ── Reorder ────────────────────────────────────────────────────────────────

  void _liftStart(int i) {
    HapticFeedback.mediumImpact();
    _setScrollLocked(false);
    setState(() {
      _lifted = i;
      _selected = null;
    });
    _startAutoScroll();
  }

  void _liftEnd() {
    _stopAutoScroll();
    if (!mounted) return;
    setState(() {
      _lifted = null;
      _hover = null;
    });
  }

  void _drop(int from, int to) {
    if (from == to) return;
    HapticFeedback.lightImpact();
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
    });
    _emitLayout();
  }

  // ── Edge auto-scroll while lifted ──────────────────────────────────────────

  void _startAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (t) {
      // Self-cancelling: the lift is the only thing keeping this alive.
      if (!mounted || _lifted == null) {
        t.cancel();
        _autoScroll = null;
        return;
      }
      _tickAutoScroll();
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  /// Creeps the page when the lifted card is held near an edge.
  ///
  /// The lifted card lives in the Overlay and tracks the finger in screen
  /// coordinates, so scrolling underneath needs no compensation — the cards
  /// move, the card in hand does not.
  void _tickAutoScroll() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const double zone = 110;
    const double maxSpeed = 16;

    double v = 0;
    if (_lastDragGlobal.dy < top + zone) {
      v = -maxSpeed * ((top + zone - _lastDragGlobal.dy) / zone).clamp(0.0, 1.0);
    } else if (_lastDragGlobal.dy > bottom - zone) {
      v = maxSpeed * ((_lastDragGlobal.dy - (bottom - zone)) / zone).clamp(0.0, 1.0);
    }
    if (v == 0) return;

    final pos = scrollable.position;
    final target = (pos.pixels + v).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() < 0.01) return;
    pos.jumpTo(target);
  }

  // ── Resize ─────────────────────────────────────────────────────────────────

  void _resizeStart(int i, DragStartDetails d) {
    final item = _items[i];
    _resizeStartHeight = item.height;
    _resizeStartSpan = item.columnSpan;
    _resizeStartGlobal = d.globalPosition;
    HapticFeedback.selectionClick();
  }

  void _resizeUpdate(
    int i,
    DragUpdateDetails d, {
    required bool vertical,
    required bool horizontal,
  }) {
    final item = _items[i];
    setState(() {
      if (vertical) {
        final dy = d.globalPosition.dy - _resizeStartGlobal.dy;
        item.height = (_resizeStartHeight + dy).clamp(
          item.minHeight,
          item.maxHeight,
        );
      }
      if (horizontal && item.minSpan != item.maxSpan) {
        final dx = d.globalPosition.dx - _resizeStartGlobal.dx;
        // Pull right past a third of the grid to go full width, push back to
        // return to half.
        final threshold = _gridW / 3;
        if (_resizeStartSpan >= item.maxSpan) {
          item.columnSpan = dx < -threshold ? item.minSpan : item.maxSpan;
        } else {
          item.columnSpan = dx > threshold ? item.maxSpan : item.minSpan;
        }
      }
    });
  }

  void _resizeEnd(int i) {
    final item = _items[i];
    setState(() {
      item.height = ((item.height / 8).round() * 8.0).clamp(
        item.minHeight,
        item.maxHeight,
      );
    });
    HapticFeedback.lightImpact();
    _emitLayout();
  }

  void _toggleSpan(int i) {
    final item = _items[i];
    if (item.minSpan == item.maxSpan) return;
    _anchor(i);
    HapticFeedback.lightImpact();
    setState(() {
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
        _gap = _editMode ? widget.spacing + 8 : widget.spacing;
        _layout = _computeLayout(_items, _gridW, _gap);

        return Padding(
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
              SizedBox(
                height: _layout!.totalHeight,
                child: Stack(
                  key: _stackKey,
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < _items.length; i++) _positioned(i),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditHeader() {
    final hint = _selected != null
        ? 'Drag a white dot to resize. Tap the card again to finish.'
        : 'Hold a card to pick it up and drop it somewhere else.\n'
              'Tap a card to resize it.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    _headerButton(
                      'Reset',
                      widget.onResetRequested!,
                      subtle: true,
                    ),
                  if (widget.onResetRequested != null)
                    const SizedBox(width: 8),
                  _headerButton('Done', _exitEdit),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
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

  Widget _headerButton(
    String label,
    VoidCallback onTap, {
    bool subtle = false,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: subtle ? 0.05 : 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: subtle ? 0.8 : 1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _positioned(int i) {
    final r = _layout!.rects[i];
    return AnimatedPositioned(
      key: ValueKey(_items[i].id),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: _cardWidget(i, r),
    );
  }

  Widget _cardWidget(int i, _Rect rect) {
    final item = _items[i];

    Widget visual = SizedBox.expand(child: item.card);

    if (!_editMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _enterEdit,
        child: visual,
      );
    }

    // The card's own buttons must not respond while arranging.
    visual = AbsorbPointer(child: visual);

    final selected = _selected == i;
    final hovered = _hover == i && _lifted != i;

    Widget framed = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: visual),
        Positioned.fill(
          child: IgnorePointer(child: _frame(selected, hovered)),
        ),
      ],
    );

    // Selected: resize handles only. The card is deliberately not draggable
    // while selected, so a pan on a handle has nothing to compete with.
    if (selected) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _select(null),
              child: framed,
            ),
          ),
          ..._resizeHandles(i, item),
        ],
      );
    }

    if (_lifted != i) {
      framed = AnimatedBuilder(
        animation: _jiggle,
        builder: (_, ch) => Transform.rotate(
          angle: (_jiggle.value + (i % 3 - 1) * 0.35) * 0.005,
          child: ch,
        ),
        child: framed,
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != i,
      onAcceptWithDetails: (d) => _drop(d.data, i),
      onMove: (_) {
        if (_hover != i) setState(() => _hover = i);
      },
      onLeave: (_) {
        if (_hover == i) setState(() => _hover = null);
      },
      builder: (context, candidate, rejected) {
        return LongPressDraggable<int>(
          data: i,
          // Long enough not to fire on a scroll flick, short enough to feel
          // like the card jumps into your hand.
          delay: const Duration(milliseconds: 180),
          maxSimultaneousDrags: 1,
          feedback: _liftedCard(i, rect),
          childWhenDragging: _emptySlot(),
          onDragStarted: () => _liftStart(i),
          onDragUpdate: (d) => _lastDragGlobal = d.globalPosition,
          onDragEnd: (_) => _liftEnd(),
          onDraggableCanceled: (_, __) => _liftEnd(),
          onDragCompleted: _liftEnd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(i),
            onDoubleTap: item.minSpan == item.maxSpan
                ? null
                : () => _toggleSpan(i),
            child: framed,
          ),
        );
      },
    );
  }

  Widget _frame(bool selected, bool hovered) {
    final color = selected
        ? const Color(0xFFF77F00)
        : hovered
        ? const Color(0xFFF77F00).withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: selected || hovered ? 2 : 1.5),
        color: hovered
            ? const Color(0xFFF77F00).withValues(alpha: 0.08)
            : Colors.transparent,
      ),
    );
  }

  /// What the finger carries. Rendered in the app Overlay by [Draggable], so
  /// it floats above the whole page and is unaffected by scrolling.
  Widget _liftedCard(int i, _Rect rect) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: rect.width,
        height: rect.height,
        child: Transform.scale(
          scale: 1.06,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AbsorbPointer(child: _items[i].card),
            ),
          ),
        ),
      ),
    );
  }

  /// The hole the lifted card leaves behind.
  Widget _emptySlot() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: const Color(0xFFF77F00).withValues(alpha: 0.55),
          width: 2,
        ),
      ),
    );
  }

  /// Bottom, right and corner grips on the selected card.
  ///
  /// Only the edges that grow the card, so dragging never fights the fact
  /// that the layout is anchored from the top-left.
  List<Widget> _resizeHandles(int i, _Item item) {
    final canHeight = item.resizable && item.minHeight != item.maxHeight;
    final canWidth = item.resizable && item.minSpan != item.maxSpan;
    if (!canHeight && !canWidth) return const [];

    return [
      if (canHeight)
        _handle(
          i,
          alignment: Alignment.bottomCenter,
          vertical: true,
          horizontal: false,
        ),
      if (canWidth)
        _handle(
          i,
          alignment: Alignment.centerRight,
          vertical: false,
          horizontal: true,
        ),
      if (canHeight && canWidth)
        _handle(
          i,
          alignment: Alignment.bottomRight,
          vertical: true,
          horizontal: true,
        ),
    ];
  }

  Widget _handle(
    int i, {
    required Alignment alignment,
    required bool vertical,
    required bool horizontal,
  }) {
    final corner = vertical && horizontal;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _resizeStart(i, d),
        onPanUpdate: (d) => _resizeUpdate(
          i,
          d,
          vertical: vertical,
          horizontal: horizontal,
        ),
        onPanEnd: (_) => _resizeEnd(i),
        onPanCancel: () => _resizeEnd(i),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: Container(
              width: corner ? 22 : 18,
              height: corner ? 22 : 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF77F00),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
