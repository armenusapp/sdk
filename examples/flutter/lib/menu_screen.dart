import 'dart:io' show Platform;

import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';

/// The dish grid.
///
/// Cards show the poster image rather than a live renderer: mounting a platform
/// view per cell would put a GPU surface and a mesh in every visible tile to
/// display what a still image already displays. The model belongs on the detail
/// screen, where the user has asked for it.
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.client,
    required this.onSelect,
    this.merchantId,
  });

  final ArmenusClient client;
  final String? merchantId;
  final void Function(EmbedItem item) onSelect;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late Future<_Menu> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Menu> _load() async {
    /*
     * config() first, always. It is the only call that distinguishes "this key
     * is revoked" from "this menu is empty" — and a bad key presenting as a
     * restaurant that sells nothing is the most confusing way for an
     * integration to fail.
     */
    final config = await widget.client.config();
    final merchantId = widget.merchantId ?? config.merchants.first.id;

    final items = await widget.client.items(
      merchantId,
      withModel: true,
      limit: 30,
    );

    /*
     * Warm the cache for the first screenful.
     *
     * Quick Look cannot read a remote URL, so this download must happen before
     * AR can open at all — only its timing is ours. Doing it now is the
     * difference between an AR button that opens instantly and one that stalls
     * on first tap.
     */
    for (final item in items.take(8)) {
      final url = Platform.isIOS ? item.model?.usdzUrl : item.model?.glbUrl;
      if (url != null) {
        // Fire and forget: a failed warm-up is not a failure, since the AR
        // path downloads on demand anyway.
        ArmenusAr.prefetch(url);
      }
    }

    return _Menu(ownerName: config.ownerName, items: items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_Menu>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final error = snapshot.error;
            if (error != null) {
              return _Problem(
                title: error is ArmenusException && error.isAuthError
                    ? 'That key did not work'
                    : 'Could not load the menu',
                detail: error is ArmenusException
                    ? error.message
                    : error.toString(),
              );
            }

            final menu = snapshot.data!;
            if (menu.items.isEmpty) {
              return const _Problem(
                title: 'No dishes with models yet',
                detail:
                    'A normal state, not an error — models are built after upload.',
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.ownerName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: Color(0xFF6B645C),
                          ),
                        ),
                        const Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _Card(
                        item: menu.items[index],
                        onTap: () => widget.onSelect(menu.items[index]),
                      ),
                      childCount: menu.items.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Menu {
  const _Menu({required this.ownerName, required this.items});

  final String ownerName;
  final List<EmbedItem> items;
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onTap});

  final EmbedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final poster = item.model?.posterUrl ?? item.imageUrl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4DFD5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: const Color(0xFFF0ECE4),
                  width: double.infinity,
                  child: poster == null
                      ? null
                      : Image.network(poster, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${(item.priceCents / 100).toStringAsFixed(2)} ${item.merchant.currency}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B645C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
