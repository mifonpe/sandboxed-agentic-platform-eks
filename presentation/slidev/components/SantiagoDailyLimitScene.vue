<template>
  <div class="limit-scene">
    <div class="office-sign"><span class="i-carbon-building" aria-hidden="true" /> Oficina</div>

    <div class="pepe" aria-label="Santiago llega a la oficina">
      <img src="/img/man_icon.png" alt="Santiago" />
    </div>

    <div class="platform" aria-label="Plataforma de desarrollo con el límite diario agotado">
      <div class="platform-header">
        <span class="i-carbon-application-web" aria-hidden="true" />
        Plataforma de desarrollo
        <span class="status"><i /> Conectado</span>
      </div>

      <div class="assistant-message">
        <span class="bot-icon i-carbon-bot" aria-hidden="true" />
        <div>
          <strong>Claudex Assistant</strong>
          <p>Se ha alcanzado el límite diario.</p>
        </div>
      </div>

      <div class="quota">
        <div class="quota-label"><span>Tokens diarios</span><strong>100% consumido</strong></div>
        <div class="quota-track"><span /></div>
      </div>

      <div class="usage-alert"><span class="i-carbon-warning-alt-filled" aria-hidden="true" /> Susana ha gastado todos los tokens.</div>
    </div>
  </div>
</template>

<style scoped>
.limit-scene { position: relative; display: flex; align-items: flex-end; justify-content: center; gap: 75px; width: 100%; height: 450px; overflow: hidden; color: #1d2533; }
.office-sign { position: absolute; top: 18px; left: 54px; display: flex; align-items: center; gap: 8px; padding: 10px 14px; border: 3px solid #2d2b3d; border-radius: 11px; background: #dcecf8; font-size: 1rem; font-weight: 900; }
.office-sign span { width: 24px; height: 24px; color: #2d526c; }
.pepe { position: relative; z-index: 2; display: grid; justify-items: center; margin-bottom: 17px; }
.pepe img { width: 280px; height: 280px; object-fit: contain; }
.actor-name { margin-top: -14px; font-size: 1.2rem; font-weight: 900; }
.arrival { position: absolute; top: 48px; left: -94px; display: flex; align-items: center; gap: 5px; color: #168b76; font-size: 0.78rem; font-weight: 900; white-space: nowrap; }
.arrival span { width: 25px; height: 25px; }
.platform { position: relative; z-index: 2; width: 455px; margin-bottom: 53px; border: 6px solid #2d2b3d; border-radius: 18px; background: #f8fbff; box-shadow: 0 18px 30px rgb(0 0 0 / 0.16); overflow: hidden; }
.platform-header { display: flex; align-items: center; gap: 8px; padding: 13px 16px; background: #253247; color: #fff; font-size: 0.9rem; font-weight: 900; }
.platform-header > span:first-child { width: 23px; height: 23px; color: #9ff3df; }
.status { display: flex; align-items: center; gap: 5px; margin-left: auto; color: #b9f5e5; font-size: 0.63rem; }
.status i { width: 8px; height: 8px; border-radius: 50%; background: #46d59e; }
.assistant-message { display: grid; grid-template-columns: 54px 1fr; gap: 12px; align-items: center; margin: 17px 18px 12px; padding: 13px; border: 3px solid #2d2b3d; border-radius: 11px; background: #fff4dc; }
.bot-icon { width: 36px; height: 36px; padding: 8px; border-radius: 8px; background: #253247; color: #9ff3df; }
.assistant-message strong { font-size: 0.91rem; }
.assistant-message p { margin: 3px 0 0; color: #8e3030; font-size: 0.8rem; font-weight: 900; }
.quota { margin: 0 18px; }
.quota-label { display: flex; justify-content: space-between; color: #516070; font-size: 0.72rem; font-weight: 800; }
.quota-label strong { color: #8e3030; }
.quota-track { height: 17px; margin-top: 7px; border: 3px solid #2d2b3d; border-radius: 999px; background: #dbe5ef; overflow: hidden; }
.quota-track span { display: block; width: 100%; height: 100%; background: linear-gradient(90deg, #f07a6a, #d85050); }
.usage-alert { display: flex; align-items: center; gap: 7px; margin: 14px 18px 18px; padding: 10px; border-radius: 8px; background: #ffe4e1; color: #8e3030; font-size: 0.72rem; font-weight: 900; }
.usage-alert span { width: 21px; height: 21px; }
</style>
