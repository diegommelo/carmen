<template>
  <div class="DesktopHome w-screen h-screen verflow-hidden bg-wallpaper bg-cover">
    <MenuBar />
    <div id="mainarea"></div>
    <DockBar />
  </div>
</template>

<script setup>
import MenuBar from '../desktop/components/MenuBar/MenuBar.vue'
import DockBar from '../desktop/components/DockBar/DockBar.vue';
</script>

<style scoped>
.DesktopHome {
  background-image: url('/images/surtur-wallpaper.jpg');
}
</style>
