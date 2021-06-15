import 'dart:convert';
import 'dart:io' as io;

const Repo _kFramework = Repo(
  name: 'framework',
  path: 'C:\\code\\tmp\\repostats\\repos\\flutter',
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
    'packages/flutter_goldens_client/',
    'packages/flutter_localizations/',
    'packages/flutter_test/',
    'packages/flutter_tools/',
    'packages/flutter_web_plugins/',
    'packages/flutter_remote_debug_protocol/',
    'packages/integration_test/',
  ],
);

const Repo _kEngine = Repo(name: 'engine',    path: 'C:\\code\\tmp\\repostats\\repos\\engine');

const Repo _kPlugins = Repo(
  name: 'plugins',
  path: 'C:\\code\\tmp\\repostats\\repos\\plugins',
  layers: <String>[
    'packages/android_alarm_manager/',
    'packages/android_intent/',
    'packages/battery/',
    'packages/camera/',
    'packages/connectivity/',
    'packages/cross_file/',
    'packages/device_info/',
    'packages/e2e/',
    'packages/espresso/',
    'packages/file_selector/',
    'packages/flutter_plugin_android_lifecycle/',
    'packages/google_maps_flutter/',
    'packages/google_sign_in/',
    'packages/image_picker/',
    'packages/integration_test/',
    'packages/in_app_purchase/',
    'packages/ios_platform_images/',
    'packages/local_auth/',
    'packages/package_info/',
    'packages/path_provider/',
    'packages/plugin_platform_interface/',
    'packages/quick_actions/',
    'packages/sensors/',
    'packages/share/',
    'packages/shared_preferences/',
    'packages/url_launcher/',
    'packages/video_player/',
    'packages/webview_flutter/',
    'packages/wifi_info_flutter/',
  ],
);

const Repo _kPackages = Repo(
  name: 'packages',
  path: 'C:\\code\\tmp\\repostats\\repos\\packages',
  layers: <String>[
    'packages/animations/',
    'packages/cross_file/',
    'packages/css_colors/',
    'packages/extension_google_sign_in_as_googleapis_auth/',
    'packages/flutter_image/',
    'packages/flutter_lints/',
    'packages/flutter_markdown/',
    'packages/flutter_template_images/',
    'packages/fuchsia_ctl/',
    'packages/imitation_game/',
    'packages/metrics_center/',
    'packages/multicast_dns/',
    'packages/palette_generator/',
    'packages/pigeon/',
    'packages/pointer_interceptor/',
    'packages/web_benchmarks/',
    'packages/xdg_directories/',
  ],
);

const Repo _kGallery = Repo(name: 'gallery',   path: 'C:\\code\\tmp\\repostats\\repos\\gallery');
const Repo _kWebsite = Repo(name: 'website',   path: 'C:\\code\\tmp\\repostats\\repos\\website');
const Repo _kBuildroot = Repo(name: 'buildroot', path: 'C:\\code\\tmp\\repostats\\repos\\buildroot');
const Repo _kWebInstallers = Repo(name: 'web_installers', path: 'C:\\code\\tmp\\repostats\\repos\\web_installers');
const Repo _kAssetsForApiDocs = Repo(name: 'assets-for-api-docs', path: 'C:\\code\\tmp\\repostats\\repos\\assets-for-api-docs');
const Repo _kCocoon = Repo(name: 'cocoon', path: 'C:\\code\\tmp\\repostats\\repos\\cocoon');
const Repo _kDevtools = Repo(
  name: 'devtools',
  path: 'C:\\code\\tmp\\repostats\\repos\\devtools',
  layers: <String>[
    'packages/devtools/',
    'packages/devtools_app/',
    'packages/devtools_server/',
    'packages/devtools_shared/',
  ],
);
const Repo _kInfra = Repo(name: 'infra', path: 'C:\\code\\tmp\\repostats\\repos\\infra');
const Repo _kTests = Repo(name: 'tests', path: 'C:\\code\\tmp\\repostats\\repos\\tests');


// An active contributor is someone submitting at least 1 commit/month.
const int _kActiveContributorCommitCount = 12;

// If the portion of contributions to the main repo is less than this,
// the contributor is deemed a "cross-repo" contributor.
const double _kCrossRepoThreshold = 0.8;

// Pick a pair of repositories and a contributor. If the contributor contributed
// this much or more to each of the repositories, then the contributor is said
// to be a repository hopper, i.e. someone who has to regularly work across the
// repo divide.
const double _kRepoHopperThreshold = 0.1;

