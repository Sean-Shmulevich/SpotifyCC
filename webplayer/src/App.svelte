<script>
  import MainWindow from "./lib/components/MainWindow.svelte";
  import WsConnect from "./lib/components/WsConnect.svelte";
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
      luaSocketConnected = true;
    }
  };
</script>

{#if luaSocketConnected}
  <svelte:component
    this={MainWindow}
    bind:socketConnection={luaSocketConnected}
  />
{:else}
  <svelte:component
    this={WsConnect}
    bind:socketConnection={luaSocketConnected}
  />
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
