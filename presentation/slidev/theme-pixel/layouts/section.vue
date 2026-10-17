<script setup lang="ts">
defineProps({
  // Numero grande de seccion (01, 02, 03...)
  number: { type: String, default: '' },
})
</script>

<template>
  <div class="slidev-layout section">
    <div class="section-inner">
      <div v-if="number" class="section-number">{{ number }}</div>
      <slot />
    </div>
  </div>
</template>

<style scoped>
.section-inner {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  gap: 0.4em;
}

.section-number {
  font-family: 'Press Start 2P', ui-monospace, monospace;
  font-size: 5rem;
  color: var(--pixel-cyan);
  text-shadow: 6px 6px 0 var(--pixel-night);
  margin-bottom: 0.2em;
}
</style>
