# Formato dos pacotes de conteúdo

O núcleo em Godot (`game/core`) não sabe nada de cidades ou suspeitos: tudo vem de um pacote de conteúdo, uma pasta com três arquivos JSON. O pacote de teste fica em [`game/content/placeholder`](../game/content/placeholder). A paródia será outro pacote, e o leitor dos `.DAT` originais vai gerar um terceiro, no mesmo formato.

## Idiomas

O pacote declara os idiomas em `pack.json`:

```json
"languages": ["pt_BR", "en"],
"default_language": "pt_BR"
```

Qualquer texto pode ser uma string simples (igual em todos os idiomas, como "Paris") ou um objeto com uma entrada por idioma:

```json
"name": { "pt_BR": "Tóquio", "en": "Tokyo" }
```

Em listas, cada item é traduzido separadamente, para que as listas tenham o mesmo tamanho em todos os idiomas. Ao carregar o pacote (`ContentPack.load_dir(pasta, idioma)`) ou ao trocar de idioma (`set_language`), cada objeto desses vira a string do idioma escolhido. Um idioma que falta cai no padrão do pacote, e `"pt"` ou `"en_US"` são aceitos como `pt_BR` e `en`. `missing_translations()` lista os textos que não têm todos os idiomas, e os testes falham se a lista não estiver vazia.

As falas das testemunhas são guardadas como índices nas listas e só viram texto na hora de mostrar (`CaseSession.place_text`). Por isso trocar de idioma no meio do caso traduz a fala sem sortear outra.

Os textos da tela (botões, status, mensagens de fim de caso) não ficam no pacote. Eles estão em `game/i18n/ui.csv` e usam o sistema de traduções do Godot (`tr("CHAVE")`). Para um idioma novo, basta uma coluna nova no CSV e o código do idioma em `languages` no pacote.

## `pack.json`

| Campo | O que é |
|---|---|
| `rules.route_base_steps` | Saltos da rota = patente + este valor (original: 4). |
| `rules.boss_after_cases` | A partir de quantos casos resolvidos o alvo é a chefe (original: 29). |
| `rules.sex_trait` | Id do traço que define os pronomes. |
| `rules.graph.max_links` | Máximo de destinos de voo por cidade (original: 4). |
| `rules.graph.min_hops` | Só liga cidades que estejam a mais de N saltos no grafo (original: 4 com 30 cidades; o pacote provisório usa 2 porque tem só 12). |
| `rules.travel` | Horas de voo = `min(d / distance_per_hour + base_hours, max_hours)`, com `d = |Δx| + |Δy| + 1` (original: 40, 2, 7). |
| `rules.investigate` | A primeira investigação na cidade custa `first_hours`, e cada uma seguinte custa 1 h a mais, até `max_hours` (original: 2 e 4). |
| `rules.clock` | Dia e hora de início, prazo, e janela de sono: terminar uma ação fora de `[wake_hour, sleep_hour)` faz o agente dormir `sleep_hours`. |
| `ranks` | Lista de patentes `{name, cases}` em ordem; `cases` é o mínimo de casos para ter a patente. |
| `location_types` | Tipos de local `{id, name, group, witnesses, not_seen, clue_chance}`. Cada cidade mostra um local de cada `group`. `not_seen` são as falas fora da rota. `clue_chance` é a chance (0 a 255) de a testemunha dar uma pista daquele traço do suspeito. |
| `traits` | Traços `{id, name, warrant, values, clues}`. `warrant: true` entra no computador do mandado. `clues` tem as frases por valor; valor sem frase vira `texts.nothing_more`. |
| `texts` | `openers` (começo das falas com pista), `final_warnings` (cidade do esconderijo), `henchman`, `danger`, `nothing_more` e `pronouns`. |

### Pronomes

As frases podem usar `{chave}`, e a chave é trocada pela tabela `texts.pronouns[sexo]` do idioma atual. A tabela inteira é traduzida, porque cada idioma tem seus próprios marcadores. No pacote provisório, em português `{Ele}`, `{ele}` e `{dele}` viram "Ela", "ela" e "dela" quando o suspeito é mulher, e em inglês `{He}`, `{he}` e `{his}` viram "She", "she" e "her".

## `suspects.json`

```json
{ "id": "baronesa", "name": "Baronesa", "boss": false,
  "traits": { "sexo": "f", "hobby": "surfe", "cabelo": "loiro", "marca": "tatuagem", "veiculo": "moto", "comida": "frutos_do_mar" },
  "dossier": "..." }
```

Um único suspeito deve ter `boss: true`. Para o mandado funcionar, a combinação dos traços com `warrant: true` precisa ser diferente para cada suspeito.

## `cities.json`

```json
{ "id": "roma", "name": "Roma", "map": { "x": 159, "y": 33 },
  "description": ["..."], "treasures": ["..."],
  "locations": ["banco", "hotel", "aeroporto", "biblioteca", "mercado", "embaixada"],
  "clues": { "banco": ["{ele} trocou dinheiro por euros"], "...": [] } }
```

- `map` usa a escala do original: `x` de oeste para leste (0 a ~300) e `y` de norte para sul (0 a ~100).
- `clues[tipo]` são as pistas **sobre esta cidade**. Quem as diz é uma testemunha da cidade anterior da rota, num local daquele tipo.
- Cada grupo de `location_types` precisa ter pelo menos um tipo presente em `locations`.

## Como as regras usam isso

Ver [spec-original.md](spec-original.md), seções 3 e 4. Diferenças conhecidas em relação ao original:

- O original testa se os nomes das cidades cabem no mapa antes de ligar duas cidades (`1ea0:091e`). O núcleo pula esse teste, porque depende da tela.
- O sorteio dos locais da cidade usa uma lista de tipos válidos em vez de sortear e repetir, o que dá a mesma distribuição, mas não a mesma sequência de números aleatórios.
- As animações de perigo viram o evento `danger`, e cada tela decide como mostrar.
