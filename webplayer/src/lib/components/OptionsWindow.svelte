<style>
    .container {
        position: absolute;
        width: 50vw;
        height: 70vh;
        z-index: 10;
        border-radius: 2ch;
        left: 50%;
        top: 45%;
        transform: translateX(-50%) translateY(-50%);
        display: grid;
        grid-template-columns: 40% auto;
        background-color: #707070;
    }
    .itemList {
        padding: 0;
        margin: 0;
        height: 100%;
        border-radius: 2ch 0 0 2ch;
    }
    
    ul {
        text-align: center;
        list-style: none;
        padding: 0;
        margin: 0;
        height: 100%;
        background-color: rgb(15, 10, 10);
        border-radius: 2ch 0 0 2ch;
    }

    .main {
        box-sizing: border-box;
        height: 100%;
        border-radius: 0 2ch 2ch 0;
        padding: 0  1rem;
        overflow: overlay;
    }
    hr {
        border: #707070 1px solid;
        width: 70%;
    }
    button span {
        position: relative;
        top: 0.25rem;
        font-size: 1.5rem;
        font-variation-settings: 'opsz' 20;
    }
    button {
        font-size: 1.5rem;
        background-color: rgba(184, 255, 255, 0.5);
        border: none;
        border-radius: 2ch;
        margin: 1rem;
        color: #fbfcfc;
        padding: 1rem;
        width: 80%;
        box-shadow: 0 0 10px 5px rgba(124, 124, 124, 0.26);
        transition: background-color 0.2s ease-in-out;
    }
    button:hover {
        cursor: pointer;
        background-color: rgba(184, 255, 255, 0.685);
    }

</style>

<script>
    import Settings from "./Settings.svelte";
    import Queue from "./Queue.svelte";
    let activeWindow = 'queue'
</script>

<div class="container">
    <div class="itemList">
        <ul>
            <li><button on:click={() => { activeWindow = 'queue'}}>
                <span class="material-symbols-rounded">
                    queue_music
                </span>
                Queue
            </button></li>
            <hr>
            <li><button on:click={() => { activeWindow = 'settings'}}>
                <span class="material-symbols-rounded">
                    tune
                </span>
                Settings
            </button></li>
        </ul>
    </div>
    <div class="main">
        {#if activeWindow == 'settings'}
            <Settings/>
        {:else if activeWindow == 'queue'}
            <Queue/>
        {/if}
    </div>
</div>