# Especificação do jogo original (DOS, 1990/1991)

Este documento descreve como funciona *Where in the World is Carmen Sandiego?* na versão MS‑DOS 2.1 (CARMEN.EXE de 21/09/1991, dados de 15/04/1990). Ele é a base para o núcleo em Godot (passo 2) e para o futuro motor que roda os dados originais (passo 4).

Tudo aqui saiu da análise do executável descompactado e dos arquivos de dados. Cada seção diz o que está **confirmado** (lido no código ou verificado decodificando os dados) e o que ainda é **a confirmar**. Endereços como `DS:2df4` são deslocamentos no segmento de dados (DGROUP) do executável descompactado; `seg:off` são endereços de código no layout carregado em 0x1000, o mesmo que o Ghidra usa.

As ferramentas citadas estão em [`tools/`](../tools). Nenhum arquivo, texto ou imagem do jogo original vai para este repositório: as ferramentas leem a cópia do jogo que cada pessoa tem.

---

## 1. Arquivos do jogo

| Arquivo | Conteúdo |
|---|---|
| `CARMEN.EXE` | Programa (Microsoft C 5.x, modelo large), comprimido com PKLITE. |
| `CITIES.DAT` | Arquivo de recursos: as 30 cidades (nome, posição no mapa, imagem, descrição, tesouros, locais e pistas). |
| `CARMEN.DAT` | Arquivo de recursos: imagens das telas, animações, música, perguntas da proteção contra cópia. |
| `DIGISND.DAT` | Sons digitalizados (carregado só se houver placa de som). Formato a confirmar. |
| `MIDISND.DAT` | Música MIDI (contém blocos `MThd`/`MTrk`). Formato do contêiner a confirmar. |
| `ACME.DAT` | Fichário de detetives (jogadores), ranking e nomes dos saves. |
| `GAMEn.SAV` | Jogo salvo de cada detetive (n = 0..). |
| `DESKTOPD.CFG` | Configuração do sistema de janelas. |

### 1.1 Descompactar o executável — confirmado

O `CARMEN.EXE` é um PKLITE de 1990. O `tools/unpack_exe.py` roda o descompactador num emulador x86 de 16 bits (unicorn) até o runtime do C começar (primeira chamada `INT 21h / AH=30h`), carrega a imagem em dois segmentos diferentes e compara as duas cópias para reconstruir as 1629 relocações. O resultado é um MZ normal que abre no Ghidra:

- ponto de entrada `1483:01c8` (relativo), DGROUP no parágrafo `196f`, pilha de 0x449e bytes;
- `analyzeHeadless` do Ghidra 11.4 decompila 540 funções.

```
python3 tools/unpack_exe.py CARMEN.EXE CARMEN_unpacked.EXE
```

### 1.2 Formato dos arquivos de recursos (.DAT) — confirmado

Vale para `CARMEN.DAT` e `CITIES.DAT` (todos os valores little endian):

```
u32   deslocamento do diretório
...   recursos
diretório:
  u16 quantidade
  quantidade × { u16 id, u32 deslocamento, u16 tamanho }
recurso em `deslocamento` (tamanho + 1 bytes):
  u8  verificação = NOT(soma de 8 bits dos bytes do conteúdo)
  ... conteúdo (tamanho bytes)
```

O código que lê os recursos e confere o byte de verificação está em `10e4:7e6d` (busca binária pelo id) e `10e4:7f09` (leitura e checagem).

### 1.3 Compressão de texto — confirmado

Decodificador em `10e4:7358`. O conteúdo de um recurso de texto é:

```
u16   tamanho do texto já decodificado
bits  fluxo de bits, do bit mais significativo para o menos
```

- Os 2 bits mais altos do primeiro byte do fluxo dão a largura de escape `w = valor + 5` (5 a 8). O fluxo começa no bit 2.
- Lê 4 bits. Se o código for diferente de zero, o caractere é `tabela[código]`.
- Se for zero, lê mais `w` bits: com `w == 8` é um byte literal; senão é `tabela[código]`.
- A tabela fica em `DS:2df4` e começa pelos caracteres mais frequentes: `" aetonisrdlhugfcwypbmk,vSA.T'PMxBCIRGDWHqE-zNFKL0j:51YJ8\U?73Q;2!469..."`.

