import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Sprite with the transparent padding of the source file measured, so blocks
/// can be stacked pixel perfectly.
class Sprite {
  Sprite(this.image, this.content, {this.seatBottom = 0, this.seatTop = 1});

  final ui.Image image;

  /// Opaque area of the image in pixels.
  final Rect content;

  /// Vertical contact band, as fractions of the content height measured from
  /// the bottom (0 = content bottom, 1 = content top). Hexagonal blocks taper
  /// to a narrow point at the top and bottom; the point is decorative and must
  /// not act as the stacking surface, otherwise the block hovers over an air
  /// gap. [seatBottom] is where the block rests on the floor below and [seatTop]
  /// is where the next floor rests on it.
  final double seatBottom;
  final double seatTop;

  double get aspect => content.width / content.height;

  Size get contentSize => content.size;
}

class GameImages {
  GameImages._();

  static final GameImages i = GameImages._();

  static const _gp = 'assets/Tower_Surge_gameplay_assets';
  static const _add = 'assets/Tower_Surge_additional_assets';

  late Sprite sky;
  late Sprite cityStrip;
  late Sprite hook;
  late Sprite baseBlock;
  late List<Sprite> blocks;
  late List<Sprite> clouds;
  late Sprite buttonBlank;
  late Sprite logo;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Alpha bounding boxes measured offline for the shipped assets.
  static const Map<String, List<double>> _contentBoxes = {
    'block_asset_01': [0, 34, 1024, 1005],
    'block_asset_02': [46, 0, 948, 1024],
    'block_asset_03': [90, 8, 942, 1024],
    'block_asset_04': [0, 0, 1024, 1024],
    'start_block_asset': [0, 0, 970, 1019],
    'hook_asset': [203, 0, 610, 1376],
    'cloud_asset_01': [32, 23, 1567, 646],
    'cloud_asset_02': [24, 27, 1583, 649],
  };

  /// Contact band `[seatBottom, seatTop]` per block, measured from the alpha
  /// width profile: the range where the block is close to its full width.
  /// Only block_asset_01 needs it — it is a hexagon whose top and bottom are
  /// narrow points, so it nestles into its neighbours. Every other block is
  /// effectively rectangular and stacks flush (the plain contact physics).
  static const Map<String, List<double>> _seatBands = {
    'block_asset_01': [0.10, 0.95],
  };

  Future<void> load({void Function(double progress)? onProgress}) async {
    if (_loaded) {
      onProgress?.call(1);
      return;
    }
    final paths = <String>[
      '$_gp/bg_sky_asset.webp',
      '$_gp/start_bg_asset.webp',
      '$_gp/hook_asset.webp',
      '$_gp/start_block_asset.webp',
      '$_gp/block_asset_01.webp',
      '$_gp/block_asset_02.webp',
      '$_gp/block_asset_03.webp',
      '$_gp/block_asset_04.webp',
      '$_gp/cloud_asset_01.webp',
      '$_gp/cloud_asset_02.webp',
      '$_gp/button_blank.webp',
      '$_add/Game_Name.webp',
    ];

    final sprites = <String, Sprite>{};
    for (var index = 0; index < paths.length; index++) {
      sprites[paths[index]] = await _loadSprite(paths[index]);
      onProgress?.call((index + 1) / paths.length);
    }

    sky = sprites['$_gp/bg_sky_asset.webp']!;
    cityStrip = sprites['$_gp/start_bg_asset.webp']!;
    hook = sprites['$_gp/hook_asset.webp']!;
    baseBlock = sprites['$_gp/start_block_asset.webp']!;
    blocks = [
      sprites['$_gp/block_asset_01.webp']!,
      sprites['$_gp/block_asset_02.webp']!,
      sprites['$_gp/block_asset_03.webp']!,
      sprites['$_gp/block_asset_04.webp']!,
    ];
    clouds = [
      sprites['$_gp/cloud_asset_01.webp']!,
      sprites['$_gp/cloud_asset_02.webp']!,
    ];
    buttonBlank = sprites['$_gp/button_blank.webp']!;
    logo = sprites['$_add/Game_Name.webp']!;
    _loaded = true;
  }

  Future<Sprite> _loadSprite(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final key = path.split('/').last.split('.').first;
    final box = _contentBoxes[key];
    final content = box == null
        ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
        : Rect.fromLTRB(box[0], box[1], box[2], box[3]);
    final band = _seatBands[key];
    return Sprite(
      image,
      content,
      seatBottom: band?[0] ?? 0,
      seatTop: band?[1] ?? 1,
    );
  }
}
