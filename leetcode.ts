// 1. Two Sum Problem
`
Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target.

You may assume that each input would have exactly one solution, and you may not use the same element twice.

You can return the answer in any order.
`
const arr = [3, 3];
const tar = 6;

// O(n^2)
function _1_twoSum(nums: number[], target: number): number[] {
    for (let i = 0; i < nums.length; i++) {
        const f = nums[i]
        for (let j = 0; j < nums.length; j++) {
            if (j !== i && f + nums[j] === target) {
                return [i, j];
            }
        }
    }
    return [];
};

// O(n)
function _2_twoSum(nums: number[], target: number): number[] {
    const map = new Map<number, number>();
    for (let i = 0; i < nums.length; i++) { 
        const num = nums[i];
        const diff = target - num;
        if (map.has(diff)) {
            return [map.get(diff)!, i];
        }
        map.set(num, i);
    }
    return [];
}

// console.log(twoSum(arr, tar));


// 2. Add Two Numbers
`
You are given two non-empty linked lists representing two non-negative integers. The digits are stored in reverse order, and each of their nodes contains a single digit. Add the two numbers and return the sum as a linked list.

You may assume the two numbers do not contain any leading zero, except the number 0 itself.
`
class ListNode {
    val: number
    next: ListNode | null
    constructor(val?: number, next?: ListNode | null) {
        this.val = (val===undefined ? 0 : val)
        this.next = (next===undefined ? null : next)
    }
}

const l1 = [2, 4, 3];
const l2 = [5, 6, 4];

function addTwoNumbers(l1: ListNode | null, l2: ListNode | null): ListNode | null {
    const dummy = new ListNode(0);
    let current = dummy;
    let carryDigit = 0;
    while (l1 !== null || l2 !== null || carryDigit > 0) { 
        // get the value of the current node, if the node is null, use 0
        const val1 = l1 ? l1.val : 0;
        const val2 = l2 ? l2.val : 0;

        // sum the digits and the carry digit
        const sum = val1 + val2 + carryDigit;
        // get the new carry digit, the remainder of the sum divided by 10
        carryDigit = Math.floor(sum / 10);
        // create a new node with the value of the sum modulo 10
        const digit = sum % 10;

        current.next = new ListNode(digit);
        current = current.next;

        if (l1) l1 = l1.next;
        if (l2) l2 = l2.next;
    }
    return dummy.next;
};

// console.log(addTwoNumbers(l1, l2));

// 3. Longest Substring Without Repeating Characters
`
Given a string s, find the length of the longest substring without repeating characters.
`
function lengthOfLongestSubstring(s: string): number {
    let left = 0;
    let right = 0;
    let maxLength = 0;
    const charSet = new Set<string>();
    while (right < s.length) {
        while (charSet.has(s[right])) {
            charSet.delete(s[left]);
            left++;
        }
        charSet.add(s[right]);
        right++;
        maxLength = Math.max(maxLength, right - left);
    }
    return maxLength;
};

// console.log(lengthOfLongestSubstring("abcabcbb"));

// Sonnet suggested prompt;
`Given the head of a singly linked list, reverse the list, and return the new head.`

function reverseList(head: ListNode | null): ListNode | null {
    let prev = null;
    let curr = head;
    while (curr !== null) {
        const next = curr.next;
        curr.next = prev;
        prev = curr;
        curr = next;
    }
    return prev;
};

// how do I test this?
// I can create a linked list from the array
const head = new ListNode(1);
head.next = new ListNode(2);
head.next.next = new ListNode(3);
head.next.next.next = new ListNode(4);
head.next.next.next.next = new ListNode(5);
// console.log(reverseList(head));

function isPalindrome(x: number): boolean {
    const str = x.toString();
    let left = 0;
    let right = str.length - 1;
    while (left < right) {
        if (str[left] !== str[right]) {
            return false;
        }
        left++;
        right--;
    }
    return true;
};

// console.log(isPalindrome(12321));

// 13. Roman to Integer
`Roman numerals are represented by seven different symbols: I, V, X, L, C, D, and M.

Symbol       Value
I             1
V             5
X             10
L             50
C             100
D             500
M             1000

For example, 2 is written as II in Roman numeral, just two ones added together. 12 is written as XII, which is simply X + II. The number 27 is written as XXVII, which is XX + V + II.

Roman numerals are usually written largest to smallest from left to right. However, the numeral for four is not IIII. Instead, the number four is written as IV. Because the one is before the five we subtract it making four. The same principle applies to the number nine, which is written as IX. There are six instances where subtraction is used:

I can be placed before V (5) and X (10) to make 4 and 9. 
X can be placed before L (50) and C (100) to make 40 and 90. 
C can be placed before D (500) and M (1000) to make 400 and 900.
`
function romanToInt(s: string): number {
    const romanMap = new Map<string, number>([
        ['I', 1],
        ['V', 5],
        ['X', 10],
        ['L', 50],
        ['C', 100],
        ['D', 500],
        ['M', 1000]
    ]);
    let total = 0;
    for (let i = 0; i < s.length; i++) {
        const curr = romanMap.get(s[i])!;
        const next = romanMap.get(s[i + 1]);
        if (next && curr < next) {
            total -= curr;
        } else {
            total += curr;
        }
    }
    return total;
};

// console.log(romanToInt("MC"));

// 14. Longest Common Prefix
`Write a function to find the longest common prefix string amongst an array of strings.

If there is no common prefix, return an empty string "".`

function longestCommonPrefix(strs: string[]): string {
    let res = [];
    for (let i = 0; i < strs[0].length; i++) {
        for (let j = 1; j < strs.length; j++) {
            if (strs[0][i] !== strs[j][i]) {
                return res.join('');
            }
        }
        res.push(strs[0][i]);
    }
    return res.join('');
};

// console.log(longestCommonPrefix(["aflower", "bflow", "cflight"]));


function validMountainArray(arr: number[]): boolean {
    let i = 0;
    while (i < arr.length - 1 && arr[i] < arr[i + 1]) {
        i++;
    }
    if (i === 0 || i === arr.length - 1) {
        return false;
    }
    while (i < arr.length - 1 && arr[i] > arr[i + 1]) {
        i++;
    }
    return i === arr.length - 1;
};

const arr2 = [2, 3, 2, 1];
console.log(validMountainArray(arr2));