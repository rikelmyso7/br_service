# Fluxo Completo da Aplicação BR Service

Este documento descreve o funcionamento completo da aplicação `br_service`, uma ferramenta de desktop construída com Flutter para processar arquivos Excel (.xlsx/.xls) e gerar arquivos BR através de um CLI Python empacotado.

## Arquitetura Detalhada

A aplicação é estruturada em camadas bem definidas:

### 1. **Interface do Usuário (Frontend)**
- **Framework:** Flutter (versão 3.7.0+)
- **Layout:** Interface desktop com sidebar verde e área de conteúdo central
- **Componentes:** Widgets especializados para cada estado da aplicação
- **Responsabilidade:** Interação com usuário, exibição de dados e feedback visual

### 2. **Gerenciamento de Estado (Business Logic)**
- **Padrão:** BLoC (Business Logic Component) usando flutter_bloc ^9.1.1
- **Núcleo:** `FileProcessorBloc` que centraliza toda lógica de negócio
- **Estados:** 8 estados distintos que representam cada fase do processamento
- **Eventos:** 5 eventos que disparam transições entre estados
- **Filtros de Processamento:** Sistema de filtros de documentos e datas implementado com `ProcessingFilters`

### 3. **Núcleo de Processamento (Backend)**
- **CLI:** Executável `br_service_cli` (Python) empacotado nos assets
- **Comunicação:** Process.start() com parsing de JSON para progresso
- **Execução:** Isolates para operações pesadas sem travar UI
- **Validação Integrada:** CLI com análise de dados válidos via `--get-options`
- **Cache de Dados:** Sistema de cache para reutilização de análises CLI
- **Plataformas:** Windows (.exe) e Linux/macOS (binário)

---

## Estados da Aplicação (FileProcessorBloc)

### 1. **InitialState** - Estado Inicial
**Localização:** `lib/bloc/states/file_processor_bloc.dart:8`

**Interface:**
- Sidebar verde com instruções de uso e logo BR
- Área central de drag-and-drop para seleção de arquivo
- Botão alternativo para seleção via dialog
- Informações sobre formatos suportados (.xlsx, .xls)

**Componente:** `InitialView` em `lib/components/initial_view_component.dart`

**Funcionalidades:**
- Drag-and-drop de arquivos com validação de formato
- Seleção via FilePicker com filtros
- Feedback visual durante operação de arrastar
- Validação de extensão antes do processamento

**Transição:** Evento `SelectFileEvent` → `FileLoadingState`

### 2. **FileLoadingState** - Carregamento do Arquivo
**Localização:** `lib/bloc/states/file_loading_bloc.dart`

**Interface:**
- Indicador de progresso circular ou linear
- Mensagem da operação atual
- Porcentagem de progresso (quando disponível)

**Componente:** `FileLoadingView` em `lib/components/file_loading_view_component.dart`

**Lógica de Carregamento:**
```dart
// Para arquivos pequenos (<5MB)
Future<ExcelData> _loadFileDirectly(String path) // linha 53

// Para arquivos grandes (>=5MB) 
FileIsolateService.loadExcelFileInIsolate() // usando isolates
```

**Processo Detalhado:**
1. Verificação do tamanho do arquivo
2. Leitura via SpreadsheetDecoder
3. Localização da planilha "Layout"
4. Busca do cabeçalho com coluna "Contrato"
5. Extração de headers e dados
6. Identificação de pares Documento-Plano na linha anterior ao cabeçalho

**Transição:** Sucesso → `FilePreviewState` | Erro → `ErrorState`

### 3. **FilePreviewState** - Pré-visualização dos Dados
**Localização:** `lib/bloc/states/file_processor_bloc.dart:12`

**Interface:**
- Tabela paginada com dados do Excel
- Headers identificados
- Informações sobre Documento-Plano encontrados
- Botão "Continuar para Validação"

**Componente:** `FilePreviewView` em `lib/components/file_preview_component.dart`
**Widget Principal:** `PaginatedExcelTable` em `lib/widgets/paginated_excel_table.dart`

**Dados Exibidos:**
- Nome do arquivo
- Total de linhas carregadas
- Headers da planilha Layout
- Primeiras linhas de dados (paginado)
- Pares Documento-Plano detectados

**Modelo de Dados:**
```dart
class FilePreviewData {
  final String filePath;
  final ExcelData? excelData;
  final PaginatedExcelData? paginatedData;
}
```

