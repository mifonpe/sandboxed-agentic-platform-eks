<template>
  <div class="obo-scene">
    <div class="stage-glow" aria-hidden="true" />

    <div class="architect" aria-label="Arquitecto de software">
      <img src="/img/arquitecto_icon.png" alt="Arquitecto" />
      <div class="role-badge"><span class="i-carbon-architecture-alt" aria-hidden="true" />Arquitecto</div>
    </div>

    <div class="speech-bubble">¡Usaremos permisos OBO!</div>

    <div class="obo-flow" aria-label="El agente actúa con permisos delegados y limitados de Santiago">
      <div class="flow-title"><span class="i-carbon-user-certification" aria-hidden="true" /> On-Behalf-Of (OBO)</div>

      <div class="flow-steps">
        <div class="principal">
          <span class="i-carbon-user-avatar-filled" aria-hidden="true" />
          <strong>Santiago</strong>
          <small>Identidad original</small>
        </div>

        <span class="connector i-carbon-arrow-right" aria-hidden="true" />

        <div class="delegation">
          <span class="i-carbon-key" aria-hidden="true" />
          <strong>Token OBO</strong>
          <small>Temporal y limitado</small>
        </div>

        <span class="connector i-carbon-arrow-right" aria-hidden="true" />

        <div class="agent">
          <span class="i-carbon-bot" aria-hidden="true" />
          <strong>Agente</strong>
          <small>Actúa por Santiago</small>
        </div>
      </div>

      <div class="scope-panel">
        <div><span class="i-carbon-checkmark-filled" aria-hidden="true" /> Solo el servicio autorizado</div>
        <div><span class="i-carbon-checkmark-filled" aria-hidden="true" /> Todas las acciones auditables</div>
        <div><span class="i-carbon-time" aria-hidden="true" /> Caduca al terminar la tarea</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.obo-scene { position: relative; display: flex; align-items: flex-end; justify-content: center; gap: 76px; width: 100%; height: 445px; overflow: hidden; color: #1d2533; }
.stage-glow { position: absolute; right: 54px; bottom: 8px; width: 710px; height: 290px; border-radius: 50%; background: radial-gradient(circle, rgb(94 180 160 / 0.2), rgb(94 180 160 / 0)); }
.architect { position: relative; z-index: 2; display: grid; justify-items: center; margin-bottom: 16px; }
.architect img { width: 275px; height: 275px; object-fit: contain; }
.role-badge { display: flex; align-items: center; gap: 8px; margin-top: -13px; padding: 8px 14px; border: 3px solid #2d2b3d; border-radius: 999px; background: #fff4dc; font-size: 1rem; font-weight: 900; }
.role-badge span { width: 22px; height: 22px; color: #a65e2e; }
.speech-bubble { position: absolute; z-index: 4; left: calc(50% - 280px); bottom: 298px; padding: 17px 22px; border: 5px solid #2d2b3d; border-radius: 22px; background: white; box-shadow: 0 14px 28px rgb(0 0 0 / 0.18); font-size: 1.3rem; font-weight: 900; }
.speech-bubble::after { content: ""; position: absolute; bottom: -21px; left: 48px; width: 30px; height: 30px; border-right: 5px solid #2d2b3d; border-bottom: 5px solid #2d2b3d; background: white; transform: rotate(45deg); }
.obo-flow { position: relative; z-index: 2; width: 520px; margin-bottom: 38px; padding: 17px; border: 6px solid #2d2b3d; border-radius: 18px; background: linear-gradient(135deg, #fff, #e7f8f4); box-shadow: 0 18px 30px rgb(0 0 0 / 0.16); }
.flow-title { display: flex; align-items: center; gap: 9px; color: #253247; font-size: 1.18rem; font-weight: 900; }
.flow-title span { width: 30px; height: 30px; color: #21b69b; }
.flow-steps { display: flex; align-items: center; justify-content: space-between; margin-top: 15px; }
.principal, .delegation, .agent { display: grid; width: 125px; justify-items: center; gap: 3px; padding: 10px 5px; border: 3px solid #2d2b3d; border-radius: 10px; background: white; text-align: center; }
.principal > span, .delegation > span, .agent > span { width: 31px; height: 31px; color: #253247; }
.principal { background: #dcecf8; }
.delegation { background: #fff4dc; }
.delegation > span { color: #a65e2e; }
.agent { background: #dff8ef; }
.agent > span { color: #168b76; }
.principal strong, .delegation strong, .agent strong { font-size: 0.82rem; }
.principal small, .delegation small, .agent small { color: #516070; font-size: 0.6rem; font-weight: 800; }
.connector { width: 23px; height: 23px; color: #21b69b; }
.scope-panel { display: grid; grid-template-columns: repeat(3, 1fr); gap: 7px; margin-top: 14px; padding-top: 12px; border-top: 2px solid #bed8d2; }
.scope-panel div { display: flex; align-items: flex-start; gap: 4px; color: #3c5d54; font-size: 0.6rem; font-weight: 800; line-height: 1.2; }
.scope-panel span { flex: 0 0 auto; width: 15px; height: 15px; color: #21b69b; }
</style>
