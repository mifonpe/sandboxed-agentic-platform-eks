---
layout: section
number: "03"
---

# Arquitectura

Cómo lo montamos sobre EKS

---

# Arquitectura
- Necesitamos
    - Ejecución aislada de agentes 
    - Ejecución aislada de código generado por agente
    - Entornos efímeros
    - Control de acceso granular para el uso de herramientas (MCP)
    - Control de acceso granular a modelos
    - Controles de red
    - Observabilidad

---

# La Arquitectura

<img src="/img/arch.png" style="max-height: 430px; margin: 0 auto;" />

---

# La Arquitectura

- [Agent Sandbox](https://agent-sandbox.sigs.k8s.io/)
- [Kata containers](https://katacontainers.io/)
- [Agent Gateway](https://agentgateway.dev/)
- [Coder](https://github.com/coder/coder)
- [FastMCP](https://gofastmcp.com/getting-started/welcome)


---

# Agent Sandbox

Entorno de ejecución aislado en Kubernetes para agentes que generan y ejecutan código

- Proyecto de **Kubernetes SIGs**
- **Basado en CRDs**
    - SandboxTemplate
    - SandboxClaim
- **Backends**
    - gVisor 
    - Kata Containers
- **SDKs**
    - Python 
    - Go
- Sandboxes **efímeros o persistentes**

<div class="text-sm opacity-70 mt-6">

[agent-sandbox.sigs.k8s.io](https://agent-sandbox.sigs.k8s.io/) · [github.com/kubernetes-sigs/agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox)

</div>


<ToolLogo src="/img/logos/agent-sandbox.svg" alt="Agent Sandbox" />

<!--

Proyecto joven de Kubernetes SIGs. Lo valioso: estandariza la API del sandbox
y el aislamiento lo eliges tú (gVisor, Kata...). No te casas con una tecnología.

-->

---

# Kata Containers

Runtime de contenedores que construye **máquinas virtuales ligeras** integradas en el ecosistema de contenedores

- **Seguridad**: kernel dedicado por pod, aislamiento de red, I/O y memoria vía virtualización
- **Compatibilidad**: formato OCI y CRI de Kubernetes, es un RuntimeClass
- **Rendimiento**: velocidad de contenedor sin el peso de una VM clásica
- **Simplicidad**: sin contenedores anidados, interfaces estándar
- **Hipervisores**: QEMU, Cloud Hypervisor, Firecracker 

<div class="text-sm opacity-70 mt-6">

[katacontainers.io](https://katacontainers.io/) · [github.com/kata-containers](https://github.com/kata-containers)

</div>

<ToolLogo src="/img/logos/kata.webp" alt="Kata Containers" />

<!--

Un contenedor normal comparte kernel con el host. Kata le da a cada pod su propio
kernel dentro de una microVM: frontera de virtualización, no solo namespaces y cgroups.
Nació en 2017 de la fusión de Intel Clear Containers y Hyper.sh runV.

-->

---

# Agent Gateway

Gateway HTTP/gRPC que maneja tráfico de aplicación y **protocolos AI-native**

- **Protocolos**
    - MCP
    - A2A
    - LLM Routing
- **Seguridad**: JWT/OIDC, API keys, mTLS, autorización por políticas
- **Gobierno de IA**: políticas de acceso a herramientas, guardrails, rate-limitting
- **Control de Costes**
- **Observabilidad**
    - OpenTelemetry
    - Prometheus
    - métricas de uso de tokens

<div class="text-sm opacity-70 mt-6">

[agentgateway.dev](https://agentgateway.dev/) · [github.com/agentgateway/agentgateway](https://github.com/agentgateway/agentgateway)

</div>

<ToolLogo src="/img/logos/agentgateway.svg" alt="Agent Gateway" />

<!--

La gracia: un único data plane para tráfico normal y para MCP/A2A/LLM.
No necesitas un gateway para la app y otro para los agentes.

-->

---

# Aislando los workloads

- Sandbox
    - Pod aislado en una micro VM (Nested KVM)
    - SandboxTemplate
    - Sandboxes Creados por el MCP Server (SandboxClaim)
- Network Policies
    - Restricciones de tráfico saliente y entrante

<img src="/img/arch-simple.png" class="absolute bottom-8 left-1/2 -translate-x-1/2" style="max-height: 220px;" />

---

# Autenticación

- JWT tokens generados por el IdP
    - Control Granular de acceso a Modelos
    - Control Granular de acceso a herramientas de MCP

<img src="/img/arch-simple.png" class="absolute bottom-8 left-1/2 -translate-x-1/2" style="max-height: 220px;" />


---

# La Arquitectura

<img src="/img/arch.png" style="max-height: 430px; margin: 0 auto;" />


---
layout: section
---

# Demo

Demo time ;)
