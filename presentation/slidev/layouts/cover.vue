<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps({
  background: {
    type: String,
    default: '/img/portada.jpeg',
  },
})

const style = computed(() => {
  const background = props.background
  const isColor = background && ['#', 'rgb', 'hsl'].some(prefix => background.startsWith(prefix))

  return {
    background: isColor ? background : undefined,
    backgroundImage: background && !isColor ? `url("${background}")` : undefined,
    backgroundRepeat: 'no-repeat',
    backgroundPosition: 'center',
    backgroundSize: 'cover',
    color: background && !isColor ? 'white' : undefined,
  }
})
</script>

<template>
  <div class="slidev-layout cover text-center" :style="style">
    <div class="my-auto w-full">
      <slot />
    </div>
  </div>
</template>
