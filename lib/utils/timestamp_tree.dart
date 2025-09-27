import 'sync_tree.dart';

export 'sync_tree.dart';

typedef TimestampSyncPoint = SyncPoint<Duration>;

class TimestampTree extends SyncTree<Duration> {}

class BeatTree extends SyncTree<int> {}