// The git stats are collected since this date.
const String _since = '2020-06-01';

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
  bool operator==(Object? other) {
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
    required this.allCommits,
  }) {
    humanCommits = allCommits.where((commit) => !commit.isAutoroll).toList();
    autorollCommits = allCommits.where((commit) => commit.isAutoroll).toList();
    byAuthorCommitCounts = <String, int>{};
    final Set<String> uniqueAuthors = <String>{};
    for (Commit commit in humanCommits) {
      final String author = commit.author;
      final int currentCount = byAuthorCommitCounts[author] ?? 0;
      byAuthorCommitCounts[author] = currentCount + 1;
      uniqueAuthors.add(author);
    }
    authors = uniqueAuthors.toList();
  }

  final Repo repo;
  final List<Commit> allCommits;
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
      value: (dynamic author) => (commits[author] as int) / totalCommitCount,
    );
  }

  final String author;
  final Map<Repo, int> commits;
  late final int totalCommitCount;
  late final Map<Repo, double> percentages;

  double get mainRepoLoad => _max(percentages.values);
}

Future<void> main(List<String> args) async {
  const List<Repo> repos = <Repo>[
    _kFramework,
    _kEngine,
    _kPlugins,
    _kPackages,
    _kGallery,
    _kWebsite,
    _kBuildroot,
    _kWebInstallers,
    _kAssetsForApiDocs,
    _kCocoon,
    _kDevtools,
    _kInfra,
    _kTests,
  ];

  final ProjectStats humanStats = await _computeProjectStats(repos);
  _printHumanAggregates(humanStats);
  await _saveProjectStats('author_stats.tsv', humanStats);
}