O texto decodificado é uma **lista de frases**: um byte com a quantidade e depois as frases terminadas em `\0`. Dentro das frases há marcadores:

| Byte | Significado |
|---|---|
| `0x80` | início de uma frase atribuída a quem dá a pista (vira "He"/"She" etc., ver 4.4) |
| `0x81` | " he " / " she " conforme o sexo do suspeito |
| `0x82` | " his " / " her " |

As listas de frases dentro do executável usam o mesmo formato (quantidade + frases), só que sem compressão.

### 1.4 Imagens — a confirmar

Recursos de imagem vêm aos pares: `x00` ou `x01` é uma paleta (99 bytes; começa com `01 00 10 00 00 00` e traz 16 cores RGB de 6 bits, padrão VGA) e o seguinte é o bitmap. O bitmap começa com dois `u16` (provavelmente tamanho e/ou dimensões) e usa uma compressão por diferença com códigos de 3 bits (`10e4:7140`, chamada por `10e4:7272`). Os BMPs `CARMEN01..21.BMP` que vêm no zip (320×200, 8 bits) parecem capturas de tela de 2003 e servem para conferir o decodificador quando ele for escrito.

---

## 2. Dados

### 2.1 Cidades (`CITIES.DAT`) — confirmado

O recurso `1` contém `u16 ?`, `u16 id_base = 10000` e `u16 passo = 100`. A cidade *k* (k = 0..29) usa os ids `10000 + 100·k + s`:

| s | Conteúdo |
|---|---|
| 0 | `u16 linha, u16 coluna` no mapa-múndi + nome (texto simples). Linha cresce para o sul (Reykjavik 7, Sydney 91) e coluna para o leste (Lima 83, Tokyo 266). |
| 1, 2 | paleta e imagem da cidade |
| 3 | descrição (3 parágrafos, texto comprimido) |
| 4 | tesouros que podem ser roubados ali (3, texto comprimido) |
| 10 | locais que existem na cidade: `u16 n` e `n × u16` tipos (1..12, ver 2.2) |
| 11..22 | pistas **sobre esta cidade**, uma lista por tipo de local (`10 + tipo`). São dadas por testemunhas na cidade anterior da rota. |

As 30 cidades: Athens, Baghdad, Bamako, Bangkok, Budapest, Buenos Aires, Cairo, Colombo, Istanbul, Kathmandu, Kigali, Lima, London, Mexico City, Montreal, Moroni, Moscow, New Delhi, New York, Oslo, Paris, Peking, Port Moresby, Reykjavik, Rio de Janeiro, Rome, San Marino, Singapore, Sydney, Tokyo.

Exemplo (Atenas, resource 10011, Bank): *"changed {his} money to drachmas"*.

```
python3 tools/carmen_dat.py cities CITIES.DAT CARMEN_unpacked.EXE > cities.json
```

### 2.2 Tipos de local — confirmado

Lista em `DS:0e67`, índice 1..12:

| Grupo | Tipos |
|---|---|
| A (1–4) | Bank, Hotel, Museum, Sport Club |
| B (5–8) | Library, Airport, Harbor, Riverfront |
| C (9–12) | Palace, Stock Exchange, Marketplace, Foreign Ministry |

Cada tipo tem 3 testemunhas possíveis (`DS:0eda`, ex.: Bank → Vice President, Bank Guard, Teller) e uma frase de "não vi ninguém" (`DS:10a8`).

### 2.3 Suspeitos — confirmado

Tabela em `DS:1ce8`, 10 registros de 14 bytes (7 × `u16`):

| Campo | Valores |
|---|---|
| sexo | 0 = masculino, 1 = feminino |
| hobby | 0 tennis, 1 music, 2 mt. climbing, 3 skydiving, 4 swimming, 5 croquet |
| cabelo | 0 brown, 1 blond, 2 red, 3 black |
| característica | 0 limps, 1 ring, 2 tattoo, 3 scar, 4 jewelry |
| veículo | 0 convertible, 1 limousine, 2 race car, 3 motorcycle |
| comida | 0 seafood, 1 Mexican food (só aparece em pistas, não entra no mandado; ver 4.4) |
| nome | ponteiro para o nome curto |

