<template>
  <div class="coffee-scene">
    <div class="break-callout">
      <div class="i-carbon-cafe" aria-hidden="true" />
      <span>Cafetería</span>
    </div>

    <div class="carmen" aria-label="Susana se marcha con un café">
      <img src="/img/woman_icon.png" alt="Susana" />
      <div class="coffee-cup i-carbon-cafe" aria-hidden="true" />
      <div class="walking-arrow i-carbon-arrow-right" aria-hidden="true" />
    </div>

    <div class="workspace" aria-label="El asistente sigue trabajando sin supervisión">
      <div class="desk" />
      <div class="laptop">
        <div class="laptop-screen">
          <div class="window-bar"><span /><span /><span /></div>
          <div class="bot-row">
            <div class="bot-icon i-carbon-bot" aria-hidden="true" />
            <div>
              <strong>Claudex Assistant</strong>
              <p>Trabajando sin supervisión</p>
            </div>
          </div>
          <div class="chat-message user-message">
            Haz troubleshooting de por qué mi microservicio está fallando.
          </div>
          <div class="chat-message assistant-message">
            <span class="thinking">thinking...</span> Parece ser que hay un security group que limita el acceso a otra API. Déjame abrirlo.
          </div>
          <div class="terminal-command">
            <span>$</span> aws ec2 authorize-security-group-ingress --group-id sg-… --protocol all --cidr 0.0.0.0/0
          </div>
        </div>
        <div class="laptop-base" />
      </div>
      <div class="plant"><span /><span /><span /></div>
    </div>
  </div>
</template>

<style scoped>
.coffee-scene {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 88px;
  height: 480px;
  overflow: hidden;
  color: #1d2533;
}

.break-callout {
  position: absolute;
  top: 4px;
  left: 34px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 18px;
  border: 3px solid #2d2b3d;
  border-radius: 12px;
  background: #fff4dc;
  font-size: 1.2rem;
  font-weight: 900;
}

.break-callout > div { width: 28px; height: 28px; color: #a65e2e; }

.carmen { position: relative; display: grid; justify-items: center; margin-bottom: 36px; }
.carmen img { width: 260px; height: 260px; object-fit: contain; }
.coffee-cup { position: absolute; right: 16px; bottom: 62px; width: 56px; height: 56px; color: #a65e2e; }
.walking-arrow { position: absolute; right: -55px; top: 112px; width: 48px; height: 48px; color: #21b69b; }

.workspace { position: relative; z-index: 1; width: 475px; padding-bottom: 35px; }
.desk { position: absolute; right: -24px; bottom: 0; left: -24px; height: 42px; border: 5px solid #2d2b3d; border-radius: 16px 16px 4px 4px; background: #b98055; }
.laptop { position: relative; z-index: 1; width: 410px; margin: auto; }
.laptop-screen { padding: 18px 21px; border: 8px solid #2d2b3d; border-radius: 18px 18px 8px 8px; background: linear-gradient(135deg, #fff, #e7f8f4); box-shadow: 0 18px 28px rgb(0 0 0 / 0.16); }
.window-bar { display: flex; gap: 7px; margin-bottom: 14px; }
.window-bar span { width: 11px; height: 11px; border-radius: 50%; background: #ff6b6b; }
.window-bar span:nth-child(2) { background: #ffd166; }
.window-bar span:nth-child(3) { background: #06d6a0; }
.bot-row { display: grid; grid-template-columns: 50px 1fr; gap: 12px; align-items: center; padding-bottom: 12px; border-bottom: 2px solid #bed8d2; }
.bot-icon { width: 48px; height: 48px; padding: 8px; border-radius: 10px; background: #253247; color: #9ff3df; }
.bot-row strong { font-size: 1.05rem; }
.bot-row p { margin: 3px 0 0; color: #516070; font-size: 0.78rem; font-weight: 700; }
.chat-message { margin-top: 9px; padding: 8px 10px; border-radius: 8px; font-size: 0.68rem; line-height: 1.25; font-weight: 700; }
.user-message { margin-left: 34px; background: #dcecf8; color: #2d526c; }
.assistant-message { margin-right: 14px; background: #edf7f3; color: #2e4d44; }
.thinking { color: #d6801e; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 900; }
.terminal-command { margin-top: 8px; padding: 8px; border-radius: 6px; background: #1d2533; color: #dff8ef; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.55rem; line-height: 1.35; overflow-wrap: anywhere; }
.terminal-command span { color: #ff7b7b; font-weight: 900; }
.laptop-base { width: 456px; height: 22px; margin-left: -23px; border: 7px solid #2d2b3d; border-top: 0; border-radius: 0 0 22px 22px; background: #cfd7e3; }
.plant { position: absolute; right: 3px; bottom: 38px; z-index: 2; width: 52px; height: 49px; border-radius: 5px 5px 18px 18px; background: #da8a51; }
.plant span { position: absolute; bottom: 37px; width: 25px; height: 48px; border-radius: 100% 0 100% 0; background: #4d9b73; transform-origin: bottom center; }
.plant span:nth-child(1) { left: 6px; transform: rotate(-40deg); }
.plant span:nth-child(2) { left: 17px; transform: rotate(5deg); }
.plant span:nth-child(3) { left: 27px; transform: rotate(45deg); }
</style>
