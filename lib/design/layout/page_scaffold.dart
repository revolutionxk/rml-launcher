import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/theme/theme.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.title,
    this.children = const <Widget>[],
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.typography.title.copyWith(color: theme.colors.text),
            ),
          ),
          if (children.isNotEmpty) const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