| # | Nome | Sexo | Hobby | Cabelo | Caract. | Veículo | Comida |
|---|---|---|---|---|---|---|---|
| 0 | Carmen Sandiego | F | tennis | brown | jewelry | convertible | Mexican |
| 1 | Merey LaRoc | F | mt. climbing | brown | jewelry | limousine | Mexican |
| 2 | Dazzle Annie | F | tennis | blond | tattoo | limousine | seafood |
| 3 | Lady Agatha | F | tennis | red | ring | convertible | Mexican |
| 4 | Len Bulk | M | mt. climbing | red | tattoo | convertible | seafood |
| 5 | Scar Graynolt | M | croquet | red | ring | limousine | Mexican |
| 6 | Nick Brunch | M | mt. climbing | black | ring | motorcycle | Mexican |
| 7 | Fast Eddie B | M | croquet | black | jewelry | convertible | Mexican |
| 8 | Ihor Ihorovich | M | croquet | blond | tattoo | limousine | seafood |
| 9 | Katherine Drib | F | mt. climbing | brown | tattoo | motorcycle | seafood |

Os textos completos dos dossiês ficam em `DS:06b5` em diante. Os suspeitos só usam parte dos valores (3 hobbies, 4 cabelos, 3 características, 3 veículos), o que mantém a dedução curta.

### 2.4 Detetives (`ACME.DAT`) — confirmado

```
u16  quantidade de registros (12)
12 × 38 bytes:
  char nome[21]
  char arquivo_save[13]   ex.: "GAME0.SAV"
  u16  casos resolvidos
  u16  patente (0..4)
```

Patentes (`DS:1ca6`): Rookie, Sleuth, Private Eye, Investigator, Ace Detective. A tabela que vem logo depois parece ser o número de casos para cada promoção: **1, 5, 12, 20** (e 30), a confirmar no código de promoção.

### 2.5 Jogo salvo (`GAMEn.SAV`) — confirmado em parte

Lido por `244a:00xx`. O arquivo tem 0x66 bytes e guarda: semente do gerador aleatório usada para criar o mapa, semente atual, dia, hora, cidade atual, local esconderijo, suspeito, passos restantes, próxima cidade da rota, cidade anterior, cidade do crime, nome do tesouro (64 bytes), suspeito do mandado e os 5 traços marcados no computador. Na carga, o grafo de voos é **regenerado a partir da semente salva** (ver 3.1), e por isso o mapa não precisa ser gravado.

### 2.6 Outros recursos de `CARMEN.DAT` — confirmado em parte

| Ids | Conteúdo |
|---|---|
| 10, 11, 12 | Proteção contra cópia: textos, 16 perguntas do *World Almanac* e as 16 respostas. Feita na promoção. |
| 100, 101 | Tabelas não identificadas |
| 200–229 | Música e efeitos em formato de sequência (cabeçalho `00 40 02`/`00 48 00`) |
| 1000+ | Imagens das telas (paleta + bitmap), em blocos de 100 por cena |

---

## 3. Mundo e rota

### 3.1 Mapa de voos aleatório — confirmado

`1fb4:00b6`. Ao começar uma partida, o jogo **sorteia** as ligações entre cidades:

1. Zera a lista de vizinhos de todas as cidades.
2. Para cada rodada `r = 1..4`, percorre as cidades em ordem. Para cada cidade com menos de `r` vizinhos, escolhe uma cidade de partida aleatória na lista circular e procura a primeira cidade *b* que também tenha menos de `r` vizinhos e que **não** esteja a 4 saltos ou menos (`1fb4:005d`, busca em profundidade de até 4 níveis).
3. Liga as duas e testa se os nomes das cidades vizinhas cabem na tela do mapa sem se sobrepor (`1ea0:091e`). Se não couberem, desfaz e tenta a próxima.

