# Controles no PC

O jogo e um titulo Xbox: ele le um controle. O VIctory traduz teclado e mouse
para um controle virtual (o "pad de reserva"), ativo quando nenhum controle
XInput/DualSense esta conectado.

## Como abrir

Uma pasta so: **`C:\GTA6-PC`**. Tudo mora la dentro — runtime, Agility SDK,
cache, saves, logs e os documentos.

1. Atalho **GTA6** na Area de Trabalho, ou
2. `C:\GTA6-PC\GTA6.exe`.

O launcher tem dois perfis: **JOGAR 1080p** (Series S, o mais leve) e
**JOGAR 1440p** (renderiza 1080p, entrega 1440p). Tambem abre os controles,
a pasta de logs, troca a pasta do jogo e aquece o cache de shaders. O GTA6.exe
extrai o runtime de dentro dele mesmo se faltar arquivo; a pasta pode ser
movida ou copiada inteira.

Os `.cmd` antigos (`JOGAR-1080P.cmd`, `JOGAR-1440P.cmd`) continuam valendo.

## Teclado e mouse

| entrada | controle Xbox | acao no jogo |
|---|---|---|
| W / A / S / D | analogico esquerdo | mover |
| mouse | analogico direito | camera |
| botao esquerdo do mouse | RT | atirar / acelerar |
| botao direito do mouse | LT | mirar / frear |
| Espaco ou Enter | A | pular / confirmar |
| Backspace | B | cancelar |
| Ctrl esquerdo ou direito | B | agachar / golpe |
| R | X | recarregar / acao |
| X | X | acao |
| Y | Y | trocar arma |
| E ou F | Y | entrar / sair de veiculo, interagir |
| setas | D-pad | menus e telefone |
| Q | LB | roda de armas |
| V | RB | cobertura / camera |
| Shift esquerdo | L3 | correr |
| H | R3 | olhar para tras |
| Z | LT | mirar (alternativa sem mouse) |
| C | RT | acelerar (alternativa sem mouse) |
| I / J / K / L | analogico direito | camera (alternativa sem mouse) |
| Esc | Menu | pausa |
| Tab | View | mapa |

O mouse fica preso no centro da janela enquanto o jogo tem foco. Ao perder o
foco (Alt+Tab, por exemplo), o cursor volta ao normal.

## Ajustes por variavel de ambiente

| variavel | padrao | efeito |
|---|---|---|
| `VICTORY_MOUSE_SENSITIVITY` | `0.05` | pixels de mouse por unidade de deflexao do analogico direito |
| `VICTORY_MOUSE_LOOK` | `1` | `0` solta o cursor (mouse nao controla a camera) |

Sensibilidade: 0.02 = camera lenta e precisa; 0.05 = padrao; 0.10 = camera
rapida. O valor e lido uma vez por execucao.

## Controle de verdade

Se um controle XInput (Xbox) ou DualSense estiver conectado, ele continua
funcionando. Teclado e mouse sao somados ao primeiro pad XInput: os dois
funcionam ao mesmo tempo, sem desconectar nada. O teclado tambem segue
funcionando como teclado (texto, atalhos do sistema).

## Teclas roteirizadas (diagnostico)

`VICTORY_KEYS=<segundos>:<tecla>,...` segura cada tecla por 0.2 s, com ou sem
foco. Teclas aceitas: letra, digito, `Enter`, `Esc`, `Tab`, `Back`, `Up`,
`Down`, `Left`, `Right`.

Exemplo: `VICTORY_KEYS=10:Enter,18:Enter` confirma a tela inicial duas vezes.
