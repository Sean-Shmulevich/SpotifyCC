<script>
  export let authState;

  import MenuWindow from "./MenuWindow.svelte";
  import { SpotifyAuth } from "../spotifyUtils";
  import SpotifyLogo from "../assets/Spotify.png";
  function login() {
    SpotifyAuth.redirectToAuthCodeFlow("c32a475ce586434d9c6436b5fa71de71"); //FIXME: hardcoded client id
  }
</script>

<MenuWindow>
  <div class="container">
    {#if authState == "bad"}
      <button on:click={login} class="mainAction"
        >Log in with Spotify<img src={SpotifyLogo} alt="" /></button
      >
      <div>
        <h1><a href="privacypolicy.txt" target="_blank">Privacy Policy</a></h1>
        <p>This application requires a Spotify Premium account</p>
      </div>
    {/if}
    {#if authState == "waiting"}
      <h1 class="mainAction">Please wait...</h1>
      <button on:click={login} class="mainAction">Retry</button>
    {/if}
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

  h1.mainAction {
    cursor: default;
    border: none;
  }

  .container {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    flex-flow: column;
  }
  img {
    height: 6rem;
    vertical-align: middle;
    margin-left: 1ch;
  }
  a {
    color: #fbfcfc;
    text-decoration: none;
  }
  p {
    margin: 0;
  }
  div {
    text-align: center;
  }
</style>
