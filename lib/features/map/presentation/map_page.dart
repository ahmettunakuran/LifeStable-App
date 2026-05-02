import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of('map')),
      ),
      body: Center(
        child: Text(S.of('map_placeholder')),
      ),
    );
  }
}

