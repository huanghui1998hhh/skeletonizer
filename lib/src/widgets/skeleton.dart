import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:skeletonizer/src/painting/skeletonizer_painting_context.dart';
import 'package:skeletonizer/src/painting/uniting_painting_context.dart';
import 'package:skeletonizer/src/utils.dart';

typedef SkeletonizerPainter = void Function(
  SkeletonizerPaintingContext context,
  Rect paintBounds,
  Painter paint,
);

typedef Painter = void Function(PaintingContext context, Offset offset);

abstract class Skeleton extends SingleChildRenderObjectWidget {
  const Skeleton({
    super.child,
    super.key,
    this.enabled = true,
  });

  final bool enabled;

  const factory Skeleton.ignore({
    Key? key,
    required Widget child,
    bool ignore,
  }) = _IgnoreSkeleton;

  const factory Skeleton.unite({
    Key? key,
    required Widget child,
    bool unite,
    BorderRadiusGeometry? borderRadius,
  }) = _UnitingSkeleton;

  const factory Skeleton.keep({
    Key? key,
    required Widget child,
    bool keep,
  }) = _KeepSkeleton;

  const factory Skeleton.shade({
    Key? key,
    required Widget child,
    bool shade,
  }) = _SkeletonShaderMask;

  static SkeletonReplace replace({
    Key? key,
    required Widget child,
    bool replace = true,
    double? width,
    double? height,
    Widget replacement = const DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
    ),
  }) =>
      SkeletonReplace(
        replace: replace,
        width: width,
        height: height,
        replacement: replacement,
        child: child,
      );
}

abstract class _BasicSkeleton extends Skeleton {
  const _BasicSkeleton({
    Key? key,
    required Widget child,
    bool enabled = true,
  }) : super(key: key, child: child, enabled: enabled);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBasicSkeleton(
      textDirection: Directionality.of(context),
      painter: paint,
      enabled: enabled,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBasicSkeleton renderObject,
  ) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..enabled = enabled;
  }

  void paint(
    SkeletonizerPaintingContext context,
    Rect paintBounds,
    Painter paint,
  );
}

class _IgnoreSkeleton extends _BasicSkeleton {
  const _IgnoreSkeleton({
    Key? key,
    required Widget child,
    bool ignore = true,
  }) : super(key: key, child: child, enabled: ignore);

  @override
  void paint(SkeletonizerPaintingContext context, _, __) {
    /// we do not paint anything
  }
}

class _KeepSkeleton extends _BasicSkeleton {
  const _KeepSkeleton({
    Key? key,
    required Widget child,
    bool keep = true,
  }) : super(key: key, child: child, enabled: keep);

  @override
  void paint(SkeletonizerPaintingContext context, rect, paint) {
    paint(context.createActualContext(rect), rect.topLeft);
  }
}

class _UnitingSkeleton extends _BasicSkeleton {
  final BorderRadiusGeometry? borderRadius;

  const _UnitingSkeleton({
    Key? key,
    required Widget child,
    this.borderRadius,
    bool unite = true,
  }) : super(key: key, child: child, enabled: unite);

  @override
  void paint(SkeletonizerPaintingContext context, Rect paintBounds, Painter paint) {
    final unitingContext = UnitingPaintingContext(context.layer, paintBounds);
    paint(unitingContext, Offset.zero);
    final canvas = unitingContext.canvas as UnitingCanvas;
    final unitedRect = canvas.unitedRect.shift(paintBounds.topLeft);
    final brRadius = borderRadius?.resolve(context.textDirection) ?? canvas.borderRadius;
    if (brRadius != null) {
      context.canvas.drawRRect(unitedRect.toRRect(brRadius), context.shaderPaint);
    } else {
      context.canvas.drawRect(unitedRect, context.shaderPaint);
    }
  }
}

class _RenderBasicSkeleton extends RenderProxyBox {
  /// Default constructor
  _RenderBasicSkeleton({
    RenderBox? child,
    required TextDirection textDirection,
    required SkeletonizerPainter painter,
    required bool enabled,
  })  : _textDirection = textDirection,
        _painter = painter,
        _enabled = enabled;

  bool _enabled = true;

  set enabled(bool value) {
    if (value != _enabled) {
      _enabled = value;
      markNeedsPaint();
    }
  }

  SkeletonizerPainter? _painter;

  set painter(SkeletonizerPainter? value) {
    if (value != _painter) {
      _painter = value;
      markNeedsPaint();
    }
  }

  TextDirection? _textDirection;

  set textDirection(TextDirection? value) {
    if (value != _textDirection) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_enabled && context is SkeletonizerPaintingContext) {
      assert(_painter != null, 'painter must not be null');
      context.textDirection = _textDirection;
      return _painter!(context, offset & size, super.paint);
    }
    super.paint(context, offset);
  }
}

/// Builds a [_RenderSkeletonShaderMask]
class _SkeletonShaderMask extends Skeleton {
  /// Creates a widget that applies a mask generated by a [Shader] to its child.
  ///
  /// The [shader] and [blendMode] arguments must not be null.
  const _SkeletonShaderMask({
    super.key,
    super.child,
    bool shade = true,
  }) : super(enabled: shade);

  @override
  _RenderSkeletonShaderMask createRenderObject(BuildContext context) {
    return _RenderSkeletonShaderMask(shade: enabled);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSkeletonShaderMask renderObject,
  ) {
    renderObject.shade = enabled;
  }
}

/// This is typically a [RenderShaderMask] with few adjustments
///
/// it takes shader info by setters instead of the widget
class _RenderSkeletonShaderMask extends RenderProxyBox {
  /// Creates a render object that applies a mask generated by a [Shader] to its child.

  _RenderSkeletonShaderMask({
    RenderBox? child,
    required bool shade,
  })  : _shade = shade,
        super(child);

  bool _shade = true;

  set shade(bool value) {
    if (value != _shade) {
      _shade = value;
      markNeedsPaint();
    }
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (_shade && context is SkeletonizerPaintingContext) {
        assert(needsCompositing);
        layer ??= ShaderMaskLayer();
        layer!
          ..shader = context.shaderPaint.shader
          ..maskRect = context.maskRect
          ..blendMode = BlendMode.srcATop;

        final childContext = context.createActualContext(offset & size);
        childContext.pushLayer(layer!, super.paint, offset);
        assert(() {
          layer!.debugCreator = debugCreator;
          return true;
        }());
      } else {
        super.paint(context, offset);
      }
    } else {
      layer = null;
    }
  }
}

// /// Replace the original element when [Skeletonizer.enabled] is true
class SkeletonReplace extends StatelessWidget {
  /// Default constructor
  const SkeletonReplace({
    super.key,
    required this.child,
    this.replace = true,
    this.width,
    this.height,
    this.replacement = const DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
    ),
  });

  final Widget child;

  /// The width nad height of the replacement
  final double? width, height;

  /// Whether replacing is enabled
  final bool replace;

  /// The replacement widget
  final Widget replacement;

  @override
  Widget build(BuildContext context) {
    final doReplace = replace && Skeletonizer.maybeOf(context)?.enabled == true;
    return doReplace
        ? SizedBox(
            width: width,
            height: height,
            child: replacement,
          )
        : child;
  }
}
