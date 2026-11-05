import 'package:flutter/material.dart';

Widget content(List<Widget> children, {Future<void> Function()? onRefresh}) {
  final listView = ListView(
    physics: const AlwaysScrollableScrollPhysics(), // 짧은 화면에서도 당겨서 새로고침(Pull-to-Refresh) 가능
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: children,
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
