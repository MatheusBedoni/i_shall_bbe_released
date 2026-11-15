# i_shall_be_released

Aplicação Flutter organizada em **Clean Architecture**, com separação por feature.

## Estrutura

```
lib/
├── main.dart                    # Ponto de entrada: só chama runApp(App())
├── app/                         # Composição da aplicação
│   ├── app.dart                 # MaterialApp (tema, rotas)
│   ├── di/injection_container.dart   # Composition root (injeção de dependências)
│   └── router/                  # Nomes de rota e onGenerateRoute
├── core/                        # Código compartilhado entre features
│   ├── error/                   # Failure (domínio) e Exception (data)
│   ├── usecase/                 # Contrato UseCase<T, Params> e NoParams
│   ├── utils/result.dart        # Result<T> = Success | Error (sem pacotes externos)
│   └── theme/                   # Tema global
└── features/
    └── home/                    # Uma pasta por feature
        ├── domain/              # Regras de negócio (Dart puro, sem Flutter)
        │   ├── entities/
        │   ├── repositories/    # Interfaces (contratos)
        │   └── usecases/
        ├── data/                # Implementação de acesso a dados
        │   ├── datasources/     # Remoto / local; lançam Exceptions
        │   ├── models/          # DTOs com fromJson/toJson e toEntity()
        │   └── repositories/    # Implementam os contratos; convertem Exception -> Failure
        └── presentation/        # UI e gerenciamento de estado
            ├── controllers/     # ChangeNotifier + estado selado
            ├── pages/
            └── widgets/

test/                            # Espelha a estrutura de lib/
```

## Regra de dependência

As dependências apontam sempre **para dentro**:

```
presentation ──► domain ◄── data
       │                      │
       └───────► core ◄───────┘
```

- `domain` não importa nada de `data`, `presentation` ou Flutter.
- `data` depende de `domain` (implementa seus contratos) e de `core`.
- `presentation` depende apenas de `domain` (use cases) e de `core`.
- `app/di` é o único lugar que conhece implementações concretas.

## Fluxo de uma chamada

1. `HomePage` chama `HomeController.loadGreeting()`.
2. O controller executa o use case `GetGreeting`.
3. O use case chama `HomeRepository.getGreeting()` (interface).
4. `HomeRepositoryImpl` chama o `HomeRemoteDataSource`, que devolve um `GreetingModel` ou lança `ServerException`.
5. O repositório converte o model em `Greeting` (entidade) e a exceção em `ServerFailure`, devolvendo `Result<Greeting>`.
6. O controller mapeia o `Result` para um `HomeState` e a UI reage.

## Como adicionar uma feature

1. Crie `lib/features/<nome>/{domain,data,presentation}`.
2. Comece pelo `domain`: entidade, interface do repositório e use cases.
3. Implemente `data`: model, datasource e `RepositoryImpl`.
4. Crie o controller e as páginas em `presentation`.
5. Registre as dependências em `app/di/injection_container.dart` e a rota em `app/router/`.
6. Espelhe a estrutura em `test/` e escreva testes com fakes das interfaces.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Evoluções sugeridas

- Trocar o `InjectionContainer` manual por `get_it` ou `riverpod`.
- Trocar `ChangeNotifier` por `flutter_bloc` se o estado crescer.
- Substituir o `HomeRemoteDataSourceImpl` de exemplo por chamadas HTTP (`dio`/`http`).
