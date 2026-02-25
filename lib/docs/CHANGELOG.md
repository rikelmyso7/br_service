# Changelog — BR Service UI

## [Unreleased]

### Corrigido

#### `BRServiceDaemon` — Writes concorrentes no stdin (`daemon_service.dart`)
- **Problema:** `Future.wait([validateFile, getDetailedFileStats])` disparava dois `send()` simultâneos ao daemon. O `StreamSink` do `stdin` não suporta writes concorrentes, lançando `Bad state: StreamSink is bound to a stream`.
- **Causa:** Ambas as corrotinas atingiam `_process!.stdin.add()` antes da primeira flush concluir.
- **Correção:** Adicionado `_writeChain` — uma `Future` encadeada que serializa os writes ao stdin. Cada `send()` agenda seu write no final da cadeia via `.then()`, garantindo que apenas um write ocorra por vez. O `_responseQueue` (FIFO) já garantia o matching correto das respostas.

#### `FileRepositoryImpl.getDetailedFileStats` — Early-return destrutivo com `colunasObrigatorias` (`file_repository_impl.dart`)
- **Problema:** Quando o CLI retornava `colunas_obrigatorias.todas_presentes = false`, o método descartava todos os dados (`docPlanos`, `availableDocuments`, `availableDates`) e retornava estruturas vazias, mesmo com dados válidos disponíveis no response do daemon.
- **Sintoma:** `DocPlanos reconstruídos: 0`, `Available docs: []`, `Available dates: []` na tela de validação — apesar de todas as validações passarem.
- **Correção:** Removido o early-return. Quando colunas estão ausentes, apenas loga um warning e continua o processamento normal. Um campo `aviso` (não `erro`) é incluído no mapa de retorno para informar a UI sobre as colunas ausentes.

#### `FileRepositoryImpl.getDetailedFileStats` — Cast `count as int` com valores `num` (`file_repository_impl.dart`)
- **Problema:** O JSON do Python serializava contagens de `block_counts` como `double` em alguns casos (ex: `408.0`). O cast direto `count as int` lançava `TypeError`, que era silenciado pelo `catch` e retornava o mapa de erro com todos os dados zerados.
- **Sintoma:** Chave `erro` presente em `DetailedStats keys`, `invalidDocPlanos` ausente — confirmando que o bloco `catch` era acionado.
- **Correção:** Cast seguro com verificação de tipo: `if (count is int)` / `else if (count is num) count.toInt()`.

#### `FileRepositoryImpl.getDetailedFileStats` — Stack trace ausente no `catch` (`file_repository_impl.dart`)
- **Problema:** O `catch (e)` não capturava o stack trace, dificultando o diagnóstico de exceções silenciosas.
- **Correção:** Alterado para `catch (e, st)` com `log.severe(...\n$st)`.

#### `FileRepositoryImpl.swapAccountNumber` — `stderr` não capturado (`file_repository_impl.dart`)
- **Problema:** Usava `Process.start` + `await proc.exitCode`, descartando stdout e stderr. Em caso de falha (code=1), a exception não incluía o motivo do erro do CLI Python.
- **Correção:** Migrado para `Process.run` (síncrono), capturando stdout e stderr. A mensagem de exception agora inclui o conteúdo do stderr.

---

### Adicionado

#### Testes unitários — Flutter (`test/unit/`)
- **`processing_filters_test.dart`** (26 testes): cobre `ProcessingFilters` — conversão de datas CLI↔ISO, `availableDatesForSelectedDocuments`, disponibilidade cruzada de datas entre documentos, `totalSelectedRecords`, `getRecordCount`, `hasSelections`, `copyWith`; e `DocPlano` — equality por valor, hashCode, uso como chave de `Map`.
- **`models_test.dart`** (10 testes): cobre `FileStats`, `DocPlanoStat` (combination getter, hasData), `InvalidDocPlano` (toString, campos), `DocPlano` como chave de Map e elemento de Set.
- **`bloc_parsing_test.dart`** (13 testes): cobre `FileProcessorBloc` via `bloc_test` — transições de estado para `SelectFileEvent` (com/sem contas, erros em `loadExcelFile` e `getAllData`); parsing de `docPlanos`, `processingFilters` e `invalidDocPlanos` via `ProceedToValidationEvent`; suporte a `double` em `recordCountsByDocument`; `canProceed` true/false; `ResetEvent`; `ProceedToValidationEvent` sem arquivo carregado.
- **Dependências adicionadas ao `pubspec.yaml`:** `bloc_test: 10.0.0`, `mocktail: ^1.0.4`.

---

### Notas de Arquitetura

#### Daemon IPC — Serialização de Writes
O `BRServiceDaemon` usa um `Queue<Completer<String>>` (FIFO) para mapear respostas às requisições. Com o `_writeChain`, o protocolo é agora totalmente serializado do ponto de vista do Dart: writes enfileirados → daemon processa em ordem → respostas completam os completers em ordem. Múltiplos callers concorrentes via `Future.wait` são suportados corretamente.
