import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of('alerts')),
      ),
      body: Center(
        child: Text(S.of('alerts_placeholder')),
      ),
    );
  }
}

