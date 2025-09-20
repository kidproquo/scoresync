import 'dart:developer' as developer;
import '../models/rectangle.dart';

/// Node colors for the red-black tree
enum NodeColor { red, black }

/// A sync point entry in the tree
class SyncPoint {
  final Duration timestamp;
  final DrawnRectangle rectangle;
  final int pageNumber;

  SyncPoint({
    required this.timestamp,
    required this.rectangle,
    required this.pageNumber,
  });
}

/// Node in the red-black tree
class _RBNode {
  SyncPoint syncPoint;
  _RBNode? left;
  _RBNode? right;
  _RBNode? parent;
  NodeColor color;

  _RBNode(this.syncPoint) : color = NodeColor.red;

  Duration get timestamp => syncPoint.timestamp;
}

/// Red-Black Tree implementation for efficient timestamp lookup
/// Provides O(log n) search, insert, and delete operations
class TimestampTree {
  _RBNode? _root;
  int _size = 0;

  int get size => _size;
  bool get isEmpty => _root == null;

  /// Insert a sync point into the tree
  void insert(SyncPoint syncPoint) {
    developer.log('Inserting sync point at ${_formatDuration(syncPoint.timestamp)}');
    
    final newNode = _RBNode(syncPoint);
    
    if (_root == null) {
      _root = newNode;
      _root!.color = NodeColor.black;
      _size++;
      return;
    }

    // Standard BST insertion
    _RBNode? parent;
    _RBNode? current = _root;

    while (current != null) {
      parent = current;
      if (newNode.timestamp.inMilliseconds < current.timestamp.inMilliseconds) {
        current = current.left;
      } else {
        current = current.right;
      }
    }

    newNode.parent = parent;
    if (newNode.timestamp.inMilliseconds < parent!.timestamp.inMilliseconds) {
      parent.left = newNode;
    } else {
      parent.right = newNode;
    }

    _size++;
    _fixAfterInsertion(newNode);
  }

  /// Find the sync point closest to the given timestamp
  /// Returns null if tree is empty
  SyncPoint? findClosest(Duration timestamp) {
    if (_root == null) return null;

    _RBNode? current = _root;
    _RBNode? closestNode = _root;
    int minDiff = (timestamp - closestNode!.timestamp).inMilliseconds.abs();

    while (current != null) {
      final diff = (timestamp - current.timestamp).inMilliseconds.abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNode = current;
      }

      if (timestamp.inMilliseconds < current.timestamp.inMilliseconds) {
        current = current.left;
      } else if (timestamp.inMilliseconds > current.timestamp.inMilliseconds) {
        current = current.right;
      } else {
        // Exact match
        return current.syncPoint;
      }
    }

    return closestNode?.syncPoint;
  }

  /// Find the sync point that should be active at the given timestamp
  /// This returns the sync point with the largest timestamp <= the given timestamp
  SyncPoint? findActiveAt(Duration timestamp) {
    if (_root == null) return null;

    _RBNode? current = _root;
    _RBNode? candidate;

    while (current != null) {
      if (current.timestamp.inMilliseconds <= timestamp.inMilliseconds) {
        candidate = current;
        current = current.right; // Look for a larger timestamp that's still <= target
      } else {
        current = current.left; // Current is too large, go left
      }
    }

    return candidate?.syncPoint;
  }

  /// Find all sync points within a time range
  List<SyncPoint> findInRange(Duration start, Duration end) {
    final result = <SyncPoint>[];
    _inOrderTraversal(_root, (node) {
      if (node.timestamp >= start && node.timestamp <= end) {
        result.add(node.syncPoint);
      }
    });
    return result;
  }

  /// Get all sync points in chronological order
  List<SyncPoint> getAllInOrder() {
    final result = <SyncPoint>[];
    _inOrderTraversal(_root, (node) => result.add(node.syncPoint));
    return result;
  }

  /// Remove all sync points for a specific rectangle
  void removeRectangleSync(String rectangleId) {
    final toRemove = <SyncPoint>[];
    _inOrderTraversal(_root, (node) {
      if (node.syncPoint.rectangle.id == rectangleId) {
        toRemove.add(node.syncPoint);
      }
    });

    for (final syncPoint in toRemove) {
      _remove(syncPoint.timestamp);
    }

    developer.log('Removed ${toRemove.length} sync points for rectangle $rectangleId');
  }

  /// Clear all sync points
  void clear() {
    _root = null;
    _size = 0;
    developer.log('Timestamp tree cleared');
  }

  // Red-Black Tree balancing operations

  void _fixAfterInsertion(_RBNode node) {
    while (node != _root && node.parent!.color == NodeColor.red) {
      if (node.parent == node.parent!.parent?.left) {
        final uncle = node.parent!.parent?.right;
        if (uncle != null && uncle.color == NodeColor.red) {
          // Case 1: Uncle is red
          node.parent!.color = NodeColor.black;
          uncle.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          node = node.parent!.parent!;
        } else {
          if (node == node.parent!.right) {
            // Case 2: Node is right child
            node = node.parent!;
            _rotateLeft(node);
          }
          // Case 3: Node is left child
          node.parent!.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          _rotateRight(node.parent!.parent!);
        }
      } else {
        // Mirror cases
        final uncle = node.parent!.parent?.left;
        if (uncle != null && uncle.color == NodeColor.red) {
          node.parent!.color = NodeColor.black;
          uncle.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          node = node.parent!.parent!;
        } else {
          if (node == node.parent!.left) {
            node = node.parent!;
            _rotateRight(node);
          }
          node.parent!.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          _rotateLeft(node.parent!.parent!);
        }
      }
    }
    _root!.color = NodeColor.black;
  }

  void _rotateLeft(_RBNode node) {
    final rightChild = node.right!;
    node.right = rightChild.left;
    
    if (rightChild.left != null) {
      rightChild.left!.parent = node;
    }
    
    rightChild.parent = node.parent;
    
    if (node.parent == null) {
      _root = rightChild;
    } else if (node == node.parent!.left) {
      node.parent!.left = rightChild;
    } else {
      node.parent!.right = rightChild;
    }
    
    rightChild.left = node;
    node.parent = rightChild;
  }

  void _rotateRight(_RBNode node) {
    final leftChild = node.left!;
    node.left = leftChild.right;
    
    if (leftChild.right != null) {
      leftChild.right!.parent = node;
    }
    
    leftChild.parent = node.parent;
    
    if (node.parent == null) {
      _root = leftChild;
    } else if (node == node.parent!.right) {
      node.parent!.right = leftChild;
    } else {
      node.parent!.left = leftChild;
    }
    
    leftChild.right = node;
    node.parent = leftChild;
  }

  void _inOrderTraversal(_RBNode? node, void Function(_RBNode) action) {
    if (node == null) return;
    _inOrderTraversal(node.left, action);
    action(node);
    _inOrderTraversal(node.right, action);
  }

  void _remove(Duration timestamp) {
    // Basic BST removal - full implementation would include rebalancing
    // For now, we'll mark this as a TODO since it's not critical for MVP
    developer.log('TODO: Implement red-black tree removal');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      String hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}