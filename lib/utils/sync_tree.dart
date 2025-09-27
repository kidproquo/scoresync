import 'dart:developer' as developer;
import '../models/rectangle.dart';

enum NodeColor { red, black }

class SyncPoint<T extends Comparable<dynamic>> {
  final T key;
  final DrawnRectangle rectangle;
  final int pageNumber;

  SyncPoint({
    required this.key,
    required this.rectangle,
    required this.pageNumber,
  });
}

class _RBNode<T extends Comparable<dynamic>> {
  SyncPoint<T> syncPoint;
  _RBNode<T>? left;
  _RBNode<T>? right;
  _RBNode<T>? parent;
  NodeColor color;

  _RBNode(this.syncPoint) : color = NodeColor.red;

  T get key => syncPoint.key;
}

class SyncTree<T extends Comparable<dynamic>> {
  _RBNode<T>? _root;
  int _size = 0;

  int get size => _size;
  bool get isEmpty => _root == null;

  void insert(SyncPoint<T> syncPoint) {
    final newNode = _RBNode<T>(syncPoint);

    if (_root == null) {
      _root = newNode;
      _root!.color = NodeColor.black;
      _size++;
      return;
    }

    _RBNode<T>? parent;
    _RBNode<T>? current = _root;

    while (current != null) {
      parent = current;
      if (newNode.key.compareTo(current.key) < 0) {
        current = current.left;
      } else {
        current = current.right;
      }
    }

    newNode.parent = parent;
    if (newNode.key.compareTo(parent!.key) < 0) {
      parent.left = newNode;
    } else {
      parent.right = newNode;
    }

    _size++;
    _fixAfterInsertion(newNode);
  }

  SyncPoint<T>? findClosest(T key) {
    if (_root == null) return null;

    _RBNode<T>? current = _root;
    _RBNode<T>? closestNode = _root;
    int minDiff = (key.compareTo(closestNode!.key)).abs();

    while (current != null) {
      final diff = (key.compareTo(current.key)).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNode = current;
      }

      final comparison = key.compareTo(current.key);
      if (comparison < 0) {
        current = current.left;
      } else if (comparison > 0) {
        current = current.right;
      } else {
        return current.syncPoint;
      }
    }

    return closestNode?.syncPoint;
  }

  SyncPoint<T>? findActiveAt(T key) {
    if (_root == null) return null;

    _RBNode<T>? current = _root;
    _RBNode<T>? candidate;

    while (current != null) {
      if (current.key.compareTo(key) <= 0) {
        candidate = current;
        current = current.right;
      } else {
        current = current.left;
      }
    }

    return candidate?.syncPoint;
  }

  List<SyncPoint<T>> findInRange(T start, T end) {
    final result = <SyncPoint<T>>[];
    _inOrderTraversal(_root, (node) {
      if (node.key.compareTo(start) >= 0 && node.key.compareTo(end) <= 0) {
        result.add(node.syncPoint);
      }
    });
    return result;
  }

  List<SyncPoint<T>> getAllInOrder() {
    final result = <SyncPoint<T>>[];
    _inOrderTraversal(_root, (node) => result.add(node.syncPoint));
    return result;
  }

  void removeRectangleSync(String rectangleId) {
    final toRemove = <SyncPoint<T>>[];
    _inOrderTraversal(_root, (node) {
      if (node.syncPoint.rectangle.id == rectangleId) {
        toRemove.add(node.syncPoint);
      }
    });

    for (final syncPoint in toRemove) {
      _remove(syncPoint.key);
    }

    developer.log('Removed ${toRemove.length} sync points for rectangle $rectangleId');
  }

  void clear() {
    _root = null;
    _size = 0;
    developer.log('Sync tree cleared');
  }

  void _fixAfterInsertion(_RBNode<T> node) {
    while (node != _root && node.parent!.color == NodeColor.red) {
      if (node.parent == node.parent!.parent?.left) {
        final uncle = node.parent!.parent?.right;
        if (uncle != null && uncle.color == NodeColor.red) {
          node.parent!.color = NodeColor.black;
          uncle.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          node = node.parent!.parent!;
        } else {
          if (node == node.parent!.right) {
            node = node.parent!;
            _rotateLeft(node);
          }
          node.parent!.color = NodeColor.black;
          node.parent!.parent!.color = NodeColor.red;
          _rotateRight(node.parent!.parent!);
        }
      } else {
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

  void _rotateLeft(_RBNode<T> node) {
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

  void _rotateRight(_RBNode<T> node) {
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

  void _inOrderTraversal(_RBNode<T>? node, void Function(_RBNode<T>) action) {
    if (node == null) return;
    _inOrderTraversal(node.left, action);
    action(node);
    _inOrderTraversal(node.right, action);
  }

  void _remove(T key) {
    developer.log('TODO: Implement red-black tree removal');
  }
}