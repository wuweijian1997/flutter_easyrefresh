import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../easy_refresh.dart';

/// Header
abstract class Header {
  /// Header容器高度
  final double extent;

  /// 触发刷新高度
  final double triggerDistance;

  /// 是否浮动
  final bool float;

  /// 完成延时
  final Duration completeDuration;

  /// 是否开启无限刷新
  final bool enableInfiniteRefresh;

  /// 开启震动反馈
  final bool enableHapticFeedback;

  /// 越界滚动(enableInfiniteRefresh为true生效)
  final bool overScroll;

  Header({
    this.extent = 60.0,
    this.triggerDistance = 70.0,
    this.float = false,
    this.completeDuration,
    this.enableInfiniteRefresh = false,
    this.enableHapticFeedback = false,
    this.overScroll = true,
  });

  // 构造器
  Widget builder(BuildContext context,
      EasyRefresh easyRefresh,
      ValueNotifier<bool> focusNotifier,
      ValueNotifier<TaskState> taskNotifier,
      ValueNotifier<bool> callRefreshNotifier) {
    return EasyRefreshSliverRefreshControl(
      refreshIndicatorExtent: extent,
      refreshTriggerPullDistance: triggerDistance,
      builder: contentBuilder,
      completeDuration: completeDuration,
      onRefresh: easyRefresh.onRefresh,
      focusNotifier: focusNotifier,
      taskNotifier: taskNotifier,
      callRefreshNotifier: callRefreshNotifier,
      taskIndependence: easyRefresh.taskIndependence,
      enableControlFinishRefresh: easyRefresh.enableControlFinishRefresh,
      enableInfiniteRefresh: enableInfiniteRefresh && !float,
      enableHapticFeedback: enableHapticFeedback,
      headerFloat: float,
      bindRefreshIndicator: (finishRefresh, resetRefreshState) {
        if (easyRefresh.controller != null) {
          easyRefresh.controller.finishRefreshCallBack = finishRefresh;
          easyRefresh.controller.resetRefreshStateCallBack = resetRefreshState;
        }
      },
    );
  }

  // Header构造器
  Widget contentBuilder(BuildContext context,
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
}

/// 通知器Header
class NotificationHeader extends Header {
  /// Header
  final Header header;

  /// 通知器
  final LinkHeaderNotifier notifier;

  NotificationHeader({
    @required this.header,
    this.notifier,
  })
      : assert(
  header != null,
  'A non-null Header must be provided to a NotifierHeader.',
  ),
        super(
        extent: header.extent,
        triggerDistance: header.triggerDistance,
        float: header.float,
        completeDuration: header.completeDuration,
        enableInfiniteRefresh: header.enableInfiniteRefresh,
        enableHapticFeedback: header.enableHapticFeedback,
      );

  @override
  Widget contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    // 发起通知
    this.notifier?.contentBuilder(
        context,
        refreshState,
        pulledExtent,
        refreshTriggerPullDistance,
        refreshIndicatorExtent,
        axisDirection,
        float,
        completeDuration,
        enableInfiniteRefresh,
        success,
        noMore);
    return header.contentBuilder(
        context,
        refreshState,
        pulledExtent,
        refreshTriggerPullDistance,
        refreshIndicatorExtent,
        axisDirection,
        float,
        completeDuration,
        enableInfiniteRefresh,
        success,
        noMore);
  }
}

/// 通用Header
class CustomHeader extends Header {
  /// Header构造器
  final RefreshControlBuilder headerBuilder;

  CustomHeader({
    extent = 60.0,
    triggerDistance = 70.0,
    float = false,
    completeDuration,
    enableInfiniteRefresh = false,
    enableHapticFeedback = false,
    @required this.headerBuilder,
  }) : super(
    extent: extent,
    triggerDistance: triggerDistance,
    float: float,
    completeDuration: completeDuration,
    enableInfiniteRefresh: enableInfiniteRefresh,
    enableHapticFeedback: enableHapticFeedback,
  );

  @override
  Widget contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    return headerBuilder(
        context,
        refreshState,
        pulledExtent,
        refreshTriggerPullDistance,
        refreshIndicatorExtent,
        axisDirection,
        float,
        completeDuration,
        enableInfiniteRefresh,
        success,
        noMore);
  }
}

/// 链接通知器
class LinkHeaderNotifier extends ChangeNotifier {
  BuildContext context;
  RefreshMode refreshState = RefreshMode.inactive;
  double pulledExtent = 0.0;
  double refreshTriggerPullDistance;
  double refreshIndicatorExtent;
  AxisDirection axisDirection;
  bool float;
  Duration completeDuration;
  bool enableInfiniteRefresh;
  bool success = true;
  bool noMore = false;