**Transição:** Evento `ProceedToValidationEvent` → `ValidationState`

### 4. **ValidationState** - Validação do Arquivo
**Localização:** `lib/bloc/states/validation_processor_bloc.dart`

**Interface:**
- Lista de validações com status (✓ ou ✗)
- Descrição de cada validação
- Mensagens de erro específicas
- **Filtros de Processamento** com documentos e datas disponíveis
- Botão "Iniciar Processamento" (se válido)

**Componente:** `ValidationView` em `lib/components/validation_view_component.dart`

**Validações Realizadas:**
1. **Planilha "Layout" presente** - Verifica existência da aba Layout
2. **Colunas obrigatórias** - Verifica presença de "Contrato", "Valor" e "Data Crédito"
3. **Dados válidos na planilha** - Verifica se os dados estão no formato correto
4. **Documentos identificados** - Pelo menos um documento detectado pelo CLI
5. **Planos por documento** - Cada documento deve ter pelo menos um plano
6. **Datas identificadas** - Pelo menos uma data válida encontrada
7. **Pares Documento-Plano** - Combinações válidas detectadas

**Novos Recursos:**
- **Análise via CLI:** Usa `--get-options` para validação completa
- **Filtros Integrados:** Mostra apenas documentos/datas com dados válidos (não zerados)
- **Cache de Dados:** Reutiliza análise CLI para melhor performance

**Método de Validação:** `FileRepositoryImpl.validateFile()` em linha 191

**Transição:** 
- Se válido + Evento `StartProcessingEvent` → `ProcessingState`
- Se inválido → Permanece em `ValidationState`

### 5. **ProcessingState** - Processamento via CLI
**Localização:** `lib/bloc/states/processing_bloc.dart`

**Interface:**
- Barra de progresso com porcentagem
- Log em tempo real das operações
- Operação atual sendo executada
- Botão para cancelar (opcional)

**Componente:** `ProcessingView` em `lib/components/processing_view_component.dart`

**Processo CLI Detalhado:**
```dart
// Iniciação do processo com filtros opcionais
final args = ['--input', input, '--output', outDir, '--progress'];

if (filters != null) {
  if (filters.selectedDocuments.isNotEmpty) {
    args.addAll(['--documentos', filters.documentosForCli]);
  }
  if (filters.selectedDates.isNotEmpty) {
    args.addAll(['--datas', filters.datasForCli]);
  }
}

_currentProcess = await Process.start(
  exe.path,
  args,
  runInShell: true,
  environment: {'PYTHONIOENCODING': 'utf-8'}
);
```

**Comunicação com CLI:**
- **Stdout/Stderr:** Captura de saída em tempo real
- **Formato JSON:** Eventos de progresso estruturados
- **Eventos Suportados:**
  - `progress`: Atualização de porcentagem e operação
  - `error`: Erro durante processamento
  - `done`: Conclusão bem-sucedida

**Exemplo de JSON do CLI:**
```json
{"event": "progress", "pct": 45, "operation": "Gerando arquivo CSV"}
{"event": "error", "msg": "Falha na validação", "details": "..."}
{"event": "done"}
```

**Transição:** 
- Sucesso → `ProcessingCompletedState`
- Erro → `ErrorState`

### 6. **ProcessingCompletedState** - Processamento Concluído
**Localização:** `lib/bloc/states/processing_completed_bloc.dart`

**Interface:**
- Resumo do processamento
- Logs finais da operação
- Botão "Ver Resultados"

**Componente:** `ProcessingCompletedView` em `lib/components/processing_completed_view_component.dart`

**Dados Disponíveis:**
- Caminho do arquivo processado
- Diretório de saída
- Logs completos da operação
- Tempo total de processamento

**Transição:** Evento `ContinueToResultsEvent` → `CompletedState`

### 7. **CompletedState** - Sucesso Final
**Localização:** `lib/bloc/states/completed_bloc.dart`

**Interface:**
- Animação de confetes
- Mensagem de sucesso
- Botão "Abrir Pasta de Destino"
- Botão "Processar Novo Arquivo"

**Componente:** `SuccessView` em `lib/components/sucess_view_component.dart`

**Funcionalidades:**
- Abertura automática do diretório de saída
- Reset da aplicação para novo processamento

**Transição:** Evento `ResetEvent` → `InitialState`

