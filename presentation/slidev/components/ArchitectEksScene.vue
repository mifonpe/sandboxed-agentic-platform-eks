<template>
  <div class="architect-scene">
    <div class="stage-glow" aria-hidden="true" />

    <div class="architect" aria-label="Arquitecto de software">
      <img src="/img/arquitecto_icon.png" alt="Arquitecto" />
    </div>

    <div class="speech-bubble">¡Hay que irse a EKS!</div>

    <div class="eks-plan" aria-label="Plan de migración a Amazon EKS">
      <div class="plan-header">
        <div class="i-carbon-cloud" aria-hidden="true" />
        <span>Amazon EKS</span>
      </div>
      <div class="cluster">
        <div class="control-plane">Control plane</div>
        <div class="nodes">
          <div><span class="i-carbon-container-software" aria-hidden="true" />Node</div>
          <div><span class="i-carbon-container-software" aria-hidden="true" />Node</div>
          <div><span class="i-carbon-container-software" aria-hidden="true" />Node</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.architect-scene {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 76px;
  width: 100%;
  height: 445px;
  overflow: hidden;
  color: #1d2533;
}

.stage-glow {
  position: absolute;
  right: 88px;
  bottom: 8px;
  width: 600px;
  height: 280px;
  border-radius: 50%;
  background: radial-gradient(circle, rgb(94 180 160 / 0.2), rgb(94 180 160 / 0));
}

.architect {
  position: relative;
  z-index: 2;
  display: grid;
  justify-items: center;
  margin-bottom: 22px;
}

.architect img {
  width: 285px;
  height: 285px;
  object-fit: contain;
}

.role-badge {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: -12px;
  padding: 8px 14px;
  border: 3px solid #2d2b3d;
  border-radius: 999px;
  background: #fff4dc;
  font-size: 1rem;
  font-weight: 900;
}

.role-badge div { width: 22px; height: 22px; color: #a65e2e; }

.speech-bubble {
  position: absolute;
  z-index: 4;
  left: calc(50% - 260px);
  bottom: 294px;
  padding: 17px 22px;
  border: 5px solid #2d2b3d;
  border-radius: 22px;
  background: white;
  box-shadow: 0 14px 28px rgb(0 0 0 / 0.18);
  font-size: 1.45rem;
  font-weight: 900;
}

.speech-bubble::after {
  content: "";
  position: absolute;
  bottom: -21px;
  left: 48px;
  width: 30px;
  height: 30px;
  border-right: 5px solid #2d2b3d;
  border-bottom: 5px solid #2d2b3d;
  background: white;
  transform: rotate(45deg);
}

.eks-plan {
  position: relative;
  z-index: 2;
  width: 370px;
  margin-bottom: 54px;
  padding: 18px;
  border: 6px solid #2d2b3d;
  border-radius: 18px;
  background: linear-gradient(135deg, #fff, #e7f8f4);
  box-shadow: 0 18px 30px rgb(0 0 0 / 0.16);
}

.plan-header {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #253247;
  font-size: 1.25rem;
  font-weight: 900;
}

.plan-header div { width: 32px; height: 32px; color: #21b69b; }

.cluster {
  display: grid;
  gap: 14px;
  margin-top: 16px;
  padding: 16px;
  border: 3px dashed #79a99c;
  border-radius: 12px;
}

.control-plane {
  padding: 9px;
  border-radius: 8px;
  background: #253247;
  color: #dff8ef;
  text-align: center;
  font-size: 0.9rem;
  font-weight: 900;
}

.nodes { display: flex; justify-content: space-between; gap: 8px; }
.nodes div { display: grid; justify-items: center; gap: 3px; color: #516070; font-size: 0.68rem; font-weight: 800; }
.nodes span { width: 35px; height: 35px; padding: 8px; border: 3px solid #2d2b3d; border-radius: 7px; background: #9ff3df; color: #253247; }
</style>
