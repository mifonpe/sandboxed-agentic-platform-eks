---
layout: section
number: "04"
---

# Conclusiones

Lo que nos llevamos

---

# Conclusiones

- **Control granular de acceso**
  - Acceso a Herramientas
  - Acceso a modelos
- **Separación entre identidad de agente y usuario**
  - IdP/JWT
  -  OBO
- **Trata al agente y su código como workload no confiable**
  - Sandboxes y control de tráfico
  - Entornos efímeros
- **Observabilidad**
  - Métricas, Trazas, Uso de herramientas
- **MCP/Agent Gateways**
  - Mucho más que routing!

---

# Expandiendo la arquitectura

- [Repositorio](https://github.com/mifonpe/sandboxed-agentic-platform-eks)
- **[Implementando OBO en AgentGateway](https://agentgateway.dev/blog/2026-07-12-agentgateway-token-exchange-jwt-assertion-entra-obo/)**
- **[Integración de IdP en AgentGateway](https://agentgateway.dev/docs/standalone/latest/integrations/auth/)**
  - Okta, Entra, KeyCloak, Oauth Proxy
- **Observabilidad**
  - [OTel Stack](https://agentgateway.dev/docs/kubernetes/latest/documentation/observability/otel-stack/)
  - [Integración con Langfuse](https://agentgateway.dev/docs/kubernetes/latest/integrations/llm/observability/langfuse/)

<div class="qr-card absolute bottom-8 right-8">
  <img src="/img/qrs/repo.png" alt="Repositorio QR" />
  <div class="qr-name">Repo</div>
</div>

<style scoped>
.qr-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 0.7rem;
  border-radius: 0.9rem;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 6px 20px rgba(16, 17, 32, 0.12);
}
.qr-card img {
  width: 100%;
  max-width: 160px;
  aspect-ratio: 1 / 1;
  object-fit: contain;
  border-radius: 0.5rem;
}
.qr-name {
  font-size: 1.05rem;
  font-weight: 600;
  color: #101120;
}
</style>

---
layout: section
---

# ¿Preguntas?

Gracias :)

---

# Ayúdanos a hacernos influencers en Linkedin para dejar de trabajar

<div class="qr-grid">
  <div class="qr-card">
    <img src="/img/qrs/phontee.png" alt="Miguel F. LinkedIn QR" />
    <div class="qr-name">Miguel F.</div>
  </div>
  <div class="qr-card">
    <img src="/img/qrs/alberto-r.png" alt="Alberto R. LinkedIn QR" />
    <div class="qr-name">Alberto R.</div>
  </div>
</div>

<div class="qr-footer">Contáctanos en Linkedin</div>

<style scoped>
.qr-grid {
  display: flex;
  flex-direction: row;
  justify-content: center;
  gap: 1.75rem;
  margin-top: 2.5rem;
}
.qr-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.9rem;
  padding: 1.1rem;
  border-radius: 0.9rem;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 6px 20px rgba(16, 17, 32, 0.12);
}
.qr-card img {
  width: 100%;
  max-width: 190px;
  aspect-ratio: 1 / 1;
  object-fit: contain;
  border-radius: 0.5rem;
}
.qr-name {
  font-size: 1.15rem;
  font-weight: 600;
  color: #101120;
}
.qr-footer {
  margin-top: 2.5rem;
  text-align: center;
  font-size: 1.05rem;
  opacity: 0.7;
}
</style>