### 8. **ErrorState** - Estado de Erro
**Localização:** `lib/bloc/states/error_bloc.dart`

**Interface:**
- Ícone de erro
- Mensagem principal do erro
- Detalhes técnicos (expandível)
- Botão "Tentar Novamente"

**Componente:** `ErrorView` em `lib/components/error_view_component.dart`

**Tipos de Erro:**
- Erro de leitura do arquivo
- Erro de validação
- Erro do CLI durante processamento
- Erro de comunicação com processo

**Transição:** Evento `ResetEvent` → `InitialState`

---

## Eventos do Sistema (FileProcessorEvent)

### 1. **SelectFileEvent**
**Localização:** `lib/bloc/events/file_events_bloc.dart:5`
```dart
class SelectFileEvent extends FileProcessorEvent {
  final String filePath;
  const SelectFileEvent(this.filePath);
}
```
**Disparado por:** Seleção de arquivo via drag-and-drop ou dialog
**Resultado:** Inicia carregamento → `FileLoadingState`

### 2. **ProceedToValidationEvent**
**Localização:** `lib/bloc/events/file_events_bloc.dart:10`
**Disparado por:** Botão "Continuar para Validação" na tela de preview
**Resultado:** Executa validações → `ValidationState`

### 3. **StartProcessingEvent** 
**Localização:** `lib/bloc/events/file_events_bloc.dart:14`
```dart
class StartProcessingEvent extends FileProcessorEvent {
  final String outputDir;
  const StartProcessingEvent(this.outputDir);
}
```
**Disparado por:** Botão "Iniciar Processamento" após validação bem-sucedida
**Resultado:** Inicia CLI → `ProcessingState`

### 4. **ContinueToResultsEvent**
**Localização:** `lib/bloc/events/file_events_bloc.dart:23`
**Disparado por:** Botão "Ver Resultados" após processamento
**Resultado:** Mostra tela de sucesso → `CompletedState`

### 5. **ResetEvent**
**Localização:** `lib/bloc/events/file_events_bloc.dart:19`
**Disparado por:** Botão "Processar Novo Arquivo" ou "Tentar Novamente"
**Resultado:** Limpa estado → `InitialState`

---

## Repositórios e Serviços

### **FileRepository Interface**
**Localização:** `lib/repository/file_repository.dart`

**Métodos:**
```dart
Future<ExcelData> loadExcelFile(String path);
Future<List<ValidationItem>> validateFile(String filePath);
Future<Map<String, dynamic>> analyzeFile(String path);
Future<Map<String, dynamic>> getDetailedFileStats(String filePath);
Stream<ProcessEvent> processFile(String inputPath, String outputDir, {ProcessingFilters? filters});
```

### **FileRepositoryImpl - Implementação Principal**
**Localização:** `lib/repository/file_repository_impl.dart`

**Responsabilidades:**
1. **Carregamento de Excel:** SpreadsheetDecoder com suporte a isolates
2. **Análise via CLI:** Integração com `--get-options` para dados válidos
3. **Validação Unificada:** Validação usando dados do CLI com cache
4. **CLI Integration:** Execução e monitoramento do processo Python com filtros
5. **Gerenciamento de Recursos:** Cleanup de processos e streams

**Métodos Principais:**
- `analyzeFile()` (linha 32): Análise via CLI com `--get-options`
- `loadExcelFile()` (linha 117): Carregamento síncrono dos dados da planilha
- `validateFile()` (linha 191): Validação unificada usando dados do CLI
- `getDetailedFileStats()` (linha 333): Estatísticas detalhadas com cache
- `processFile()` (linha 430): Execução do CLI com filtros opcionais
- `hasCliDataFor()` (linha 168): Verifica se há dados salvos do CLI
- `_getExecutable()` (linha 542): Extração/localização do executável CLI

**Novos Recursos:**
- **Cache de Dados CLI:** Armazena resultado de `analyzeFile()` para reutilização
- **Filtros de Processamento:** Suporte a filtros de documentos e datas
- **Validação Integrada:** Usa dados do CLI para validação mais precisa

### **Serviços Auxiliares**

#### **IsolateService**
**Localização:** `lib/services/isolate_service.dart`
**Função:** Execução de operações pesadas em isolates separados
**Métodos:**
- `loadExcelFileInIsolate()`: Carregamento de arquivos Excel
- `validateFileInIsolate()`: Validação de arquivos
- `getDetailedStatsInIsolate()`: Obtenção de estatísticas detalhadas
**Benefício:** Não trava a UI durante operações pesadas

