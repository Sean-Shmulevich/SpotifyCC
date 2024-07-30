import { writable } from "svelte/store";

// Initialize your store with the initial data
// src/lib/hashUtils.js
function generateRandomHash(length = 8) {
    const array = new Uint8Array(length / 2);
    crypto.getRandomValues(array);
    return Array.from(array, byte => ('0' + byte.toString(16)).slice(-2)).join('');
}
if (localStorage.getItem('userSocketHash') === null) {
    localStorage.setItem('userSocketHash', JSON.stringify(generateRandomHash()));
}
const userSocketHash = JSON.parse(localStorage.getItem('userSocketHash'));

let websocket = new WebSocket(`wss://amused-consideration-production.up.railway.app/ws/webclient/${userSocketHash}`)
let socketStore = writable(websocket);

export default socketStore;
