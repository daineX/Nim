from math import randomize, random
from sequtils import mapIt
from times import epochTime
import strutils

proc qsort[T](l: seq[T]): seq[T] =
    if l.len <= 1:
        return l
    let pivot = l[0]
    var less = newSeq[int]()
    var greater = newSeq[int]()
    for i in l[1..l.high]:
        if i <= pivot:
            less.add(i)
        else:
            greater.add(i)
    return qsort(less) & @[pivot] & qsort(greater)

proc swap[T](l: var seq[T], a: int, b: int) =
    let temp = l[a]
    l[a] = l[b]
    l[b] = temp


proc qsort_inline[T](l: var seq[T]) =
    var stack = newSeq[tuple[low: int, high: int]]()
    stack.add((0, l.high))
    while stack.len > 0:
        let st = stack.pop()
        var pivot_idx = (st.low + st.high) div 2
        var mid = pivot_idx
        var low = st.low
        var high = st.high
        while low <= high:
            while l[low] < l[pivot_idx]:
                inc low
            while l[pivot_idx] < l[high]:
                dec high
            if low < high:
                swap(l, low, high)
                if pivot_idx == low:
                    pivot_idx = high
                elif pivot_idx == high:
                    pivot_idx = low
                inc low
                dec high
            elif low == high:
                inc low
                dec high
                break

        var nlow = low
        var nhigh = high
        if low > high:
            nlow = low - 1
            nhigh = high + 1
        if nlow - st.low > 1:
            stack.add((st.low, nlow))
        if st.high - nhigh > 1:
            stack.add((nhigh, st.high))

when isMainModule:
    randomize()

    var cumulativeTime = 0.0
    for _ in 1..100:
        var random_list = mapIt(newSeq[int](1000), int, random(1000))
        let startTime = epochTime()
        qsort_inline(random_list)
        let endTime = epochTime()
        cumulativeTime += endTime - startTime
    echo cumulativeTime

    var float_list = mapIt(newSeq[float](1000), float, random(1.0))
    qsort_inline(float_list)
