<template>
  <div class="guardrail-scene">
    <div class="stage-glow" aria-hidden="true" />

    <div class="architect" aria-label="Arquitecto de software">
      <img src="/img/arquitecto_icon.png" alt="Arquitecto" />
    </div>

    <div class="speech-bubble">¡Hay que implementar control de uso!</div>

    <div class="guardrail" aria-label="Guardrail que valida las acciones del agente">
      <div class="guardrail-header"><span class="i-carbon-security" aria-hidden="true" /> Guardrail de acciones</div>
      <div class="request">
        <span class="i-carbon-bot" aria-hidden="true" />
        <span>Acción</span>
      </div>
      <div class="policy-checks">
        <div><span class="i-carbon-checkmark-filled" aria-hidden="true" /> Permisos</div>
        <div><span class="i-carbon-checkmark-filled" aria-hidden="true" /> Seguridad</div>
        <div><span class="i-carbon-checkmark-filled" aria-hidden="true" /> Límite diario</div>
      </div>
      <div class="result"><span class="i-carbon-checkmark-outline" aria-hidden="true" /> Acción validada</div>
    </div>
  </div>
</template>

<style scoped>
.guardrail-scene { position: relative; display: flex; align-items: flex-end; justify-content: center; gap: 88px; width: 100%; height: 445px; overflow: hidden; color: #1d2533; }
.stage-glow { position: absolute; right: 65px; bottom: 12px; width: 650px; height: 290px; border-radius: 50%; background: radial-gradient(circle, rgb(94 180 160 / 0.2), rgb(94 180 160 / 0)); }
.architect { position: relative; z-index: 2; display: grid; justify-items: center; margin-bottom: 16px; }
.architect img { width: 275px; height: 275px; object-fit: contain; }
.role-badge { display: flex; align-items: center; gap: 8px; margin-top: -13px; padding: 8px 14px; border: 3px solid #2d2b3d; border-radius: 999px; background: #fff4dc; font-size: 1rem; font-weight: 900; }
.role-badge span { width: 22px; height: 22px; color: #a65e2e; }
.speech-bubble { position: absolute; z-index: 4; left: calc(50% - 290px); bottom: 296px; max-width: 420px; padding: 17px 22px; border: 5px solid #2d2b3d; border-radius: 22px; background: white; box-shadow: 0 14px 28px rgb(0 0 0 / 0.18); font-size: 1.42rem; font-weight: 900; }
.speech-bubble::after { content: ""; position: absolute; bottom: -21px; left: 48px; width: 30px; height: 30px; border-right: 5px solid #2d2b3d; border-bottom: 5px solid #2d2b3d; background: white; transform: rotate(45deg); }
.guardrail { position: relative; z-index: 2; width: 445px; margin-bottom: 40px; padding: 18px; border: 6px solid #2d2b3d; border-radius: 18px; background: linear-gradient(135deg, #fff, #e7f8f4); box-shadow: 0 18px 30px rgb(0 0 0 / 0.16); }
.guardrail-header { display: flex; align-items: center; gap: 9px; color: #253247; font-size: 1.35rem; font-weight: 900; }
.guardrail-header span { width: 34px; height: 34px; color: #168b76; }
.request { display: flex; align-items: center; gap: 9px; margin-top: 15px; padding: 12px; border: 3px solid #2d2b3d; border-radius: 9px; background: #dcecf8; color: #2d526c; font-size: 0.88rem; font-weight: 900; }
.request span { width: 28px; height: 28px; }
.request span:last-child { min-width: 0; line-height: 1.15; }
.policy-checks { display: grid; grid-template-columns: repeat(3, 1fr); gap: 7px; margin: 13px 0; }
.policy-checks div { display: grid; justify-items: center; gap: 5px; padding: 8px 4px; border-radius: 8px; background: #edfaf5; color: #3c5d54; font-size: 0.78rem; font-weight: 900; text-align: center; }
.policy-checks span { width: 21px; height: 21px; color: #21b69b; }
.result { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 11px; border-radius: 8px; background: #253247; color: #dff8ef; font-size: 1rem; font-weight: 900; }
.result span { width: 24px; height: 24px; color: #9ff3df; }
</style>
