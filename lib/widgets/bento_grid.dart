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

/// Arranging is tap-driven rather than drag-driven.
///
/// Drag-and-drop here depended on gesture-arena behaviour that competed with
/// the enclosing scroll view — the card body, a grip and the resize corners
/// all fighting over the same touch, with the page trying to scroll
/// underneath. Repeated attempts to referee that fight did not hold up on a
/// real device.
///
/// So: pick a card, then press buttons. A button tap has no arena to lose, it
/// cannot be stolen by a scrollable, and it works the same whatever the finger
/// does afterwards. Scrolling is left completely untouched, which also means a
/// card that moves off-screen can still be reached — select it, then keep
/// pressing.
class _BentoGridState extends State<BentoGrid> with TickerProviderStateMixin {
  static const double _heightStep = 20;

  late List<_Item> _items;
  bool _editMode = false;

  /// Index of the card the controls act on, if any.
  int? _selected;

  late AnimationController _jiggle;

  /// Measures where cards sit on screen, so a card can be kept visually still
  /// across a layout change.
  final GlobalKey _stackKey = GlobalKey();

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
    _jiggle.dispose();
    super.dispose();
  }

  void _syncItems() {
    _items = widget.items.map(_Item.from).toList();
    if (_selected != null && _selected! >= _items.length) {
      _selected = _items.isEmpty ? null : _items.length - 1;
    }
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

  // ── Keeping a card visually still ──────────────────────────────────────────

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

  /// Takes the layout shift out of the scroll offset, so the card being
  /// worked on does not walk off the screen as things resize around it.
  ///
  /// Reordering changes the card's index, hence the two arguments: measure it
  /// where it was, restore it where it landed.
  void _anchor(int? fromIndex, [int? toIndex]) {
    if (fromIndex == null) return;
    final before = _cardGlobalTop(fromIndex);
    if (before == null) return;
    final target = toIndex ?? fromIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = _cardGlobalTop(target);
      final scrollable = Scrollable.maybeOf(context);
      if (after == null || scrollable == null) return;

      final delta = after - before;
      if (delta.abs() < 1) return;

      final pos = scrollable.position;
      final to = (pos.pixels + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((to - pos.pixels).abs() < 1) return;
      pos.jumpTo(to);
    });
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEdit({int? select}) {
    if (_editMode) return;
    _anchor(select ?? _topmostVisibleIndex());
    HapticFeedback.mediumImpact();
    _jiggle.repeat(reverse: true);
    setState(() {
      _editMode = true;
      _selected = select;
    });
    widget.onEditModeChanged?.call(true);
  }

  void _exitEdit() {
    if (!_editMode) return;
    _anchor(_selected ?? _topmostVisibleIndex());
    _jiggle
      ..stop()
      ..value = 0;
    setState(() {
      _editMode = false;
      _selected = null;
    });
    widget.onEditModeChanged?.call(false);
  }

  void _select(int i) {
    HapticFeedback.selectionClick();
    setState(() => _selected = _selected == i ? null : i);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  void _move(int i, int delta) {
    final target = (i + delta).clamp(0, _items.length - 1);
    if (target == i) return;

    _anchor(i, target);
    HapticFeedback.selectionClick();
    setState(() {
      final item = _items.removeAt(i);
      _items.insert(target, item);
      _selected = target;
    });
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

  void _resize(int i, double delta) {
    final item = _items[i];
    final next = (item.height + delta).clamp(item.minHeight, item.maxHeight);
    if (next == item.height) return;

    _anchor(i);
    HapticFeedback.selectionClick();
    setState(() => item.height = next);
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
    final hint = _selected == null
        ? 'Tap a card to select it.'
        : 'Use the buttons on the card to move and resize it.';

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
      child: _cardWidget(i),
    );
  }

  Widget _cardWidget(int i) {
    final item = _items[i];
    final selected = _editMode && _selected == i;

    Widget c = SizedBox.expand(child: item.card);

    // Stop the card's own buttons responding while arranging.
    if (_editMode) c = AbsorbPointer(child: c);

    if (_editMode) {
      c = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: c),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF77F00)
                        : Colors.white.withValues(alpha: 0.2),
                    width: selected ? 2 : 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (selected) _controls(i, item),
        ],
      );

      // Gentle wobble so it is obvious the board is editable.
      if (!selected) {
        c = AnimatedBuilder(
          animation: _jiggle,
          builder: (_, ch) => Transform.rotate(
            angle: (_jiggle.value + (i % 3 - 1) * 0.35) * 0.005,
            child: ch,
          ),
          child: c,
        );
      }
    }

    // One tap target for the card, and one gesture only: a tap to select.
    // Nothing here competes with the scroll view, which is what keeps the
    // page scrollable while arranging.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editMode ? () => _select(i) : null,
      onLongPress: _editMode ? null : () => _enterEdit(select: i),
      child: c,
    );
  }

  /// The controls for the selected card.
  ///
  /// Five compact buttons, sized so the row still fits across a half-width
  /// card on a small phone.
  Widget _controls(int i, _Item item) {
    final canMoveUp = i > 0;
    final canMoveDown = i < _items.length - 1;
    final canSpan = item.minSpan != item.maxSpan;
    final canShrink = item.resizable && item.height > item.minHeight;
    final canGrow = item.resizable && item.height < item.maxHeight;

    // Row rather than Center: a Positioned with no top/height gives its child
    // loose constraints, and Center would expand to the full card height and
    // park the bar in the middle instead of at the bottom.
    //
    // Flexible + scaleDown because the row is ~178px wide and a half-width
    // card on a 360dp phone is only ~154px — without it this overflows.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _controlButton(
                      Icons.keyboard_arrow_up,
                      'Move up',
                      canMoveUp ? () => _move(i, -1) : null,
                    ),
                    _controlButton(
                      Icons.keyboard_arrow_down,
                      'Move down',
                      canMoveDown ? () => _move(i, 1) : null,
                    ),
                    _controlDivider(),
                    _controlButton(
                      item.columnSpan >= 2
                          ? Icons.close_fullscreen
                          : Icons.open_in_full,
                      item.columnSpan >= 2 ? 'Half width' : 'Full width',
                      canSpan ? () => _toggleSpan(i) : null,
                    ),
                    _controlDivider(),
                    _controlButton(
                      Icons.remove,
                      'Shorter',
                      canShrink ? () => _resize(i, -_heightStep) : null,
                    ),
                    _controlButton(
                      Icons.add,
                      'Taller',
                      canGrow ? () => _resize(i, _heightStep) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, String tooltip, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 19,
              color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.25),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlDivider() => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: Colors.white.withValues(alpha: 0.18),
  );
}
