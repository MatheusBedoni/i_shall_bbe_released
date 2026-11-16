# I Shall Be Released

App público de finanças pessoais em Flutter: **orçamento mensal** (evolução do
[protótipo Plano de Contas](https://planodecontas-matheusbedoni.vercel.app/)) com foco em
**investimentos** (carteira, cotações, proventos, metas e projeções).

Backend: **Firebase** (Authentication + Cloud Firestore). Dados **offline-first**: o app lê e
escreve num banco local (sembast) e sincroniza com o Firestore em segundo plano. Arquitetura:
**Clean Architecture** por feature.

## Configuração do Firebase (obrigatória para rodar)

1. Crie um projeto em <https://console.firebase.google.com>.
2. Ative **Authentication → E-mail/senha** e crie um banco **Cloud Firestore**.
3. Na raiz do projeto:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Isso substitui o placeholder `lib/firebase_options.dart` e registra os apps Android/iOS/Web.
4. Publique as regras de segurança (ou cole o conteúdo de `firestore.rules` no console):

   ```bash
   firebase deploy --only firestore:rules
   ```

Enquanto o Firebase não estiver configurado, o app abre uma tela explicando o passo a passo
em vez de quebrar.

## Cotações reais (brapi.dev)

A carteira busca cotações de ações, FIIs, ETFs e BDRs na [brapi.dev](https://brapi.dev).
Sem token só os tickers de teste respondem (PETR4, VALE3, MGLU3, ITUB4, HGLG11, MXRF11).
Para cotar a carteira inteira, crie uma chave gratuita em <https://brapi.dev/dashboard>
(15 mil requisições/mês, 1 ticker por chamada, atraso de ~30 min) e coloque no `.env`
da raiz do projeto (copie de `.env.example`; o `.env` é ignorado pelo git):

```
BRAPI_TOKEN=sua_chave
```

Alternativa em build time, que tem precedência sobre o `.env`:

```bash
flutter run --dart-define=BRAPI_TOKEN=sua_chave
```

Atenção: o `.env` é empacotado como asset, então a chave vai dentro do binário (APK/web).
Isso é aceitável para uso pessoal; para um app público em produção, o ideal é um proxy no
backend (ex.: Cloud Function) que guarde a chave.

A busca de tickers no cadastro de ativos (`/api/v2/tickers?search=`) não exige token.
Ativos sem cotação (renda fixa, cripto, outros) valem o custo de aquisição.

## Banco local e sincronização

O app funciona sem internet. Toda tela lê de um banco local por usuário
([sembast](https://pub.dev/packages/sembast): NoSQL puro Dart, arquivo em mobile/desktop,
IndexedDB na web) e toda escrita é gravada nele **e** numa fila persistente (*outbox*), na
mesma transação. O `SyncEngine` (`lib/core/data/sync/`) mantém o espelho com o Firestore:

- **Push**: drena a outbox em ordem para `users/{uid}/...`. Sem rede, o envio expira e o motor
  entra em `offline`, tentando de novo com backoff (1s → 60s) e assim que o Firestore volta a
  responder. A outbox é compactada por documento (só a última operação de cada id).
- **Pull**: ouve cada coleção remota e reconcilia o store local a cada snapshot (grava novos e
  alterados, apaga os que sumiram). Documentos com escrita local pendente nunca são
  sobrescritos pelo remoto.
- **Conflitos**: *last-write-wins* por documento, usando o campo `updatedAt` gravado em toda
  escrita. Documentos antigos sem o campo contam como os mais antigos.
- **Ids** são gerados no cliente (mesmo formato do Firestore), então criar offline não precisa
  de ida ao servidor.
- O cache offline do próprio Firestore fica **desligado**: a outbox é a única fila de escrita.
- A aba **Conta** mostra o estado (sincronizado / pendências / sem conexão / erro) e tem um
  botão "Sincronizar agora".

Uma sessão (`UserSession`, em `app/di`) abre o banco local e liga o sync no login e fecha tudo
no logout. O arquivo local fica no aparelho (`local_db/user_<uid>.db`), então relogar é
instantâneo.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Estrutura

```
lib/
├── main.dart                      # Inicializa Firebase e sobe o App
├── firebase_options.dart          # Gerado pelo flutterfire configure
├── app/
│   ├── app.dart                   # MaterialApp + AuthGate + shell com abas
│   ├── di/injection_container.dart# Composition root (DI manual) + UserSession
│   └── setup_required_page.dart   # Tela exibida sem Firebase configurado
├── core/                          # Compartilhado entre features
│   ├── data/
│   │   ├── local/                 # LocalDatabase (sembast) e abertura por plataforma
│   │   └── sync/                  # Outbox, SyncedCollection, RemoteStore, SyncEngine
│   ├── error/                     # Failure (domínio) e Exception (data)
│   ├── usecase/                   # UseCase<T, Params>, SyncUseCase, NoParams
│   ├── utils/                     # Result<T>, Money, Percent
│   └── theme/
└── features/
    ├── auth/                      # Login/cadastro por e-mail (Firebase Auth)
    ├── budget/                    # Orçamento mensal (Firestore em tempo real)
    ├── portfolio/                 # Carteira: ativos, aportes, proventos, cotações (brapi)
    ├── goals/                     # Metas com projeção e vínculo com ativos da carteira
    └── shell/                     # Navegação inferior e conta
```

Cada feature segue `domain/` (entidades, contratos, use cases), `data/` (models,
datasources **locais** sobre `SyncedCollection`, repositórios) e `presentation/` (controllers,
pages, widgets). `test/` espelha `lib/` e usa fakes dos contratos e o sembast em memória,
nunca o Firebase real.

## Regra de dependência

```
presentation ──► domain ◄── data
       │                      │
       └───────► core ◄───────┘
```

`domain` não conhece Flutter nem Firebase. `data` implementa os contratos do domínio e
traduz exceções em `Failure`s. `app/di` é o único lugar que instancia implementações.

## Modelo de dados (Firestore = banco local)

```
users/{uid}/settings/allocation_rule   { fixedExpensePct, investmentPct, updatedAt }
users/{uid}/budget_entries/{id}        { period: "2025-12", type, description, amount, createdAt, updatedAt }
users/{uid}/assets/{id}                { ticker, name, assetClass, currency, updatedAt }
users/{uid}/transactions/{id}          { assetId, type: buy|sell, quantity, unitPrice, fees, date, updatedAt }
users/{uid}/dividends/{id}             { assetId, type, amount, date, updatedAt }
users/{uid}/goals/{id}                 { name, targetAmount, currentAmount, monthlyContribution, annualRate, deadline, linkedAssetIds: [assetId], updatedAt }
```

Cada coleção acima é um *store* do banco local com os mesmos ids; o store `_outbox` guarda as
escritas pendentes.

## Regras de negócio principais

- **Orçamento em cascata dinâmica** (como no protótipo): fixas = ganho × 33%;
  investimentos = (ganho − fixas *gastas*) × 33%; recorrentes = ganho − fixas gastas −
  investimentos realizados. Percentuais configuráveis. O que não for usado em fixas ou
  investimentos sobra automaticamente para recorrentes. Saldo final = ganho − tudo que foi
  lançado. Gasto diário = restante de recorrentes ÷ dias restantes no mês.
- **Posições da carteira**: preço médio ponderado incluindo taxas; vendas mantêm o preço médio
  e realizam lucro/prejuízo; proventos somam ao retorno total; ativos sem cotação valem o custo.
  Para renda fixa e outros ativos sem cotação o formulário pede só o valor e grava
  `quantity = valor, unitPrice = 1`, o que permite resgates parciais.
- **Carteira ↔ orçamento**: todo aporte (compra) registrado na carteira entra automaticamente
  no envelope de **Investimentos** do mês da sua data, junto com os lançamentos avulsos. O
  orçamento também permite registrar o aporte direto (escolhendo um ativo já cadastrado), e
  editar/excluir ali reflete na carteira. Vendas não entram no orçamento.
- **Projeção de metas**: juros compostos com aportes mensais, meses até a meta, valor
  projetado no prazo e aporte necessário para cumprir o prazo.
- **Metas ↔ carteira**: uma meta pode vincular ativos da carteira (`linkedAssetIds`). O saldo
  da meta passa a ser `currentAmount` (dinheiro fora da carteira) + valor de mercado das
  posições vinculadas, então aportes e cotações movem o progresso sozinhos. A projeção parte
  desse saldo total. Ativos apagados da carteira são ignorados no cálculo e sinalizados na
  tela para o usuário desvincular.

## Roadmap

- [x] Esqueleto Clean Architecture
- [x] Auth por e-mail/senha + recuperação de senha
- [x] Orçamento mensal completo (lançamentos, envelopes, copiar mês anterior, regra configurável)
- [x] Domínio de carteira (ativos, transações, proventos, posições) com testes
- [x] Domínio de metas (projeção com juros compostos) com testes
- [x] Carteira: Firestore + telas (ativos, aportes, posição consolidada, alocação por classe)
- [x] Cotações reais via brapi.dev + busca de tickers no cadastro
- [x] Proventos por ativo
- [x] Aportes da carteira integrados ao envelope de investimentos do orçamento
- [x] Banco local (sembast) com sincronização offline-first para o Firestore
- [ ] Rendimento mensal de proventos / evolução do patrimônio
- [ ] Valor atual manual para renda fixa (hoje vale o custo)
- [x] Metas: banco local/Firestore, telas, gráfico de projeção e vínculo com ativos da carteira
- [ ] Login com Google
- [ ] Gráficos de evolução (patrimônio, gastos por categoria)
