import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Use the app icon (same as launcher icon) as splash image
  final iconBytes = File('app-icon/ic_launcher_xxxhdpi_192x192 (1).png').readAsBytesSync();
  final icon = img.decodePng(iconBytes)!;

  // Create 512x512 image with black background and icon centered
  final canvas = img.Image(width: 512, height: 512, numChannels: 4);

  // Fill with black
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));

  // Draw icon centered
  final offsetX = (512 - icon.width) ~/ 2;
  final offsetY = (512 - icon.height) ~/ 2;
  img.compositeImage(canvas, icon, dstX: offsetX, dstY: offsetY);

  File('assets/splash_icon.png').writeAsBytesSync(img.encodePng(canvas));
  print('Done: created assets/splash_icon.png (512x512, black bg, centered icon)');
}
