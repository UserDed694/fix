/// «Главная» простого режима: один экран вместо панели FlClash.
///
/// Без подписки показывает поле для ключа или ссылки и кнопку «Подключить»;
/// с подпиской: статус соединения, большую кнопку Подключить/Отключить,
/// карточку подписки с обновлением и список серверов первой группы выбора.
/// Экран попадает во вкладки через `Navigation.getItems` (`navigation.dart`)
/// и переиспользует действия и провайдеры полного приложения: ничего из
/// логики подключения здесь не дублируется.
library;

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_detail.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _pageInset = 16.0;
const _toggleSize = 128.0;

class SimpleHomeView extends ConsumerWidget {
  const SimpleHomeView({super.key});

  /// Профиль добавляется и соединение поднимается одним нажатием; ошибки
  /// загрузки показывает `loadingRun`, поэтому здесь проверяется лишь итог.
  Future<void> _addAndConnect(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    await ref.read(profilesActionProvider.notifier).addProfileFromLink(url);
    if (!context.mounted ||
        ref.read(currentProfileProvider) == null ||
        ref.read(isStartProvider)) {
      return;
    }
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  Future<void> _changeSubscription(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.changeSubscription,
      message: TextSpan(text: appLocalizations.changeSubscriptionTip),
      confirmText: appLocalizations.confirm,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final profilesAction = ref.read(profilesActionProvider.notifier);
    for (final profile in ref.read(profilesProvider)) {
      await profilesAction.deleteProfile(profile.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
    return CommonScaffold(
      title: appLocalizations.home,
      isLoading: isLoading,
      menuItems: [
        if (profile != null)
          CommonPopupMenuItem(
            glyph: AppGlyphs.swap,
            label: appLocalizations.changeSubscription,
            onPressed: () => _changeSubscription(context, ref),
          ),
        CommonPopupMenuItem(
          glyph: AppGlyphs.settings,
          label: appLocalizations.advancedSettings,
          onPressed: () => BaseNavigator.push(context, const ToolsView()),
        ),
      ],
      body: profile == null
          ? _SubscriptionEntry(
              onConnect: (url) => _addAndConnect(context, ref, url),
            )
          : _ConnectionPanel(profile: profile),
    );
  }
}

class _SubscriptionEntry extends StatefulWidget {
  const _SubscriptionEntry({required this.onConnect});

  final Future<void> Function(String url) onConnect;

  @override
  State<_SubscriptionEntry> createState() => _SubscriptionEntryState();
}

class _SubscriptionEntryState extends State<_SubscriptionEntry> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations appLocalizations, String url) {
    if (url.isEmpty) {
      return appLocalizations.emptyTip(appLocalizations.subscriptionKey);
    }
    if (!isAllowedSubscriptionUrl(url)) {
      return appLocalizations.subscriptionHostNotAllowed(
        allowedSubscriptionHost,
      );
    }
    return null;
  }

  Future<void> _connect() async {
    final url = subscriptionUrlFor(_controller.text);
    final error = _validate(context.appLocalizations, url);
    setState(() {
      _error = error;
    });
    if (error != null) {
      return;
    }
    await widget.onConnect(url);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        _pageInset,
        context.contentTopPadding,
        _pageInset,
        _pageInset + context.bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            appLocalizations.subscriptionKeyDesc,
            style: AppTextStyle.body
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          FilledInputTheme(
            borderRadius: AppRadius.lg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _connect(),
              decoration: InputDecoration(
                hintText: appLocalizations.subscriptionKey,
                errorText: _error,
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _connect,
              icon: const GlyphIcon(AppGlyphs.vpn, fill: 1),
              label: Text(appLocalizations.connect),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends ConsumerWidget {
  const _ConnectionPanel({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final groups = ref.watch(currentGroupsStateProvider).value;
    final group =
        groups.firstWhereOrNull((group) => group.type == GroupType.Selector) ??
        groups.firstOrNull;
    final cardType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.cardType),
    );
    final layout = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.layout),
    );
    return WidthBuilder(
      builder: (context, maxWidth) {
        final columns = getProxiesColumns(
          max(maxWidth - _pageInset * 2, 0),
          layout,
        );
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _pageInset,
                context.contentTopPadding,
                _pageInset,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 24,
                  children: [
                    _ConnectionStatus(running: isStart),
                    _ConnectToggle(running: isStart),
                    _SubscriptionCard(profile: profile),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _ServersHeader(
                group: group,
                title: group?.name ?? appLocalizations.servers,
              ),
            ),
            if (group == null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _pageInset),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    appLocalizations.noServersTip,
                    style: AppTextStyle.footnote.of(context).toLight,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _pageInset),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: getItemHeight(cardType),
                    crossAxisSpacing: proxyGridSpacing,
                    mainAxisSpacing: proxyGridSpacing,
                  ),
                  itemCount: group.all.length,
                  itemBuilder: (_, index) => ProxyCard(
                    groupName: group.name,
                    testUrl: group.testUrl,
                    proxy: group.all[index],
                    groupType: group.type,
                    type: cardType,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: _pageInset + context.bottomInset),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final runTime = ref.watch(runTimeProvider);
    final total = ref.watch(totalTrafficProvider);
    final meta = AppTextStyle.subheadline
        .of(context)
        .toTabular
        .copyWith(color: colorScheme.onSurfaceVariant);
    return Column(
      spacing: 4,
      children: [
        Text(
          running ? appLocalizations.connected : appLocalizations.disconnected,
          style: AppTextStyle.title2.of(context, emphasized: true),
        ),
        if (running) Text(getTimeText(runTime), style: meta),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            _TrafficFigure(
              glyph: AppGlyphs.arrowUp,
              value: total.up.traffic.show,
              style: meta,
            ),
            _TrafficFigure(
              glyph: AppGlyphs.arrowDown,
              value: total.down.traffic.show,
              style: meta,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrafficFigure extends StatelessWidget {
  const _TrafficFigure({
    required this.glyph,
    required this.value,
    required this.style,
  });

  final Glyph glyph;
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        GlyphIcon(glyph, size: 16, color: style.color),
        Text(value, style: style),
      ],
    );
  }
}

/// Упрощённый аналог `_StartToggle` с панели: та же команда `toggleRunning`,
/// но обычная круглая кнопка вместо морфинга фигуры.
class _ConnectToggle extends ConsumerWidget {
  const _ConnectToggle({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final label = running
        ? appLocalizations.disconnect
        : appLocalizations.connect;
    final style = ElasticPress.buttonStyle.merge(
      FilledButton.styleFrom(
        shape: AppShape.full,
        padding: EdgeInsets.zero,
        backgroundColor: running
            ? colorScheme.successContainer
            : colorScheme.primary,
        foregroundColor: running
            ? colorScheme.onSuccessContainer
            : colorScheme.onPrimary,
      ),
    );
    return Column(
      spacing: 12,
      children: [
        Tooltip(
          message: label,
          child: SizedBox.square(
            dimension: _toggleSize,
            child: FilledButton(
              style: style,
              onPressed: () =>
                  ref.read(commonActionProvider.notifier).toggleRunning(),
              child: GlyphIcon(
                AppGlyphs.playPause(running ? 1 : 0),
                size: _toggleSize * 0.34,
                fill: 1,
              ),
            ),
          ),
        ),
        Text(label, style: AppTextStyle.callout.of(context)),
      ],
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isUpdating = ref.watch(isUpdatingProvider(profile.updatingKey));
    return CommonCard(
      radius: AppCorner.xl,
      inert: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLocalizations.subscription,
                        style: AppTextStyle.footnote.of(context).toLight,
                      ),
                      EmojiText(
                        profile.realLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.headline.of(context),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  const SizedBox.square(
                    dimension: 40,
                    child: Center(child: CommonCircleLoading(size: 18)),
                  )
                else
                  IconButton(
                    tooltip: appLocalizations.update,
                    icon: const GlyphIcon(AppGlyphs.sync),
                    onPressed: () => syncProfile(ref, profile),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SubscriptionInfoView(
                subscriptionInfo: profile.subscriptionInfo,
              ),
            ),
            LastUpdateTimeText(
              lastUpdateDate: profile.lastUpdateDate,
              style: AppTextStyle.footnote.of(context).toLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServersHeader extends ConsumerWidget {
  const _ServersHeader({required this.group, required this.title});

  final Group? group;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = this.group;
    final testing =
        group != null &&
        ref.watch(
          delayTestingGroupsProvider.select(
            (state) => state.contains(group.name),
          ),
        );
    return ListHeader(
      title: title,
      actions: [
        if (group != null)
          IconButtonData(
            glyph: AppGlyphs.bolt,
            tooltip: context.appLocalizations.delayTest,
            isLoading: testing,
            onPressed: () => ref
                .read(proxiesActionProvider.notifier)
                .delayTestPageGroup(group.name, matchSearch: false),
          ),
      ],
    );
  }
}
