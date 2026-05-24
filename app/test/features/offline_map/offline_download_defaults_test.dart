// Tests untuk default zoom range download offline.
//
// PR #40 — pertama kali hardcode-kan range default ke 8-18 supaya
// user tidak dapat blank tile saat zoom > download_max.
//
// PR #41 — turunkan max ke 16 setelah audit menemukan 8-18
// menghasilkan download ±4 GB untuk area 50×50 km dan ±17 GB di
// HP retina (karena retina +1 compensation). Tidak realistis untuk
// mobile. Trade-off: di display zoom > 16 saat offline, tile akan
// stretched dari z=16 (mild blur).
//
// Test ini lock value-nya supaya developer yang ubah tanpa
// koordinasi dengan estimasi storage / live maxNativeZoom dapat
// CI fail duluan.

import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/features/offline_map/data/tile_cache_service.dart';

void main() {
  group('OfflineDownloadDefaults', () {
    test('minZoom is 8 (regional view yang berguna untuk fishing)', () {
      expect(OfflineDownloadDefaults.minZoom, 8);
    });

    test('maxZoom is 16 (sweet spot antara detail vs ukuran download)', () {
      // PR #41: 16 dipilih supaya download area medium (50×50 km)
      // muat di ±280 MB. Untuk display zoom 17-20 saat offline,
      // flutter_map akan stretched tile dari z=16 (blur ringan).
      // Live TileLayer maxNativeZoom: 19 — saat online tetap fetch
      // tile sharp dari network.
      expect(OfflineDownloadDefaults.maxZoom, 16);
    });

    test('range tidak terlalu lebar (efek storage size manageable)', () {
      final range =
          OfflineDownloadDefaults.maxZoom - OfflineDownloadDefaults.minZoom;
      // 8 levels = 4^8 = ~65K tiles untuk full earth (di luar bounds
      // tentu jauh lebih kecil). Cukup untuk coast/channel detail
      // tanpa membuat download multi-GB.
      expect(range, lessThanOrEqualTo(10));
      expect(range, greaterThanOrEqualTo(6));
    });
  });
}
