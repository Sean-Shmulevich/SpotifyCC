import { UAParser } from "ua-parser-js";
import { readable, writable } from "svelte/store";
import { getQueue } from "./playerApi";
import { settings } from "../stores";
import { getAccessToken } from "./auth";

import { get } from 'svelte/store'

let lastState = { track_window: { next_tracks: [] } }
let updateQueue
let lastQueue

function getUserAgent() {
    const uap = UAParser(window.navigator.userAgent);
    // console.log(uap);
    return `${uap.browser.name} · ${uap.os.name}`;
}
export async function createPlayer() {
    player = new Spotify.Player({
        name: `cleanplayer (${getUserAgent()}) `,
        getOAuthToken: (cb) => {
            cb(getAccessToken());
        },
        volume: get(settings).volume,
    });
    player.addListener("player_state_changed", (currentState) => {
        if (JSON.stringify(currentState.track_window.next_tracks) != JSON.stringify(lastState.track_window.next_tracks)) {
            lastState = currentState
            setTimeout((async () => {
                let q = await getQueue();
                lastQueue = q
                if (updateQueue) {
                    console.log("Updated queue: ", q)
                    updateQueue(q);
                }
            }), 1000);
        } else {
            console.log('Chose not to update queue')
        }

    });
    player.addListener("ready", ({ device_id }) => {
        deviceId = device_id
    })
}

export let queue = readable([], function start(set) {
    updateQueue = set
    set(lastQueue)
})

export let player
export let deviceId