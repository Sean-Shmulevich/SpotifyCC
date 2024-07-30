<script>
const sessionData = JSON.parse(localStorage.getItem("userSocketHash"));
</script>

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
        href="https://github.com/SquidDev-CC/cloud-catcher">GitHub repository</a
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
