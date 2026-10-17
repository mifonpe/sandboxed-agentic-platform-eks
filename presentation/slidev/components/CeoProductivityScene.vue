<template>
  <div class="ceo-scene">
    <div class="paper-bin" aria-label="Papelera con informe MIT">
      <img class="mit-report" src="/img/MIT_report.png" alt="MIT report about failed generative AI pilots" />
      <div class="i-ph-trash-duotone bin-icon" aria-hidden="true" />
    </div>

    <img class="ceo-image" src="/img/ceo_icon.png" alt="CEO" />

    <div class="speech-bubble">
      habilitaremos la IA para los desarrolladores de esta empresa!
    </div>

    <div class="laptop" aria-label="Articulo sobre productividad con IA">
      <div class="laptop-screen">
        <div class="article-kicker">BUSINESS INSIGHTS</div>
        <div class="article-title">AI Boost Productivity!</div>
        <div class="article-lines">
          <span />
          <span />
          <span />
        </div>
      </div>
      <div class="laptop-base" />
    </div>
  </div>
</template>

<style scoped>
.ceo-scene {
  position: relative;
  width: 100%;
  height: 440px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  overflow: hidden;
}

.ceo-image {
  position: relative;
  z-index: 2;
  width: 330px;
  height: 330px;
  object-fit: contain;
}

.speech-bubble {
  position: absolute;
  z-index: 4;
  left: 50%;
  bottom: 286px;
  width: 340px;
  padding: 16px 20px;
  border: 5px solid #2d2b3d;
  border-radius: 22px;
  background: white;
  color: #1d2533;
  font-size: 1.05rem;
  font-weight: 800;
  line-height: 1.18;
  box-shadow: 0 14px 28px rgb(0 0 0 / 0.18);
  transform: translateX(18%);
}

.speech-bubble::after {
  content: "";
  position: absolute;
  left: 38px;
  bottom: -22px;
  width: 32px;
  height: 32px;
  border-right: 5px solid #2d2b3d;
  border-bottom: 5px solid #2d2b3d;
  background: white;
  transform: rotate(45deg);
}

.laptop {
  position: absolute;
  z-index: 3;
  left: 50%;
  bottom: 30px;
  width: 300px;
  transform: translateX(-2%);
}

.laptop-screen {
  height: 170px;
  padding: 22px 26px;
  border: 7px solid #2d2b3d;
  border-radius: 14px 14px 8px 8px;
  background: #f8fbff;
  box-shadow: 0 16px 30px rgb(0 0 0 / 0.18);
}

.article-kicker {
  margin-bottom: 12px;
  color: #687386;
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.article-title {
  color: #1d2533;
  font-size: 1.65rem;
  font-weight: 900;
  line-height: 1.05;
}

.article-lines {
  display: grid;
  gap: 8px;
  margin-top: 18px;
}

.article-lines span {
  height: 8px;
  border-radius: 999px;
  background: #d8e0ea;
}

.article-lines span:nth-child(2) {
  width: 82%;
}

.article-lines span:nth-child(3) {
  width: 58%;
}

.laptop-base {
  width: 340px;
  height: 22px;
  margin-left: -20px;
  border: 7px solid #2d2b3d;
  border-top: 0;
  border-radius: 0 0 22px 22px;
  background: #cfd7e3;
}

.paper-bin {
  position: absolute;
  z-index: 1;
  left: 12px;
  bottom: 42px;
  width: 188px;
  height: 202px;
  opacity: 0.8;
}

.bin-icon {
  position: absolute;
  z-index: 2;
  left: 28px;
  bottom: 0;
  width: 132px;
  height: 132px;
  color: #6f7f93;
  filter: drop-shadow(0 8px 14px rgb(0 0 0 / 0.18));
}

.mit-report {
  position: absolute;
  z-index: 1;
  top: 6px;
  left: 6px;
  width: 170px;
  border: 5px solid white;
  box-shadow: 0 8px 18px rgb(0 0 0 / 0.22);
  transform: rotate(-13deg);
}
</style>
