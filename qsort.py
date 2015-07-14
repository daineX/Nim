from itertools import tee
from random import choice, randint


def qsort(l):
    if len(l) <= 1:
        return l
    pivot_idx = randint(0, len(l) - 1)
    pivot = l[pivot_idx]
    pivotted_list = l[:pivot_idx] + l[pivot_idx + 1:]
    return (qsort([n for n in pivotted_list if n <= pivot]) +
            [pivot] +
            qsort([n for n in pivotted_list if n > pivot]))

def qsort0(l):
    if len(l) <= 1:
        return l
    pivot = l[0]
    pivotted_list = l[1:]
    return (qsort([n for n in pivotted_list if n <= pivot]) +
            [pivot] +
            qsort([n for n in pivotted_list if n > pivot]))

def iter_qsort(it):
    it, peek = tee(it)
    try:
        next(peek), next(peek)
    except StopIteration:
        yield next(it)
    else:
        pivot = next(it)
        lesser, greater = tee(it)
        for n in iter_qsort(n for n in lesser if n <= pivot):
            yield n
        yield pivot
        for n in iter_qsort(n for n in greater if n > pivot):
            yield n


if __name__ == "__main__":
    random_list = [randint(1, 1000) for _ in xrange(1000)]

    import time
    print "qsort0:"
    start_time = time.time()
    for _ in range(100):
        qsort0(random_list)
    end_time = time.time()
    print end_time - start_time

    print "iter_qsort:"
    start_time = time.time()
    for _ in range(100):
        list(iter_qsort(iter(random_list)))
    end_time = time.time()
    print end_time - start_time

    print "Sort:"
    start_time = time.time()
    for _ in range(100):
        sorted(random_list)
    end_time = time.time()
    print end_time - start_time
