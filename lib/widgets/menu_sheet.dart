import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sfx.dart';
import '../core/store.dart';
import '../game/tower_game.dart';
import '../screens/web_page_screen.dart';
import 'hazard.dart';

Future<void> showGameMenu(BuildContext context, TowerGame game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _MenuSheet(game: game),
  );
}

Future<void> showGameInfo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _InfoSheet(),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child, required this.title});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 30),
      decoration: const BoxDecoration(
        color: P.bottomPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazardStrip(height: 9, stripeWidth: 11),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(title, style: T.black(18))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Flexible(child: child),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}

class _MenuSheet extends StatefulWidget {
  const _MenuSheet({required this.game});

  final TowerGame game;

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Menu',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Column(
          children: [
            Center(
              child: Image.asset(
                'assets/Tower_Surge_additional_assets/Game_Name.webp',
                height: 88,
              ),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Store.i.sound
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              label: 'Sound effects',
              trailing: _Toggle(value: Store.i.sound),
              onTap: () {
                Store.i.sound = !Store.i.sound;
                Sfx.i.play(Sfx.click);
                setState(() {});
              },
            ),
            _MenuTile(
              icon: Store.i.music
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              label: 'Music',
              trailing: _Toggle(value: Store.i.music),
              onTap: () async {
                Store.i.music = !Store.i.music;
                await Sfx.i.applyMusicSetting();
                setState(() {});
              },
            ),
            _MenuTile(
              icon: Icons.help_outline_rounded,
              label: 'How to play',
              onTap: () {
                Navigator.of(context).pop();
                showGameInfo(context);
              },
            ),
            _MenuTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WebPageScreen(
                    title: 'Privacy Policy',
                    url: WebPageScreen.privacyPolicy,
                  ),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.support_agent_rounded,
              label: 'Support',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WebPageScreen(
                    title: 'Support',
                    url: WebPageScreen.support,
                  ),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.restart_alt_rounded,
              label: 'Reset FUN balance',
              onTap: widget.game.phase == Phase.idle
                  ? () {
                      widget.game.resetBalance();
                      Sfx.i.play(Sfx.coin);
                      setState(() {});
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              'Tower Surge · demo play with FUN credits',
              style: T.bold(11.5, color: const Color(0xFF8B8983)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 24,
      decoration: BoxDecoration(
        color: value ? P.blue : const Color(0xFF3C3A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF56534D)),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: P.bottomPanelLight,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap == null
              ? null
              : () {
                  Sfx.i.play(Sfx.click);
                  onTap!();
                },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: P.goldLight, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: T.bold(15))),
                ?trailing,
                if (trailing == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'How to play',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _p(
              'Set your bet with − / +, x2 or ALL IN and press BUILD. The crane '
              'releases a floor onto the tower.',
            ),
            _p(
              'Every floor that lands adds its own random multiplier to your '
              'running total. Multipliers can also be below x1, which lowers the '
              'total.',
            ),
            _p(
              'Press CASHOUT between floors to collect bet × current total. If a '
              'floor fails to land, the tower collapses and the round is lost.',
            ),
            const SizedBox(height: 6),
            _title('Bonus floors'),
            _bonus(
              Icons.temple_buddhist_rounded,
              'Temple Floor',
              'Spins a 10 segment wheel that multiplies the running total by x1.5 '
                  'up to x7.',
            ),
            _bonus(
              Icons.layers_rounded,
              'Triple Build',
              'Adds three collapse-proof floors in a row, each with a multiplier of '
                  'x1 or higher.',
            ),
            const SizedBox(height: 10),
            _title('Limits'),
            _row('Maximum win', 'x100 of the bet'),
            _row('Bet range', '100 – 10 000 FUN'),
            _row('Theoretical RTP', '97%'),
            const SizedBox(height: 12),
            Text(
              'Tower Surge is played with FUN credits only. No real money bets, '
              'deposits or payouts are available in this app.',
              style: T.bold(12, color: const Color(0xFF9C9A93)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _p(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: T.bold(13.5, color: const Color(0xFFDCDAD3))),
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: T.black(15.5, color: P.goldLight)),
  );

  Widget _bonus(IconData icon, String name, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: P.ice, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: T.black(14)),
              const SizedBox(height: 2),
              Text(text, style: T.bold(12.5, color: const Color(0xFFBFBDB6))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: T.bold(13, color: const Color(0xFFBFBDB6))),
        Text(value, style: T.black(13, color: Colors.white)),
      ],
    ),
  );
}
