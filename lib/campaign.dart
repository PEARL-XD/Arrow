/// Four fifteen-stage stories, followed by the existing optional Crown Keeper.
const chapterLength = 15;
const storyLevelCount = 60;
const campaignVersion = 2;
const previousStageOffsets = [0, 1, 3, 4, 6, 7, 9, 11, 13, 14];

int expandedStage(int old) =>
    old == 40 ? 60 : old ~/ 10 * chapterLength + previousStageOffsets[old % 10];

/// Preserve earned milestones when inserting stages into a previously played
/// chapter. Added stages before the old frontier are grandfathered, without
/// paying coins or inventing time records; they remain available for replay.
Map<String, dynamic> migrateCampaign(Map<String, dynamic> source) {
  if (source['campaignVersion'] == campaignVersion) return source;
  if (source['campaignVersion'] != null && source['campaignVersion'] != 1) {
    throw const FormatException('Unsupported campaign version');
  }
  final oldIndex = source['index'];
  final raw = source['completed'];
  if (oldIndex is! int || oldIndex < 0 || oldIndex > 40 || raw is! List) {
    throw const FormatException('Invalid previous campaign');
  }
  final oldCompleted = raw.cast<int>().toSet();
  if (oldCompleted.any((i) => i < 0 || i > 40)) {
    throw const FormatException('Invalid previous milestones');
  }
  var frontier = 0;
  while (frontier < 40 && oldCompleted.contains(frontier)) {
    frontier++;
  }
  final mappedFrontier = expandedStage(frontier);
  final completed = oldCompleted.map(expandedStage).toSet();
  // Only fill inserted stages below genuine contiguous progress, not skips.
  for (var i = 0; i < mappedFrontier; i++) {
    completed.add(i);
  }
  final result = Map<String, dynamic>.from(source)
    ..['campaignVersion'] = campaignVersion
    ..['index'] = expandedStage(oldIndex)
    ..['completed'] = completed.toList();
  if (source['storyVersion'] == null || source['legacyAttempt'] == true) {
    result['legacyLevelIndex'] = source['legacyLevelIndex'] ?? oldIndex;
  }
  final rawRewards = source['rewards'];
  if (rawRewards is Map) {
    final rewards = Map<String, dynamic>.from(rawRewards);
    for (final name in ['best', 'times', 'speed', 'skills']) {
      final records = rewards[name];
      if (records is! Map) throw const FormatException('Invalid records');
      if (records.keys.any((key) {
        final old = int.tryParse('$key');
        return old == null || old < 0 || old > 40;
      })) {
        throw const FormatException('Invalid previous record index');
      }
      rewards[name] = {
        for (final entry in records.entries)
          '${expandedStage(int.parse(entry.key as String))}': entry.value,
      };
    }
    result['rewards'] = rewards;
  }
  return result;
}
