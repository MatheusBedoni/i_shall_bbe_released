# I Shall Be Released

App público de finanças pessoais em Flutter: **orçamento mensal** (evolução do
[protótipo Plano de Contas](https://planodecontas-matheusbedoni.vercel.app/)) com foco em
**investimentos** (carteira, cotações, proventos, metas e projeções).

Backend: **Firebase** (Authentication + Cloud Firestore). Arquitetura: **Clean Architecture**
por feature.

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
│   ├── di/injection_container.dart# Composition root (DI manual)
│   └── setup_required_page.dart   # Tela exibida sem Firebase configurado
├── core/                          # Compartilhado entre features
│   ├── error/                     # Failure (domínio) e Exception (data)
│   ├── usecase/                   # UseCase<T, Params>, SyncUseCase, NoParams
│   ├── utils/                     # Result<T>, Money, Percent
│   └── theme/
└── features/
    ├── auth/                      # Login/cadastro por e-mail (Firebase Auth)
    ├── budget/                    # Orçamento mensal (Firestore em tempo real)
    ├── portfolio/                 # Carteira de investimentos (domínio pronto)
    ├── goals/                     # Metas e projeções (domínio pronto)
    └── shell/                     # Navegação inferior, conta, placeholders
```

Cada feature segue `domain/` (entidades, contratos, use cases), `data/` (models,
datasources, repositórios) e `presentation/` (controllers, pages, widgets). `test/`
espelha `lib/` e usa fakes dos contratos, nunca o Firebase real.

## Regra de dependência

```
presentation ──► domain ◄── data
       │                      │
       └───────► core ◄───────┘
```

`domain` não conhece Flutter nem Firebase. `data` implementa os contratos do domínio e
traduz exceções em `Failure`s. `app/di` é o único lugar que instancia implementações.

## Modelo de dados (Firestore)

```
users/{uid}/settings/allocation_rule   { fixedExpensePct, investmentPct }
users/{uid}/budget_entries/{id}        { period: "2025-12", type, description, amount, createdAt }
users/{uid}/assets/{id}                (próxima iteração)
users/{uid}/transactions/{id}          (próxima iteração)
users/{uid}/dividends/{id}             (próxima iteração)
users/{uid}/goals/{id}                 (próxima iteração)
```

## Regras de negócio principais

- **Orçamento em cascata dinâmica** (como no protótipo): fixas = ganho × 33%;
  investimentos = (ganho − fixas *gastas*) × 33%; recorrentes = ganho − fixas gastas −
  investimentos realizados. Percentuais configuráveis. O que não for usado em fixas ou
  investimentos sobra automaticamente para recorrentes. Saldo final = ganho − tudo que foi
  lançado. Gasto diário = restante de recorrentes ÷ dias restantes no mês.
- **Posições da carteira**: preço médio ponderado incluindo taxas; vendas mantêm o preço médio
  e realizam lucro/prejuízo; proventos somam ao retorno total; ativos sem cotação valem o custo.
- **Projeção de metas**: juros compostos com aportes mensais, meses até a meta, valor
  projetado no prazo e aporte necessário para cumprir o prazo.

## Roadmap

- [x] Esqueleto Clean Architecture
- [x] Auth por e-mail/senha + recuperação de senha
- [x] Orçamento mensal completo (lançamentos, envelopes, copiar mês anterior, regra configurável)
- [x] Domínio de carteira (ativos, transações, proventos, posições) com testes
- [x] Domínio de metas (projeção com juros compostos) com testes
- [ ] Carteira: Firestore + telas (ativos, aportes, posição consolidada, alocação por classe)
- [ ] Cotações em tempo real via brapi.dev
- [ ] Proventos: lançamento e rendimento mensal
- [ ] Metas: Firestore + telas + gráfico de projeção
- [ ] Login com Google
- [ ] Gráficos de evolução (patrimônio, gastos por categoria)
