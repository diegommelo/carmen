<template>
  <div class="DesktopHome w-screen h-screen verflow-hidden">
    <MenuBar />
  </div>
</template>

<script setup>
import MenuBar from '../desktop/components/MenuBar/MenuBar.vue'
</script>

<style scoped>
.DesktopHome {
  background-image: url('/images/surtur-wallpaper.jpg');
  background-size: cover;
  background-position: center;
}
</style>
