<template>
  <div class="actors-scene">
    <div class="i-carbon-enterprise enterprise-icon" aria-label="Empresa" />

    <div class="actors-row">
      <div class="actor">
        <img class="actor-image" src="/img/woman_icon.png" alt="Susana" />
        <div class="actor-name">Susana</div>
      </div>

      <div class="laptop-wrap">
        <div class="i-carbon-laptop laptop-icon" aria-label="Portatil" />
      </div>

      <div class="actor">
        <img class="actor-image" src="/img/man_icon.png" alt="Santiago" />
        <div class="actor-name">Santiago</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.actors-scene {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 40px;
  height: 230px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  color: currentColor;
}

.enterprise-icon {
  position: absolute;
  bottom: 6px;
  width: 320px;
  height: 320px;
  opacity: 0.16;
}

.actors-row {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 140px 130px 140px;
  column-gap: 22px;
  align-items: end;
  justify-items: center;
}

.actor {
  text-align: center;
}

.actor-image {
  width: 118px;
  height: 118px;
  object-fit: contain;
}

.actor-name {
  margin-top: 10px;
  font-size: 1.15rem;
  font-weight: 800;
}

.laptop-wrap {
  margin-bottom: 42px;
}

.laptop-icon {
  width: 118px;
  height: 118px;
}
</style>
