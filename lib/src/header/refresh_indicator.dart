// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../easy_refresh.dart';

class _EasyRefreshSliverRefresh extends SingleChildRenderObjectWidget {
  const _EasyRefreshSliverRefresh({
    Key key,
    this.refreshIndicatorLayoutExtent = 0.0,
    this.hasLayoutExtent = false,
    this.enableInfiniteRefresh = false,
    this.headerFloat = false,
    this.axisDirectionNotifier,
    @required this.infiniteRefresh,
    Widget child,
  })  : assert(refreshIndicatorLayoutExtent != null),
        assert(refreshIndicatorLayoutExtent >= 0.0),
        assert(hasLayoutExtent != null),
        super(key: key, child: child);

  final double refreshIndicatorLayoutExtent;

  final bool hasLayoutExtent;

  /// 是否开启无限刷新
  final bool enableInfiniteRefresh;

  /// 无限加载回调
  final VoidCallback infiniteRefresh;

  /// Header浮动
  final bool headerFloat;

  /// 列表方向
  final ValueNotifier<AxisDirection> axisDirectionNotifier;

  @override
  _RenderEasyRefreshSliverRefresh createRenderObject(BuildContext context) {
    return _RenderEasyRefreshSliverRefresh(
      refreshIndicatorExtent: refreshIndicatorLayoutExtent,
      hasLayoutExtent: hasLayoutExtent,
      enableInfiniteRefresh: enableInfiniteRefresh,
      infiniteRefresh: infiniteRefresh,
      headerFloat: headerFloat,
      axisDirectionNotifier: axisDirectionNotifier,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      covariant _RenderEasyRefreshSliverRefresh renderObject) {
    renderObject
      ..refreshIndicatorLayoutExtent = refreshIndicatorLayoutExtent
      ..hasLayoutExtent = hasLayoutExtent
      ..enableInfiniteRefresh = enableInfiniteRefresh
      ..headerFloat = headerFloat;
  }
}

class _RenderEasyRefreshSliverRefresh extends RenderSliverSingleBoxAdapter {
  _RenderEasyRefreshSliverRefresh({
    @required double refreshIndicatorExtent,
    @required bool hasLayoutExtent,
    @required bool enableInfiniteRefresh,
    @required this.infiniteRefresh,
    @required bool headerFloat,
    @required this.axisDirectionNotifier,
    RenderBox child,
  })  : assert(refreshIndicatorExtent != null),
        assert(refreshIndicatorExtent >= 0.0),
        assert(hasLayoutExtent != null),
        _refreshIndicatorExtent = refreshIndicatorExtent,
        _enableInfiniteRefresh = enableInfiniteRefresh,
        _hasLayoutExtent = hasLayoutExtent,
        _headerFloat = headerFloat {
    this.child = child;
  }

  // The amount of layout space the indicator should occupy in the sliver in a
  // resting state when in the refreshing mode.
  double get refreshIndicatorLayoutExtent => _refreshIndicatorExtent;
  double _refreshIndicatorExtent;

  set refreshIndicatorLayoutExtent(double value) {
    assert(value != null);
    assert(value >= 0.0);
    if (value == _refreshIndicatorExtent) return;
    _refreshIndicatorExtent = value;
    markNeedsLayout();
  }

  /// 列表方向
  final ValueNotifier<AxisDirection> axisDirectionNotifier;

  // The child box will be laid out and painted in the available space either
  // way but this determines whether to also occupy any
  // [SliverGeometry.layoutExtent] space or not.
  bool get hasLayoutExtent => _hasLayoutExtent;
  bool _hasLayoutExtent;

