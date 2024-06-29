// Copyright 2014 The Flutter Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:io' as io;

const String repoCheckoutRoot = '/Users/yjbanov/code/tmp/repostats';

const Repo _kFramework = Repo(
  name: 'framework',
  path: '$repoCheckoutRoot/flutter',
  layers: <String>[
    'packages/flutter/lib/src/animation/',
    'packages/flutter/lib/src/cupertino/',
    'packages/flutter/lib/src/foundation/',
    'packages/flutter/lib/src/gestures/',
    'packages/flutter/lib/src/material/',
    'packages/flutter/lib/src/painting/',
    'packages/flutter/lib/src/physics/',
    'packages/flutter/lib/src/rendering/',
    'packages/flutter/lib/src/scheduler/',
    'packages/flutter/lib/src/semantics/',
    'packages/flutter/lib/src/services/',
    'packages/flutter/lib/src/widgets/',
    'packages/flutter_driver/',
    'packages/flutter_goldens/',
    'packages/flutter_localizations/',
    'packages/flutter_test/',
    'packages/flutter_tools/',
    'packages/flutter_web_plugins/',
    'packages/flutter_remote_debug_protocol/',
    'packages/integration_test/',
  ],
);

const Repo _kEngine = Repo(
  name: 'engine',
  path: '$repoCheckoutRoot/engine',
);

const Repo _kPackages = Repo(
  name: 'packages',
  path: '$repoCheckoutRoot/packages',
  layers: <String>[
    'packages/animations/',
    'packages/interactive_media_ads/',
    'packages/camera/',
    'packages/ios_platform_images/',
    'packages/cross_file/',
    'packages/local_auth/',
    'packages/css_colors/',
    'packages/metrics_center/',
    'packages/multicast_dns/',
    'packages/espresso/',
    'packages/palette_generator/',
    'packages/extension_google_sign_in_as_googleapis_auth/',
    'packages/path_provider/',
    'packages/file_selector/',
    'packages/pigeon/',
    'packages/flutter_adaptive_scaffold/',
    'packages/platform/',
    'packages/flutter_image/',
    'packages/plugin_platform_interface/',
    'packages/flutter_lints/',
    'packages/pointer_interceptor/',
    'packages/flutter_markdown/',
    'packages/process/',
    'packages/flutter_migrate/',
    'packages/quick_actions/',
    'packages/flutter_plugin_android_lifecycle/',
    'packages/rfw/',
    'packages/flutter_template_images/',
    'packages/shared_preferences/',
    'packages/go_router/',
    'packages/standard_message_codec/',
    'packages/go_router_builder/',
    'packages/two_dimensional_scrollables/',
    'packages/google_identity_services_web/',
    'packages/url_launcher/',
    'packages/google_maps_flutter/',
    'packages/video_player/',
    'packages/google_sign_in/',
    'packages/web_benchmarks/',
    'packages/image_picker/',
    'packages/webview_flutter/',
    'packages/in_app_purchase/',
    'packages/xdg_directories/',
    'packages/integration_test/',
  ],
);

// An active contributor is someone submitting at least 1 commit/month.
const int _kActiveContributorCommitCount = 12;

// If the portion of contributions to the main repo is less than this,
// the contributor is deemed a "cross-repo" contributor.
const double _kCrossRepoThreshold = 0.9;

// Pick a pair of repositories and a contributor. If the contributor contributed
// this much or more to each of the repositories, then the contributor is said
// to be a repository hopper, i.e. someone who has to regularly work across the
// repo divide.
const double _kRepoHopperThreshold = 0.1;

// The git stats are collected since this date.
const String _since = '2023-06-28';

class Repo {
  const Repo({
    required this.name,
    required this.path,
    this.layers = const <String>[],
  });

  final String name;
  final String path;
  final List<String> layers;

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator==(Object other) {
    return other is Repo && name == other.name;
  }

  Future<RepoStats> getRepoStats() async {
    return RepoStats(
      repo: this,
      allCommits: await _gitLog(this),
    );
  }
}

class ProjectStats {
  ProjectStats({
    required this.repos,
    required this.repoStats,
    required this.authorStats,
  });

  final List<RepoStats> repoStats;
  final List<AuthorStats> authorStats;
  final List<Repo> repos;
  RepoStats statsFor(Repo repo) => repoStats[repos.indexOf(repo)];
}

