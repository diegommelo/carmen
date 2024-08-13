<template>
  <div class="relative">
    <button
      class="px-3 py-1 hover:bg-gray-200 rounded"
      @mouseenter="isOpen = true"
      @mouseleave="isOpen = false"
    >
      {{ label }}
    </button>
    <div
      v-if="isOpen && items.length"
      class="absolute left-0 mt-1 py-1 bg-white shadow-lg rounded-md"
      @mouseenter="isOpen = true"
      @mouseleave="isOpen = false"
    >
      <div class="flex flex-col w-48">
        <button
          v-for="(item, index) in items"
          :key="index"
          class="px-4 py-2 text-left hover:bg-gray-100"
        >
          {{ item }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

defineProps({
  label: {
    type: String,
    required: true
  },
  items: {
    type: Array,
    default: () => []
  }
});

const isOpen = ref(false);
</script>