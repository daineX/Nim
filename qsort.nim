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

proc swap[T](l: var seq[T], a: T, b: T) =
    let temp = l[a]
    l[a] = l[b]
    l[b] = temp


proc qsort_inline[T](l: var seq[T]) =
    type StackType = tuple[low: T, high: T]
    var stack = newSeq[StackType]()
    var top: StackType
    top = (0, l.high)
    stack.add(top)
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
            top = (st.low, nlow)
            stack.add(top)
        if st.high - nhigh > 1:
            top = (nhigh, st.high)
            stack.add(top)

when isMainModule:
    randomize()
#     var random_list = @[9, 7, 6, 2, 2, 9, 2, 8, 2, 4]

    var cumulativeTime = 0.0
    for _ in 1..100:
        var random_list = mapIt(newSeq[int](1000), int, random(1000))
        let startTime = epochTime()
        qsort_inline(random_list)
        let endTime = epochTime()
        cumulativeTime += endTime - startTime
    echo cumulativeTime
