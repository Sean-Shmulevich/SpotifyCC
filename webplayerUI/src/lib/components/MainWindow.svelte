<script>

    // The user logs in, the svelte page shouldn't load at all until the socket is connected on both sides.
    // Should I add this to the svelte? Or should I create another frontend for this.
    // Generated hash should go into session storage, if either of the sockets
    // are disconnected, display which one it is and prompt re-connection.
    // don't show the player at all until both sockets are connected.
    // if socket disconnects while playing. Redirect to socket page.
    import { tweened } from "svelte/motion";
    import { linear } from "svelte/easing";

    import OptionsWindow from "../components/OptionsWindow.svelte";
    import SpotifyLogin from "../components/SpotifyLogin.svelte";
    import { SpotifyAuth, SpotifyPlayerApi } from "../spotifyUtils";

    import { settings, playerActivated } from "../stores";
    import { findLargestImageIndex } from "../commonUtils";

    import { player, createPlayer, deviceId } from "../spotifyUtils/player.js";

    import { SvelteToast } from "@zerodevx/svelte-toast";
    import { toast } from "@zerodevx/svelte-toast";
    import EntranceWindow from "../components/EntranceWindow.svelte";
    import { getAccessToken } from "../spotifyUtils/auth";

    import SpotifyLogo from "../assets/Spotify.png";
    import SpotifyBlackLogo from "../assets/SpotifyBlack.png";
    import socketStore from "../wsStore";
    import WsConnect from "./WsConnect.svelte";

    let ws = $socketStore;
    let showOptions = false;
    let showAttributionMenu = false;
    let authState;
    let luaSocketConnected = false;

    if (localStorage.getItem("accessToken")) {
        authState = "waiting";
    } else {
        authState = "bad";
    }
    function debounce(func, delay) {
    let timeoutId;
    return function(...args) {
        if (timeoutId) {
            clearTimeout(timeoutId);
        }
        timeoutId = setTimeout(() => {
            func.apply(this, args);
        }, delay);
    };
}
    const debouncedSend = debounce((data) => {
        ws.send(data);
        localStorage.setItem("storedTrack", data);
    }, 2000);

    let lastState = {};
    let title = "";
    let artist = "";
    let artwork = "";
    let albumTitle = "";
    let albumLink = "#";
    let context = "";
    let contextIcon = "";
    let playing = false;
    const percentage = tweened(0, {
        duration: 1000, // 1000 because of update interval, and to make the animation smooth even when changing playback device
        easing: linear,
    });
    let duration = 100000;
    let position = 0;
    let shuffle = false;
    let disallows = {
        pausing: false,
        peeking_next: false,
        peeking_prev: false,
        resuming: false,
        seeking: false,
        skipping_next: false,
        skipping_prev: false,
    };
    let albumArtRadius;
    settings.subscribe((value) => {
        if (value.roundedCorners) {
            albumArtRadius = "2ch";
        } else {
            albumArtRadius = 0;
        }
    });

    function handlePlay() {
        if (playing) {
            player.pause().then(() => {
                playing = false;
            });
        } else {
            player.resume().then(() => {
                playing = true;
            });
        }
    }
    async function handleShuffle() {
        if (shuffle == true) {
            await SpotifyPlayerApi.setShuffle(false, deviceId);
            shuffle = false;
        } else {
            await SpotifyPlayerApi.setShuffle(true, deviceId);
            shuffle = true;
        }
    }

    setInterval(updatePosition, 1000); // this is probably bad? I don't actually know but this could pose potential performance issues
    function updatePosition() {
        if (playing) {
            position = position + 1000;
            percentage.set((position * 100) / duration);
        }
    }

    function updatePlayerState(state) {
        const tempLastState = lastState;
        lastState = state;

        // if (!state.paused) {
            //   playing = true;
            // } else {
                //   playing = false;
                // }
        player.pause().then(() => {
            playing = false;
        });

        if (
            (tempLastState === null)  || (
                tempLastState.track_window.current_track.id !==
                state.track_window.current_track.id)
        ) {
            let currentTrack = state.track_window.current_track;

            let data = {
                id: currentTrack.id,
                artist: currentTrack.artists[0].name,
                name: currentTrack.name,
                albumName: currentTrack.album.name,
                albumArt:
                currentTrack.album.images[
                    findLargestImageIndex(currentTrack.album.images)
                ].url,
            };
            debouncedSend(JSON.stringify(data));
        }
        title = state.track_window.current_track.name;
        artist = state.track_window.current_track.artists
            .map((a) => a.name)
            .join(", ");
        // TODO: this transition is quite frankly jarring, find a better way to smoothly transition in album art and background
        artwork =
            state.track_window.current_track.album.images[
                findLargestImageIndex(state.track_window.current_track.album.images)
            ].url;
        albumTitle = state.track_window.current_track.album.name;

        albumLink = `https://open.spotify.com/album/${state.track_window.current_track.album.uri.slice(14)}`;
        context = "";
        contextIcon = "";
        if (state.context.uri.startsWith("spotify:playlist")) {
            contextIcon = "library_music";
            context = state.context.metadata.context_description;
        }
        if (state.context.uri.startsWith("spotify:user")) {
            contextIcon = "favorite";
            context = "Liked Songs";
        }
        // if(state.context.uri.startsWith("spotify:artist")) { // doesn't like it when you play something from inside artist page
            //     context += `<span class="material-symbols-rounded">
                //         person
            //         </span> ${state.context.metadata.context_description}`;
            // }

        // playing = !state.paused; this caused issues?
            //todo send specific events on play pause.
            // if (state.paused) {
                //   playing = false;
                // } else {
                    //   playing = true;
                    // }
        duration = state.duration;
        position = state.position;
        shuffle = state.shuffle;
        disallows = state.disallows;
        // console.log(state);
    }


    ws.onmessage = function (event) {
        let message = event.data;
        console.log("message sent from lua" + message);
        if (message === "nextSong") {
            player
                .nextTrack()
                .then(() => {
                    console.log("track has been skipped");
                })
                .catch((error) => {
                    console.error("Error skipping tracks", error);
                });
        } else if (message === "prevSong") {
            player
                .previousTrack()
                .then(() => {
                    console.log("going to last track");
                })
                .catch((error) => {
                    console.error("Error going back", error);
                });
        } else if (message === "luaConnected") {
            luaSocketConnected = true;
            luaSocketConnected = luaSocketConnected;
            if (JSON.stringify(lastState) !== "{}") {
                let currentTrack = lastState.track_window.current_track;
                let data = {
                    id: currentTrack.id,
                    artist: currentTrack.artists[0].name,
                    name: currentTrack.name,
                    albumName: currentTrack.album.name,
                    albumArt:
                    lastState.track_window.current_track.album.images[
                        findLargestImageIndex(
                            lastState.track_window.current_track.album.images
                        )
                    ].url,
                };
                ws.send(JSON.stringify(data));
            }
        } else if (message === "luaDisconnect") {
            console.log("caught lua disconnect");
            luaSocketConnected = false;
            luaSocketConnected = luaSocketConnected;
            let currentTrack = lastState.track_window.current_track;
            let data = {
                id: currentTrack.id,
                artist: currentTrack.artists[0].name,
                name: currentTrack.name,
                albumName: currentTrack.album.name,
                albumArt:
                lastState.track_window.current_track.album.images[
                    findLargestImageIndex(
                        lastState.track_window.current_track.album.images
                    )
                ].url,
            };
            localStorage.setItem("storedTrack", JSON.stringify(data));

        } else if (message === "luaConnectedOnInit") {
            console.log("caught lua connected on init");
            luaSocketConnected = true;
            luaSocketConnected = luaSocketConnected;
            if(localStorage.getItem("storedTrack")) {
                const storedTrack = JSON.parse(localStorage.getItem("storedTrack"));
                ws.send(JSON.stringify(storedTrack));
            }
        }

    };
    window.addEventListener("beforeunload", function(e){
        // Do something
        let currentTrack = lastState.track_window.current_track;
        let data = {
            id: currentTrack.id,
            artist: currentTrack.artists[0].name,
            name: currentTrack.name,
            albumName: currentTrack.album.name,
            albumArt:
            lastState.track_window.current_track.album.images[
                findLargestImageIndex(
                    lastState.track_window.current_track.album.images
                )
            ].url,
        };
        localStorage.setItem("storedTrack", JSON.stringify(data));
    });

    window.onSpotifyWebPlaybackSDKReady = async function () {
        // console.log("sdk ready");
        // auth to spotify
        const authCode = new URLSearchParams(window.location.search).get("code");
        if (authCode) {
            await SpotifyAuth.newAccessToken(
                "c32a475ce586434d9c6436b5fa71de71",
                authCode
            );
            window.history.replaceState(
                {},
                document.title,
                window.location.origin + window.location.pathname
            );
            authState = "waiting";
        }
        let res = getAccessToken();
        if (res == false || res == undefined) {
            console.log("Access token not found")
            authState = "bad";
        } else {
            createPlayer();

            player.addListener("ready", ({ device_id }) => {
                console.log("Ready with Device ID", device_id);
                toast.push(`Ready with Device ID ${device_id}`);
                authState = "good";
            });

            player.addListener("not_ready", ({ device_id }) => {
                console.log("Device ID has gone offline", device_id);
                toast.push(`Device ID has gone offline ${device_id}`);
            });

            player.addListener("initialization_error", ({ message }) => {
                console.error(message);
                toast.push(`Spotify initialization error: ${message}`);
            });

            player.addListener("authentication_error", ({ message }) => {
                console.error(message);
                toast.push(`Spotify authentication error: ${message}`);
                authState = "bad";
            });

            player.addListener("account_error", ({ message }) => {
                console.error(message);
                toast.push(`Spotify account error: ${message}`);
            });

            player.connect().then((success) => {
                if (success) {
                    console.log(
                        "The Web Playback SDK successfully connected to Spotify!"
                    );
                    toast.push("Successfully connected to Spotify");
                    return;
                }
            });

            player.addListener("player_state_changed", (state) => {
                updatePlayerState(state);
            });
        }
    };