  set hasLayoutExtent(bool value) {
    assert(value != null);
    if (value == _hasLayoutExtent) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  /// 是否开启无限刷新
  bool get enableInfiniteRefresh => _enableInfiniteRefresh;
  bool _enableInfiniteRefresh;

  set enableInfiniteRefresh(bool value) {
    assert(value != null);
    if (value == _enableInfiniteRefresh) return;
    _enableInfiniteRefresh = value;
    markNeedsLayout();
  }

  /// Header是否浮动
  bool get headerFloat => _headerFloat;
  bool _headerFloat;

  set headerFloat(bool value) {
    assert(value != null);
    if (value == _headerFloat) return;
    _headerFloat = value;
    markNeedsLayout();
  }

  /// 无限加载回调
  final VoidCallback infiniteRefresh;

  // 触发无限刷新
  bool _triggerInfiniteRefresh = false;

  // 获取子组件大小
  double get childSize =>
      constraints.axis == Axis.vertical ? child.size.height : child.size.width;

  double layoutExtentOffsetCompensation = 0.0;

  @override
  void performLayout() {
    axisDirectionNotifier.value = constraints.axisDirection;
    final double layoutExtent =
        _hasLayoutExtent || enableInfiniteRefresh ? _refreshIndicatorExtent : 0;
    if (layoutExtent != layoutExtentOffsetCompensation) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: layoutExtent - layoutExtentOffsetCompensation,
      );
      layoutExtentOffsetCompensation = layoutExtent;
      return;
    }
    final bool active = constraints.overlap < 0.0 || layoutExtent > 0.0;
    final double overScrolledExtent = min(constraints.overlap, 0.0).abs();
    child.layout(
      constraints.asBoxConstraints(
        maxExtent: layoutExtent + overScrolledExtent,
      ),
      parentUsesSize: true,
    );

    if (active) {
      final _layoutExtent =
          max(max(childSize, layoutExtent) - constraints.scrollOffset, 0.0);
      print('paintOrigin: ${-overScrolledExtent - constraints.scrollOffset}}');
      geometry = SliverGeometry(
        scrollExtent: layoutExtent,
        paintExtent: min(_layoutExtent, constraints.remainingPaintExtent),
        maxPaintExtent: _layoutExtent,
        paintOrigin: -overScrolledExtent - constraints.scrollOffset,
        layoutExtent: max(layoutExtent - constraints.scrollOffset, 0.0),
      );
    } else {
      geometry = SliverGeometry.zero;
    }
  }

  @override
  void paint(PaintingContext paintContext, Offset offset) {
    if (constraints.overlap < 0.0 || constraints.scrollOffset + childSize > 0) {
      paintContext.paintChild(child, offset);
    }
  }

  // Nothing special done here because this sliver always paints its child
  // exactly between paintOrigin and paintExtent.
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}

/// The current state of the refresh control.
///
/// Passed into the [RefreshControlBuilder] builder function so
/// users can show different UI in different modes.
enum RefreshMode {
  /// Initial state, when not being overscrolled into, or after the overscroll
  /// is canceled or after done and the sliver retracted away.
  inactive,

  /// While being overscrolled but not far enough yet to trigger the refresh.
  drag,

  /// Dragged far enough that the onRefresh callback will run and the dragged
  /// displacement is not yet at the final refresh resting state.
  armed,

  /// While the onRefresh task is running.
  refresh,

  /// 刷新完成
  refreshed,

  /// While the indicator is animating away after refreshing.
  done,
}

/// Signature for a builder that can create a different widget to show in the
/// refresh indicator space depending on the current state of the refresh
/// control and the space available.
///
/// The `refreshTriggerPullDistance` and `refreshIndicatorExtent` parameters are
/// the same values passed into the [EasyRefreshSliverRefreshControl].
///
/// The `pulledExtent` parameter is the currently available space either from
/// overscrolling or as held by the sliver during refresh.
typedef RefreshControlBuilder = Widget Function(
    BuildContext context,
    RefreshMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
    AxisDirection axisDirection,
    bool float,
    Duration completeDuration,
    bool enableInfiniteRefresh,
    bool success,
    bool noMore);

/// A callback function that's invoked when the [EasyRefreshSliverRefreshControl] is
/// pulled a `refreshTriggerPullDistance`. Must return a [Future]. Upon
/// completion of the [Future], the [EasyRefreshSliverRefreshControl] enters the
/// [RefreshMode.done] state and will start to go away.
typedef OnRefreshCallback = Future<void> Function();

