<script>
  import MainWindow from "./lib/components/MainWindow.svelte";
  import socketStore from "./lib/wsStore";

  let ws = $socketStore;

  // src/lib/hashUtils.js
  function generateRandomHash(length = 16) {
    const array = new Uint8Array(length / 2);
    crypto.getRandomValues(array);
    return Array.from(array, (byte) =>
      ("0" + byte.toString(16)).slice(-2)
    ).join("");
  }
  const sessionData = JSON.parse(localStorage.getItem("userSocketHash"));
  // I have to be able to listen for the lua connected message.
  if (localStorage.getItem("luaSocketConnected") === null) {
    localStorage.setItem("luaSocketConnected", JSON.stringify(false));
  }
  let luaSocketConnected = JSON.parse(
    localStorage.getItem("luaSocketConnected")
  );
  ws.onmessage = function (event) {
    let message = event.data;
    //what if lua is connected? before.
    if (!luaSocketConnected && message == "luaConnected") {
      localStorage.setItem("luaSocketConnected", JSON.stringify(true));
    } else if (message == "luaDisconnect") {
      localStorage.setItem("luaSocketConnected", JSON.stringify(false));
    }
  };
</script>

{#if luaSocketConnected}
  <MainWindow />
{:else}
  <div class="container">
    <div class="getting-started">
      <h1>Getting started</h1>
      <div class="code-block">
        <p>&gt; wget https://cloud-catcher.squiddev.cc/cloud.lua</p>
        <p>&gt; spotify.lua {sessionData}</p>
      </div>
    </div>
    <div class="content">
      <p>
        For more information, as well as source code and screenshots, see the <a
          href="https://github.com/SquidDev-CC/cloud-catcher"
          >GitHub repository</a
        >.
      </p>
    </div>
    <div class="getting-started">
      <h2>Getting started</h2>
      <p>You will require:</p>
      <ul>
        <li>An internet connection</li>
        <li><a href="https://tweaked.cc">CC: Tweaked</a></li>
      </ul>
      <p>Then just follow the instructions at the top!</p>
    </div>
  </div>
{/if}

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link
    href="https://fonts.googleapis.com/css2?family=Libre+Franklin:wght@300&display=swap"
    rel="stylesheet"
  />
  <style>
    body {
      padding: 0;
      margin: 0;
      font-family: "Libre Franklin", sans-serif;
      color: #fbfcfc;
      /* font-family: Arial, Helvetica, sans-serif; */
    }
  </style>
  <script src="https://sdk.scdn.co/spotify-player.js"></script>
  <!-- Google icons -->
  <link
    rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,300,0,0"
  />
  <style>
    .material-symbols-outlined {
      font-variation-settings:
        "FILL" 0,
        "wght" 300,
        "GRAD" 0,
        "opsz" 48;
    }
  </style>
</svelte:head>

<style>
  /* styles.css */

  .container {
    max-width: 800px;
    margin: 0 auto;
    color: black;
  }

  .getting-started {
    margin-bottom: 20px;
  }

  .code-block {
    background-color: #f5f5f5;
    border: 1px solid #ddd;
    padding: 10px;
    font-family: monospace;
    font-size: 16px;
    margin-bottom: 20px;
  }

  h1 {
    font-size: 24px;
    margin-bottom: 10px;
  }

  h2 {
    font-size: 20px;
    margin-bottom: 10px;
  }

  p {
    line-height: 1.6;
    margin-bottom: 10px;
  }

  a {
    color: #0366d6;
    text-decoration: none;
  }

  a:hover {
    text-decoration: underline;
  }

  ul {
    margin: 10px 0;
    padding-left: 20px;
  }

  li {
    margin-bottom: 5px;
  }

  code {
    background-color: #e6e6e6;
    padding: 2px 4px;
    border-radius: 4px;
    font-family: monospace;
  }
</style>
