import 'package:flutter/material.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_state.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:on_time_front/presentation/shared/time/time_zone_catalog.dart';

Future<String?> showScheduleTimeZonePicker({
  required BuildContext context,
  required String currentZone,
  required DateTime? civil,
  required int? offsetSeconds,
  required bool Function() isCurrent,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _TimeZonePicker(currentZone: currentZone, civil: civil),
  );
  return context.mounted && isCurrent() ? selected : null;
}

class _TimeZonePicker extends StatefulWidget {
  const _TimeZonePicker({required this.currentZone, required this.civil});
  final String currentZone;
  final DateTime? civil;
  @override
  State<_TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<_TimeZonePicker> {
  final _search = TextEditingController();
  String? _candidate;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _choice(String zone, {String? label}) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      title: Text('${TimeZoneCatalog.cityName(zone, l.localeName)} · $zone'),
      subtitle: label == null ? null : Text(label),
      selected: _candidate == zone,
      trailing: _candidate == zone ? const Icon(Icons.check) : null,
      onTap: () => setState(() => _candidate = zone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final device = DeviceTimeZoneScope.stateOf(context);
    final matches = TimeZoneCatalog.search(_search.text);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final zone = _candidate;
    final civil = widget.civil;
    final candidates = zone == null || civil == null
        ? const <CivilTimeOccurrence>[]
        : CivilTimeResolver.resolve(civil, zone);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height * .9 -
                    MediaQuery.viewInsetsOf(context).bottom)
                .clamp(0.0, double.infinity),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l.zonedTimeChooseZone,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextField(
                      key: const ValueKey('time-zone-search'),
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: l.zonedTimeSearch,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l.zonedTimeClearSearch,
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (device.status == DeviceTimeZoneStatus.known)
                      _choice(
                        device.identifier!,
                        label: l.zonedTimeCurrentDeviceZone,
                      )
                    else
                      Text(
                        device.status == DeviceTimeZoneStatus.loading
                            ? l.zonedTimeDeviceLoading
                            : l.zonedTimeDeviceUnavailable,
                      ),
                    if (TimeZoneRules.contains(widget.currentZone))
                      _choice(
                        widget.currentZone,
                        label: l.zonedTimeCurrentSelection,
                      )
                    else if (widget.currentZone.isNotEmpty)
                      Text(
                        '${l.zonedTimeCurrentSelection}: ${widget.currentZone}\n${l.zonedTimeUnknownZone}',
                      ),
                    if (zone != null) ...[
                      const Divider(),
                      Text(
                        l.zonedTimeDraftPreview,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l.zonedTimeKeepCivil),
                      if (civil == null)
                        Text(zone)
                      else
                        ScheduleZonedTime(
                          civil: CivilDateTime.fromFields(civil),
                          timeZoneId: zone,
                          resolution: ScheduleTimeResolution(
                            status: candidates.isEmpty
                                ? ScheduleTimeResolutionStatus.nonexistent
                                : candidates.length == 1
                                ? ScheduleTimeResolutionStatus.resolved
                                : ScheduleTimeResolutionStatus.ambiguous,
                            instantUtc: candidates.length == 1
                                ? candidates.single.instantUtc
                                : null,
                            occurrences: candidates,
                          ),
                          showInstant: true,
                        ),
                    ],
                    const Divider(),
                    if (matches.isEmpty) Text(l.zonedTimeNoMatches),
                    ...matches.map((zone) => _choice(zone)),
                  ],
                ),
              ),
              if (keyboardOpen)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: l.cancel,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        key: const ValueKey('time-zone-apply'),
                        tooltip: l.zonedTimeApplyDraft,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: _candidate == null
                            ? null
                            : () => Navigator.pop(context, _candidate),
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        key: const ValueKey('time-zone-apply'),
                        onPressed: _candidate == null
                            ? null
                            : () => Navigator.pop(context, _candidate),
                        child: Text(l.zonedTimeApplyDraft),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
