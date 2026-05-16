import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/export_service.dart';
import '../domain/entities/export_filter.dart';

/// Reactive provider untuk ringkasan "isi yang akan diekspor"
/// (PR #27 R5) di footer ExportScreen.
///
/// Family-keyed by [ExportFilter] (yang implement value equality),
/// jadi setiap perubahan filter di UI otomatis trigger recompute.
/// `autoDispose` supaya snapshot stale di-release saat user tutup
/// screen.
///
/// Tidak ada caching khusus — repo lookups cepat (in-memory Drift)
/// dan `ExportFilter.==`/`hashCode` sudah memastikan tidak duplikasi
/// kerja untuk filter yang identical.
final exportPreviewProvider = FutureProvider.autoDispose
    .family<ExportPreview, ExportFilter>((ref, filter) async {
  final service = ref.watch(exportServiceProvider);
  return service.previewFiltered(filter);
});
