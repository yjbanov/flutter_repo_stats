import 'dart:convert';
import 'dart:io' as io;

// A top contributor is someone submitting at least 1 commit/month.
const int _kTopContributorCommitCount = 12;

// If portion of contributions to the main repo is less than this,
// the contributor is deemed a "cross-repo" contributor.
const double _kCrossRepoThreshold = 0.8;

const String _since = '2020-06-01';

class Repo {
  const Repo({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;

  @override
  int get hashCode => name.hashCode + 17 * path.hashCode;

  @override
  bool operator==(Object? other) {
    return other is Repo && name == other.name && path == other.path;
  }

  Future<RepoStats> getRepoStats(bool Function(String) authorPredicate) async {
    final List<Commit> commits = await _gitLog(path, _since);
    final Map<String, int> stats = <String, int>{};
    for (Commit commit in commits) {
      final String author = commit.author;
      if (authorPredicate(author)) {
        stats[author] ??= 0;
        stats[author] = stats[author]! + 1;
      }
    }
    return RepoStats(
      repo: this,
      stats: stats,
      commits: commits,
    );
  }
}

class ProjectStats {
  ProjectStats({
    required this.repoStats,
    required this.authorStats,
  });

  final List<RepoStats> repoStats;
  final List<AuthorStats> authorStats;

  List<Repo> get repos => repoStats.map((s) => s.repo).toList();
  RepoStats forRepo(String repoName) => repoStats.firstWhere((s) => s.repo.name == repoName);
}

class RepoStats {
  RepoStats({
    required this.repo,
    required this.stats,
    required this.commits,
  }) {
    totalCommitCount = stats.values.fold(0, (prev, count) => prev + count);
  }

  final Repo repo;
  final Map<String, int> stats;
  late final int totalCommitCount;
  final List<Commit> commits;
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
    Repo(name: 'framework', path: 'C:\\code\\tmp\\repostats\\repos\\flutter'),
    Repo(name: 'engine',    path: 'C:\\code\\tmp\\repostats\\repos\\engine'),
    Repo(name: 'plugins',   path: 'C:\\code\\tmp\\repostats\\repos\\plugins'),
    Repo(name: 'packages',  path: 'C:\\code\\tmp\\repostats\\repos\\packages'),
    Repo(name: 'gallery',   path: 'C:\\code\\tmp\\repostats\\repos\\gallery'),
    // Repo(name: 'website',   path: 'C:\\code\\tmp\\repostats\\repos\\website'),
    Repo(name: 'buildroot', path: 'C:\\code\\tmp\\repostats\\repos\\buildroot'),
  ];

  bool isRoller(String author) => author.contains('-autoroll');
  final ProjectStats humanStats = await _computeProjectStats(repos, (author) => !isRoller(author));
  final ProjectStats botStats = await _computeProjectStats(repos, isRoller);
  _printHumanAggregates(humanStats);
  await _saveProjectStats('author_stats.tsv', humanStats);
  await _saveProjectStats('roller_stats.tsv', botStats);
}

Future<ProjectStats> _computeProjectStats(List<Repo> repos, bool Function(String) authorPredicate) async {
  final List<RepoStats> allRepoStats = <RepoStats>[];
  for (Repo repo in repos) {
    allRepoStats.add(await repo.getRepoStats(authorPredicate));
  }

  final Set<String> authors = <String>{
    ...allRepoStats.expand((e) => e.stats.keys)
  };

  final List<AuthorStats> allAuthorStats = <AuthorStats>[];
  for (String author in authors) {
    final Map<Repo, int> authorCommits = <Repo, int>{};
    for (RepoStats repoStats in allRepoStats) {
      int commitCount = repoStats.stats[author] ?? 0;
      authorCommits[repoStats.repo] = commitCount;
    }
    allAuthorStats.add(AuthorStats(
      author: author,
      commits: authorCommits,
    ));
  }
  return ProjectStats(
    repoStats: allRepoStats,
    authorStats: allAuthorStats,
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

final RegExp _kRollRevisionCount = RegExp(r'\((\d)+ revision[s]?\)');

void _printHumanAggregates(ProjectStats humanStats) {
  print('Statistics since $_since');
  int totalCommitCount = 0;
  for (RepoStats repoStats in humanStats.repoStats) {
    totalCommitCount += repoStats.totalCommitCount;
  }
  print('$totalCommitCount commits globally');

  for (RepoStats repoStats in humanStats.repoStats) {
    print('  ${repoStats.commits.length} commits in ${repoStats.repo.name}');
  }

  final List<AuthorStats> activeContributors = humanStats.authorStats
    .where((AuthorStats stats) => stats.totalCommitCount >= _kTopContributorCommitCount)
    .toList();

  int topContributorCommits = 0;
  for (AuthorStats contributorStats in activeContributors) {
    topContributorCommits += contributorStats.totalCommitCount;
  }
  print('${activeContributors.length} contributors contributed at least 1 commit per month (active contributors)');
  print('$topContributorCommits commits (or ${_percent(topContributorCommits, totalCommitCount)} of total) came from active contributors');

  print('Contributors whose main repo portion is ${100 * _kCrossRepoThreshold}% or less are "cross-repo contributors"');
  final int crossRepoContributors = activeContributors
    .where((AuthorStats stats) => stats.mainRepoLoad < _kCrossRepoThreshold)
    .length;
  print('There have been $crossRepoContributors cross-repo contributors (or ${_percent(crossRepoContributors, activeContributors.length)} of all active)');

  print('Repository hoppers: which repo splits contributors have to work across the most');
  final Map<RepoLink, int> repoLinks = <RepoLink, int>{};
  for (int i = 0; i < humanStats.repos.length; i++) {
    final Repo fromRepo = humanStats.repos[i];
    for (int j = i + 1; j < humanStats.repos.length; j++) {
      final Repo toRepo = humanStats.repos[j];
      final RepoLink link = RepoLink(from: fromRepo, to: toRepo);
      for (AuthorStats authorStats in activeContributors) {
        if (authorStats.percentages[fromRepo]! > 0.1 && authorStats.percentages[toRepo]! > 0.1) {
          repoLinks[link] ??= 0;
          repoLinks[link] = repoLinks[link]! + 1;
        }
      }
    }
  }
  repoLinks.forEach((RepoLink link, int count) {
    print('  ${link.from.name} => ${link.to.name}: $count contributors');
  });

  print('Reverts:');
  int engineRollRevertCount = 0;
  int engineRollCommitReverts = 0;
  for (RepoStats repoStats in humanStats.repoStats) {
    int revertCount = 0;
    for (Commit commit in repoStats.commits) {
      if (commit.message.trim().toLowerCase().startsWith('revert')) {
        revertCount += 1;
        if (repoStats.repo.name == 'framework') {
          final Match? revisionCountMatch = _kRollRevisionCount.firstMatch(commit.messageLines.first);
          if (revisionCountMatch != null) {
            engineRollRevertCount += 1;
            engineRollCommitReverts += int.parse(revisionCountMatch.group(1)!);
          }
        }
      }
    }
    print('  ${repoStats.repo.name} $revertCount');
  }
  print('Engine rolls were reverted $engineRollRevertCount times (${_percent(engineRollRevertCount, humanStats.forRepo('framework').commits.length)})');
  print('Engine reverts reverted $engineRollCommitReverts commits');
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
  final double percent = 100 * portion / total;
  return '${percent.toStringAsFixed(2)}%';
}

final RegExp _commitLinePrefix = RegExp(r'commit ([a-z0-9]{40})');

Future<List<Commit>> _gitLog(String path, String since) async {
  final io.Process gitLog = await io.Process.start(
    'git', ['log', '--since="$_since"', '--date=iso8601'],
    workingDirectory: path,
  );
  _watchExitCode('git log', gitLog);

  String? sha;
  String? author;
  DateTime? commitDate;
  StringBuffer? message;

  final List<Commit> commits = <Commit>[];

  void _flushCommit() {
    commits.add(Commit(
      sha: sha!,
      author: author!,
      date: commitDate!,
      message: message!.toString(),
    ));
    sha = null;
    author = null;
    commitDate = null;
    message = null;
  }

  final List<String> lines = <String>[];
  gitLog.stdout
    .transform(const Utf8Decoder())
    .transform(const LineSplitter())
    .listen(lines.add);

  await gitLog.exitCode;

  for (final String line in lines) {
    try {
      final Match? commitStart = _commitLinePrefix.matchAsPrefix(line);
      if (commitStart != null) {
        if (sha != null) {
          _flushCommit();
        }
        sha = commitStart.group(1);
        message = StringBuffer();
      } else if (line.startsWith('Author:')) {
        author = line.substring(8);
      } else if (line.startsWith('Date:')) {
        commitDate = DateTime.parse(line.substring(8));
      } else {
        message!.writeln(line);
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

class Commit {
  Commit({
    required this.sha,
    required this.author,
    required this.date,
    required this.message,
  });

  final String sha;
  final String author;
  final DateTime date;
  final String message;

  List<String> get messageLines => message
    .split('\n')
    .where((String line) => line.trim().isNotEmpty)
    .toList();

  String toString() {
    return '''commit $sha
Author: $author
Date:   $date
$message''';
  }
}