class RepoStats {
  RepoStats({
    required this.repo,
    required List<Commit> allCommits,
  }) {
    humanCommits = allCommits.where((commit) => commit.isHuman).toList();
    autorollCommits = allCommits.where((commit) => commit.isAutoroll).toList();
    byAuthorCommitCounts = <String, int>{};
    final uniqueAuthors = <String>{};
    for (final commit in humanCommits) {
      final author = commit.author;
      final currentCount = byAuthorCommitCounts[author] ?? 0;
      byAuthorCommitCounts[author] = currentCount + 1;
      uniqueAuthors.add(author);
    }
    authors = uniqueAuthors.toList();
  }

  final Repo repo;
  late final List<Commit> humanCommits;
  late final List<Commit> autorollCommits;
  late final Map<String, int> byAuthorCommitCounts;
  late final List<String> authors;

  int get multiLayerCommitCount => humanCommits.where((c) => c.crossLayer == CrossLayer.multiLayer).length;
  int get singleLayerCommitCount => humanCommits.where((c) => c.crossLayer == CrossLayer.singleLayer).length;
  int get nonLayerCommitCount => humanCommits.where((c) => c.crossLayer == CrossLayer.nonLayer).length;
  int get layerCommitCount => multiLayerCommitCount + singleLayerCommitCount;

  /// Percentage of commits that cross layers.
  String get crossLayerCommitPortion => _percent(multiLayerCommitCount, layerCommitCount);
}

class AuthorStats {
  AuthorStats({
    required this.author,
    required this.commits,
  }) {
    totalCommitCount = commits.entries
      .fold<int>(0, (previousValue, element) => previousValue + element.value);
    percentages = Map.fromIterable(
      commits.keys,
      value: (dynamic author) => (commits[author]!) / totalCommitCount,
    );
  }

  final String author;
  final Map<Repo, int> commits;
  late final int totalCommitCount;
  late final Map<Repo, double> percentages;

  double get mainRepoLoad => _max(percentages.values);
}

Future<void> main(List<String> args) async {
  const repos = <Repo>[
    _kFramework,
    _kEngine,
    _kPackages,
  ];

  final humanStats = await _computeProjectStats(repos);
  _printHumanAggregates(humanStats);
  await _saveProjectStats('author_stats.tsv', humanStats);
}

Future<ProjectStats> _computeProjectStats(List<Repo> repos) async {
  final allRepoStats = <RepoStats>[];
  final allAuthors = <String>{};
  for (final repo in repos) {
    final repoStats = await repo.getRepoStats();
    allRepoStats.add(repoStats);
    allAuthors.addAll(repoStats.authors);
  }

  final authorStats = <AuthorStats>[];
  for (final author in allAuthors) {
    final authorCommits = <Repo, int>{};
    for (final repoStats in allRepoStats) {
      final commitCount = repoStats.byAuthorCommitCounts[author] ?? 0;
      authorCommits[repoStats.repo] = commitCount;
    }
    authorStats.add(AuthorStats(
      author: author,
      commits: authorCommits,
    ));
  }
  return ProjectStats(
    repos: repos,
    repoStats: allRepoStats,
    authorStats: authorStats,
  );
}

Future<void> _saveProjectStats(String fileName, ProjectStats projectStats) async {
  final buf = StringBuffer();

  for (final repo in projectStats.repos) {
    buf
      ..write('\t')
      ..write(repo.name);
  }
  buf.writeln('\ttotal');

  for (final authorStats in projectStats.authorStats) {
    buf.write(authorStats.author);
    for (final repo in projectStats.repos) {
      final commits = authorStats.commits[repo]!;
      buf.write('\t$commits');
    }
    buf.writeln('\t${authorStats.totalCommitCount}');
  }
  final statsFile = io.File(fileName);
  statsFile.writeAsStringSync(buf.toString());
}

