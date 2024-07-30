<script>
  import { settings } from "../stores";
  import { player } from "../spotifyUtils/player";
  import { getAccessToken, logOut } from "../spotifyUtils/auth";
  let debugSettings = false;
  settings.subscribe((value) => {
    player.setVolume(value.volume);
    debugSettings = value.debugSettings;
  });

  function handleAlbumArtChange(event) {
    if (event.target.checked) {
      settings.update((s) => {
        return {
          ...s,
          roundedCorners: true,
        };
      });
    } else {
      settings.update((s) => {
        return {
          ...s,
          roundedCorners: false,
        };
      });
    }
  }
</script>

<div class="container">
  <div class="settingItem">
    Volume
    <input
      type="range"
      min="0"
      max="1"
      step="0.01"
      bind:value={$settings.volume}
    />
  </div>
  <div class="settingItem">
    Rounded album art
    <input
      type="checkbox"
      on:change={handleAlbumArtChange}
      checked={$settings.roundedCorners}
    />
  </div>
</div>
<div class="settingItem logout">
  <button on:click={logOut}>Log out</button>
</div>

<div class="info">
  <p>
    This application is fully open source on <a
      href="https://github.com/jakubiakdev/cleanplayer">Github</a
    >
  </p>
  <p>
    Please consider supporting me by <a
      href="https://ko-fi.com/jakubiakdev"
      target="_blank">buying me a coffee</a
    >
  </p>
  <p>&copy; jakubiakdev 2023</p>
</div>
<div class="info">
  <p>All metadata and audio is from Spotify</p>
  <p>
    <a href="privacypolicy.txt" target="_blank" rel="noopener noreferrer"
      >Privacy Policy
    </a>
  </p>
</div>

{#if debugSettings}
  ultra secret debug settings:
  <div class="settingItem">
    <button
      on:click={() => {
        console.log(getAccessToken());
      }}
    >
      access token log
    </button>
  </div>
{/if}

<style>
  .settingItem {
    height: 3rem;
    padding: 1rem;
    margin: 0.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: #3a3a3a;
    border-radius: 2ch;
  }
  .logout {
    background-color: rgb(255, 78, 78);
    transition: background-color 0.2s ease-in-out;
  }
  .logout button {
    border: 0;
    background: 0;
    width: 100%;
    height: 100%;
    color: #fbfcfc;
    margin: 0;
    font-size: 150%;
  }

  .logout button:hover {
    cursor: pointer;
  }
  .logout:hover {
    background-color: rgb(255, 23, 23);
  }
  .info {
    padding: 1rem;
    margin: 0.5rem;
    background-color: rgba(0, 0, 0, 0.315);
    border-radius: 2ch;
    text-align: center;
  }
  .info a {
    color: rgba(184, 255, 255, 1);
  }
</style>
