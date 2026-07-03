import 'package:flutter/material.dart';


@immutable
class TabPlayerAssets {
  final String rightPlayerAsset;

  const TabPlayerAssets({
    required this.rightPlayerAsset,
  });
}


class BackgroundManager<T> {
  BackgroundManager({
    required this.leftPlayerAsset,
    required this.tabAssets,
  });


  final String leftPlayerAsset;


  final Map<T, TabPlayerAssets> tabAssets;

  bool _isPrecached = false;

  bool get isPrecached => _isPrecached;


  Future<void> precacheAll(BuildContext context) async {
    if (_isPrecached) return;

    final futures = <Future<void>>[];

    // Static left player
    futures.add(
      precacheImage(
        AssetImage(leftPlayerAsset),
        context,
      ),
    );

    // Right players
    for (final assets in tabAssets.values) {
      futures.add(
        precacheImage(
          AssetImage(assets.rightPlayerAsset),
          context,
        ),
      );
    }

    await Future.wait(futures);

    _isPrecached = true;
  }


  String rightPlayerFor(T tab) {
    final asset = tabAssets[tab];

    if (asset == null) {
      throw Exception(
        'No player asset registered for tab: $tab',
      );
    }

    return asset.rightPlayerAsset;
  }
}