/// 结束刷新
/// success 为是否成功(为false时，noMore无效)
/// noMore 为是否有更多数据
typedef FinishRefresh = void Function({
  bool success,
  bool noMore,
});

/// 绑定刷新指示剂
typedef BindRefreshIndicator = void Function(
    FinishRefresh finishRefresh, VoidCallback resetRefreshState);

/// A sliver widget implementing the iOS-style pull to refresh content control.
class EasyRefreshSliverRefreshControl extends StatefulWidget {
  /// Create a new refresh control for inserting into a list of slivers.
  const EasyRefreshSliverRefreshControl({
    Key key,
    this.refreshTriggerPullDistance = _defaultRefreshTriggerPullDistance,
    this.refreshIndicatorExtent = _defaultRefreshIndicatorExtent,
    @required this.builder,
    this.completeDuration,
    this.onRefresh,
    this.focusNotifier,
    this.taskNotifier,
    this.callRefreshNotifier,
    this.taskIndependence,
    this.bindRefreshIndicator,
    this.enableControlFinishRefresh = false,
    this.enableInfiniteRefresh = false,
    this.enableHapticFeedback = false,
    this.headerFloat = false,
  }) : super(key: key);

  /// The amount of overscroll the scrollable must be dragged to trigger a reload.
  final double refreshTriggerPullDistance;

  /// The amount of space the refresh indicator sliver will keep holding while
  /// [onRefresh]'s [Future] is still running.
  final double refreshIndicatorExtent;

  /// A builder that's called as this sliver's size changes, and as the state
  /// changes.
  final RefreshControlBuilder builder;

  /// Callback invoked when pulled by [refreshTriggerPullDistance].
  final OnRefreshCallback onRefresh;

  /// 完成延时
  final Duration completeDuration;

  /// 绑定刷新指示器
  final BindRefreshIndicator bindRefreshIndicator;

  /// 是否开启控制结束
  final bool enableControlFinishRefresh;

  /// 是否开启无限刷新
  final bool enableInfiniteRefresh;

  /// 开启震动反馈
  final bool enableHapticFeedback;

  /// 滚动状态
  final ValueNotifier<bool> focusNotifier;

  /// 触发刷新状态
  final ValueNotifier<bool> callRefreshNotifier;

  /// 任务状态
  final ValueNotifier<TaskState> taskNotifier;

  /// 是否任务独立
  final bool taskIndependence;

  /// Header浮动
  final bool headerFloat;

  static const double _defaultRefreshTriggerPullDistance = 100.0;
  static const double _defaultRefreshIndicatorExtent = 60.0;

  @override
  _EasyRefreshSliverRefreshControlState createState() =>
      _EasyRefreshSliverRefreshControlState();
}

