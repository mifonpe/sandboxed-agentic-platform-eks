<script setup lang="ts">
// Logo de la herramienta, esquina inferior derecha de la slide.
defineProps({
  src: { type: String, required: true },
  alt: { type: String, default: '' },
  size: { type: String, default: '110px' },
})
</script>

<template>
  <img class="tool-logo" :src="src" :alt="alt" :style="{ height: size }" />
</template>

<style scoped>
.tool-logo {
  position: absolute;
  right: 48px;
  bottom: 40px;
  width: auto;
  object-fit: contain;
}
</style>
