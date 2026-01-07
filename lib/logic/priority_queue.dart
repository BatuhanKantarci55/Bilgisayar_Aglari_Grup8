// lib/logic/priority_queue.dart

class PriorityQueue<E> {
  final List<E> _heap = [];
  final Comparator<E> _comparator;

  PriorityQueue(this._comparator);

  bool get isEmpty => _heap.isEmpty;
  int get length => _heap.length;

  void add(E value) {
    _heap.add(value);
    _siftUp(_heap.length - 1);
  }

  E removeMin() {
    if (_heap.isEmpty) {
      throw StateError('Cannot remove from an empty priority queue');
    }
    final min = _heap[0];
    if (_heap.length == 1) {
      _heap.removeAt(0);
    } else {
      _heap[0] = _heap.removeLast();
      _siftDown(0);
    }
    return min;
  }

  void _siftUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      if (_comparator(_heap[index], _heap[parentIndex]) < 0) {
        _swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }

  void _siftDown(int index) {
    while (true) {
      final leftChildIndex = 2 * index + 1;
      final rightChildIndex = 2 * index + 2;
      var smallest = index;

      if (leftChildIndex < _heap.length &&
          _comparator(_heap[leftChildIndex], _heap[smallest]) < 0) {
        smallest = leftChildIndex;
      }

      if (rightChildIndex < _heap.length &&
          _comparator(_heap[rightChildIndex], _heap[smallest]) < 0) {
        smallest = rightChildIndex;
      }

      if (smallest != index) {
        _swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
}
