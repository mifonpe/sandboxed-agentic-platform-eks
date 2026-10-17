<template>
  <div class="install-scene">
    <div class="stage-glow" aria-hidden="true" />

    <div class="actor">
      <img class="actor-image" src="/img/woman_icon.png" alt="Susana" />
      <div class="actor-name">Susana</div>
    </div>

    <div class="laptop" aria-label="Susana instala un asistente en el portatil">
      <div class="laptop-screen">
        <div class="window-bar">
          <span />
          <span />
          <span />
        </div>

        <div class="assistant-card">
          <div class="assistant-icon">
            <div class="i-carbon-bot" aria-hidden="true" />
          </div>
          <div>
            <div class="app-name">Claudex Assistant</div>
            <div class="app-status">Instalando asistente</div>
          </div>
        </div>

        <div class="progress-track">
          <div class="progress-fill" />
        </div>

        <div class="terminal">
          <span>$ setup assistant</span>
          <span>Conectando con repos...</span>
          <span>Listo para codificar</span>
        </div>
      </div>
      <div class="laptop-base" />
    </div>
  </div>
</template>

<style scoped>
.install-scene {
  position: relative;
  width: 100%;
  height: 445px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 54px;
  overflow: hidden;
  color: #1d2533;
}

.stage-glow {
  position: absolute;
  right: 88px;
  bottom: 16px;
  width: 650px;
  height: 260px;
  border-radius: 50%;
  background: radial-gradient(circle, rgb(94 180 160 / 0.18), rgb(94 180 160 / 0));
}

.actor {
  position: relative;
  z-index: 2;
  display: grid;
  justify-items: center;
  margin-bottom: 22px;
}

.actor-image {
  width: 245px;
  height: 245px;
  object-fit: contain;
}

.actor-name {
  margin-top: 8px;
  font-size: 1.35rem;
  font-weight: 900;
}

.laptop {
  position: relative;
  z-index: 2;
  width: 440px;
  margin-bottom: 28px;
}

.laptop-screen {
  height: 268px;
  padding: 20px 24px 22px;
  border: 8px solid #2d2b3d;
  border-radius: 18px 18px 10px 10px;
  background:
    linear-gradient(135deg, rgb(255 255 255 / 0.94), rgb(231 248 244 / 0.94)),
    #f8fbff;
  box-shadow: 0 22px 36px rgb(0 0 0 / 0.18);
}

.window-bar {
  display: flex;
  gap: 8px;
  margin-bottom: 18px;
}

.window-bar span {
  width: 12px;
  height: 12px;
  border-radius: 999px;
  background: #ff6b6b;
}

.window-bar span:nth-child(2) {
  background: #ffd166;
}

.window-bar span:nth-child(3) {
  background: #06d6a0;
}

.assistant-card {
  display: grid;
  grid-template-columns: 58px 1fr;
  gap: 14px;
  align-items: center;
  padding: 16px;
  border: 3px solid #2d2b3d;
  border-radius: 8px;
  background: white;
}

.assistant-icon {
  display: grid;
  width: 58px;
  height: 58px;
  place-items: center;
  border-radius: 8px;
  background: #253247;
  color: #9ff3df;
}

.assistant-icon div {
  width: 36px;
  height: 36px;
}

.app-name {
  font-size: 1.28rem;
  font-weight: 900;
  line-height: 1.05;
}

.app-status {
  margin-top: 6px;
  color: #516070;
  font-size: 0.86rem;
  font-weight: 800;
}

.progress-track {
  height: 18px;
  margin-top: 18px;
  border: 3px solid #2d2b3d;
  border-radius: 999px;
  background: #dbe5ef;
  overflow: hidden;
}

.progress-fill {
  width: 76%;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #21b69b, #74d680);
}

.terminal {
  display: grid;
  gap: 5px;
  margin-top: 16px;
  padding: 12px 14px;
  border-radius: 8px;
  background: #1d2533;
  color: #dff8ef;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.72rem;
  font-weight: 800;
}

.terminal span:nth-child(1) {
  color: #8ee5d1;
}

.laptop-base {
  width: 500px;
  height: 28px;
  margin-left: -30px;
  border: 8px solid #2d2b3d;
  border-top: 0;
  border-radius: 0 0 26px 26px;
  background: #cfd7e3;
  box-shadow: 0 16px 24px rgb(0 0 0 / 0.12);
}
</style>
