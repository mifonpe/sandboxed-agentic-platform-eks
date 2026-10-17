<template>
  <div class="risk-controls-scene">
    <div class="lane-label risk-label">Riesgo</div>
    <div class="lane-label control-label">Control</div>
    <div class="shield i-carbon-security" aria-hidden="true" />

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-cloud-data-ops" aria-hidden="true" />Exfiltración de información</div>
      <div class="connection"><span>La red limita la salida</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-network-3" aria-hidden="true" />Control de acceso a Internet + DLP en guardrails</div>
    </div>

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-virus" aria-hidden="true" />Instalación de malware</div>
      <div class="connection"><span>Sin persistencia ni descarga libre</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-container-runtime" aria-hidden="true" />Entornos efímeros + control de red</div>
    </div>

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-document-unknown" aria-hidden="true" />Cambios fuera de la tarea</div>
      <div class="connection"><span>Reduce lo que puede alterar</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-data-enrichment" aria-hidden="true" />Contexto mínimo necesario</div>
    </div>

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-save" aria-hidden="true" />Persistencia local de datos</div>
      <div class="connection"><span>Desaparece al terminar</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-trash-can" aria-hidden="true" />Entornos efímeros</div>
    </div>

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-user-military" aria-hidden="true" />Elevación de privilegios</div>
      <div class="connection"><span>El usuario reconoce el riesgo</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-education" aria-hidden="true" />Educación y entrenamiento</div>
    </div>

    <div class="control-row">
      <div class="risk-card"><span class="i-carbon-wallet" aria-hidden="true" />Denial of wallet</div>
      <div class="connection"><span>Limita el consumo por usuario</span><i class="i-carbon-arrow-right" aria-hidden="true" /></div>
      <div class="control-card"><span class="i-carbon-meter" aria-hidden="true" />Rate limiting y uso segregado por usuario</div>
    </div>
  </div>
</template>

<style scoped>
.risk-controls-scene { position: relative; display: grid; gap: 9px; width: 100%; height: 448px; padding: 51px 38px 14px; overflow: hidden; color: #1d2533; }
.lane-label { position: absolute; top: 7px; padding: 8px 16px; border: 3px solid #2d2b3d; border-radius: 999px; font-size: 0.95rem; font-weight: 900; }
.risk-label { left: 52px; background: #ffe4e1; color: #8e3030; }
.control-label { right: 52px; background: #dff8ef; color: #168b76; }
.shield { position: absolute; z-index: 0; top: 95px; left: calc(50% - 105px); width: 210px; height: 210px; color: rgb(33 182 155 / 0.09); }
.control-row { position: relative; z-index: 1; display: grid; grid-template-columns: 285px 1fr 335px; gap: 15px; align-items: center; }
.risk-card, .control-card { display: flex; align-items: center; gap: 11px; min-height: 54px; padding: 9px 13px; border: 3px solid #2d2b3d; border-radius: 10px; font-size: 0.83rem; font-weight: 900; line-height: 1.1; }
.risk-card { background: #fff0ee; color: #8e3030; }
.control-card { background: #edfaf5; color: #285a4e; }
.risk-card span, .control-card span { flex: 0 0 auto; width: 29px; height: 29px; }
.risk-card span { color: #d85050; }
.control-card span { color: #168b76; }
.connection { display: flex; align-items: center; justify-content: center; gap: 8px; color: #516070; font-size: 0.67rem; font-weight: 800; text-align: center; line-height: 1.05; }
.connection i { flex: 0 0 auto; width: 29px; height: 29px; color: #21b69b; }
</style>
