import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/opening_explorer.dart';
import 'package:lichess_mobile/src/model/analysis/opening_explorer_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/opening_explorer_repository.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/game/game_share_service.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/utils/share.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_share_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

import 'analysis_widgets.dart';
import 'opening_explorer_settings.dart';

class OpeningExplorerScreen extends StatelessWidget {
  const OpeningExplorerScreen({required this.pgn, required this.options});

  final String pgn;
  final AnalysisOptions options;

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      androidBuilder: _androidBuilder,
      iosBuilder: _iosBuilder,
    );
  }

  Widget _androidBuilder(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.openingExplorer),
        actions: [
          AppBarIconButton(
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              isDismissible: true,
              builder: (_) => OpeningExplorerSettings(pgn, options),
            ),
            semanticsLabel: context.l10n.settingsSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _Body(pgn: pgn, options: options),
    );
  }

  Widget _iosBuilder(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Styles.cupertinoScaffoldColor.resolveFrom(context),
        border: null,
        middle: Text(context.l10n.openingExplorer),
        trailing: AppBarIconButton(
          onPressed: () => showAdaptiveBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            isDismissible: true,
            builder: (_) => OpeningExplorerSettings(pgn, options),
          ),
          semanticsLabel: context.l10n.settingsSettings,
          icon: const Icon(Icons.settings),
        ),
      ),
      child: _Body(pgn: pgn, options: options),
    );
  }
}

class _Body extends ConsumerWidget {
  final String pgn;

  final AnalysisOptions options;
  const _Body({required this.pgn, required this.options});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = constraints.biggest.aspectRatio;
                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                return aspectRatio > 1
                    ? Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: kTabletBoardTableSidePadding,
                              top: kTabletBoardTableSidePadding,
                              bottom: kTabletBoardTableSidePadding,
                            ),
                            child: Row(
                              children: [
                                AnalysisBoard(
                                  pgn,
                                  options,
                                  boardSize,
                                  isTablet: isTablet,
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: PlatformCard(
                                    margin: const EdgeInsets.all(
                                      kTabletBoardTableSidePadding,
                                    ),
                                    semanticContainer: false,
                                    child: _OpeningExplorer(
                                      pgn: pgn,
                                      options: options,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isTablet)
                            Padding(
                              padding: const EdgeInsets.all(
                                kTabletBoardTableSidePadding,
                              ),
                              child: AnalysisBoard(
                                pgn,
                                options,
                                boardSize,
                                isTablet: isTablet,
                              ),
                            )
                          else
                            AnalysisBoard(
                              pgn,
                              options,
                              boardSize,
                              isTablet: isTablet,
                            ),
                          Expanded(
                            child: _OpeningExplorer(pgn: pgn, options: options),
                          ),
                        ],
                      );
              },
            ),
          ),
        ),
        _BottomBar(pgn: pgn, options: options),
      ],
    );
  }
}

class _OpeningExplorer extends ConsumerWidget {
  const _OpeningExplorer({
    required this.pgn,
    required this.options,
  });

  final String pgn;
  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(pgn, options);
    final position = ref.watch(ctrlProvider.select((value) => value.position));

    if (position.fullmoves > 24) {
      return const Expanded(
        child: Align(
          alignment: Alignment.center,
          child: Text('Max depth reached'),
        ),
      );
    }

    final isRootNode = ref.watch(
      ctrlProvider.select((s) => s.currentNode.isRoot),
    );
    final nodeOpening =
        ref.watch(ctrlProvider.select((s) => s.currentNode.opening));
    final branchOpening =
        ref.watch(ctrlProvider.select((s) => s.currentBranchOpening));
    final contextOpening =
        ref.watch(ctrlProvider.select((s) => s.contextOpening));
    final opening = isRootNode
        ? LightOpening(
            eco: '',
            name: context.l10n.startPosition,
          )
        : nodeOpening ?? branchOpening ?? contextOpening;

    final openingDb = ref.watch(
      openingExplorerPreferencesProvider.select(
        (state) => state.db,
      ),
    );

    return switch (openingDb) {
      OpeningDatabase.master => _MasterOpeningExplorer(
          ctrlProvider: ctrlProvider,
          opening: opening,
        ),
      OpeningDatabase.lichess => _LichessOpeningExplorer(
          ctrlProvider: ctrlProvider,
          opening: opening,
        ),
    };
  }
}