  void contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    this.context = context;
    this.refreshState = refreshState;
    this.pulledExtent = pulledExtent;
    this.refreshTriggerPullDistance = refreshTriggerPullDistance;
    this.refreshIndicatorExtent = refreshIndicatorExtent;
    this.axisDirection = axisDirection;
    this.float = float;
    this.completeDuration = completeDuration;
    this.enableInfiniteRefresh = enableInfiniteRefresh;
    this.success = success;
    this.noMore = noMore;
    SchedulerBinding.instance.addPostFrameCallback((Duration timestamp) {
      notifyListeners();
    });
  }
}

/// 链接器Header
class LinkHeader extends Header {
  final LinkHeaderNotifier linkNotifier;

  LinkHeader(this.linkNotifier, {
    extent = 60.0,
    triggerDistance = 70.0,
    completeDuration,
    enableHapticFeedback = false,
  }) : super(
    extent: extent,
    triggerDistance: triggerDistance,
    float: true,
    completeDuration: completeDuration,
    enableHapticFeedback: enableHapticFeedback,
  );

  @override
  Widget contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    linkNotifier.contentBuilder(
        context,
        refreshState,
        pulledExtent,
        refreshTriggerPullDistance,
        refreshIndicatorExtent,
        axisDirection,
        float,
        completeDuration,
        enableInfiniteRefresh,
        success,
        noMore);
    return SizedBox(
      width: 0.0,
      height: 0.0,
    );
  }
}

/// 经典Header
class ClassicalHeader extends Header {
  /// Key
  final Key key;

  /// 方位
  final AlignmentGeometry alignment;

  /// 提示刷新文字
  final String refreshText;

  /// 准备刷新文字
  final String refreshReadyText;

  /// 正在刷新文字
  final String refreshingText;

  /// 刷新完成文字
  final String refreshedText;

  /// 刷新失败文字
  final String refreshFailedText;

  /// 没有更多文字
  final String noMoreText;

  /// 显示额外信息(默认为时间)
  final bool showInfo;

  /// 更多信息
  final String infoText;

  /// 背景颜色
  final Color bgColor;

  /// 字体颜色
  final Color textColor;

  /// 更多信息文字颜色
  final Color infoColor;

  ClassicalHeader({
    double extent = 60.0,
    double triggerDistance = 70.0,
    bool float = false,
    Duration completeDuration = const Duration(seconds: 1),
    bool enableInfiniteRefresh = false,
    bool enableHapticFeedback = true,
    bool overScroll = true,
    this.key,
    this.alignment,
    this.refreshText,
    this.refreshReadyText,
    this.refreshingText,
    this.refreshedText,
    this.refreshFailedText,
    this.noMoreText,
    this.showInfo: true,
    this.infoText,
    this.bgColor: Colors.transparent,
    this.textColor: Colors.black,
    this.infoColor: Colors.teal,
  }) : super(
    extent: extent,
    triggerDistance: triggerDistance,
    float: float,
    completeDuration: float
        ? completeDuration == null
        ? Duration(
      milliseconds: 400,
    )
        : completeDuration +
        Duration(
          milliseconds: 400,
        )
        : completeDuration,
    enableInfiniteRefresh: enableInfiniteRefresh,
    enableHapticFeedback: enableHapticFeedback,
    overScroll: overScroll,
  );

  @override
  Widget contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    return ClassicalHeaderWidget(
      key: key,
      classicalHeader: this,
      refreshState: refreshState,
      pulledExtent: pulledExtent,
      refreshTriggerPullDistance: refreshTriggerPullDistance,
      refreshIndicatorExtent: refreshIndicatorExtent,
      axisDirection: axisDirection,
      float: float,
      completeDuration: completeDuration,
      enableInfiniteRefresh: enableInfiniteRefresh,
      success: success,
      noMore: noMore,
    );
  }
}

/// 经典Header组件
class ClassicalHeaderWidget extends StatefulWidget {
  final ClassicalHeader classicalHeader;
  final RefreshMode refreshState;

  ///下拉的范围
  final double pulledExtent;
  final double refreshTriggerPullDistance;

  ///刷新指示器范围
  final double refreshIndicatorExtent;
  final AxisDirection axisDirection;
  final bool float;
  final Duration completeDuration;
  final bool enableInfiniteRefresh;
  final bool success;
  final bool noMore;

  ClassicalHeaderWidget({Key key,
    this.refreshState,
    this.classicalHeader,
    this.pulledExtent,
    this.refreshTriggerPullDistance,
    this.refreshIndicatorExtent,
    this.axisDirection,
    this.float,
    this.completeDuration,
    this.enableInfiniteRefresh,
    this.success,
    this.noMore})
      : super(key: key);

  @override
  ClassicalHeaderWidgetState createState() => ClassicalHeaderWidgetState();
}

