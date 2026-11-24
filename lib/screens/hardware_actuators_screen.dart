import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/title_bar.dart';
import 'dashboard_screen.dart' show HardwareSection;

class HardwareActuatorsScreen extends StatelessWidget {
  const HardwareActuatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar(
        screenName: 'Hardware & Actuators',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: ListView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          children: const [HardwareSection()],
        ),
      ),
    );
  }
}
