# GH Switcher

**Troque a conta do GitHub CLI pela barra de menus do macOS, com um clique.**

O GH Switcher é um app nativo de barra de menus para quem usa mais de uma conta do GitHub
(pessoal e do trabalho, por exemplo) no [GitHub CLI](https://cli.github.com). Ele lista as
contas que o `gh` conhece e executa `gh auth switch` por você, num painel com o visual da
Central de Controle do macOS.

🇺🇸 [Read in English](README.md)

## Recursos

- **Troca com um clique** da conta ativa do `gh`, por servidor (github.com e GitHub Enterprise).
- **Painel em Liquid Glass** no estilo da Central de Controle, sem ícone no Dock.
- **Sincronizado com o terminal:** atualiza ao abrir e a cada 60 segundos.
- **Adicione e remova contas** sem terminal: login pelo navegador com código de uso único.
- **Login na barra de menus** (opcional), notificações e abertura no login.
- **Português (Brasil) e inglês.**

## Instalação

```bash
brew trust willianrattis/tap
brew install --cask willianrattis/tap/gh-switcher
```

O `brew trust` é exigido pelo Homebrew para taps de terceiros. O Homebrew também instala o GitHub CLI, se você ainda não tiver. Depois abra o
**GH Switcher** e, se precisar, clique em **Adicionar conta**.

Prefere baixar? Pegue o `.dmg` na
[última versão](https://github.com/willianrattis/gh-switcher/releases/latest) e arraste o app
para Aplicativos. As versões são assinadas com Developer ID e notarizadas pela Apple.

**Requisitos:** macOS 13 ou mais recente (Liquid Glass no macOS 26+), Apple silicon ou Intel.

## Segurança e privacidade

- O GH Switcher **nunca lê, grava ou exibe tokens**. As credenciais ficam com o GitHub CLI,
  no Keychain do macOS.
- Ele só executa `gh auth status --json hosts`, `gh auth switch`, `gh auth login --web` e
  `gh auth logout`, os dois últimos apenas quando você pede. O campo `token` retornado pelo
  `gh auth status` nunca é decodificado.
- No login, a única informação extraída da saída do `gh` é o código de uso único. Nada é
  registrado em log.
- Sem analytics nem telemetria. As únicas conexões são os avatares do GitHub e o que o
  próprio `gh` faz.

Veja o [SECURITY.md](SECURITY.md) para relatar uma vulnerabilidade.

## Dicas

**Identidade de commit por pasta.** Trocar a conta do `gh` não muda `user.name`/`user.email`
do git. Use `includeIf` no `~/.gitconfig`:

```ini
[includeIf "gitdir:~/trabalho/"]
    path = ~/.gitconfig-trabalho
```

**Local do gh.** O GH Switcher procura o `gh` nos Ajustes, em `/opt/homebrew/bin`,
`/usr/local/bin` e no `PATH` do seu shell de login.

## Compilar a partir do código

```bash
swift build && swift test
scripts/bundle.sh          # build/GHSwitcher.app (debug, assinatura ad-hoc)
open build/GHSwitcher.app
```

## Licença

[FSL-1.1-MIT](LICENSE.md) (Functional Source License). Resumindo: você pode usar, estudar,
modificar e compartilhar o GH Switcher para qualquer fim, **exceto** oferecer um produto
comercial concorrente. **Cada versão vira MIT automaticamente dois anos após a publicação.**

O GH Switcher não tem afiliação nem endosso do GitHub, Inc. GitHub e o logo do GitHub são
marcas do GitHub, Inc.

## Apoie

Se o GH Switcher economiza o seu tempo, considere
[patrocinar o projeto](https://github.com/sponsors/willianrattis). ❤️
