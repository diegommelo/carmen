<template>
  <div class="relative" @mouseleave="handleMouseLeave">
    <button
      class="px-3 py-1 hover:bg-black/10 rounded text-black/90"
      @mouseenter="handleMouseEnter"
      @click="handleClick"
      ref="menuButton"
    >
      {{ label }}
    </button>
    <div
      v-if="isOpen"
      class="absolute left-0 mt-1 py-1 bg-white/70 backdrop-blur-md shadow-lg rounded-md"
    >
      <div class="flex flex-col w-48">
        <button
          v-for="(item, index) in items"
          :key="index"
          class="px-4 py-2 text-left hover:bg-black/10 text-black/90"
          @click="selectItem(item)"
        >
          {{ item }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
  label: {
    type: String,
    required: true
  },
  items: {
    type: Array,
    default: () => []
  },
  activeMenu: {
    type: String,
    default: ''
  }
});

const emit = defineEmits(['select', 'activateMenu', 'deactivateMenu']);

const isOpen = ref(false);
const menuButton = ref(null);

const handleMouseEnter = () => {
  if (props.activeMenu) {
    emit('activateMenu', props.label);
  }
};

const handleMouseLeave = () => {
  if (props.activeMenu && props.activeMenu !== props.label) {
    isOpen.value = false;
  }
};

const handleClick = () => {
  if (isOpen.value) {
    emit('deactivateMenu');
  } else {
    emit('activateMenu', props.label);
  }
};

const selectItem = (item) => {
  emit('select', item);
  emit('deactivateMenu');
};

watch(() => props.activeMenu, (newActiveMenu) => {
  isOpen.value = newActiveMenu === props.label;
});
</script>