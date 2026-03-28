part of '../hero_talents_tab.dart';

/// Berechnet die angezeigte Lernkomplexität einer Sprache.
///
/// Ist der Held Mitglied derselben Sprachfamilie wie die Sprache
/// (= Muttersprache liegt in derselben Familie), gilt die
/// family-interne Komplexität ('A'), sonst 'B'.
/// Hat die Sprache selbst [SpracheDef.steigerung] == 'B', gilt immer 'B'.
String _computeSprachKomplexitaet({
  required SpracheDef def,
  required String muttersprache,
  required List<SpracheDef> alleSprachen,
}) {
  if (def.steigerung == 'B') {
    return 'B';
  }
  if (muttersprache.isEmpty) {
    return 'B';
  }
  final mutterDef = alleSprachen
      .where((s) => s.id == muttersprache)
      .firstOrNull;
  if (mutterDef == null) {
    return 'B';
  }
  return mutterDef.familie == def.familie ? 'A' : 'B';
}

// ---------------------------------------------------------------------------
// Sprachen & Schriften Sub-Tab
// ---------------------------------------------------------------------------

class _SprachenSchriftenTab extends StatelessWidget {
  const _SprachenSchriftenTab({
    required this.heroId,
    required this.draftSprachen,
    required this.draftSchriften,
    required this.draftMuttersprache,
    required this.alleSprachen,
    required this.alleSchriften,
    required this.isEditing,
    required this.onPrepareAddEntry,
    required this.onSprachWertChanged,
    required this.onSchriftWertChanged,
    required this.onMuttersprachChanged,
    required this.onAddSprache,
    required this.onRemoveSprache,
    required this.onAddSchrift,
    required this.onRemoveSchrift,
  });

  final String heroId;
  final Map<String, HeroLanguageEntry> draftSprachen;
  final Map<String, HeroScriptEntry> draftSchriften;
  final String draftMuttersprache;
  final List<SpracheDef> alleSprachen;
  final List<SchriftDef> alleSchriften;
  final bool isEditing;
  final Future<void> Function() onPrepareAddEntry;
  final void Function(String id, int wert) onSprachWertChanged;
  final void Function(String id, int wert) onSchriftWertChanged;
  final void Function(String id) onMuttersprachChanged;
  final void Function(String id) onAddSprache;
  final void Function(String id) onRemoveSprache;
  final void Function(String id) onAddSchrift;
  final void Function(String id) onRemoveSchrift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SprachenSection(
            draftSprachen: draftSprachen,
            draftMuttersprache: draftMuttersprache,
            alleSprachen: alleSprachen,
            isEditing: isEditing,
            onPrepareAddEntry: onPrepareAddEntry,
            onWertChanged: onSprachWertChanged,
            onMuttersprachChanged: onMuttersprachChanged,
            onAddSprache: onAddSprache,
            onRemoveSprache: onRemoveSprache,
          ),
          const SizedBox(height: 8),
          _SchriftenSection(
            draftSchriften: draftSchriften,
            alleSchriften: alleSchriften,
            isEditing: isEditing,
            onPrepareAddEntry: onPrepareAddEntry,
            onWertChanged: onSchriftWertChanged,
            onAddSchrift: onAddSchrift,
            onRemoveSchrift: onRemoveSchrift,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sprachen-Sektion
// ---------------------------------------------------------------------------

class _SprachenSection extends StatelessWidget {
  const _SprachenSection({
    required this.draftSprachen,
    required this.draftMuttersprache,
    required this.alleSprachen,
    required this.isEditing,
    required this.onPrepareAddEntry,
    required this.onWertChanged,
    required this.onMuttersprachChanged,
    required this.onAddSprache,
    required this.onRemoveSprache,
  });

  final Map<String, HeroLanguageEntry> draftSprachen;
  final String draftMuttersprache;
  final List<SpracheDef> alleSprachen;
  final bool isEditing;
  final Future<void> Function() onPrepareAddEntry;
  final void Function(String id, int wert) onWertChanged;
  final void Function(String id) onMuttersprachChanged;
  final void Function(String id) onAddSprache;
  final void Function(String id) onRemoveSprache;

  @override
  Widget build(BuildContext context) {
    // Aktive Sprachen nach Familie gruppieren.
    final activeDefs = alleSprachen
        .where((s) => draftSprachen.containsKey(s.id))
        .toList();

    final byFamilie = <String, List<SpracheDef>>{};
    for (final def in activeDefs) {
      byFamilie.putIfAbsent(def.familie, () => []).add(def);
    }
    final families = byFamilie.keys.toList()..sort();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: const Text('Sprachen'),
        subtitle: Text(
          'Lege bekannte Sprachen mit Lernwert und Muttersprache an.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await onPrepareAddEntry();
                if (!context.mounted) {
                  return;
                }
                _showSprachKatalog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Sprache'),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (draftSprachen.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                isEditing
                    ? 'Keine Sprachen eingetragen. Tippe auf Sprache, um einen Eintrag hinzuzufügen.'
                    : 'Keine Sprachen eingetragen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ..._buildFamilienHeader(context, families, byFamilie),
        ],
      ),
    );
  }

