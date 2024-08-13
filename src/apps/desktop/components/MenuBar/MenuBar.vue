<template>
  <div class="sticky top-0 z-50">
    <div class="absolute inset-0 bg-white/30 backdrop-blur-md"></div>
    <div class="relative flex items-center h-8 border-b border-gray-300/50">
      <div class="flex items-center space-x-2 px-2">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-apple"><path d="M12 20.94c1.5 0 2.75 1.06 4 1.06 3 0 6-8 6-12.22A4.91 4.91 0 0 0 17 5c-2.22 0-4 1.44-5 2-1-.56-2.78-2-5-2a4.9 4.9 0 0 0-5 4.78C2 14 5 22 8 22c1.25 0 2.5-1.06 4-1.06Z"/><path d="M10 2c1 .5 2 2 2 5"/></svg>
        <MenubarItem
          v-for="menu in menus"
          :key="menu.label"
          :label="menu.label"
          :items="menu.items"
          :activeMenu="activeMenu"
          @select="handleMenuItemSelect"
          @activateMenu="setActiveMenu"
          @deactivateMenu="clearActiveMenu"
        />
      </div>
      <div class="flex-grow" />
      <div class="flex items-center space-x-2 px-2">
        <span class="text-sm">{{ currentTime }}</span>
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-down"><path d="m6 9 6 6 6-6"/></svg>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import MenubarItem from './components/MenuBarItem.vue';

const currentTime = ref('');
const activeMenu = ref('');

const menus = [
  { label: 'Finder', items: ['About Finder', 'Preferences', 'Empty Trash'] },
  { label: 'File', items: ['New Folder', 'Open', 'Close Window'] },
  { label: 'Edit', items: ['Undo', 'Redo', 'Cut', 'Copy', 'Paste'] },
  { label: 'View', items: ['as Icons', 'as List', 'as Columns'] },
];

const updateTime = () => {
  const now = new Date();
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const day = days[now.getDay()];
  const hours = now.getHours().toString().padStart(2, '0');
  const minutes = now.getMinutes().toString().padStart(2, '0');
  currentTime.value = `${day} ${hours}:${minutes}`;
};

const handleMenuItemSelect = (item) => {
  console.log(`Selected menu item: ${item}`);
  // Here you can add any logic to handle the selected menu item
};

const setActiveMenu = (menu) => {
  activeMenu.value = menu;
};

const clearActiveMenu = () => {
  activeMenu.value = '';
};

const handleClickOutside = (event) => {
  if (!event.target.closest('.relative')) {
    clearActiveMenu();
  }
};

let timer;

onMounted(() => {
  updateTime();
  timer = setInterval(updateTime, 60000);
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  clearInterval(timer);
  document.removeEventListener('click', handleClickOutside);
});
</script>

<style scoped>
.sticky {
  position: sticky;
  backdrop-filter: saturate(180%) blur(20px);
}
</style>