void _printHumanAggregates(ProjectStats projectStats) {
  print('Statistics since $_since');
  var totalCommitCount = 0;
  var totalMultiLayerCommitCount = 0;
  var totalLayerCommitCount = 0;
  for (final repoStats in projectStats.repoStats) {
    totalCommitCount += repoStats.humanCommits.length;
    totalMultiLayerCommitCount += repoStats.multiLayerCommitCount;
    totalLayerCommitCount += repoStats.multiLayerCommitCount + repoStats.singleLayerCommitCount;
  }

  // All commits
  print('$totalCommitCount commits globally');
  for (final repoStats in projectStats.repoStats) {
    print('  ${repoStats.humanCommits.length} commits in ${repoStats.repo.name}');
  }

  // Cross-layer commits
  print('$totalLayerCommitCount layer commits globally, $totalMultiLayerCommitCount '
        '(${_percent(totalMultiLayerCommitCount, totalLayerCommitCount)}) cross-layer');

  for (final repoStats in projectStats.repoStats) {
    print('  ${repoStats.layerCommitCount} layer commits in ${repoStats.repo.name}, ${repoStats.multiLayerCommitCount} '
          '(${repoStats.crossLayerCommitPortion}) cross-layer');
  }

  final activeContributors = projectStats.authorStats
    .where((AuthorStats stats) => stats.totalCommitCount >= _kActiveContributorCommitCount)
    .toList();
  activeContributors.sort((a, b) {
    return b.totalCommitCount - a.totalCommitCount;
  });

  print('Active contributors:');
  for (final contributor in activeContributors) {
    print('  > ${contributor.author} (${contributor.totalCommitCount})');
  }

  var activeContributorCommits = 0;
  for (final contributorStats in activeContributors) {
    activeContributorCommits += contributorStats.totalCommitCount;
  }
  print('${activeContributors.length} contributors contributed at least 1 commit per month (active contributors).');
  print('$activeContributorCommits commits (or ${_percent(activeContributorCommits, totalCommitCount)} of total) came from active contributors.');

  print('Contributors whose main repo portion is ${100 * _kCrossRepoThreshold}% or less are "cross-repo contributors".');
  final crossRepoContributors = activeContributors
    .where((AuthorStats stats) => stats.mainRepoLoad < _kCrossRepoThreshold)
    .toList();
  final crossRepoContributorCount = crossRepoContributors.length;
  print('There have been $crossRepoContributorCount cross-repo contributors (or ${_percent(crossRepoContributorCount, activeContributors.length)} of all active).');

  print('Which repo splits contributors have to work across the most (a.k.a. repo hoppers):');
  final repoLinks = <RepoLink, int>{};
  for (var i = 0; i < projectStats.repos.length; i++) {
    final fromRepo = projectStats.repos[i];
    for (var j = i + 1; j < projectStats.repos.length; j++) {
      final toRepo = projectStats.repos[j];
      final link = RepoLink(from: fromRepo, to: toRepo);
      for (final authorStats in activeContributors) {
        if (authorStats.percentages[fromRepo]! > 0.1 && authorStats.percentages[toRepo]! > _kRepoHopperThreshold) {
          repoLinks[link] ??= 0;
          repoLinks[link] = repoLinks[link]! + 1;
        }
      }
    }
  }
  repoLinks.forEach((RepoLink link, int count) {
    print('  ${link.from.name} | ${link.to.name}: $count contributors');
  });

  print('Reverts:');
  for (final repoStats in projectStats.repoStats) {
    var revertCount = 0;
    for (final commit in repoStats.humanCommits) {
      if (commit.isRevert) {
        revertCount += 1;
      }
    }
    print('  ${repoStats.repo.name} $revertCount');
  }

  _printEngineRollStats(projectStats);
}

void _printEngineRollStats(ProjectStats projectStats) {
  final frameworkStats = projectStats.statsFor(_kFramework);

  print('Engine rolls:');
  var engineRollRevertCount = 0;
  var engineRollRevertedCommitCount = 0;
  for (final repoStats in projectStats.repoStats) {
    for (final commit in repoStats.humanCommits) {
      final autorollInfo = commit.autorollInfo;
      if (commit.isRevert && autorollInfo != null) {
        if (repoStats.repo == _kFramework) {
          engineRollRevertCount += 1;
          engineRollRevertedCommitCount += autorollInfo.commitCount ?? 0;
        }
      }
    }
  }

  final engineRollCount = frameworkStats.autorollCommits.length;
  final engineRollCommitCount = frameworkStats.autorollCommits.fold<int>(0, (prev, value) => prev + (value.autorollInfo!.commitCount ?? 0));
  final frameworkRevertCount = frameworkStats.humanCommits.where((c) => c.isRevert).length;
  final percentOfRollsReverted = _percent(engineRollRevertCount, engineRollCount);
  final percentOfReverts = _percent(engineRollRevertCount, frameworkRevertCount);

  print('  Engine was rolled $engineRollCount times.');
  print('  $engineRollCommitCount engine commits were rolled into the framework, including rerolled commits.');
  print('  Engine rolls were reverted $engineRollRevertCount times ($percentOfRollsReverted of roll, $percentOfReverts of reverts).');
  print('  On average an engine roll is reverted once every ${(365 / engineRollRevertCount).toStringAsFixed(1)} days');
  print('  Engine reverts reverted $engineRollRevertedCommitCount commits.');
  print('  On average an engine commit is reverted due to roller revert once every ${(365 / engineRollRevertedCommitCount).toStringAsFixed(1)} days');
  print('  On average an engine revert reverted ${(engineRollRevertedCommitCount / engineRollRevertCount).toStringAsFixed(2)} commits.');
}

