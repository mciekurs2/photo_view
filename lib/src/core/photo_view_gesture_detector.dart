import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'photo_view_hit_corners.dart';

class PhotoViewGestureDetector extends StatelessWidget {
  const PhotoViewGestureDetector({
    Key key,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTap,
    this.child,
    this.onTapUp,
    this.onTapDown,
  }) : super(key: key);

  final GestureDoubleTapCallback onDoubleTap;
  final HitCornersDetector hitDetector;

  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;

  final GestureTapUpCallback onTapUp;
  final GestureTapDownCallback onTapDown;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = PhotoViewGestureDetectorScope.of(context);

    final Axis axis = scope?.scrollDirection ?? Axis.horizontal;

    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp;
        },
      );
    }

    gestures[PhotoViewGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
      () => PhotoViewGestureRecognizer(hitDetector, this, axis),
      (PhotoViewGestureRecognizer instance) {
        instance
          ..onStart = onScaleStart
          ..onUpdate = onScaleUpdate
          ..onEnd = onScaleEnd;
      },
    );

    gestures[DoubleTapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      () => DoubleTapGestureRecognizer(debugOwner: this),
      (DoubleTapGestureRecognizer instance) {
        instance..onDoubleTap = onDoubleTap;
      },
    );

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: child,
      gestures: gestures,
    );
  }
}

class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  PhotoViewGestureRecognizer(
    this.hitDetector,
    Object debugOwner,
    this.scrollDirection,
  ) : super(debugOwner: debugOwner);
  final HitCornersDetector hitDetector;
  final Axis scrollDirection;

  Map<int, Offset> _pointerLocations = <int, Offset>{};

  Offset _initialFocalPoint;
  Offset _currentFocalPoint;

  bool ready = true;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    ready = true;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    _computeEvent(event);
    _updateDistances();
    _decideIfWeAcceptEvent(event);

    super.handleEvent(event);
  }

  void _computeEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!event.synthesized) {
        _pointerLocations[event.pointer] = event.position;
      }
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
    }

    _initialFocalPoint = _currentFocalPoint;
  }

  void _updateDistances() {
    final int count = _pointerLocations.keys.length;
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer];
    _currentFocalPoint =
        count > 0 ? focalPoint / count.toDouble() : Offset.zero;
  }

  void _decideIfWeAcceptEvent(PointerEvent event) {
    if (!(event is PointerMoveEvent)) {
      return;
    }
    final move = _initialFocalPoint - _currentFocalPoint;
    final bool shouldMove = scrollDirection == Axis.vertical
        ? hitDetector.shouldMoveY(move)
        : hitDetector.shouldMoveX(move);
    if (shouldMove || _pointerLocations.keys.length > 1) {
      resolve(GestureDisposition.accepted);
    }
  }
}

class PhotoViewGestureDetectorScope extends InheritedWidget {
  PhotoViewGestureDetectorScope({
    this.scrollDirection,
    @required Widget child,
  }) : super(child: child);

  static PhotoViewGestureDetectorScope of(BuildContext context) {
    final PhotoViewGestureDetectorScope scope =
        context.inheritFromWidgetOfExactType(PhotoViewGestureDetectorScope);
    return scope;
  }

  final Axis scrollDirection;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return scrollDirection != oldWidget.scrollDirection;
  }
}