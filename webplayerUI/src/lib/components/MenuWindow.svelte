<style>
    .container {
        position: absolute;
        width: 70vw;
        height: 60vh;
        z-index: 10;
        border-radius: 2ch;
        left: 50%;
        top: 50%;
        transform: translateX(-50%) translateY(-50%);
        /* backdrop-filter: blur(60px); */
        background-color: #707070ad;
        z-index: 20;
    }
    .background {
        position: absolute;
        width: 100%;
        height: 100%;
        z-index: 19;
        backdrop-filter: blur(20px);
    }
</style>

<div class="background">
    <div class="container">
        <slot></slot>
    </div>
</div>