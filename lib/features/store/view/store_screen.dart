import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/layout/page_scaffold.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PageScaffold(title: context.t.nav.store);
}
