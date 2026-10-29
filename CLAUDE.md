# CLAUDE.md

Guia para o Claude Code neste repositório. O dono é o diego, que escreve em português do Brasil: responda em pt-BR.

## O que é

*Where in the World Are the Bolsonaros?* (pt-BR: *Onde estão os Bolsonaros?*), paródia do *Where in the World is Carmen Sandiego?* (DOS) feita em Godot 4.7. O jogador é um agente da PF que caça um membro da família (ou aliado) por caso. O repositório cuida só da paródia. Uma recriação fiel do original, lendo os `.DAT`, é outro projeto: não desenhe o formato de pacote pensando num carregador de `.DAT`.

- `game/core`: regras, sem dependência de tela (`CaseSession`, `ContentPack`, `Career` = fichário de agentes, `WorldGraph`, `GameClock`, `MscRng`).
- `game/ui`: telas. `main.gd` liga o `CaseSession` à moldura `game_frame.gd`; telas cheias em `ui/screens/` (mapa de viagem, dossiê, fichário PF).
- `game/content/parody`: pacote de conteúdo da paródia. `game/content/placeholder`: pacote mínimo usado pelos testes.
- `docs/spec-original.md`: regras e formatos do original (engenharia reversa). `docs/content-format.md`: formato dos pacotes.

## Como o diego trabalha

- Fluxo **plano → spec → implementação**: para mudança que não seja trivial, proponha o plano e espere o ok antes de escrever código.
- Ambiente: Windows, Godot 4.7 local. O executável costuma se chamar `Godot_v4.7*-stable_win64.exe` (ou `_console.exe` para ver a saída); troque `godot` nos comandos abaixo pelo caminho dele.
- Ele revisa jogando no Godot local; não precisa mandar captura de tela.

## Comandos

```
godot --headless --path game -s res://tests/run_tests.gd                 # testes
godot --headless --path game -s res://tests/balance_sim.gd -- 0,0.4 4,0.4  # balanceamento
godot --headless --path game --import                                     # depois de mudar i18n/ui.csv
```

Sem o `--import`, as chaves novas de `ui.csv` aparecem cruas na tela. O repositório não tem CI: rode os testes antes de abrir PR.

Testes só onde ajudam a validar o código (regras do núcleo, save/replay, balanceamento); não escreva teste por obrigação, nem para tela.

## Regras de código

- GDScript, não C# (C# quebra o export para web).
- Comentários só quando acrescentam algo; nada de comentário explicando o óbvio. Comentários e docs em português.
- Ids e chaves JSON em inglês, snake_case. Texto para o jogador fica em objetos de idioma `{"pt_BR": ..., "en": ...}`.
- Textos da interface em `game/i18n/ui.csv` (pt_BR e en), sempre via `tr()`.
- Conteúdo em JSON, um arquivo por cidade e por suspeito, sem banco de dados e sem validador por enquanto.
- Nada do jogo original entra no repositório: executável, `.DAT`, textos extraídos, imagens, nem como base para traçar.

## PRs e commits

- **Sem links da conversa ou da sessão do Claude** no corpo do PR nem nos commits (nada de `Claude-Session:`, nada de link de thread). A linha "Generated with Claude Code" pode.
- Se a ferramenta que cria o PR acrescentar um rodapé com link da sessão, edite o corpo logo depois.
- PRs em cadeia não mudam de base sozinhos quando a base é mergeada antes: troque a base para `main` antes do merge.

## Decisões de jogo

