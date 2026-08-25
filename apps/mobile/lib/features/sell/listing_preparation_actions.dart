import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import 'listing_text.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';

/// Real listing preparation, not a fake marketplace publish: Copy puts the
/// canonical listing text on the clipboard, Share opens the native share
/// sheet, and Export shares the same text as a `.txt` file. There is no
/// third-party marketplace integration behind any of these.
class ListingPreparationActions extends StatefulWidget {
  const ListingPreparationActions({
    super.key,
    required this.item,
    this.valuation,
    this.listings = const [],
  });

  final Item item;
  final ValuationRow? valuation;
  final List<ListingRow> listings;

  @override
  State<ListingPreparationActions> createState() =>
      _ListingPreparationActionsState();
}

class _ListingPreparationActionsState extends State<ListingPreparationActions> {
  bool _busy = false;

  String get _listingText => buildListingText(
    item: widget.item,
    valuation: widget.valuation,
    listings: widget.listings,
  );

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      await Clipboard.setData(ClipboardData(text: _listingText));
      if (!mounted) return;
      showErrorSnackBar(context, 'Listing copied.');
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('copy this listing'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await SharePlus.instance.share(
        ShareParams(text: _listingText, subject: widget.item.name),
      );
      // A completed share (or an intentional dismiss) is not reported as an
      // error, but it is never claimed as "shared" either — the share sheet
      // opening is the only thing this app can actually confirm.
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('share this listing'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = Uint8List.fromList(utf8.encode(_listingText));
      final file = XFile.fromData(
        bytes,
        mimeType: 'text/plain',
        name: 'listing.txt',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: const ['listing.txt'],
          subject: widget.item.name,
        ),
      );
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('export this listing'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _copy,
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('Copy'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.ios_share, size: 16),
          label: const Text('Share'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export'),
        ),
      ],
    );
  }
}