</script>

{#if authState == "bad" || authState == "waiting"}
    <SpotifyLogin {authState} />
{/if}

{#if showOptions}
    <OptionsWindow />
{/if}

{#if !$playerActivated && authState == "good"}
    <EntranceWindow />
{/if}

{#if showAttributionMenu}
    <div class="attributionMenu">
        <div class="item">
            <a
                href="https://open.spotify.com/track/{lastState.track_window
                .current_track.id}"
                target="_blank"
                >
                <img src={SpotifyLogo} alt="" />
                <span class="text">Song</span>
                <span class="material-symbols-rounded"> open_in_new </span>
            </a>
        </div>
        {#each lastState.track_window.current_track.artists as artist}
            <div class="item">
                <a
                    href="https://open.spotify.com/artist/{artist.uri.slice(15)}"
                    target="_blank"
                    >
                    <img src={SpotifyLogo} alt="" />
                    <span class="text">Artist: {artist.name}</span>
                    <span class="material-symbols-rounded"> open_in_new </span>
                </a>
            </div>
        {/each}
        <div class="item">
            <a
                href="https://open.spotify.com/album/{lastState.track_window.current_track.album.uri.slice(14)}"
                target="_blank"
                >
                <img src={SpotifyLogo} alt="" />
                <span class="text">Album</span>
                <span class="material-symbols-rounded"> open_in_new </span>
            </a>
        </div>
    </div>
{/if}

<SvelteToast />

<div class="unsupportedSizeNotice">
    <h1>This aspect ratio is not yet supported</h1>
    <h3>Please resize the application window</h3>
</div>

<div class="progress" style="width: {$percentage}vw;" />
    <div class="background" style="background-image: url({artwork})" />
        <div class="playerContainer">
            
            {#if !luaSocketConnected}
                <WsConnect />
            {:else}
            <div class="albumContainer">
                <img
                src={artwork}
                alt=""
                class="albumArt"
                style="border-radius: {albumArtRadius}"
                />
                <div class="albumInfo">
                    <div class="infoText">
                        <span class="material-symbols-rounded"> album </span>
                        <a href={albumLink} class="clickable" target="_blank"> {albumTitle}</a>
                    </div>
                    {#if context}
                        <div class="infoText">
                            <span class="material-symbols-rounded">
                                {contextIcon}
                            </span>
                            {context}
                        </div>
                    {/if}
                </div>
                <!-- <div>{albumDetails}</div> TODO: check if we have another way of accessing it? WebPlaybackTrack doesn't seem to have one -->
            </div>
            <div class="trackInfo">
                <div class="title">{title}</div>
                <div class="artist">{artist}</div>
            </div>
            <!-- TODO: aria-label for buttons-->

            <div class="controls">
                <button
                    class="side"
                    disabled={disallows.skipping_prev}
                    on:click={() => {
                    player.previousTrack();

                    player.pause().then(() => {
                    playing = false;
                    });
                    }}
                    >
                    <span class="material-symbols-rounded"> skip_previous </span>
                </button>

                <button class="play" disabled >
                        <span class="material-symbols-rounded"> play_circle </span>
                </button>

                <button
                    class="side"
                    disabled={disallows.skipping_next}
                    on:click={() => {
                    player.nextTrack();
                    player.pause().then(() => {
                    playing = false;
                    });
                    }}
                    >
                    <span class="material-symbols-rounded"> skip_next </span>
                </button>
            </div>
            {/if}
        </div>

<style>
    .background {
        background-color: #9fc9dd;
        background-repeat: no-repeat;
        background-size: cover;
        background-position: center;
        filter: blur(65px) brightness(0.6);
        z-index: -1;
        display: block;
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        transform: scale(1.4);
    }

    .playerContainer {
        top: 5vh;
        height: 95vh;
        width: 100vw;
        text-align: center;
        position: absolute;
    }
    button {
        background: none;
        border: none;
    }
    button span,
    button img {
        cursor: pointer;
    }
    button {
        -webkit-transition: all 0.2s ease-in-out;
        transition: all 0.2s ease-in-out;
    }
    button:hover {
        -webkit-filter: brightness(130%);
        filter: brightness(130%);
    }
    .albumContainer img {
        height: 100%;
        border-radius: 3ch;
    }
    /* .playerContainer {
       text-align: center;
    } */
    .sideActions {
        position: absolute;
        right: 3.5rem;
    }
    .sideActions button {
        background-color: rgba(140, 142, 240, 0.1);
        border-radius: 3.75rem;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 5rem;
        height: 5rem;
        backdrop-filter: blur(100px) brightness(1.5);
        margin: 1rem;
    }
    .sideActions button img {
        width: 3rem;
        height: 3rem;
    }

    .sideActions button img.imageTurnedOn {
        filter: invert(1);
    }
    .sideActions button span {
        font-size: 3rem;
    }
    .sideActions button span.turnedOn {
        color: #fbfcfc;
    }
    .controls {
        display: flex;
        align-items: center;
        justify-content: center;
        bottom: 5vh;
        position: absolute;
        left: 50%;
        transform: translateX(-50%);
    }
    .controls button {
        margin-left: 3rem;
        margin-right: 3rem;
        color: #fcfcfc;
        transition-property: all;
        transition-duration: 120ms;
    }
    .controls button.play span {
        font-size: 7rem;
    }
    .controls button.play {
        border-radius: 4.5rem;
    }
    .controls button span {
        font-size: 5rem;
    }
    .controls button.side {
        border-radius: 2.5rem;
    }
    .controls button:active {
        background-color: rgba(140, 142, 240, 0.1);
    }
    .albumContainer {
        width: 100%;
        height: 60vh;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .albumArt {
        height: 60vh;
        /* left: calc(50% - 30vh);
        position: fixed; */ /* chuj go wie */
    }
    .albumInfo {
        margin-left: 32vh;
        position: absolute;
        left: 50%;
        color: #abafb2;
        text-align: left;
        font-size: 1.5rem;
    }
    :global(.infoText span) {
        font-size: 2rem;
        font-variation-settings: "opsz" 20;
    }
    .albumInfo .infoText {
        display: flex;
        align-items: center;
        justify-content: left;
    }
    .infoText a {
        text-decoration: none;
        color: #abafb2;
    }

    .clickable:hover {
        text-decoration: underline;
    }

    .albumInfo .infoText:nth-child(2) {
        margin-top: 0.25rem;
    }
    .trackInfo {
        margin: 3vh;
        color: #fbfcfc;
        font-size: 1.65vh;
    }
    .title {
        font-size: 300%;
    }
    .artist {
        font-size: 200%;
    }
    .progress {
        background-color: #fbfcfc;
        height: 1vh;
        position: absolute;
        bottom: 0;
        border-radius: 0 0.3vh 0.3vh 0;
    }
    .play {
        height: 13vh;
    }
    .side {
        height: 10vh;
    }
    button[disabled] {
        filter: contrast(0.5) brightness(0.5);
        cursor: not-allowed;
    }

    .attributionMenu {
        position: absolute;
        width: 60vh;
        height: 70vh;
        z-index: 10;
        border-radius: 2ch;
        left: 50%;
        top: 45%;
        transform: translateX(-50%) translateY(-50%);
        background-color: hsla(0, 0%, 44%, 0.5);
        backdrop-filter: blur(100px);
        display: flex;
        align-items: center;
        justify-content: space-evenly;
        flex-flow: column;
    }
    .attributionMenu .item {
        width: 60%;
        background: none;
        border: white 1px solid;
        border-radius: 3ch;
        padding: 1rem;
    }
    .attributionMenu .item span {
        margin-left: auto;
    }
    .attributionMenu .item img {
        height: 1.5rem;
        margin-right: 1ch;
    }

    .attributionMenu .item a {
        cursor: pointer;
        color: #fbfcfc;
        text-decoration: none;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .attributionMenu .item a span.text {
        flex: 1;
    }
    .unsupportedSizeNotice {
        display: none;
    }
    @media (max-width: 95rem) {
        .sideActions {
            display: flex;
            flex-direction: column;
            left: 0;
        }
        /* TODO: this still misses my phone?*/
        /* .unsupportedSizeNotice {
           z-index: 100;
           display: block;
           position: absolute;
           text-align: center;
           width: 100vw;
           height: 100vh;
           background-color: #000;
           color: #fff;
        } */
    }
</style>
