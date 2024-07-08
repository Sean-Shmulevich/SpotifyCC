export function findLargestImageIndex(arr) {
    return arr
        .map((o) => o.height)
        .indexOf(Math.max(...arr.map((o) => o.height)));
}