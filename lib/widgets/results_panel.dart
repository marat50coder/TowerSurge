import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../game/tower_game.dart';

/// Right hand column listing the multiplier of every floor of the round,
/// newest on top, exactly like the original game.
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({super.key, required this.results});

  final List<FloorEntry> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    final visible = results.take(7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6),
          child: Text(
            'Results',
            style: T.black(
              13.5,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x88103048),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
        for (final entry in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _Pill(entry: entry),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.entry});

  final FloorEntry entry;

  @override
  Widget build(BuildContext context) {
    final failed = entry.multiplier == 0;
    final background = failed
        ? const Color(0xB3A03A32)
        : P.pill.withValues(alpha: 0.62);
    final border = failed ? const Color(0xFFF19A92) : P.pillBorder;
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (entry.kind == FloorKind.temple)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(
                Icons.star_rounded,
                size: 13,
                color: Color(0xFFFFE07A),
              ),
            ),
          Text(
            fmtMultiplier(entry.multiplier),
            style: T.black(14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
