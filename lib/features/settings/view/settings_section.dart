import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/theme/theme.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ThemeColors colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.typography.heading.copyWith(color: colors.text),
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < children.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) Container(height: 1, color: colors.line),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({required this.label, required this.control, super.key});

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.typography.body.copyWith(color: theme.colors.text),
              ),
            ),
            const SizedBox(width: 16),
            control,
          ],
        ),
      ),
    );
  }
}
