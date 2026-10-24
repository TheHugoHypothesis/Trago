# Trago — Android (MVP local)

Cliente Android **Kotlin/Jetpack Compose** da primeira fatia local PF/PJ do
Trago. É um MVP demonstrável com **dados sintéticos**: nenhum pagamento,
escrow, importação, KYC ou cálculo fiscal real acontece. A interface não
promete conformidade aduaneira nem entrega real.

O app consome o contrato congelado `contracts/http/openapi.json` (não alterado
por este componente) e conecta em uma API real; **não há sucesso fictício** —
falha de rede vira estado de erro na UI.

## O que ele faz

- **Início** — configuração da conexão (URL base + token demo) e seleção do
  contexto **PF/PJ** (`GET /v1/me/accounts`). A troca de conta limpa o estado
  privado (viagem/rascunho selecionado).
- **Buscar** — busca de viagens fictícias por origem/destino/data
  (`GET /v1/trips`), com estados de carregando, vazio e erro.
- **Rascunho** — criação de solicitação privada `DRAFT`
  (`POST /v1/purchase-requests`) com validação local e **chave de
  idempotência** reutilizada em reenvios idênticos.
- **Pedidos** — listagem das solicitações do contexto selecionado
  (`GET /v1/purchase-requests?accountId=…`), isoladas por conta PF/PJ.

## Identidades demo (somente modo demo explícito)

| Token Bearer | Papel |
| --- | --- |
| `dev:buyer` | Comprador PF + representante PJ ativo (padrão) |
| `dev:traveler` | Viajante fictício |
| `dev:outsider` | Outra PF sem acesso aos rascunhos alheios |
| `dev:revoked` | Representante PJ revogado |

Produção rejeita esse mecanismo; é uma simplificação autorizada para a fatia
local, não autenticação produtiva.

## Requisitos de build

- JDK 17
- Android SDK com `platforms;android-35` e `build-tools;35.0.0`
  (o `local.properties`/`ANDROID_HOME` precisa apontar para o SDK)
- Rede para baixar dependências (Maven Central / Google Maven)

> **Locale:** se o caminho do checkout tiver caracteres não-ASCII (ex.
> `6º Semestre`), o JVM precisa de um locale UTF-8. O `gradlew` já tenta
> forçar `LC_ALL=C.UTF-8` automaticamente; se isso não bastar, rode com
> `LC_ALL=C.UTF-8 bash android/gradlew …`.

## Como compilar e testar

Na raiz do repositório:

```bash
bash apps/android/gradlew -p apps/android assembleDebug testDebugUnitTest
```

Saídas:

- APK debug: `apps/android/app/build/outputs/apk/debug/app-debug.apk`
- Relatório de testes: `apps/android/app/build/reports/tests/testDebugUnitTest/index.html`

Executar no emulador/dispositivo (a API deve estar acessível):

```bash
adb install -r apps/android/app/build/outputs/apk/debug/app-debug.apk
```

O primeiro build não depende de emulador/KVM.

## Configuração da API

- **Padrão de build:** `http://10.0.2.2:3001` (`buildConfigField API_BASE_URL`
  em `app/build.gradle.kts`) — `10.0.2.2` alcança o host a partir do emulador
  Android.
- **Em tempo de execução:** tela Início → *Configurar* (URL base + token demo),
  persistido localmente via `SharedPreferences`.
- O manifesto habilita tráfego cleartext apenas para permitir `http://` no
  ambiente de desenvolvimento local.

## Estrutura

```text
app/src/main/java/com/trago/app/
├── TragoApplication.kt        # container manual (settings + repository)
├── MainActivity.kt
├── data/
│   ├── api/                   # TragoApi (Retrofit) + ApiClient
│   ├── model/                 # DTOs espelhando o OpenAPI congelado
│   ├── AppSettings.kt         # URL/token persistidos
│   ├── AppState.kt            # sessão demo + contexto selecionado
│   └── TragoRepository.kt     # fonte única (interface + impl. padrão)
└── ui/
    ├── theme/                 # paleta derivada de InitialAssets/Design.png
    ├── navigation/            # home / busca / rascunho / pedidos
    ├── home|search|draft|orders/  # telas + ViewModels
    └── components/            # componentes compartilhados
```

## Testes

Testes JVM (`kotlinx-coroutines-test`) de estado e isolamento de contexto:

- `DraftViewModelTest` — envio válido encaminha conta/viagem/produto e chave de
  idempotência; falha de rede **não** vira sucesso e reenvio reutiliza a chave;
  formulário inválido não chama a API.
- `OrdersViewModelTest` — trocar de conta PF→PJ recarrega pedidos no novo
  contexto privado.

## Limites explícitos

- Nenhum pagamento/escrow/importação/transporte reais; dados 100% sintéticos.
- O backend é autoritativo para autorização, idempotência e validação.
- Cliente Kotlin gerado manualmente a partir do contrato congelado; endpoints
  não presentes no OpenAPI não são inventados.
- Sem dependência de emulador/KVM para build; instrumentação não é necessária
  para o primeiro build.