Future<ProjectStats> _computeProjectStats(List<Repo> repos) async {
  final List<RepoStats> allRepoStats = <RepoStats>[];
  final Set<String> allAuthors = <String>{};
  for (Repo repo in repos) {
    final RepoStats repoStats = await repo.getRepoStats();
    allRepoStats.add(repoStats);
    allAuthors.addAll(repoStats.authors);
  }

  final List<AuthorStats> authorStats = <AuthorStats>[];
  for (String author in allAuthors) {
    final Map<Repo, int> authorCommits = <Repo, int>{};
    for (RepoStats repoStats in allRepoStats) {
      int commitCount = repoStats.byAuthorCommitCounts[author] ?? 0;
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
  final StringBuffer buf = StringBuffer();

  for (Repo repo in projectStats.repos) {
    buf
      ..write('\t')
      ..write(repo.name);
  }
  buf.writeln('\ttotal');

  for (AuthorStats authorStats in projectStats.authorStats) {
    buf.write(authorStats.author);
    for (Repo repo in projectStats.repos) {
      int commits = authorStats.commits[repo]!;
      buf.write('\t$commits');
    }
    buf.writeln('\t${authorStats.totalCommitCount}');
  }
  final io.File statsFile = io.File(fileName);
  statsFile.writeAsStringSync(buf.toString());
}

void _printHumanAggregates(ProjectStats projectStats) {
  print('Statistics since $_since');
  int totalCommitCount = 0;
  int totalMultiLayerCommitCount = 0;
  int totalLayerCommitCount = 0;
  for (RepoStats repoStats in projectStats.repoStats) {
    totalCommitCount += repoStats.humanCommits.length;
    totalMultiLayerCommitCount += repoStats.multiLayerCommitCount;
    totalLayerCommitCount += repoStats.multiLayerCommitCount + repoStats.singleLayerCommitCount;
  }

  // All commits
  print('$totalCommitCount commits globally');
  for (RepoStats repoStats in projectStats.repoStats) {
    print('  ${repoStats.humanCommits.length} commits in ${repoStats.repo.name}');
  }

  // Cross-layer commits
  print('$totalLayerCommitCount layer commits globally, $totalMultiLayerCommitCount '
        '(${_percent(totalMultiLayerCommitCount, totalLayerCommitCount)}) cross-layer');

  for (RepoStats repoStats in projectStats.repoStats) {
    print('  ${repoStats.layerCommitCount} layer commits in ${repoStats.repo.name}, ${repoStats.multiLayerCommitCount} '
          '(${repoStats.crossLayerCommitPortion}) cross-layer');
  }

  final List<AuthorStats> activeContributors = projectStats.authorStats
    .where((AuthorStats stats) => stats.totalCommitCount >= _kActiveContributorCommitCount)
    .toList();

  int activeContributorCommits = 0;
  for (AuthorStats contributorStats in activeContributors) {
    activeContributorCommits += contributorStats.totalCommitCount;
  }
  print('${activeContributors.length} contributors contributed at least 1 commit per month (active contributors).');
  print('$activeContributorCommits commits (or ${_percent(activeContributorCommits, totalCommitCount)} of total) came from active contributors.');

  print('Contributors whose main repo portion is ${100 * _kCrossRepoThreshold}% or less are "cross-repo contributors".');
  final int crossRepoContributors = activeContributors
    .where((AuthorStats stats) => stats.mainRepoLoad < _kCrossRepoThreshold)
    .length;
  print('There have been $crossRepoContributors cross-repo contributors (or ${_percent(crossRepoContributors, activeContributors.length)} of all active).');

  print('Which repo splits contributors have to work across the most (a.k.a. repo hoppers):');
  final Map<RepoLink, int> repoLinks = <RepoLink, int>{};
  for (int i = 0; i < projectStats.repos.length; i++) {
    final Repo fromRepo = projectStats.repos[i];
    for (int j = i + 1; j < projectStats.repos.length; j++) {
      final Repo toRepo = projectStats.repos[j];
      final RepoLink link = RepoLink(from: fromRepo, to: toRepo);
      for (AuthorStats authorStats in activeContributors) {
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
  for (RepoStats repoStats in projectStats.repoStats) {
    int revertCount = 0;
    for (Commit commit in repoStats.humanCommits) {
      if (commit.isRevert) {
        revertCount += 1;
      }
    }
    print('  ${repoStats.repo.name} $revertCount');
  }

  _printEngineRollStats(projectStats);
}

void _printEngineRollStats(ProjectStats projectStats) {
  final RepoStats frameworkStats = projectStats.statsFor(_kFramework);

  print('Engine rolls:');
  int engineRollRevertCount = 0;
  int engineRollRevertedCommitCount = 0;
  for (RepoStats repoStats in projectStats.repoStats) {
    for (Commit commit in repoStats.humanCommits) {
      final AutorollInfo? autorollInfo = commit.autorollInfo;
      if (commit.isRevert && autorollInfo != null) {
        if (repoStats.repo == _kFramework) {
          engineRollRevertCount += 1;
          engineRollRevertedCommitCount += autorollInfo.commitCount ?? 0;
        }
      }
    }
  }

  final int engineRollCount = frameworkStats.autorollCommits.length;
  final int engineRollCommitCount = frameworkStats.autorollCommits.fold(0, (prev, value) => prev + (value.autorollInfo!.commitCount ?? 0));
  final int frameworkRevertCount = frameworkStats.humanCommits.where((c) => c.isRevert).length;
  final String percentOfRollsReverted = _percent(engineRollRevertCount, engineRollCount);
  final String percentOfReverts = _percent(engineRollRevertCount, frameworkRevertCount);

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
  bool operator==(Object? other) {
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
  final double percent = 100 * portion / total;
  return '${percent.toStringAsFixed(2)}%';
}

final RegExp _commitLinePrefix = RegExp(r'commit ([a-z0-9]{40})');

Future<List<Commit>> _gitLog(Repo repo) async {
  final io.Process gitLog = await io.Process.start(
    'git', ['log', '--since="$_since"', '--date=iso8601', '--name-only'],
    workingDirectory: repo.path,
  );
  _watchExitCode('git log', gitLog);

  String? sha;
  String? author;
  DateTime? commitDate;
  StringBuffer? message;
  List<String>? files;

  final List<Commit> commits = <Commit>[];

  void _flushCommit() {
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

  final List<String> lines = <String>[];
  gitLog.stdout
    .transform(const Utf8Decoder())
    .transform(const LineSplitter())
    .listen(lines.add);

  await gitLog.exitCode;

  for (final String line in lines) {
    final String trimmedLine = line.trim();
    try {
      final Match? commitStart = _commitLinePrefix.matchAsPrefix(line);
      if (commitStart != null) {
        if (sha != null) {
          _flushCommit();
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
    _flushCommit();
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
    required repo,
    required sha,
    required author,
    required date,
    required message,
    required files,
  }) {
    final List<String> messageLines = message
      .split('\n')
      .where((String line) => line.trim().isNotEmpty)
      .toList();
    final bool isAutoroll = author.contains('-autoroll');
    final bool isRevert = message.trim().toLowerCase().startsWith('revert');

    String? revertedCommit;
    if (isRevert) {
      for (String line in messageLines) {
        const String revertMessage = 'This reverts commit';
        final int indexOfRevertMessage = line.indexOf(revertMessage);
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
    required this.isAutoroll,
    required this.autorollInfo,
  });

  static CrossLayer _getCrossLayerType(Repo repo, List<String> files) {
    if (repo.layers.isEmpty) {
      return CrossLayer.nonLayer;
    }
    final Set<String> changedLayers = <String>{};
    for (String file in files) {
      for (String layer in repo.layers) {
        if (file.startsWith(layer)) {
          changedLayers.add(layer);
        }
      }
    }
    if (changedLayers.length == 0) {
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
  final isAutoroll;
  final AutorollInfo? autorollInfo;

  String toString() {
    return '''commit $sha
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
      final int? commitCount = revisionCountMatch != null
        ? int.parse(revisionCountMatch.group(1)!)
        : null;

      Match? revisionRangeMatch = _kRevisionRange.firstMatch(messageLines.first);
      if (revisionRangeMatch == null) {
        revisionRangeMatch = _kFuchsiaRevisionRange.firstMatch(messageLines.first);
      }
      final String? fromCommit = revisionRangeMatch?.group(1)!;
      final String? toCommit = revisionRangeMatch?.group(2)!;

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
