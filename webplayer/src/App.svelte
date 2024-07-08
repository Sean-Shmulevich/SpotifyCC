<script>
  import MainWindow from "./lib/components/MainWindow.svelte";
</script>

<MainWindow />

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