class RepoLink {
  RepoLink({
    required this.from,
    required this.to,
  });

  final Repo from;
  final Repo to;

  @override
  int get hashCode => from.hashCode + 17 * to.hashCode;

  @override
  bool operator==(Object other) {
    return other is RepoLink && from == other.from && to == other.to;
  }
}

void _watchExitCode(String name, io.Process process) {
  process.exitCode.then((int exitCode) {
    if (exitCode != 0) {
      io.stderr.write('Process $name failed with exit code $exitCode');
    }
  });
}

T _max<T extends num>(Iterable<T> values) {
  return values.reduce((value, element) => value > element ? value : element);
}

String _percent(num portion, num total) {
  if (total == 0) {
    return 'N/A';
  }
  final percent = 100 * portion / total;
  return '${percent.toStringAsFixed(2)}%';
}

final RegExp _commitLinePrefix = RegExp(r'commit ([a-z0-9]{40})');

Future<List<Commit>> _gitLog(Repo repo) async {
  final gitLog = await io.Process.start(
    'git', ['log', '--since="$_since"', '--date=iso8601', '--name-only'],
    workingDirectory: repo.path,
  );
  _watchExitCode('git log', gitLog);

  String? sha;
  String? author;
  DateTime? commitDate;
  StringBuffer? message;
  List<String>? files;

  final commits = <Commit>[];

  void flushCommit() {
    commits.add(Commit(
      repo: repo,
      sha: sha!,
      author: author!,
      date: commitDate!,
      message: message!.toString(),
      files: files!,
    ));
    sha = null;
    author = null;
    commitDate = null;
    message = null;
    files = null;
  }

  final lines = <String>[];
  gitLog.stdout
    .transform(const Utf8Decoder())
    .transform(const LineSplitter())
    .listen(lines.add);

  await gitLog.exitCode;

  for (final line in lines) {
    final trimmedLine = line.trim();
    try {
      final commitStart = _commitLinePrefix.matchAsPrefix(line);
      if (commitStart != null) {
        if (sha != null) {
          flushCommit();
        }
        sha = commitStart.group(1);
        message = StringBuffer();
        files = <String>[];
      } else if (line.startsWith('Author:')) {
        author = line.substring(8);
      } else if (line.startsWith('Date:')) {
        commitDate = DateTime.parse(line.substring(8));
      } else if (line.startsWith('Merge:')) {
        // Skip merge info
      } else if (line.startsWith(' ') || trimmedLine.isEmpty) {
        message!.writeln(line);
      } else if (trimmedLine.isNotEmpty) {
        files!.add(trimmedLine);
      }
    } catch (error) {
      print('Error on line: $line');
      rethrow;
    }
  }
  if (sha != null) {
    flushCommit();
  }
  return commits;
}

enum CrossLayer {
  /// The commit changes multiple layers.
  multiLayer,
  /// The commit changes only one layer.
  singleLayer,
  /// The commit does not change code participating in a layered architecture (e.g. CI configuration commit).
  nonLayer,
}

