# BR Service UI

Aplicativo desktop Flutter para processamento e extração de dados de planilhas Excel.

## Sobre

O BR Service UI é uma ferramenta que permite:

- Carregar e visualizar planilhas Excel (aba "Layout")
- Validar estrutura e dados do arquivo
- Filtrar por documentos e datas
- Processar e extrair dados para arquivos de saída
- Verificar contas ativas/inativas

## Requisitos

- Flutter SDK ^3.7.0
- Windows 10/11 (suporte principal)
- CLI executável (`br_service_cli.exe`)

> **Importante:** O executável CLI não está incluído no repositório devido ao tamanho.
> Coloque o arquivo `br_service_cli.exe` (Windows) ou `br_service_cli` (Linux/macOS) na pasta `lib/assets/` antes de executar.

## Instalação

```bash
# Clone o repositório
git clone <repo-url>
cd br_service

# Instale as dependências
flutter pub get

# Execute em modo debug
flutter run -d windows

# Ou compile para release
flutter build windows
```

## Estrutura do Projeto

```
lib/
├── assets/              # Recursos (CLI executável, imagens)
├── bloc/                # Gerenciamento de estado (BLoC pattern)
│   ├── events/          # Eventos do BLoC
│   └── states/          # Estados do BLoC
├── components/          # Componentes de UI por tela
├── models/              # Modelos de dados
├── pages/               # Páginas da aplicação
├── repository/          # Repositórios (acesso a dados/CLI)
├── services/            # Serviços (isolates, updates)
├── utils/               # Utilitários
└── widgets/             # Widgets reutilizáveis
```

## Arquitetura

- **BLoC Pattern**: Gerenciamento de estado com `flutter_bloc`
- **Repository Pattern**: Abstração do acesso ao CLI
- **Daemon IPC**: Processo CLI persistente via stdin/stdout, eliminando o cold start do PyInstaller (~1-3s por invocação)

## Fluxo da Aplicação

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Início    │────→│  Carregar   │────→│   Preview   │
│             │     │   Arquivo   │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                    ┌─────────────┐     ┌──────▼──────┐
                    │  Processar  │←────│  Validação  │
                    │             │     │  + Filtros  │
                    └─────────────┘     └─────────────┘
                           │
                    ┌──────▼──────┐
                    │  Concluído  │
                    └─────────────┘
```

| Etapa                 | Descrição                                                                                         |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| **Início**     | Tela inicial com drag-and-drop ou seleção de arquivo                                              |
| **Carregar**    | Preview da planilha (`--get-preview`) + análise completa (`--get-all`) via daemon, em paralelo |
| **Preview**     | Visualização dos dados e seleção de contas ativas/inativas                                      |
| **Validação** | Verifica estrutura obrigatória (colunas, documentos, datas) via daemon                             |
| **Filtros**     | Seleção de documentos e datas para processar                                                      |
| **Processar**   | CLI extrai dados com progresso em tempo real (eventos NDJSON)                                       |
| **Concluído**  | Arquivos gerados, botão para abrir pasta de saída                                                 |

### Daemon IPC — Serialização de Writes

O `BRServiceDaemon` serializa todos os writes ao `stdin` do processo via `_writeChain` (uma `Future` encadeada), evitando o erro `Bad state: StreamSink is bound to a stream` quando múltiplas chamadas concorrentes (ex: `Future.wait`) tentam escrever simultaneamente. As respostas são emparelhadas com os callers via `Queue<Completer<String>>` (FIFO).

### Estados do BLoC

```dart
InitialState → FileLoadingState → FilePreviewState → ValidationState
    ↑                                                      │
    │                                                      ▼
    └──────────────── ErrorState ←──── ProcessingState → CompletedState
```

## Dependências Principais

| Pacote             | Uso                                       |
| ------------------ | ----------------------------------------- |
| `flutter_bloc`   | Gerenciamento de estado                   |
| `file_picker`    | Seleção de arquivos                     |
| `rxdart`         | Streams reativos                          |
| `window_manager` | Controle da janela desktop                |
| `desktop_drop`   | Drag & drop de arquivos                   |
| `logging`        | Logs estruturados (visíveis no DevTools) |

> `spreadsheet_decoder` foi removido — a leitura da planilha é feita pelo daemon CLI via `--get-preview`.

## CLI e Daemon

O processamento dos dados é feito pelo executável `br_service_cli.exe`. A UI inicia o processo em **modo daemon** no startup, eliminando o cold start do PyInstaller:

```bash
# Modo daemon (iniciado automaticamente pela UI no startup)
br_service_cli.exe --daemon
# Aguarda DAEMON_READY no stderr, depois aceita comandos JSON via stdin

# Análise completa (opções + datas + contas)
br_service_cli.exe --input arquivo.xlsx --get-all --quiet

# Preview da planilha para exibição na UI
br_service_cli.exe --input arquivo.xlsx --get-preview --quiet

# Processamento com filtros
br_service_cli.exe --input arquivo.xlsx --output ./saida --documentos "DOC1,DOC2" --datas "01/01/2024,02/01/2024"
```

### Protocolo Daemon (stdin/stdout NDJSON)

A UI se comunica com o daemon via JSON linha a linha:

```
→ {"cmd": "get-all",     "input": "C:\\arquivo.xlsx"}
← {"documentos": [...], "planos_por_documento": {...}, "datas": [...], ...}

→ {"cmd": "get-preview", "input": "C:\\arquivo.xlsx"}
← {"headers": [...], "rows": [[...]]}
```

O executável é extraído automaticamente dos assets em `%TEMP%` na primeira execução e reutilizado nas subsequentes. Erros de texto no app são **selecionáveis** para cópia.

## Versão

Versão atual: **1.5.1**

Veja o histórico completo de alterações em [docs/CHANGELOG.md](docs/CHANGELOG.md).

## Build

```bash
# Windows Release
flutter build windows --release

# O executável estará em:
# build/windows/x64/runner/Release/
```

## Licença

Este projeto é disponibilizado apenas para **fins de demonstração e portfólio**.

- Visualização e estudo do código são permitidos
- **Proibida** a cópia, redistribuição ou uso comercial sem autorização
- **Proibido** utilizar este código em outros projetos sem permissão

© 2025 - Todos os direitos reservados.
