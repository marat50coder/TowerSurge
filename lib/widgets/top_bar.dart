import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sfx.dart';
import 'hazard.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.balance,
    required this.roundId,
    required this.onMenu,
  });

  final double balance;
  final int roundId;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: topInset + 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TopBarTexture(),
          Padding(
            padding: EdgeInsets.only(top: topInset, left: 14, right: 16),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Sfx.i.play(Sfx.click);
                    onMenu();
                  },
                  child: SizedBox(
                    width: 40,
                    height: 46,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        3,
                        (i) => Container(
                          width: 22,
                          height: 2.6,
                          margin: const EdgeInsets.symmetric(vertical: 2.4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ID : $roundId',
                      style: T.bold(10.5, color: const Color(0xFFB9B7B0)),
                    ),
                    const SizedBox(height: 1),
                    Text('${fmtAmount(balance)} FUN', style: T.black(16.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