class _EasyRefreshSliverRefreshControlState
    extends State<EasyRefreshSliverRefreshControl> {
  static const double _inactiveResetOverscrollFraction = 0.1;

  RefreshMode refreshState;

  // [Future] returned by the widget's `onRefresh`.
  Future<void> _refreshTask;

  Future<void> get refreshTask => _refreshTask;

  bool get hasTask {
    return widget.taskIndependence
        ? _refreshTask != null
        : widget.taskNotifier.value.loading ||
            widget.taskNotifier.value.refreshing;
  }

  set refreshTask(Future<void> task) {
    _refreshTask = task;
    if (!widget.taskIndependence && task != null) {
      widget.taskNotifier.value =
          widget.taskNotifier.value.copy(refreshing: true);
    }
    if (!widget.taskIndependence &&
        task == null &&
        widget.refreshIndicatorExtent == double.infinity) {
      print(222);
      widget.taskNotifier.value =
          widget.taskNotifier.value.copy(refreshing: false);
    }
  }

  double latestIndicatorBoxExtent = 0.0;
  bool hasSliverLayoutExtent = false;

  // 滚动焦点
  bool get _focus => widget.focusNotifier.value;

  // 刷新完成
  bool _success;

  // 没有更多数据
  bool _noMore;

  // 列表方向
  ValueNotifier<AxisDirection> _axisDirectionNotifier;

  // 初始化
  @override
  void initState() {
    super.initState();
    refreshState = RefreshMode.inactive;
    _axisDirectionNotifier = ValueNotifier<AxisDirection>(AxisDirection.down);
    // 绑定刷新指示器
    if (widget.bindRefreshIndicator != null) {
      widget.bindRefreshIndicator(finishRefresh, resetRefreshState);
    }
    widget.callRefreshNotifier.addListener(() {
      if (widget.callRefreshNotifier.value) {
        refreshState = RefreshMode.inactive;
      }
    });
    // 监听是否触发加载
    widget.taskNotifier.addListener(() {
      if (widget.taskNotifier.value.loading && !widget.taskIndependence) {
        setState(() {});
      }
    });
  }

  // 销毁
  @override
  void dispose() {
    _axisDirectionNotifier.dispose();
    super.dispose();
  }

  // 完成刷新
  void finishRefresh({
    bool success,
    bool noMore,
  }) {
    _success = success;
    _noMore = _success == false ? false : noMore;
    widget.taskNotifier.value =
        widget.taskNotifier.value.copy(refreshNoMore: _noMore);
    if (widget.enableControlFinishRefresh && refreshTask != null) {
      if (widget.enableInfiniteRefresh) {
        refreshState = RefreshMode.inactive;
      }
      setState(() => refreshTask = null);
      refreshState = transitionNextState();
    }
  }

  // 恢复状态
  void resetRefreshState() {
    if (mounted) {
      setState(() {
        _success = true;
        _noMore = false;
        refreshState = RefreshMode.inactive;
        hasSliverLayoutExtent = false;
      });
    }
  }

  // 无限刷新
  void _infiniteRefresh() {
    if (widget.callRefreshNotifier.value) {
      widget.callRefreshNotifier.value = false;
    }
    if (!hasTask && widget.enableInfiniteRefresh && _noMore != true) {
      if (widget.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      SchedulerBinding.instance.addPostFrameCallback((Duration timestamp) {
        refreshState = RefreshMode.refresh;
        refreshTask = widget.onRefresh()
          ..then((_) {
            if (mounted && !widget.enableControlFinishRefresh) {
              refreshState = RefreshMode.refresh;
              setState(() => refreshTask = null);
              refreshState = transitionNextState();
            }
          });
        setState(() => hasSliverLayoutExtent = true);
      });
    }
  }

  // A state machine transition calculator. Multiple states can be transitioned
  // through per single call.
  RefreshMode transitionNextState() {
    RefreshMode nextState;
    // 结束
    void goToDone() {
      nextState = RefreshMode.done;
      refreshState = RefreshMode.done;
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        setState(() => hasSliverLayoutExtent = false);
      } else {
        SchedulerBinding.instance.addPostFrameCallback((Duration timestamp) {
          if (mounted) setState(() => hasSliverLayoutExtent = false);
        });
      }
      if (!widget.taskIndependence) {
        widget.taskNotifier.value =
            widget.taskNotifier.value.copy(refreshing: false);
      }
    }

    // 完成
    RefreshMode goToFinish() {
      // 判断刷新完成
      RefreshMode state = RefreshMode.refreshed;
      // 添加延时
      if (widget.completeDuration == null || widget.enableInfiniteRefresh) {
        goToDone();
        return null;
      } else {
        Future.delayed(widget.completeDuration, () {
          if (mounted) {
            goToDone();
          }
        });
        return state;
      }
    }

    switch (refreshState) {
      case RefreshMode.inactive:
        if (latestIndicatorBoxExtent <= 0 ||
            (!_focus && !widget.callRefreshNotifier.value)) {
          return RefreshMode.inactive;
        } else {
          nextState = RefreshMode.drag;
        }
        continue drag;
      drag:
      case RefreshMode.drag:
        if (latestIndicatorBoxExtent == 0) {
          return RefreshMode.inactive;
        } else if (latestIndicatorBoxExtent <=
            widget.refreshTriggerPullDistance) {
          // 如果未触发刷新则取消固定高度
          if (hasSliverLayoutExtent && !hasTask) {
            SchedulerBinding.instance
                .addPostFrameCallback((Duration timestamp) {
              setState(() => hasSliverLayoutExtent = false);
            });
          }
          return RefreshMode.drag;
        } else {
          // 提前固定高度，防止列表回弹
          SchedulerBinding.instance.addPostFrameCallback((Duration timestamp) {
            if (!hasSliverLayoutExtent) {
              if (mounted) setState(() => hasSliverLayoutExtent = true);
            }
          });
          if (widget.onRefresh != null && !hasTask) {
            if (!_focus) {
              if (widget.callRefreshNotifier.value) {
                widget.callRefreshNotifier.value = false;
              }
              if (widget.enableHapticFeedback) {
                HapticFeedback.mediumImpact();
              }
              // 触发刷新任务
              SchedulerBinding.instance
                  .addPostFrameCallback((Duration timestamp) {
                refreshTask = widget.onRefresh()
                  ..then((_) {
                    if (mounted && !widget.enableControlFinishRefresh) {
                      if (widget.enableInfiniteRefresh) {
                        refreshState = RefreshMode.inactive;
                      }
                      setState(() => refreshTask = null);
                      if (!widget.enableInfiniteRefresh)
                        refreshState = transitionNextState();
                    }
                  });
              });
              return RefreshMode.armed;
            }
            return RefreshMode.drag;
          }
          return RefreshMode.drag;
        }
        // Don't continue here. We can never possibly call onRefresh and
        // progress to the next state in one [computeNextState] call.
        break;
      case RefreshMode.armed:
        if (refreshState == RefreshMode.armed && !hasTask) {
          // 完成
          var state = goToFinish();
          if (state != null) return state;
          continue done;
        }

        if (latestIndicatorBoxExtent != widget.refreshIndicatorExtent) {
          return RefreshMode.armed;
        } else {
          nextState = RefreshMode.refresh;
        }
        continue refresh;
      refresh:
      case RefreshMode.refresh:
        if (refreshTask != null) {
          return RefreshMode.refresh;
        } else {
          // 完成
          var state = goToFinish();
          if (state != null) return state;
        }
        continue done;
      done:
      case RefreshMode.done:
        if (latestIndicatorBoxExtent >
            widget.refreshTriggerPullDistance *
                _inactiveResetOverscrollFraction) {
          return RefreshMode.done;
        } else {
          nextState = RefreshMode.inactive;
        }
        break;
      case RefreshMode.refreshed:
        nextState = refreshState;
        break;
      default:
        break;
    }

    return nextState;
  }

  @override
  Widget build(BuildContext context) {
    return _EasyRefreshSliverRefresh(
      refreshIndicatorLayoutExtent: widget.refreshIndicatorExtent,
      hasLayoutExtent: hasSliverLayoutExtent,
      enableInfiniteRefresh: widget.enableInfiniteRefresh,
      infiniteRefresh: _infiniteRefresh,
      headerFloat: widget.headerFloat,
      axisDirectionNotifier: _axisDirectionNotifier,
      // A LayoutBuilder lets the sliver's layout changes be fed back out to
      // its owner to trigger state changes.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 判断是否有加载任务
          if (!widget.taskIndependence && widget.taskNotifier.value.loading) {
            return SizedBox();
          }
          // 是否为垂直方向
          bool isVertical =
              _axisDirectionNotifier.value == AxisDirection.down ||
                  _axisDirectionNotifier.value == AxisDirection.up;
          latestIndicatorBoxExtent =
              isVertical ? constraints.maxHeight : constraints.maxWidth;
          print('latestIndicatorBoxExtent: $latestIndicatorBoxExtent');
          refreshState = transitionNextState();
          if (widget.builder != null && latestIndicatorBoxExtent >= 0) {
            return widget.builder(
              context,
              refreshState,
              latestIndicatorBoxExtent,
              widget.refreshTriggerPullDistance,
              widget.refreshIndicatorExtent,
              _axisDirectionNotifier.value,
              widget.headerFloat,
              widget.completeDuration,
              widget.enableInfiniteRefresh,
              _success ?? true,
              _noMore ?? false,
            );
          }
          return Container();
        },
      ),
    );
  }
}