class Commit {
  factory Commit({
    required Repo repo,
    required String sha,
    required String author,
    required DateTime date,
    required String message,
    required List<String> files,
  }) {
    final messageLines = message
      .split('\n')
      .where((String line) => line.trim().isNotEmpty)
      .toList();
    final isAutoroll = author.contains('-autoroll');
    final isBot =
      author.contains('dependabot') ||
      author.contains('pub-roller-bot') ||
      author.contains('auto-submit') ||
      author.contains('Flutter GitHub Bot');
    final isRevert = message.trim().toLowerCase().startsWith('revert');

    String? revertedCommit;
    if (isRevert) {
      for (final line in messageLines) {
        const revertMessage = 'This reverts commit';
        final indexOfRevertMessage = line.indexOf(revertMessage);
        if (indexOfRevertMessage != -1) {
          revertedCommit = line.substring(indexOfRevertMessage + revertMessage.length).trim();
          break;
        }
      }
    }

    return Commit._(
      repo: repo,
      sha: sha,
      author: author,
      date: date,
      message: message,
      files: files,
      messageLines: messageLines,
      crossLayer: _getCrossLayerType(repo, files),
      isRevert: isRevert,
      revertedCommit: revertedCommit,
      isBot: isBot,
      isAutoroll: isAutoroll,
      autorollInfo: AutorollInfo.fromMessage(
        messageLines: messageLines,
        isAutoroll: isAutoroll,
        isRevert: isRevert,
      ),
    );
  }

  Commit._({
    required this.repo,
    required this.sha,
    required this.author,
    required this.date,
    required this.message,
    required this.files,
    required this.messageLines,
    required this.crossLayer,
    required this.isRevert,
    required this.revertedCommit,
    required this.isBot,
    required this.isAutoroll,
    required this.autorollInfo,
  });

  static CrossLayer _getCrossLayerType(Repo repo, List<String> files) {
    if (repo.layers.isEmpty) {
      return CrossLayer.nonLayer;
    }
    final changedLayers = <String>{};
    for (final file in files) {
      for (final layer in repo.layers) {
        if (file.startsWith(layer)) {
          changedLayers.add(layer);
        }
      }
    }
    if (changedLayers.isEmpty) {
      return CrossLayer.nonLayer;
    } else if (changedLayers.length == 1) {
      return CrossLayer.singleLayer;
    } else {
      return CrossLayer.multiLayer;
    }
  }

  final Repo repo;
  final String sha;
  final String author;
  final DateTime date;
  final String message;
  final List<String> files;
  final List<String> messageLines;
  final CrossLayer crossLayer;
  final bool isRevert;
  final String? revertedCommit;
  final bool isBot;
  final bool isAutoroll;
  final AutorollInfo? autorollInfo;

  bool get isHuman => !isBot && !isAutoroll;

  @override
  String toString() {
    return '''
commit $sha
Author: $author
Date:   $date
$message
${files.join('\n')}
''';
  }
}

// Looks for strings like "(4 revisions)" and "(1 revision)" that are
// included by the autorollers in the commit messages.
final RegExp _kRollRevisionCount = RegExp(r'\((\d)+ revision[s]?\)');

class AutorollInfo {
  AutorollInfo({
    required this.commitCount,
    required this.fromCommit,
    required this.toCommit,
  });

  static final RegExp _kRevisionRange = RegExp(r'from ([a-z0-9]{12}) to ([a-z0-9]{12})');
  static final RegExp _kFuchsiaRevisionRange = RegExp(r'from ([a-zA-Z0-9\-_]{5,})\.\.\. to ([a-zA-Z0-9\-_]{5,})\.\.\.');

  static AutorollInfo? fromMessage({
    required List<String> messageLines,
    required bool isRevert,
    required bool isAutoroll,
  }) {
    try {
      if (!isRevert && !isAutoroll) {
        // Autoroll information is only available on autorolls or
        // reverts of autorolls.
        return null;
      }

      if (isRevert && !messageLines.first.toLowerCase().contains('roll ')) {
        // The change that's being reverted doesn't appear to be a roll.
        return null;
      }

      final Match? revisionCountMatch = _kRollRevisionCount.firstMatch(messageLines.first);
      final commitCount = revisionCountMatch != null
        ? int.parse(revisionCountMatch.group(1)!)
        : null;

      Match? revisionRangeMatch = _kRevisionRange.firstMatch(messageLines.first);
      revisionRangeMatch ??= _kFuchsiaRevisionRange.firstMatch(messageLines.first);
      final fromCommit = revisionRangeMatch?.group(1);
      final toCommit = revisionRangeMatch?.group(2);

      return AutorollInfo(
        commitCount: commitCount,
        fromCommit: fromCommit,
        toCommit: toCommit,
      );
    } catch (error) {
      print('''
Failed to parse autoroll info (revert: $isRevert, autoroll: $isAutoroll):
  ${messageLines.join('\n  ')}
'''.trim());
      rethrow;
    }
  }

  final int? commitCount;
  final String? fromCommit;
  final String? toCommit;
}