  List<Widget> _buildFamilienHeader(
    BuildContext context,
    List<String> families,
    Map<String, List<SpracheDef>> byFamilie,
  ) {
    final widgets = <Widget>[];
    for (final familie in families) {
      final defs = byFamilie[familie]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Text(
            familie,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      for (final def in defs) {
        final entry = draftSprachen[def.id]!;
        final kompl = _computeSprachKomplexitaet(
          def: def,
          muttersprache: draftMuttersprache,
          alleSprachen: alleSprachen,
        );
        final isMutter = draftMuttersprache == def.id;
        widgets.add(
          _SprachRow(
            def: def,
            entry: entry,
            kompl: kompl,
            isMuttersprache: isMutter,
            isEditing: isEditing,
            onWertChanged: (v) => onWertChanged(def.id, v),
            onMuttersprachChanged: () => onMuttersprachChanged(def.id),
            onRemove: () => onRemoveSprache(def.id),
          ),
        );
      }
    }
    return widgets;
  }

  void _showSprachKatalog(BuildContext context) {
    final activeIds = draftSprachen.keys.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: screenHeight * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Sprachen',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: alleSprachen.length,
                      itemBuilder: (ctx, index) {
                        final def = alleSprachen[index];
                        final isActive = activeIds.contains(def.id);
                        return CheckboxListTile(
                          value: isActive,
                          title: Text(def.name),
                          subtitle: Text(
                            def.familie,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          secondary: Text(
                            'max ${def.maxWert}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          onChanged: (checked) {
                            if (checked == true) {
                              onAddSprache(def.id);
                            } else {
                              onRemoveSprache(def.id);
                            }
                            setSheetState(() {
                              if (checked == true) {
                                activeIds.add(def.id);
                              } else {
                                activeIds.remove(def.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SprachRow extends StatefulWidget {
  const _SprachRow({
    required this.def,
    required this.entry,
    required this.kompl,
    required this.isMuttersprache,
    required this.isEditing,
    required this.onWertChanged,
    required this.onMuttersprachChanged,
    required this.onRemove,
  });

  final SpracheDef def;
  final HeroLanguageEntry entry;
  final String kompl;
  final bool isMuttersprache;
  final bool isEditing;
  final void Function(int wert) onWertChanged;
  final VoidCallback onMuttersprachChanged;
  final VoidCallback onRemove;

  @override
  State<_SprachRow> createState() => _SprachRowState();
}

class _SprachRowState extends State<_SprachRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.entry.wert}');
  }

  @override
  void didUpdateWidget(_SprachRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing && oldWidget.entry.wert != widget.entry.wert) {
      _ctrl.text = '${widget.entry.wert}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveWert = widget.entry.wert + widget.entry.modifier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Muttersprachen-Stern
          GestureDetector(
            onTap: widget.isEditing ? widget.onMuttersprachChanged : null,
            child: Tooltip(
              message: widget.isMuttersprache
                  ? 'Muttersprache'
                  : widget.isEditing
                  ? 'Als Muttersprache setzen'
                  : '',
              child: Icon(
                widget.isMuttersprache ? Icons.star : Icons.star_outline,
                size: 18,
                color: widget.isMuttersprache
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.def.name),
                if (widget.def.hinweise.isNotEmpty)
                  Text(
                    widget.def.hinweise,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Komplexität
          SizedBox(
            width: 28,
            child: Text(
              widget.kompl,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          // TaW
          SizedBox(
            width: 48,
            child: widget.isEditing
                ? TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        widget.onWertChanged(
                          parsed.clamp(0, widget.def.maxWert),
                        );
                      }
                    },
                  )
                : Text(
                    '$effectiveWert',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
          ),
          // Max
          SizedBox(
            width: 40,
            child: Text(
              '/${widget.def.maxWert}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Entfernen-Button
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              tooltip: 'Entfernen',
              onPressed: widget.onRemove,
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schriften-Sektion
// ---------------------------------------------------------------------------

class _SchriftenSection extends StatelessWidget {
  const _SchriftenSection({
    required this.draftSchriften,
    required this.alleSchriften,
    required this.isEditing,
    required this.onPrepareAddEntry,
    required this.onWertChanged,
    required this.onAddSchrift,
    required this.onRemoveSchrift,
  });

  final Map<String, HeroScriptEntry> draftSchriften;
  final List<SchriftDef> alleSchriften;
  final bool isEditing;
  final Future<void> Function() onPrepareAddEntry;
  final void Function(String id, int wert) onWertChanged;
  final void Function(String id) onAddSchrift;
  final void Function(String id) onRemoveSchrift;

  @override
  Widget build(BuildContext context) {
    final activeDefs = alleSchriften
        .where((s) => draftSchriften.containsKey(s.id))
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: const Text('Schriften'),
        subtitle: Text(
          'Erfasse gelernte Schriften inklusive aktuellem Wert.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await onPrepareAddEntry();
                if (!context.mounted) {
                  return;
                }
                _showSchriftKatalog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Schrift'),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (draftSchriften.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                isEditing
                    ? 'Keine Schriften eingetragen. Tippe auf Schrift, um einen Eintrag hinzuzufügen.'
                    : 'Keine Schriften eingetragen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...activeDefs.map((def) {
              final entry = draftSchriften[def.id]!;
              return _SchriftRow(
                def: def,
                entry: entry,
                isEditing: isEditing,
                onWertChanged: (v) => onWertChanged(def.id, v),
                onRemove: () => onRemoveSchrift(def.id),
              );
            }),
        ],
      ),
    );
  }

  void _showSchriftKatalog(BuildContext context) {
    final activeIds = draftSchriften.keys.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: screenHeight * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Schriften',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: alleSchriften.length,
                      itemBuilder: (ctx, index) {
                        final def = alleSchriften[index];
                        final isActive = activeIds.contains(def.id);
                        return CheckboxListTile(
                          value: isActive,
                          title: Text(def.name),
                          subtitle: def.beschreibung.isNotEmpty
                              ? Text(
                                  def.beschreibung,
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          secondary: Text(
                            '${def.steigerung} / max ${def.maxWert}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          onChanged: (checked) {
                            if (checked == true) {
                              onAddSchrift(def.id);
                            } else {
                              onRemoveSchrift(def.id);
                            }
                            setSheetState(() {
                              if (checked == true) {
                                activeIds.add(def.id);
                              } else {
                                activeIds.remove(def.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SchriftRow extends StatefulWidget {
  const _SchriftRow({
    required this.def,
    required this.entry,
    required this.isEditing,
    required this.onWertChanged,
    required this.onRemove,
  });

  final SchriftDef def;
  final HeroScriptEntry entry;
  final bool isEditing;
  final void Function(int wert) onWertChanged;
  final VoidCallback onRemove;

  @override
  State<_SchriftRow> createState() => _SchriftRowState();
}

class _SchriftRowState extends State<_SchriftRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.entry.wert}');
  }

  @override
  void didUpdateWidget(_SchriftRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing && oldWidget.entry.wert != widget.entry.wert) {
      _ctrl.text = '${widget.entry.wert}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveWert = widget.entry.wert + widget.entry.modifier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Name + Beschreibung
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.def.name),
                if (widget.def.beschreibung.isNotEmpty)
                  Text(
                    widget.def.beschreibung,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Komplexität
          SizedBox(
            width: 28,
            child: Text(
              widget.def.steigerung,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          // TaW
          SizedBox(
            width: 48,
            child: widget.isEditing
                ? TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        widget.onWertChanged(
                          parsed.clamp(0, widget.def.maxWert),
                        );
                      }
                    },
                  )
                : Text(
                    '$effectiveWert',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
          ),
          // Max
          SizedBox(
            width: 40,
            child: Text(
              '/${widget.def.maxWert}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Entfernen-Button
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              tooltip: 'Entfernen',
              onPressed: widget.onRemove,
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