#### **PaginatedFileService** 
**Localização:** `lib/services/paginated_file_service.dart`
**Função:** Criação de visualização paginada para arquivos grandes
**Benefício:** Performance otimizada para milhares de linhas

#### **ErrorHandler**
**Localização:** `lib/utils/error_handler.dart`
**Função:** Tratamento global de erros não capturados
**Configuração:** `ErrorHandler.setupGlobalErrorHandling()` no main.dart

---

## Interface do Usuário

### **Estrutura Principal**
```
HomePage (lib/pages/home_page.dart)
├── Sidebar (lib/widgets/side_bar.widget.dart)
│   ├── Logo BR
│   ├── Instruções de uso
│   └── Informações do desenvolvedor
└── ContentArea (lib/widgets/content_area_widget.dart)
    ├── Título "Gerador de arquivos 📋"
    ├── ProgressIndicatorWidget 
    └── StateContent (componente dinâmico)
```

### **Sidebar - Instruções Fixas**
**Cor:** Verde (#007547)
**Conteúdo:**
- Logo do Brasil (lib/assets/br.png)
- Título "Como utilizar"
- 3 passos de instrução:
  1. Selecionar arquivo Excel (.xlsx)
  2. Requisitos: Layout, colunas Contrato/Valor/Data Crédito, Documento/Plano
  3. Selecionar pasta de destino
- Créditos do desenvolvedor

### **ContentArea - Conteúdo Dinâmico**
**Componente:** `StateContent` em `lib/components/state_content_component.dart`
**Função:** Switch entre diferentes views baseado no estado do BLoC

```dart
switch (state.runtimeType) {
  case InitialState: return InitialView();
  case FileLoadingState: return FileLoadingView();
  case FilePreviewState: return FilePreviewView();
  case ValidationState: return ValidationView();
  case ProcessingState: return ProcessingView();
  case ProcessingCompletedState: return ProcessingCompletedView();
  case ErrorState: return ErrorView();
  case CompletedState: return SuccessView();
}
```

---

## Modelos de Dados

### **ExcelData**
```dart
class ExcelData {
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;
  final List<DocPlano> docPlanos;
  final FileStats? fileStats;
  final ProcessingFilters? processingFilters;
}
```

### **FilePreviewData**
```dart
class FilePreviewData {
  final String filePath;
  final ExcelData? excelData;
  final PaginatedExcelData? paginatedData;
}
```

### **ValidationItem**
```dart
class ValidationItem {
  final String title;
  final String description;
  final bool isValid;
  final String? errorMessage;
}
```

### **ProcessingFilters**
```dart
class ProcessingFilters {
  final List<String> selectedDocuments;
  final List<String> selectedDates;
  final List<DocPlano> selectedDocPlanos;
  final List<String> availableDocuments;
  final List<String> availableDates;
  final List<DocPlano> availableDocPlanos;
  
  String get documentosForCli; // Conversão para formato CLI
  String get datasForCli;      // Conversão de data (YYYY-MM-DD → DD/MM/YYYY)
}
```

### **ProcessEvent (Hierarquia)**
```dart
abstract class ProcessEvent {}

class ProgressEvent extends ProcessEvent {
  final int percentage;
  final String currentOperation;
}

class LogEvent extends ProcessEvent {
  final String message;
}

class ErrorEvent extends ProcessEvent {
  final String message;
  final String? details;
}

class CompletedEvent extends ProcessEvent {}
```

---

## Fluxo de Execução Completo

### **Fase 1: Inicialização**
1. **main.dart** configura error handling global
2. **MyApp** cria MaterialApp com tema verde
3. **BlocProvider** instancia FileProcessorBloc com FileRepositoryImpl
4. **HomePage** renderiza layout com Sidebar + ContentArea
5. **StateContent** exibe InitialView (estado inicial)

### **Fase 2: Seleção de Arquivo**
1. **Usuário** arrasta arquivo ou clica em "Selecionar Arquivo"
2. **InitialView** valida extensão (.xlsx/.xls)
3. **SelectFileEvent** é disparado para o BLoC
4. **BLoC** transita para FileLoadingState
5. **StateContent** exibe FileLoadingView

### **Fase 3: Carregamento**
1. **FileRepositoryImpl.loadExcelFileWithProgress()** inicia
2. Se arquivo <5MB: carregamento direto
3. Se arquivo >=5MB: usa FileIsolateService
4. **SpreadsheetDecoder** processa bytes do arquivo
5. Localiza planilha "Layout" obrigatória
6. Identifica cabeçalho com coluna "Contrato"
7. Extrai headers, dados e pares Documento-Plano
8. **BLoC** transita para FilePreviewState

### **Fase 4: Pré-visualização**
1. **StateContent** exibe FilePreviewView
2. **PaginatedExcelTable** renderiza dados (se muitas linhas)
3. Exibe informações do arquivo carregado
4. **Usuário** clica "Continuar para Validação"
5. **ProceedToValidationEvent** é disparado

### **Fase 5: Validação**
1. **BLoC** chama `analyzeFile()` para obter dados do CLI
2. **FileRepositoryImpl.validateFile()** executa 7 validações usando dados CLI
3. **BLoC** transita para ValidationState com filtros de processamento
4. **ValidationView** exibe resultado das validações e filtros disponíveis
5. **Usuário** seleciona documentos/datas desejados e pasta de destino
6. Se todas válidas: botão "Iniciar Processamento" habilitado

### **Fase 6: Processamento**
1. **StartProcessingEvent** é disparado com outputDir e filtros
2. **BLoC** transita para ProcessingState
3. **FileRepositoryImpl.processFile()** inicia CLI com filtros
4. **_getExecutable()** extrai br_service_cli dos assets
5. **Process.start()** executa CLI com argumentos filtrados (`--documentos`, `--datas`)
6. **Stream combinado** monitora stdout/stderr
7. **JSON parsing** extrai eventos de progresso
8. **ProcessingView** atualiza UI em tempo real

### **Fase 7: Finalização**
1. **CLI** termina com exit code 0 (sucesso) ou != 0 (erro)
2. Se sucesso: **BLoC** → ProcessingCompletedState → CompletedState
3. Se erro: **BLoC** → ErrorState
4. **SuccessView** exibe confetes e botão "Abrir Pasta"
5. **Usuário** pode processar novo arquivo (ResetEvent)

---

## Diagrama de Estados Detalhado

```
┌─────────────┐    SelectFileEvent    ┌─────────────────┐
│ InitialState│────────────────────→│ FileLoadingState│
└─────────────┘                    └─────────────────┘
      ↑                                       │
      │                                       │ Sucesso
      │                                       ↓
      │                              ┌─────────────────┐
      │                              │ FilePreviewState│
      │                              └─────────────────┘
      │                                       │
      │                       ProceedToValidationEvent
      │                                       ↓
      │                              ┌─────────────────┐
      │                              │ ValidationState │
      │                              └─────────────────┘
      │                                       │
      │                           StartProcessingEvent
      │                                       ↓
      │                              ┌─────────────────┐
      │ ResetEvent                   │ ProcessingState │
      │                              └─────────────────┘
      │                                       │
      │                                       │ Sucesso
      │                                       ↓
      │                          ┌─────────────────────────┐
      │                          │ ProcessingCompletedState│
      │                          └─────────────────────────┘
      │                                       │
      │                           ContinueToResultsEvent
      │                                       ↓
      │                              ┌─────────────────┐
      └──────────────────────────────│ CompletedState  │
                                     └─────────────────┘

                     Erro em qualquer fase
                             ↓
                    ┌─────────────────┐
                    │   ErrorState    │
                    └─────────────────┘
                             │
                         ResetEvent
                             ↓
                    [Volta para InitialState]
```

---

## Requisitos Técnicos do Arquivo Excel

### **Estrutura Obrigatória:**
1. **Planilha "Layout"** deve existir
2. **Linha de Cabeçalho** contendo:
   - Coluna "Contrato" (obrigatória)
   - Coluna "Data Crédito" (obrigatória)
   - Outras colunas conforme necessário
3. **Linha Anterior ao Cabeçalho** deve conter:
   - Pares consecutivos Documento-Plano
   - Exemplo: [Doc1][Plano1][Doc2][Plano2]...
4. **Linhas de Dados** subsequentes ao cabeçalho

### **Algoritmo de Detecção:**
```dart
// Busca cabeçalho pela coluna "Contrato"
int headerRowIdx = sheet.rows.indexWhere((r) => 
  r.any((c) => c?.toString().trim().toLowerCase() == 'contrato')
);

// Extrai pares Documento-Plano da linha anterior
if (headerRowIdx > 0) {
  final docRow = sheet.rows[headerRowIdx - 1];
  for (int i = 0; i < docRow.length - 1; i++) {
    final doc = docRow[i]?.toString().trim();
    final plano = docRow[i + 1]?.toString().trim();
    if (doc.isNotEmpty && plano.isNotEmpty) {
      docPlanos.add(DocPlano(doc, plano));
      i++; // avança para não reprocessar
    }
  }
}
```

---

## Tecnologias e Dependências

### **Flutter/Dart:**
- flutter_bloc ^9.1.1 (gerenciamento estado)
- file_picker ^10.2.0 (seleção arquivos)
- desktop_drop ^0.6.1 (drag and drop)
- excel ^4.0.6 (leitura Excel)
- spreadsheet_decoder ^2.3.0 (decodificação)
- rxdart ^0.28.0 (streams reativos)
- process_run ^1.2.4 (execução processos)
- path_provider ^2.1.5 (diretórios sistema)

### **UI/UX:**
- google_fonts ^6.2.1 (tipografia)
- font_awesome_flutter ^10.8.0 (ícones)
- Material Design 3 (tema)
- Cupertino (componentes iOS)

### **Backend:**
- Python CLI empacotado (br_service_cli)
- Comunicação via stdout/stderr JSON
- Execução cross-platform (Windows/Linux/macOS)

### **Arquitetura:**
- Clean Architecture com camadas bem definidas
- Repository Pattern para abstração de dados
- BLoC Pattern para gerenciamento de estado
- Stream-based communication para real-time updates

---

## Performance e Otimizações

### **Carregamento e Análise:**
- **Isolates:** Operações pesadas executadas em threads separadas
- **Cache CLI:** Reutilização de dados do `--get-options` para evitar chamadas redundantes
- **Análise Inteligente:** CLI identifica apenas dados válidos (não zerados)
- **Paginação:** Visualização otimizada para arquivos com milhares de linhas

### **Validação Eficiente:**
- **Validação Unificada:** Um método único que usa dados cached do CLI
- **Análise Prévia:** CLI executa validação completa antes da interface
- **Filtros Pré-computados:** Documentos e datas disponíveis já filtrados

### **Gerenciamento de Memória:**
- Cleanup automático de processos e streams
- Dispose pattern no FileRepositoryImpl
- Cache limitado com invalidação automática
- Isolates para reduzir memory footprint

### **UI Responsiva:**
- 60fps mantido durante operações pesadas
- Feedback visual imediato para todas ações
- Loading states para operações assíncronas
- Error recovery com opções de retry

---

---

## Principais Melhorias Implementadas

### **Sistema de Filtros**
- **ProcessingFilters:** Modelo completo para gerenciar seleções de documentos e datas
- **Integração CLI:** Filtros passados via argumentos `--documentos` e `--datas` 
- **Conversão de Formato:** Datas convertidas automaticamente (YYYY-MM-DD → DD/MM/YYYY)
- **Filtros Inteligentes:** Mostra apenas combinações com dados válidos (não zerados)

### **Validação Aprimorada**
- **Análise via CLI:** Usa `--get-options` para validação precisa
- **Cache Inteligente:** Reutiliza dados CLI entre validação e processamento
- **Validações Expandidas:** 7 validações abrangentes incluindo colunas obrigatórias
- **Método Unificado:** Eliminação da duplicação entre `validateFile()` e `validateFileWithCliData()`

### **Performance Otimizada**
- **Isolates:** Carregamento, validação e estatísticas em threads separadas
- **Cache CLI:** Evita chamadas redundantes ao Python CLI
- **Processamento Assíncrono:** UI sempre responsiva durante operações pesadas
- **Análise Prévia:** CLI identifica dados válidos antes da exibição

### **Arquitetura Robusta**
- **Gerenciamento de Estado:** BLoC pattern com estados bem definidos
- **Separação de Responsabilidades:** Repository pattern com isolates
- **Tratamento de Erros:** Error recovery em cada etapa do processo
- **Documentação Completa:** Fluxo documentado com exemplos de código

---

Este documento representa o funcionamento completo e atualizado da aplicação BR Service, incluindo as melhorias mais recentes em filtros, validação e performance, servindo como referência técnica para desenvolvedores e documentação de arquitetura do sistema.
