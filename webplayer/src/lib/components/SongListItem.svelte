<script>
  import { findLargestImageIndex } from "../commonUtils";
  export let song;
</script>

<div class="card">
  <img
    src={song.album.images[findLargestImageIndex(song.album.images)].url}
    alt=""
  />
  <!-- this should not be hq-->
  <div class="info">
    <div class="name">
      {song.name}
    </div>
    <div class="artist">
      {song.artists[0].name}
    </div>
  </div>
</div>

<style>
  .card {
    height: 3rem;
    padding: 1rem;
    margin: 0.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: #3a3a3a;
    border-radius: 2ch;
  }
  .info {
    text-align: right;
  }
  .artist {
    filter: brightness(0.5); /* TODO: this is not a good way of doing this */
  }
  img {
    height: 100%;
  }
</style>
