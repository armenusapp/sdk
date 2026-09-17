import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';

/// One dish, with AR.
///
/// `interactionEnabled` is left on here because this is a full screen, not a
/// list cell. Inside a scrollable it must be false, or the platform view and
/// the scrollable fight over every vertical drag.
class DishScreen extends StatelessWidget {
  const DishScreen({super.key, required this.item});

  final EmbedItem item;

  @override
  Widget build(BuildContext context) {
    final model = item.model;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArmenusModel(
              item: item,
              arLabel: 'See it on your table',
              onEnterAr: (dish) {
                // Your analytics. Fires on activation, not when the button
                // merely appears.
                debugPrint('AR opened: ${dish.id}');
              },
              onError: (message) => debugPrint('Armenus: $message'),
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(item.priceCents / 100).toStringAsFixed(2)} ${item.merchant.currency}',
                  style: const TextStyle(fontSize: 17),
                ),
              ],
            ),

            if (item.description != null) ...[
              const SizedBox(height: 10),
              Text(
                item.description!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF4A453F),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Text(
              model == null
                  ? 'This dish does not have a 3D model yet.'
                  : 'Shown at actual size — '
                      '${(model.physicalSizeM * 100).round()} cm across.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B645C)),
            ),

            /*
             * The one unsupported case worth a hopeful message: on iOS a model
             * whose USDZ has not converted yet has nothing SceneKit can draw,
             * so the preview above is showing a photograph rather than a mesh.
             * It resolves by itself in a minute or two.
             */
            if (model != null && model.usdzStatus == UsdzStatus.processing) ...[
              const SizedBox(height: 8),
              const Text(
                'The AR version is still being prepared.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B645C)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
