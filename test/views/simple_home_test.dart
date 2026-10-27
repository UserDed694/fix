import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/simple/simple_home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _RecordingProfilesAction extends ProfilesAction {
  final links = <String>[];

  @override
  Future<void> addProfileFromLink(
    String link, {
    String? label,
    String ageSecretKey = '',
  }) async {
    links.add(link);
  }
}

const _group = Group(
  name: 'Selector',
  type: GroupType.Selector,
  hidden: false,
  all: [
    Proxy(name: 'Amsterdam', type: 'vless'),
    Proxy(name: 'Warsaw', type: 'vless'),
  ],
);

void main() {
  late ProviderContainer container;
  late _RecordingProfilesAction action;

  void setUpContainer(
    List<Profile> profiles, {
    List<Override> overrides = const [],
  }) {
    action = _RecordingProfilesAction();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        profilesActionProvider.overrideWith(() => action),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value =
        profiles.firstOrNull?.id;
  }

  Future<void> pumpHome(WidgetTester tester) async {
    const size = Size(800, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container.read(viewSizeProvider.notifier).update((_) => size);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: SimpleHomeView()),
      ),
    );
    await tester.pump();
  }

  testWidgets('without a profile offers the key field and a connect button', (
    tester,
  ) async {
    setUpContainer([]);
    await pumpHome(tester);

    final l10n = currentAppLocalizations;
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(l10n.subscriptionKey), findsOneWidget);
    expect(find.widgetWithText(FilledButton, l10n.connect), findsOneWidget);
    expect(find.byType(ProxyCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refuses a subscription from another host before adding it', (
    tester,
  ) async {
    setUpContainer([]);
    await pumpHome(tester);

    final l10n = currentAppLocalizations;
    await tester.enterText(find.byType(TextField), 'https://evil.example/t');
    await tester.tap(find.widgetWithText(FilledButton, l10n.connect));
    await tester.pump();

    expect(
      find.text(l10n.subscriptionHostNotAllowed(allowedSubscriptionHost)),
      findsOneWidget,
    );
    expect(action.links, isEmpty);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, l10n.connect));
    await tester.pump();

    expect(find.text(l10n.emptyTip(l10n.subscriptionKey)), findsOneWidget);
    expect(action.links, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turns a bare key into the panel link and adds it', (
    tester,
  ) async {
    setUpContainer([]);
    await pumpHome(tester);

    final l10n = currentAppLocalizations;
    await tester.enterText(find.byType(TextField), ' abc123 ');
    await tester.tap(find.widgetWithText(FilledButton, l10n.connect));
    await tester.pump();

    expect(action.links, ['https://$allowedSubscriptionHost/abc123']);
    expect(
      find.text(l10n.subscriptionHostNotAllowed(allowedSubscriptionHost)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a profile shows the status, the toggle and the servers', (
    tester,
  ) async {
    final profile = Profile.normal(
      label: 'My plan',
      url: 'https://$allowedSubscriptionHost/abc',
    );
    setUpContainer(
      [profile],
      overrides: [
        currentGroupsStateProvider.overrideWithValue(
          const GroupsState(value: [_group]),
        ),
        groupsProvider.overrideWithValue(const [_group]),
      ],
    );
    await pumpHome(tester);

    final l10n = currentAppLocalizations;
    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.disconnected), findsOneWidget);
    expect(find.byTooltip(l10n.connect), findsOneWidget);
    expect(find.text('My plan', findRichText: true), findsOneWidget);
    expect(find.byTooltip(l10n.update), findsOneWidget);
    expect(find.text('Selector'), findsOneWidget);
    expect(find.byType(ProxyCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