Resultado: cada cidade tem até 4 destinos de voo, e cidades ligadas ficam "longe" no grafo. A semente desse sorteio é guardada no save (`DS:36a6`).

### 3.2 Gerador aleatório — confirmado

`2356:0a89`: LCG do Microsoft C, `semente = semente × 214013 + 2531011`, e o resultado de `aleatorio(n)` é `(semente >> 16) mod (n + 1)`, ou seja, um número de 0 a n. A semente inicial vem do relógio.

### 3.3 Início do caso — confirmado em parte

- Suspeito: se o detetive tem **menos de 29 casos**, um capanga ao acaso (`aleatorio(8) + 1`, 1..9); a partir daí é a própria Carmen (0).
- Número de saltos da rota: `patente + 4` (Rookie 4, Ace 8).
- Relógio: segunda‑feira, 9h. Prazo: domingo, 17h.
- A cidade do crime e o tesouro (um dos 3 do recurso `+4` da cidade) são sorteados. A confirmar o sorteio exato.
- Mensagem inicial: tesouro roubado, sexo do suspeito ("Female suspect reported at the scene of the crime"), rota "from %s to %s hideout", prazo.

### 3.4 A rota é gerada enquanto o jogador anda — confirmado

`1ea0:000e`, chamada a cada chegada numa cidade. O estado guarda: cidade atual (`3982`), próxima cidade da rota (`399c`), cidade da rota em que o ladrão estava (`39a0`) e saltos restantes (`3998`).

Quando o jogador chega na *próxima* cidade e ainda restam saltos, o jogo escolhe ao acaso a nova próxima cidade **entre os vizinhos da atual**, diferente da anterior, e desconta um salto. Quando os saltos acabam, a próxima cidade passa a ser a própria cidade atual: é o esconderijo final.

### 3.5 Viagem — confirmado

`1ea0:02c2`. O avião segue em linha reta pelo mapa. Com `d = |Δlinha| + |Δcoluna| + 1`, o voo leva `min(d / 40 + 2, 7)` horas. Os destinos oferecidos são os vizinhos do grafo (até 4).

---

## 4. Investigação

### 4.1 Locais da cidade — confirmado

`227d:0372`, ao chegar numa cidade. Há sempre 3 locais, um de cada grupo da seção 2.2. Para o local *i* (0..2) o jogo sorteia um tipo `4·i + aleatorio(3) + 1` até achar um tipo que exista na cidade atual **e** que tenha pistas na próxima cidade da rota.

### 4.2 O que a testemunha diz — confirmado

- **Cidade fora da rota**: uma frase de "não vi ninguém" da lista de 12 em `DS:10a8` (a escolha exata, por tipo de local ou ao acaso, está a confirmar).
- **Cidade da rota** (`atual == 39a0`): `abertura + " " + pista`.
  - abertura: uma das 8 de `DS:13e6` ("My sources tell me", "I heard", "A suspicious person was here and"...);
  - pista: frase aleatória do recurso `próxima_cidade + 10 + tipo`, ou seja, fala da próxima cidade (moeda, bandeira, idioma, monumentos...);
  - opcionalmente **uma** pista sobre o suspeito (4.4).
- **Esconderijo final** (`atual == 399c`): um dos 4 avisos de `DS:161c` ("Rumor has it that the gang is in town somewhere", "You're getting too close, gumshoe...").

### 4.3 Custo de tempo — confirmado

`2356:0566` avança o relógio hora a hora. A primeira investigação numa cidade custa 2 h, a segunda 3 h e a terceira em diante 4 h (contador `265c`, reiniciado em 2 na chegada).

**Sono**: se a hora cai entre 23h e 7h, aparece "SLEEPING..." e o relógio avança 9 h (não acontece durante o voo).

**Prazo**: passou de domingo às 16h, o caso termina com o ladrão escapando ("slipped through your fingers").

### 4.4 Pistas sobre o suspeito — confirmado

Depois da pista de destino, o jogo começa numa categoria aleatória entre 5 (hobby, cabelo, característica, veículo, comida) e testa cada uma em rodízio: a categoria entra se `aleatorio(255) ≤ chance[tipo][categoria]`. No máximo uma entra por testemunha. As chances, em 0..255, ficam em `DS:26a9`:

