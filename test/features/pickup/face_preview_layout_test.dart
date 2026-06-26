import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/features/pickup/page/pickup_verification_page.dart';

void main() {
  test('face preview display aspect ratio reverses camera preview size', () {
    final aspectRatio = facePreviewDisplayAspectRatio(const Size(720, 1280));

    expect(aspectRatio, closeTo(1280 / 720, 0.0001));
  });

  test(
    'face preview cover size fills container width for narrow camera preview',
    () {
      final size = facePreviewCoverSize(
        containerSize: const Size(257, 330),
        previewAspectRatio: 9 / 16,
      );

      expect(size.width, 257);
      expect(size.height, greaterThan(330));
    },
  );

  test(
    'face preview cover size fills container height for wide camera preview',
    () {
      final size = facePreviewCoverSize(
        containerSize: const Size(257, 330),
        previewAspectRatio: 16 / 9,
      );

      expect(size.width, greaterThan(257));
      expect(size.height, 330);
    },
  );
}
