# carmen

Estudo e recriação em Godot da mecânica de *Where in the World is Carmen Sandiego?* (DOS, 1990), com dois objetivos:

1. Um jogo paródia, *Where in the World Are the Bolsonaros?*, em que o jogador é um agente da PF.
2. Estudar a mecânica do original e aprender Godot. Uma recriação fiel do jogo original, que leia os arquivos de dados de quem tem o jogo, fica para um projeto separado.

## Plano

1. **Estudar o original**: formatos de arquivo e regras do jogo. Ver [docs/spec-original.md](docs/spec-original.md).
2. **Núcleo em Godot**: a mecânica lendo um formato de dados próprio (JSON). Ver [docs/content-format.md](docs/content-format.md).
3. **Conteúdo da paródia**: cidades, pistas, alvos, arte e textos próprios.

## Jogo (Godot 4.7)

O projeto fica em [`game/`](game). A mecânica está em `game/core`, sem nenhuma dependência de tela, e o conteúdo vem de pacotes JSON ([formato](docs/content-format.md)). A tela (`game/ui`) segue o guia de estilo: tela lógica de 640 × 360 com escala inteira, tema de terminal da PF (`game/ui/theme`) e uma moldura comum com barra de menu, barra do caso, cena, painel de texto, notas e três verbos (`game/ui/game_frame.gd`). A arte ainda é placeholder. Fonte: Press Start 2P, SIL Open Font License. O jogo está em português do Brasil e inglês: os textos do conteúdo ficam nos pacotes e os da tela em `game/i18n/ui.csv` (ver [idiomas](docs/content-format.md#idiomas)).

Testes do núcleo:

```
godot --headless --path game -s res://tests/run_tests.gd
```

Simulação de balanceamento da paródia (1000 casos por argumento `patente,taxa_de_voo_errado[,verba]`):

```
godot --headless --path game -s res://tests/balance_sim.gd -- 0,0.4 4,0.4
```

## Ferramentas

Precisam de Python 3. O jogo original **não** está neste repositório; aponte as ferramentas para a sua cópia.

```
pip install unicorn
python3 tools/unpack_exe.py CARMEN.EXE CARMEN_unpacked.EXE        # tira o PKLITE
python3 tools/carmen_dat.py list CITIES.DAT                       # lista os recursos
python3 tools/carmen_dat.py cities CITIES.DAT CARMEN_unpacked.EXE # cidades em JSON
python3 tools/carmen_dat.py text CARMEN.DAT CARMEN_unpacked.EXE   # textos decodificados
```
