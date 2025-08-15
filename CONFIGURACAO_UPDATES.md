# 🔄 Sistema de Atualizações Automáticas

Sistema completo para verificar, baixar e instalar atualizações do GitHub automaticamente.

## 📋 Configuração Necessária

### 1. Atualize as constantes no arquivo `lib/services/update_service.dart`:

```dart
static const String _owner = 'SEU_USUARIO_GITHUB'; // Exemplo: 'rikelmyso7'
static const String _repo = 'SEU_REPOSITORIO';     // Exemplo: 'br_service'
static const String _currentVersion = '1.0.0';     // Versão atual do app
```

### 2. Versão atual do pubspec.yaml:

Atualize a versão no `pubspec.yaml` para coincidir:
```yaml
version: 1.0.0+1
```

## 🏷️ Como Funciona

### Verificação de Versões
- Compara a versão atual com a última release do GitHub
- Usa comparação semver (x.y.z)
- Verifica a cada 24 horas automaticamente

### Downloads Suportados
- ✅ Arquivos `.exe` (executáveis diretos)
- ✅ Arquivos `.zip` (extrai e executa)
- ✅ Releases com "windows" no nome

### Processo de Atualização
1. **Verificação**: Consulta a API do GitHub
2. **Notificação**: Mostra banner animado na tela
3. **Download**: Baixa o arquivo da release
4. **Instalação**: Executa automaticamente
5. **Reinício**: Fecha o app atual

## 🎯 Como Criar Releases no GitHub

### 1. Crie uma Release:
```bash
git tag v1.1.0
git push origin v1.1.0
```

### 2. No GitHub:
- Vá em "Releases" → "Create a new release"
- Tag: `v1.1.0` (sempre com 'v' na frente)
- Title: `Versão 1.1.0`
- Descrição: Notas da versão
- **Anexe o arquivo**: `br_service_ui.exe` ou `br_service_windows.zip`

### 3. Exemplo de estrutura de release:
```
Título: Versão 1.1.0
Tag: v1.1.0

Descrição:
## 🆕 Novidades
- Container responsivo implementado
- Sistema de atualizações automáticas
- Melhorias na interface

## 🐛 Correções
- Corrigido crash ao redimensionar janela
- Melhorada performance de carregamento

Assets:
📎 br_service_ui.exe (23.5 MB)
```

## 🚀 Como Testar

### Teste Manual:
```dart
// No seu código, você pode forçar uma verificação:
final updateInfo = await UpdateService.checkForUpdates();
if (updateInfo != null) {
  print('Update disponível: ${updateInfo.version}');
}
```

### Teste de Versão:
1. Mude `_currentVersion` para `'0.9.0'`
2. Execute o app
3. Se houver release v1.0.0 ou superior, aparecerá a notificação

## 🎨 Personalização

### Mudar Intervalo de Verificação:
```dart
AutoUpdateChecker(
  checkInterval: Duration(hours: 6), // Verifica a cada 6 horas
  child: HomePage(),
)
```

### Verificação Manual:
```dart
// Adicione um botão na UI para verificar manualmente
ElevatedButton(
  onPressed: () async {
    final update = await UpdateService.checkForUpdates();
    if (update != null) {
      // Mostrar diálogo de atualização
    } else {
      // Mostrar "Nenhuma atualização disponível"
    }
  },
  child: Text('Verificar Atualizações'),
)
```

## 🔒 Segurança

- ✅ Verifica apenas releases oficiais do seu repositório
- ✅ Downloads via HTTPS
- ✅ Validação de versão semver
- ✅ Execução apenas de arquivos esperados (.exe, .zip)

## 📱 Interface

### Notificação Automática:
- Banner animado no topo da tela
- Informações da versão e data
- Botões: "Ver Detalhes", "Atualizar Agora", "Fechar"
- Barra de progresso durante download
- Status de instalação em tempo real

### Estados da Interface:
- 🟦 **Azul**: Atualização disponível
- 🟨 **Amarelo**: Baixando atualização
- 🟩 **Verde**: Instalação concluída
- 🟥 **Vermelho**: Erro durante processo

## 🛠️ Solução de Problemas

### Erro "Não foi possível baixar":
- Verifique conexão com internet
- Confirme se a release tem arquivo Windows anexado

### Erro "Falha na instalação":
- Execute como administrador
- Verifique se antivírus não está bloqueando

### Versão não detectada:
- Confirme formato da tag: `v1.2.3`
- Verifique se `_currentVersion` está correto

## 🎉 Pronto!

Agora seu app irá:
- ✅ Verificar atualizações automaticamente
- ✅ Notificar usuários sobre novas versões
- ✅ Baixar e instalar com um clique
- ✅ Funcionar mesmo se o usuário diminuir muito a tela

**O sistema está integrado e funcionando!** 🚀