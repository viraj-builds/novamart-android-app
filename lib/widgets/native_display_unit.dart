import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/clevertap_models.dart';
import '../services/clevertap_service.dart';

/// Renders every CleverTap Native Display unit targeted at [screen].
///
/// Native Display content is fully dashboard-driven: if no campaign is live for
/// this screen the widget collapses to nothing, so it is safe to drop anywhere
/// in a layout. See https://docs.clevertap.com/docs/native-display
class NativeDisplayPlacement extends StatelessWidget {
  final String screen;

  const NativeDisplayPlacement({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    final units = CleverTapService.instance.unitsForScreen(screen);
    if (units.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: units.map((unit) => NativeDisplayUnitCard(unit: unit)).toList(),
    );
  }
}

/// A single Native Display unit. Raises the impression event once when it first
/// appears and the click event when tapped.
class NativeDisplayUnitCard extends StatefulWidget {
  final CtDisplayUnit unit;

  const NativeDisplayUnitCard({super.key, required this.unit});

  @override
  State<NativeDisplayUnitCard> createState() => _NativeDisplayUnitCardState();
}

class _NativeDisplayUnitCardState extends State<NativeDisplayUnitCard> {
  int _activeIndex = 0;
  String? _viewedUnitId;

  @override
  void initState() {
    super.initState();
    _recordViewed();
  }

  @override
  void didUpdateWidget(NativeDisplayUnitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The widget is recycled when the campaign list changes underneath it.
    if (oldWidget.unit.unitId != widget.unit.unitId) _recordViewed();
  }

  /// Guarded so a rebuild never double-counts an impression.
  void _recordViewed() {
    if (_viewedUnitId == widget.unit.unitId) return;
    _viewedUnitId = widget.unit.unitId;
    CleverTapService.instance.recordDisplayUnitViewed(widget.unit.unitId);
  }

  void _onTap() => CleverTapService.instance.recordDisplayUnitClicked(widget.unit);

  @override
  Widget build(BuildContext context) {
    final isCarousel = widget.unit.contents.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: isCarousel ? _buildCarousel() : _buildCard(widget.unit.primary),
    );
  }

  Widget _buildCarousel() {
    final contents = widget.unit.contents;

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            viewportFraction: 1.0,
            onPageChanged: (index, _) => setState(() => _activeIndex = index),
          ),
          items: contents.map(_buildCard).toList(),
        ),
        const SizedBox(height: 8),
        AnimatedSmoothIndicator(
          activeIndex: _activeIndex,
          count: contents.length,
          effect: const WormEffect(dotHeight: 8, dotWidth: 8),
        ),
      ],
    );
  }

  Widget _buildCard(CtContent content) {
    return GestureDetector(
      onTap: _onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (content.hasMedia)
              CachedNetworkImage(
                imageUrl: content.mediaUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 180, color: Colors.black12),
                errorWidget: (_, __, ___) =>
                    Container(height: 180, color: Colors.black12),
              )
            else
              Container(height: 180, width: double.infinity, color: Colors.blueGrey),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (content.title.isNotEmpty)
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _parseColor(content.titleColor, Colors.white),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (content.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _parseColor(content.messageColor, Colors.white70),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Marks dashboard-driven content so it is distinguishable from
            // hard-coded merchandising during QA.
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CleverTap sends colors as `#RRGGBB`; fall back when a campaign omits them.
  static Color _parseColor(String value, Color fallback) {
    final hex = value.replaceFirst('#', '').trim();
    if (hex.length != 6) return fallback;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }
}
