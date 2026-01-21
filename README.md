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
- **Isolates**: Processamento pesado em threads separadas

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

| Etapa | Descrição |
|-------|-----------|
| **Início** | Tela inicial com drag-and-drop ou seleção de arquivo |
| **Carregar** | Leitura do Excel + análise CLI em paralelo |
| **Preview** | Visualização dos dados e seleção de contas |
| **Validação** | Verifica estrutura obrigatória (Layout, colunas, documentos) |
| **Filtros** | Seleção de documentos e datas para processar |
| **Processar** | CLI extrai dados com progresso em tempo real |
| **Concluído** | Arquivos gerados, botão para abrir pasta de saída |

### Estados do BLoC

```dart
InitialState → FileLoadingState → FilePreviewState → ValidationState
    ↑                                                      │
    │                                                      ▼
    └──────────────── ErrorState ←──── ProcessingState → CompletedState
```

## Dependências Principais

| Pacote                  | Uso                        |
| ----------------------- | -------------------------- |
| `flutter_bloc`        | Gerenciamento de estado    |
| `spreadsheet_decoder` | Leitura de arquivos Excel  |
| `file_picker`         | Seleção de arquivos      |
| `rxdart`              | Streams reativos           |
| `window_manager`      | Controle da janela desktop |
| `desktop_drop`        | Drag & drop de arquivos    |

## CLI

O processamento dos dados é feito pelo executável `br_service_cli.exe` que suporta os seguintes comandos:

```bash
# Análise completa (opções + datas + contas)
br_service_cli --input arquivo.xlsx --get-all --quiet

# Apenas opções de documentos/planos
br_service_cli --input arquivo.xlsx --get-options --quiet

# Processamento com filtros
br_service_cli --input arquivo.xlsx --output ./saida --documentos "DOC1,DOC2" --datas "01/01/2024,02/01/2024"
```

## Versão

Versão atual: **1.4.4**

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
