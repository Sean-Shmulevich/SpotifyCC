<script>

    import MenuWindow from "./MenuWindow.svelte";
    import { player, deviceId } from "../spotifyUtils/player";
    import { handoff } from "../spotifyUtils/playerApi"
    import { playerActivated } from "../stores";
    import { UAParser } from "ua-parser-js";
</script>


<MenuWindow>
    <div class="container">
    <button class="mainAction" on:click={ (async () => {
        player.activateElement()
        await handoff(deviceId)
        if(UAParser(window.navigator.userAgent).device.type == "mobile") {
            document.body.requestFullscreen({ navigationUI: "hide" })
        }
        playerActivated.set(true)
    })
        }>Enter the app</button>
    <p>Clicking this button you will transfer your Spotify playback session to this app. You can select new music from your other client</p>
    <p>For playback to work, you need to interact with this page before audio can start playing</p>
</div>
</MenuWindow>

<style>
    .mainAction {
        background: none;
        border: white 2px solid;
        border-radius: 3ch;
        cursor: pointer;
        color: #fbfcfc;
        font-size: 3rem;
        padding: 2rem;
    }
    .container {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
        flex-flow: column;
    }
</style>