- **Suspeitos**: 11. Jair é o chefe; os outros são Michelle, Flávio, Eduardo, Carlos, Jair Renan, Vorcaro, Marçal, Wassef, Bia Kicis e Valéria Bolsonaro. Não há traço de cabelo; o traço `profession` faz esse papel, com `clue_weight` menor para valores que só um suspeito tem.
- **Tom**: pode ser ácido, mas fica em fatos noticiados e memes; não invente crimes.
- **Carreira**: um suspeito não se repete até todos serem presos; o chefe vem por último. Patentes, saltos, pistas de traço, prazo, verba e atalho por patente ficam em `pack.json` (`ranks`).
- **Diferenças do original**: o esconderijo é sorteado entre os três locais na chegada; com o mandado certo, um voo certo pode levar direto ao esconderijo (nunca no primeiro voo); passagens custam verba.
- **Mandado**: marcar traços não filtra nada. O jogador busca pelos traços (`rules.warrant.search_hours`) ou pede o mandado direto (`issue_hours`, um pouco mais caro); pedido com mais de um compatível conta como busca. Tela no layout padrão: caricatura do Alexandre de Moraes na cena e animação dele batendo o martelo quando o mandado sai. O dossiê risca quem ficou fora da última busca.
- **Horas de investigação**: progressivas como no original (2h, 3h, depois 4h; voltam a 2h ao chegar numa cidade).
- **Agentes**: fichário como o `ACME.DAT` do original, em `user://agents.json` (até 8 agentes, cada um com carreira e caso próprios; o antigo `career.json` vira o primeiro agente). Ao abrir, o jogo sempre pede o nome, como no original: nome conhecido entra naquele agente, nome novo cadastra um agente com carreira do zero. Com caso em andamento, pergunta se retoma; sem caso, mostra a carreira e oferece nova investigação, que passa pelo briefing ("*** URGENTE ***") antes da primeira cidade. Nova carreira só aparece depois de prender o chefe e recomeça o mesmo agente.
- **Fluxo**: o caso é salvo depois de cada ação (semente + ações, refeitas por `CaseSession.replay()`).
- **Menus**: Jogo (Novo caso, Novo agente, Idioma, Sobre), PF e Dossiês. Novo caso com caso aberto pede confirmação; Novo agente volta para a identificação. PF abre o fichário por cima da tela: ficha de cada agente (nome, patente, casos, quanto falta para a promoção, caso aberto) e apagar, com confirmação.
- **Pistas** somem do painel a cada investigação, como no original; não há caderno de pistas.
- **Dossiê**: no menu de cima, no formato do PowerPoint do Dallagnol (chefe no centro, os outros em volta com setas, só os nomes, quebrados com hífen). Clicar abre um cartão no estilo do original; quem já foi preso leva o carimbo PRESO.

## Visual

- Visual DOS puxado para um VGA moderno (referências: Skald, Forbidden Solitaire), mantendo o esqueleto da tela do original.
- Tela lógica de 640 × 360, escala inteira, filtro nearest, grade de 8 px.
- Interface com as 8 cores de `ui/theme/palette.gd` (tema de terminal da PF: azul-marinho, dourado, creme). Fonte Press Start 2P em 8 px (ou múltiplos) em tudo.
- Moldura: barra de menu (Jogo, PF, Dossiês), barra do caso (verba à esquerda, prazo à direita), cena à esquerda, texto à direita começando no alto, notas e três verbos (Investigar, Viajar, Mandado).
- Os verbos estão sempre disponíveis, por isso Investigar, Viajar e Mandado não têm botão Voltar. Onde há Voltar (dossiê), ele fica à direita.
- A cena mostra o lugar (a cidade ao chegar, o local ao investigar). Quem fala aparece no pé do painel de texto, como no original: retrato com nome e a fala num balão.
- Sequência ao investigar, também usada em captura e desfecho: animação na cena (se houver evento), texto do evento, depois a testemunha com a fala (`play_animation`, `wait_typing`, `show_speaker` em `game_frame.gd`).
- Briefing: roubo e suspeito, pausa (qualquer tecla ou Continuar), missão, verba e prazo, boa sorte, e o botão Aceitar missão.
- Toda a arte é original. Por enquanto as cenas são placeholders coloridos com o nome do arquivo esperado (`arte: ...`, `animação: ...`).
