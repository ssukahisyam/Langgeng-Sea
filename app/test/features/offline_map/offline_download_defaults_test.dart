// PR #40 — tests untuk default zoom range download offline.
//
// Sebelumnya user pilih zoom range sendiri lewat RangeSlider 3-16
// dengan default max 14. Itu menyebabkan banyak user dapat blank tile
// saat zoom > 14 padahal app menampilkan sampai zoom 19. Sekarang
// hardcode 8-18 supaya selalu cocok dengan kebutuhan navigasi laut.
//
// Test ini lock value-nya supaya kalau ada developer yang ubah tanpa
// koordinasi dengan max zoom live map, CI gagal duluan.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/offline_map/data/tile_cache_service.dart';

void main() {
  group('OfflineDownloadDefaults', () {
    test('minZoom is 8 (regional view yang berguna untuk fishing)', () {
      expect(OfflineDownloadDefaults.minZoom, 8);
    });

    test('maxZoom is 18 (close enough to maxNativeZoom 19 di map_screen)', () {
      // Live TileLayer di map_screen pakai maxNativeZoom: 19. Download
      // pakai 18 supaya retina simulation (+1) sampai 19. Kalau
      // maxNativeZoom dinaikkan, default ini juga harus naik.
      expect(OfflineDownloadDefaults.maxZoom, 18);
    });

    test('range tidak terlalu lebar (efek storage size manageable)', () {
      final range =
          OfflineDownloadDefaults.maxZoom - OfflineDownloadDefaults.minZoom;
      // 10 zoom levels = 4^10 = ~1M tiles untuk full earth (di luar
      // bounds tentu jauh lebih kecil). Cukup untuk port-level detail
      // tanpa membuat download multi-GB untuk area medium.
      expect(range, lessThanOrEqualTo(12));
      expect(range, greaterThanOrEqualTo(8));
    });
  });
}
