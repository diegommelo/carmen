# carmen

Estudo e recriação em Godot da mecânica de *Where in the World is Carmen Sandiego?* (DOS, 1990), com dois objetivos:

1. Um jogo paródia, *Where in the World is Bolsonaro Family*, em que o jogador é um agente da PF.
2. No futuro, um motor open source que roda o jogo original a partir dos arquivos de dados de quem tem o jogo.

## Plano

1. **Estudar o original**: formatos de arquivo e regras do jogo. Ver [docs/spec-original.md](docs/spec-original.md).
2. **Núcleo em Godot**: a mecânica lendo um formato de dados próprio (JSON). Ver [docs/content-format.md](docs/content-format.md).
3. **Conteúdo da paródia**: cidades, pistas, alvos, arte e textos próprios.
4. **Motor do original**: leitor dos `.DAT` originais alimentando o mesmo núcleo.

## Jogo (Godot 4.7)

O projeto fica em [`game/`](game). A mecânica está em `game/core`, sem nenhuma dependência de tela, e o conteúdo vem de pacotes JSON ([formato](docs/content-format.md)). A tela provisória em `game/ui/main.tscn` é só texto e botões, para jogar o núcleo com o pacote de teste.

Testes do núcleo:

```
godot --headless --path game -s res://tests/run_tests.gd
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
