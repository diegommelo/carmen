<template>
  <div class="flex items-center h-8 bg-gray-100 border-b border-gray-300">
    <div class="flex items-center space-x-2 px-2">
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-apple">
        <path d="M12 20.94c1.5 0 2.75 1.06 4 1.06 3 0 6-8 6-12.22A4.91 4.91 0 0 0 17 5c-2.22 0-4 1.44-5 2-1-.56-2.78-2-5-2a4.9 4.9 0 0 0-5 4.78C2 14 5 22 8 22c1.25 0 2.5-1.06 4-1.06Z"/>
        <path d="M10 2c1 .5 2 2 2 5"/>
      </svg>
      <MenubarItem
        label="Finder"
        :items="['About Finder', 'Preferences', 'Empty Trash']"
      />
      <MenubarItem
        label="File"
        :items="['New Folder', 'Open', 'Close Window']"
      />
      <MenubarItem
        label="Edit"
        :items="['Undo', 'Redo', 'Cut', 'Copy', 'Paste']"
      />
      <MenubarItem
        label="View"
        :items="['as Icons', 'as List', 'as Columns']"
      />
    </div>
    <div class="flex-grow" />
    <div class="flex items-center space-x-2 px-2">
      <span class="text-sm">{{ currentTime }}</span>
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-down"><path d="m6 9 6 6 6-6"/></svg>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import MenubarItem from './components/MenuBarItem.vue';

const currentTime = ref('');

const updateTime = () => {
  const now = new Date();
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const day = days[now.getDay()];
  const hours = now.getHours().toString().padStart(2, '0');
  const minutes = now.getMinutes().toString().padStart(2, '0');
  currentTime.value = `${day} ${hours}:${minutes}`;
};

let timer;

onMounted(() => {
  updateTime();
  timer = setInterval(updateTime, 60000);
});

onUnmounted(() => {
  clearInterval(timer);
});
</script>