| Tipo | hobby | cabelo | caract. | veículo | comida |
|---|---|---|---|---|---|
| 1 Bank | 0 | 32 | 40 | 48 | 0 |
| 2 Hotel | 0 | 32 | 32 | 48 | 48 |
| 3 Museum | 0 | 0 | 32 | 0 | 0 |
| 4 Sport Club | 64 | 48 | 48 | 56 | 48 |
| 5 Library | 32 | 32 | 32 | 0 | 0 |
| 6 Airport | 32 | 32 | 0 | 48 | 32 |
| 7 Harbor | 48 | 32 | 0 | 32 | 0 |
| 8 Riverfront | 48 | 0 | 32 | 32 | 0 |
| 9 Palace | 0 | 0 | 48 | 0 | 0 |
| 10 Stock Exchange | 0 | 32 | 32 | 40 | 0 |
| 11 Marketplace | 48 | 48 | 48 | 48 | 16 |
| 12 Foreign Ministry | 32 | 32 | 32 | 48 | 0 |

As frases de cada traço estão em `DS:0237` (5 ponteiros, um por categoria, cada um com uma lista por valor). Alguns valores não têm pista ("That's all I know."), por exemplo os hobbies music, skydiving e swimming. O pronome entra em `0x80` com "She"/"He" (`DS:2680`/`DS:2698`).

### 4.5 Esconderijo, capanga e prisão — confirmado em parte

- Na cidade final, o primeiro local visitado nunca é o esconderijo: o jogo sorteia um dos outros dois (`265a`). Entrar nele dispara o fim do caso.
- Na primeira entrada numa cidade da rota (que não seja a do crime) aparece **uma vez** o capanga: "A V.I.L.E. henchman! You must be on the right track." Nas cidades da rota também tocam animações de perigo sorteadas.
- Fim do caso (`20e3:0998`, máquina de estados ainda não decompilada por inteiro): sem mandado → o ladrão foge; mandado de outro → "we could all be sued for false arrest"; mandado certo → prisão, +1 caso e, se atingir o limite, promoção (com pergunta da proteção contra cópia). Prender a Carmen leva ao Hall of Fame.

### 4.6 Mandado (computador da Interpol) — confirmado

`1dd1:02f1`. O jogador marca até 5 traços: sexo, hobby, cabelo, característica e veículo (`-1` = não sabe). O computador filtra os 10 suspeitos. Se sobrar exatamente um, o mandado sai no nome dele. Se sobrar mais de um, lista os nomes. Se não sobrar nenhum: "The information provided eliminates all possible suspects." O mandado não custa horas no código analisado (a confirmar).

---

## 5. Pontos a confirmar

1. Sorteio da cidade do crime e do tesouro.
2. Tabela de promoção (1, 5, 12, 20, 30?) e quantas perguntas da proteção aparecem.
3. Formato das imagens (`10e4:7140`) e dos sons (`DIGISND.DAT`, `MIDISND.DAT`, recursos 200–229).
4. A máquina de estados de `20e3:0998`, que mistura salto por tabela e confundiu o Ghidra; precisa ser lida em assembly.
5. Recursos 100 e 101 de `CARMEN.DAT` e o primeiro `u16` do recurso 1 de `CITIES.DAT`.

## 6. O que isso significa para o núcleo em Godot

- O formato de dados próprio (JSON) pode espelhar exatamente estas estruturas: cidades com posição, locais, descrições, tesouros e pistas por tipo de local; suspeitos com 5 traços de mandado + traços só de pista; tabela de chances por tipo de local.
- O mapa aleatório e a rota gerada na hora são o que dá variedade ao jogo; vale manter os dois como parâmetros (número de vizinhos, distância mínima no grafo, saltos por patente).
- Tempo, sono e prazo são regras simples e ficam bem como um componente `Clock` separado.
- Para a paródia basta trocar o conteúdo: cidades, pistas, "suspeitos" (os membros da família) e os textos de abertura, e o agente da PF no lugar do detetive da ACME.
