# GH Switcher

App de barra de menus do macOS para trocar a conta ativa do GitHub CLI (`gh`) com um clique.

- Lista as contas de `gh auth status --json hosts` e troca com `gh auth switch`.
- **Nunca** lê, grava ou exibe tokens: as credenciais ficam com o `gh` (Keychain).
- Painel no estilo da Central de Controle (blocos de Liquid Glass soltos), sem ícone no Dock.
- Atualiza ao abrir o painel e a cada 60 segundos (mostra trocas feitas pelo terminal).
- Ajustes (botão ⚙, ⌘, ou clique direito no ícone): adicionar conta (`gh auth login --web`),
  sair de uma conta (`gh auth logout`, com confirmação), abrir no login, notificações,
  login na barra de menus, estilo do vidro e caminho do `gh`.

## Segurança
- Login e logout só por ação explícita do usuário; logout sempre pede confirmação.
- Do login, o app extrai apenas o código de uso único; a saída do `gh` não é registrada.
- `gh auth token`, `refresh` e `setup-git` nunca são executados.

## Requisitos
- macOS 13+
- [GitHub CLI](https://cli.github.com) com uma ou mais contas autenticadas

## Build
```bash
swift build
swift test
scripts/bundle.sh   # gera build/GHSwitcher.app (assinatura ad-hoc)
```

## Instalação
```bash
cp -R build/GHSwitcher.app /Applications/
```
Na primeira execução, clique com o botão direito no app > **Abrir**, porque a assinatura é ad-hoc.

"Abrir no login" usa `SMAppService` e deve ser ativado com o app já em `/Applications`.
O GH Switcher não tem janela principal; os Ajustes abrem pelo painel.

## Caminho do gh
O app procura o `gh` nesta ordem: `UserDefaults` (`ghPath`), `/opt/homebrew/bin/gh`,
`/usr/local/bin/gh` e `zsh -lc 'command -v gh'`. Para forçar um caminho:
```bash
defaults write com.willianrattis.ghswitcher ghPath /caminho/para/gh
```

## Identidade de commit por pasta (recomendado)
Trocar a conta do `gh` não muda `user.name`/`user.email` do git. Use `includeIf` no `~/.gitconfig`:
```ini
[includeIf "gitdir:~/Development/git/casas-bahia/"]
    path = ~/.gitconfig-gcb
```
E em `~/.gitconfig-gcb`:
```ini
[user]
    name = Seu Nome
    email = voce@empresa.com
```
