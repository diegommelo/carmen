<template>
  <div class="fixed bottom-0 left-1/2 transform -translate-x-1/2 mb-2 p-2 rounded-2xl bg-white/20 backdrop-blur-md shadow-lg">
    <div class="flex space-x-2">
      <div
        v-for="app in apps"
        :key="app.name"
        class="relative group"
        @mouseenter="hoveredApp = app.name"
        @mouseleave="hoveredApp = null"
      >
        <div
          class="w-12 h-12 flex items-center justify-center rounded-xl bg-white/50 shadow-sm transition-all duration-300 group-hover:scale-125"
          :class="{ 'scale-125': hoveredApp === app.name }"
        >
          <component :is="app.icon" class="w-8 h-8" />
        </div>
        <div
          v-if="hoveredApp === app.name"
          class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-xs text-white bg-black/75 rounded-md whitespace-nowrap"
        >
          {{ app.name }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { Compass, FileText, MessageCircle, Music, Settings } from 'lucide-vue-next';

const apps = [
  { name: 'Finder', icon: Compass },
  { name: 'Notes', icon: FileText },
  { name: 'Messages', icon: MessageCircle },
  { name: 'Music', icon: Music },
  { name: 'Settings', icon: Settings },
];

const hoveredApp = ref(null);
</script>

<style scoped>
/* Add any additional styles here */
</style>