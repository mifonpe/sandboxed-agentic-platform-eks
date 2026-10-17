<script setup lang="ts">
withDefaults(defineProps<{ day: string }>(), {
  day: 'Lunes',
})
</script>

<template>
  <div class="day-marker" :aria-label="day">
    <div class="i-carbon-calendar" aria-hidden="true" />
    <span>{{ day }}</span>
  </div>
</template>

<style scoped>
.day-marker {
  position: fixed;
  top: 1.5rem;
  right: 2rem;
  display: inline-flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.8rem 1.2rem;
  border: 3px solid #2d2b3d;
  border-radius: 0.7rem;
  background: #fff;
  color: #1d2533;
  font-size: 1.4rem;
  font-weight: 800;
  box-shadow: 0 6px 14px rgb(0 0 0 / 0.12);
}

.day-marker > div {
  width: 2.1rem;
  height: 2.1rem;
  color: #21b69b;
}
</style>
