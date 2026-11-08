import 'package:flutter/material.dart';

class StaggeredListItem extends StatefulWidget {
  final int index;
  final int refreshKey;
  final Widget child;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.refreshKey,
    required this.child,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  static final Set<String> _animatedKeys = {};
  static int _lastSessionTimestamp = 0;
  static int _lastRefreshKey = -1;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 좌측(-0.15)에서 우측(0.0)으로 슬라이드 인
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.15, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (_lastRefreshKey != widget.refreshKey) {
      _lastRefreshKey = widget.refreshKey;
      _lastSessionTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    final itemKey = 'key_${widget.refreshKey}_idx_${widget.index}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastSessionTimestamp;

    // 💡 탭 진입/새로고침 초기 500ms가 지난 후(이후 스크롤 시) 노출되는 하단 위젯들은
    // 이미 탭 로드 시점에 애니메이션이 완성된 상태로 인정하여, 스크롤 시 뒤늦은 애니메이션 발동 완전 차단!
    if (_animatedKeys.contains(itemKey) || elapsed > 500) {
      _animatedKeys.add(itemKey);
      _controller.value = 1.0;
    } else {
      _startAnimation(itemKey);
    }
  }

  @override
  void didUpdateWidget(StaggeredListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _lastRefreshKey = widget.refreshKey;
      _lastSessionTimestamp = DateTime.now().millisecondsSinceEpoch;
      final itemKey = 'key_${widget.refreshKey}_idx_${widget.index}';
      setState(() {
        _isClearing = true;
      });
      _startAnimation(itemKey);
    }
  }

  void _startAnimation(String itemKey) {
    _controller.reset();
    // 상단부터 순차적으로 위젯이 노출되도록 시차(Staggered Delay: index * 45ms) 적용
    final delayMs = (widget.index * 45).clamp(0, 450);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _animatedKeys.add(itemKey);
        setState(() {
          _isClearing = false;
        });
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 새로고침 직후에는 이전 잔상이 남지 않도록 즉시 흰색 비어있는 영역으로 표시
    if (_isClearing) {
      return const SizedBox(height: 60);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

Widget content(
  List<Widget> children, {
  Future<void> Function()? onRefresh,
  int refreshKey = 0,
}) {
  final List<Widget> animatedChildren = [];
  for (int i = 0; i < children.length; i++) {
    animatedChildren.add(
      StaggeredListItem(
        index: i,
        refreshKey: refreshKey,
        child: children[i],
      ),
    );
  }

  final listView = ListView(
    physics: const AlwaysScrollableScrollPhysics(), // 짧은 화면에서도 당겨서 새로고침(Pull-to-Refresh) 가능
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: animatedChildren,
  );

  final body = Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: listView,
    ),
  );

  if (onRefresh != null) {
    return RefreshIndicator(
      color: const Color(0xff146b59),
      onRefresh: onRefresh,
      child: body,
    );
  }

  return body;
}

Widget panel(String title, String description, IconData icon, VoidCallback? onTap) => Card(
  clipBehavior: Clip.antiAlias,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    minLeadingWidth: 44,
    leading: Icon(icon, size: 26),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(description)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ),
);
