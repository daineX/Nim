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


def swap(l, a, b):
    temp = l[a]
    l[a] = l[b]
    l[b] = temp

def qsort_inline(l):
    stack = []
    stack.append((0, len(l) - 1))
    while stack:
        st = stack.pop()
        low, high = st
        pivot_idx = (low + high) / 2
        while low <= high:
            while l[low] < l[pivot_idx]:
                low += 1
            while l[pivot_idx] < l[high]:
                high -= 1
            if low < high:
                swap(l, low, high)
                if pivot_idx == low:
                    pivot_idx = high
                elif pivot_idx == high:
                    pivot_idx = low
                low += 1
                high -= 1
            elif low == high:
                low += 1
                high -= 1
                break
        nlow = low
        nhigh = high
        if low > high:
            nlow = low - 1
            nhigh = high + 1
        if nlow - st[0] > 1:
            stack.append((st[0], nlow))
        if st[1] - nhigh > 1:
            stack.append((nhigh, st[1]))


if __name__ == "__main__":
    import time
    from functools import wraps

    def time_sort_func(sort_func_or_tuple):
        try:
            s_func, p_func = sort_func_or_tuple
            @wraps(s_func)
            def composite(*args, **kwargs):
                return p_func(s_func(*args, **kwargs))
            sort_func = composite
        except:
            sort_func = sort_func_or_tuple
        cumulative_time = 0
        for _ in range(100):
            random_list = [randint(1, 1000) for _ in xrange(1000)]
            start_time = time.time()
            sort_func(random_list)
            end_time = time.time()
            cumulative_time += end_time - start_time
        return sort_func.__name__, cumulative_time

    for sort_func in (qsort, qsort0, (iter_qsort, list), qsort_inline, sorted):
        name, result = time_sort_func(sort_func)
        print "{}: {:.4f}s".format(name, result)
