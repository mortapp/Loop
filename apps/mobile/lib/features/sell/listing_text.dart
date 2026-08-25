import '../../core/utils/money.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';

/// The one canonical text representation of an item's listing, shared by
/// Copy/Share/Export. Mirrors `buildListingText` in
/// apps/web/src/app/(app)/sell/listing-text.ts field-for-field.
///
/// Deliberately excludes ids, account ids, Storage paths, and every other
/// backend/authorization detail — this text is meant to leave the device.
String buildListingText({
  required Item item,
  ValuationRow? valuation,
  List<ListingRow> listings = const [],
}) {
  final lines = <String>[item.name];

  final details = [
    item.category,
    item.condition,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  if (details.isNotEmpty) lines.add(details);

  final activeListing = listings.where(
    (l) => l.status == ListingStatus.draft || l.status == ListingStatus.active,
  );
  if (activeListing.isNotEmpty) {
    final listing = activeListing.first;
    final price = listing.listPriceCents;
    lines.add(
      price != null
          ? 'Asking ${MoneyUtils.formatCents(price)} on ${listing.marketplace}'
          : 'Listed on ${listing.marketplace}',
    );
  } else if (valuation != null) {
    lines.add(
      'Estimated value ${MoneyUtils.formatCents(valuation.estimatedValueCents)}',
    );
  }

  return lines.join('\n');
}