class _MasterOpeningExplorer extends ConsumerWidget {
  const _MasterOpeningExplorer({
    required this.ctrlProvider,
    required this.opening,
  });

  final AnalysisControllerProvider ctrlProvider;
  final Opening? opening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey5,
            context,
          )
        : Theme.of(context).colorScheme.secondaryContainer;

    final position = ref.watch(ctrlProvider.select((value) => value.position));

    final masterDbAsync = ref.watch(
      masterOpeningDatabaseProvider(
        fen: position.fen,
      ),
    );

    return masterDbAsync.when(
      data: (masterDb) {
        return Column(
          children: [
            if (opening != null)
              Container(
                padding: const EdgeInsets.only(left: 6.0),
                color: primaryColor,
                child: Row(
                  children: [
                    if (opening!.eco.isEmpty)
                      Text(opening!.name)
                    else
                      Text('${opening!.eco} ${opening!.name}'),
                  ],
                ),
              ),
            if (masterDb.moves.isEmpty)
              const Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text('No game found'),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoveTable(
                        moves: masterDb.moves,
                        whiteWins: masterDb.white,
                        draws: masterDb.draws,
                        blackWins: masterDb.black,
                        ctrlProvider: ctrlProvider,
                      ),
                      _GameList(
                        title: context.l10n.topGames,
                        games: masterDb.topGames
                            .map((g) => Game.fromTopGame(g))
                            .toIList(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => Center(
        child: Text(error.toString()),
      ),
    );
  }
}

class _LichessOpeningExplorer extends ConsumerWidget {
  const _LichessOpeningExplorer({
    required this.ctrlProvider,
    required this.opening,
  });

  final AnalysisControllerProvider ctrlProvider;
  final Opening? opening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey5,
            context,
          )
        : Theme.of(context).colorScheme.secondaryContainer;

    final position = ref.watch(ctrlProvider.select((value) => value.position));

    final lichessDbAsync = ref.watch(
      lichessOpeningDatabaseProvider(
        fen: position.fen,
      ),
    );

    return lichessDbAsync.when(
      data: (lichessDb) {
        return Column(
          children: [
            if (opening != null)
              Container(
                padding: const EdgeInsets.only(left: 6.0),
                color: primaryColor,
                child: Row(
                  children: [
                    if (opening!.eco.isEmpty)
                      Text(opening!.name)
                    else
                      Text('${opening!.eco} ${opening!.name}'),
                  ],
                ),
              ),
            if (lichessDb.moves.isEmpty)
              const Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text('No game found'),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoveTable(
                        moves: lichessDb.moves,
                        whiteWins: lichessDb.white,
                        draws: lichessDb.draws,
                        blackWins: lichessDb.black,
                        ctrlProvider: ctrlProvider,
                      ),
                      _GameList(
                        title: context.l10n.recentGames,
                        games: lichessDb.recentGames
                            .map((g) => Game.fromRecentGame(g))
                            .toIList(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => Center(
        child: Text(error.toString()),
      ),
    );
  }
}

class _MoveTable extends ConsumerWidget {
  const _MoveTable({
    required this.moves,
    required this.whiteWins,
    required this.draws,
    required this.blackWins,
    required this.ctrlProvider,
  });

  final IList<OpeningMove> moves;
  final int whiteWins;
  final int draws;
  final int blackWins;
  final AnalysisControllerProvider ctrlProvider;

  String formatNum(int num) => NumberFormat.decimalPatternDigits().format(num);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey5,
            context,
          )
        : Theme.of(context).colorScheme.secondaryContainer;
    const rowPadding = EdgeInsets.all(6.0);

    final games = whiteWins + draws + blackWins;

    return Table(
      columnWidths: const {
        0: FractionColumnWidth(0.2),
        1: FractionColumnWidth(0.3),
        2: FractionColumnWidth(0.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: primaryColor,
          ),
          children: [
            Container(
              padding: rowPadding,
              child: Text(context.l10n.move),
            ),
            Container(
              padding: rowPadding,
              child: Text(context.l10n.games),
            ),
            Container(
              padding: rowPadding,
              child: Text(context.l10n.whiteDrawBlack),
            ),
          ],
        ),
        ...List.generate(
          moves.length,
          (int index) {
            final move = moves.get(index);
            final percentGames = ((move.games / games) * 100).round();
            return TableRow(
              decoration: BoxDecoration(
                color: index.isEven
                    ? Theme.of(context).colorScheme.surfaceContainerLow
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              children: [
                TableRowInkWell(
                  onTap: () => ref
                      .read(ctrlProvider.notifier)
                      .onUserMove(Move.fromUci(move.uci)!),
                  child: Container(
                    padding: rowPadding,
                    child: Text(move.san),
                  ),
                ),
                TableRowInkWell(
                  onTap: () => ref
                      .read(ctrlProvider.notifier)
                      .onUserMove(Move.fromUci(move.uci)!),
                  child: Container(
                    padding: rowPadding,
                    child: Tooltip(
                      message: '$percentGames%',
                      child: Text(formatNum(move.games)),
                    ),
                  ),
                ),
                TableRowInkWell(
                  onTap: () => ref
                      .read(ctrlProvider.notifier)
                      .onUserMove(Move.fromUci(move.uci)!),
                  child: Container(
                    padding: rowPadding,
                    child: _WinPercentageChart(
                      white: move.white,
                      draws: move.draws,
                      black: move.black,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        TableRow(
          decoration: BoxDecoration(
            color: moves.length.isEven
                ? Theme.of(context).colorScheme.surfaceContainerLow
                : Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          children: [
            Container(
              padding: rowPadding,
              alignment: Alignment.centerLeft,
              child: const Icon(Icons.functions),
            ),
            Container(
              padding: rowPadding,
              child: Tooltip(
                message: '100%',
                child: Text(formatNum(games)),
              ),
            ),
            Container(
              padding: rowPadding,
              child: _WinPercentageChart(
                white: whiteWins,
                draws: draws,
                black: blackWins,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({
    required this.title,
    required this.games,
  });

  final String title;
  final IList<Game> games;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey5,
            context,
          )
        : Theme.of(context).colorScheme.secondaryContainer;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6.0),
          color: primaryColor,
          child: Row(
            children: [
              Text(title),
            ],
          ),
        ),
        ...List.generate(games.length, (int index) {
          return _Game(
            game: games.get(index),
            color: index.isEven
                ? Theme.of(context).colorScheme.surfaceContainerLow
                : Theme.of(context).colorScheme.surfaceContainerHigh,
          );
        }),
      ],
    );
  }
}

class _Game extends StatelessWidget {
  const _Game({
    required this.game,
    required this.color,
  });

  final Game game;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const widthResultBox = 50.0;
    const paddingResultBox = EdgeInsets.all(5);

    return Container(
      padding: const EdgeInsets.all(6.0),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.white.rating.toString()),
                  Text(game.black.rating.toString()),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.white.name),
                  Text(game.black.name),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (game.winner == 'white')
                Container(
                  width: widthResultBox,
                  padding: paddingResultBox,
                  color: Colors.white,
                  child: const Text(
                    '1-0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                )
              else if (game.winner == 'black')
                Container(
                  width: widthResultBox,
                  padding: paddingResultBox,
                  color: Colors.black,
                  child: const Text(
                    '0-1',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Container(
                  width: widthResultBox,
                  padding: paddingResultBox,
                  color: Colors.grey,
                  child: const Text(
                    '½-½',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              if (game.month != null) ...[
                const SizedBox(width: 10.0),
                Text(game.month!),
              ],
              if (game.speed != null) ...[
                const SizedBox(width: 10.0),
                Icon(game.speed!.icon),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WinPercentageChart extends StatelessWidget {
  const _WinPercentageChart({
    required this.white,
    required this.draws,
    required this.black,
  });

  final int white;
  final int draws;
  final int black;

  String label(int percent) => percent < 20 ? '' : '$percent%';

  @override
  Widget build(BuildContext context) {
    int percentGames(int games) =>
        ((games / (white + draws + black)) * 100).round();

    final percentWhite = percentGames(white);
    final percentDraws = percentGames(draws);
    final percentBlack = percentGames(black);

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(
        children: [
          Expanded(
            flex: percentWhite,
            child: ColoredBox(
              color: Colors.white,
              child: Text(
                label(percentWhite),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ),
          Expanded(
            flex: percentDraws,
            child: ColoredBox(
              color: Colors.grey,
              child: Text(
                label(percentDraws),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Expanded(
            flex: percentBlack,
            child: ColoredBox(
              color: Colors.black,
              child: Text(
                label(percentBlack),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.pgn,
    required this.options,
  });

  final String pgn;
  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(pgn, options);
    final canGoBack =
        ref.watch(ctrlProvider.select((value) => value.canGoBack));
    final canGoNext =
        ref.watch(ctrlProvider.select((value) => value.canGoNext));

    return Container(
      color: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoTheme.of(context).barBackgroundColor
          : Theme.of(context).bottomAppBarTheme.color,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.menu,
                  onTap: () {
                    _showAnalysisMenu(context, ref);
                  },
                  icon: Icons.menu,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.analysis,
                  onTap: () => pushReplacementPlatformRoute(
                    context,
                    builder: (_) => AnalysisScreen(
                      pgnOrId: pgn,
                      options: options,
                    ),
                  ),
                  icon: Icons.biotech,
                ),
              ),
              Expanded(
                child: RepeatButton(
                  onLongPress: canGoBack ? () => _moveBackward(ref) : null,
                  child: BottomBarButton(
                    key: const ValueKey('goto-previous'),
                    onTap: canGoBack ? () => _moveBackward(ref) : null,
                    label: 'Previous',
                    icon: CupertinoIcons.chevron_back,
                    showTooltip: false,
                  ),
                ),
              ),
              Expanded(
                child: RepeatButton(
                  onLongPress: canGoNext ? () => _moveForward(ref) : null,
                  child: BottomBarButton(
                    key: const ValueKey('goto-next'),
                    icon: CupertinoIcons.chevron_forward,
                    label: context.l10n.next,
                    onTap: canGoNext ? () => _moveForward(ref) : null,
                    showTooltip: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveForward(WidgetRef ref) =>
      ref.read(analysisControllerProvider(pgn, options).notifier).userNext();
  void _moveBackward(WidgetRef ref) => ref
      .read(analysisControllerProvider(pgn, options).notifier)
      .userPrevious();

  Future<void> _showAnalysisMenu(BuildContext context, WidgetRef ref) {
    return showAdaptiveActionSheet(
      context: context,
      actions: [
        BottomSheetAction(
          makeLabel: (context) => Text(context.l10n.flipBoard),
          onPressed: (context) {
            ref
                .read(analysisControllerProvider(pgn, options).notifier)
                .toggleBoard();
          },
        ),
        BottomSheetAction(
          makeLabel: (context) => Text(context.l10n.mobileShareGamePGN),
          onPressed: (_) {
            pushPlatformRoute(
              context,
              title: context.l10n.studyShareAndExport,
              builder: (_) => AnalysisShareScreen(pgn: pgn, options: options),
            );
          },
        ),
        BottomSheetAction(
          makeLabel: (context) => Text(context.l10n.mobileSharePositionAsFEN),
          onPressed: (_) {
            launchShareDialog(
              context,
              text: ref
                  .read(analysisControllerProvider(pgn, options))
                  .position
                  .fen,
            );
          },
        ),
        if (options.gameAnyId != null)
          BottomSheetAction(
            makeLabel: (context) =>
                Text(context.l10n.screenshotCurrentPosition),
            onPressed: (_) async {
              final gameId = options.gameAnyId!.gameId;
              final state = ref.read(analysisControllerProvider(pgn, options));
              try {
                final image =
                    await ref.read(gameShareServiceProvider).screenshotPosition(
                          gameId,
                          options.orientation,
                          state.position.fen,
                          state.lastMove,
                        );
                if (context.mounted) {
                  launchShareDialog(
                    context,
                    files: [image],
                    subject: context.l10n.puzzleFromGameLink(
                      lichessUri('/$gameId').toString(),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showPlatformSnackbar(
                    context,
                    'Failed to get GIF',
                    type: SnackBarType.error,
                  );
                }
              }
            },
          ),
      ],
    );
  }
}