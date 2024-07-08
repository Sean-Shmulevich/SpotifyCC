<script>
  import SongListItem from "./SongListItem.svelte";
  import { queue } from "../spotifyUtils/player";
  let q = [];
  queue.subscribe((value) => {
    q = value;
  });
</script>

{#if q != undefined && q?.length > 0}
  {#each q as song}
    <SongListItem {song} />
  {/each}
{:else}
  <p>Nothing here yet...</p>
{/if}

<!-- <button on:click={getQueue}> TODO: Find a way to get it working
        <span class="material-symbols-rounded">
            refresh
        </span>
        Refresh
    </button> -->