class ClassicalHeaderWidgetState extends State<ClassicalHeaderWidget>
    with TickerProviderStateMixin<ClassicalHeaderWidget> {
  // 是否到达触发刷新距离
  bool _overTriggerDistance = false;

  bool get overTriggerDistance => _overTriggerDistance;

  set overTriggerDistance(bool over) {
    if (_overTriggerDistance != over) {
      _overTriggerDistance ? _controller.forward() : _controller.reverse();
      _overTriggerDistance = over;
    }
  }

  /// 文本
  String get _refreshText {
    return widget.classicalHeader.refreshText ?? 'Pull to refresh';
  }

  String get _refreshReadyText {
    return widget.classicalHeader.refreshReadyText ?? 'Release to refresh';
  }

  String get _refreshingText {
    return widget.classicalHeader.refreshingText ?? 'Refreshing...';
  }

  String get _refreshedText {
    return widget.classicalHeader.refreshedText ?? 'Refresh completed';
  }

  String get _refreshFailedText {
    return widget.classicalHeader.refreshFailedText ?? 'Refresh failed';
  }

  String get _noMoreText {
    return widget.classicalHeader.noMoreText ?? 'No more';
  }

  // 是否刷新完成
  bool _refreshFinish = false;

  set refreshFinish(bool finish) {
    if (_refreshFinish != finish) {
      _refreshFinish = finish;
    }
  }

  // 动画
  AnimationController _controller;

  // 显示文字
  String get _showText {
    if (widget.noMore) return _noMoreText;
    if (widget.enableInfiniteRefresh) {
      if (widget.refreshState == RefreshMode.refreshed ||
          widget.refreshState == RefreshMode.inactive ||
          widget.refreshState == RefreshMode.drag) {
        return _finishedText;
      } else {
        return _refreshingText;
      }
    }
    switch (widget.refreshState) {
      case RefreshMode.refresh:
        return _refreshingText;
      case RefreshMode.armed:
        return _refreshingText;
      case RefreshMode.refreshed:
        return _finishedText;
      case RefreshMode.done:
        return _finishedText;
      default:
        if (overTriggerDistance) {
          return _refreshReadyText;
        } else {
          return _refreshText;
        }
    }
  }

  // 刷新结束文字
  String get _finishedText {
    if (!widget.success) return _refreshFailedText;
    if (widget.noMore) return _noMoreText;
    return _refreshedText;
  }

  // 刷新结束图标
  IconData get _finishedIcon {
    if (!widget.success) return Icons.error_outline;
    if (widget.noMore) return Icons.hourglass_empty;
    return Icons.done;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        value: 1,
        lowerBound: .5,
        upperBound: 1,
        duration: const Duration(milliseconds: 200),
        vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 是否到达触发刷新距离
    overTriggerDistance = widget.refreshState != RefreshMode.inactive &&
        widget.pulledExtent >= widget.refreshTriggerPullDistance;
    if (widget.refreshState == RefreshMode.refreshed) {
      refreshFinish = true;
    }
    return Stack(
      children: <Widget>[
        Positioned(
          top: null,
          bottom: .0,
          left: 0,
          right: 0,
          child: Container(
            alignment: Alignment.bottomCenter,
            width: double.infinity,
            height: max(widget.refreshIndicatorExtent, widget.pulledExtent),
            color: widget.classicalHeader.bgColor,
            child: SizedBox(
              height: widget.refreshIndicatorExtent,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建显示内容
  List<Widget> _buildContent() {
    return <Widget>[
      Expanded(
        flex: 2,
        child: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(
            right: 10.0,
          ),
          child: (widget.refreshState == RefreshMode.refresh ||
              widget.refreshState == RefreshMode.armed) &&
              !widget.noMore
              ? Container(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation(
                widget.classicalHeader.textColor,
              ),
            ),
          )
              : widget.refreshState == RefreshMode.refreshed ||
              widget.refreshState == RefreshMode.done ||
              (widget.enableInfiniteRefresh &&
                  widget.refreshState != RefreshMode.refreshed) ||
              widget.noMore
              ? Icon(
            _finishedIcon,
            color: widget.classicalHeader.textColor,
          )
              : AnimatedBuilder(
            animation: _controller,
            builder: (_, Widget child) {
              return Transform.rotate(
                child: child,
                angle: 2 * pi * _controller.value,
              );
            },
            child: Icon(
              Icons.arrow_downward,
              color: widget.classicalHeader.textColor,
            ),
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _showText,
              style: TextStyle(
                fontSize: 16.0,
                color: widget.classicalHeader.textColor,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        flex: 2,
        child: SizedBox(),
      ),
    ];
  }
}

/// 首次刷新Header
class FirstRefreshHeader extends Header {
  /// 子组件
  final Widget child;

  FirstRefreshHeader(this.child)
      : super(
    extent: double.infinity,
    triggerDistance: 60.0,
    float: true,
    enableInfiniteRefresh: false,
    enableHapticFeedback: false,
  );

  @override
  Widget contentBuilder(BuildContext context,
      RefreshMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
      AxisDirection axisDirection,
      bool float,
      Duration completeDuration,
      bool enableInfiniteRefresh,
      bool success,
      bool noMore) {
    return (refreshState == RefreshMode.armed ||
        refreshState == RefreshMode.refresh) &&
        pulledExtent >
            refreshTriggerPullDistance + EasyRefresh.callOverExtent
        ? child
        : Container();
  }
}
