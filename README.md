# Nhac-Nhac 🟢

Jogo de labirinto no estilo "come-pastilhas" feito para o console portátil **R36S**
(ArkOS, dArkOS, ROCKNIX, AmberELEC…), escrito em Lua com o [LÖVE](https://love2d.org) 11.5.

Você controla o **Nhac-Nhac**, um bichinho verde comilão. Coma todas as pastilhas do
labirinto sem ser pego pelos quatro besouros:

| Besouro | Comportamento |
|---------|---------------|
| **BRASA** (vermelho) | persegue você diretamente |
| **FADA** (rosa) | mira à sua frente e arma emboscadas |
| **GELO** (azul) | imprevisível, trabalha em dupla com a Brasa |
| **MEL** (laranja) | tímido: chega perto e foge para o canto |

- **Pastilha grande**: por alguns segundos os besouros ficam azuis e podem ser comidos (200, 400, 800, 1600 pontos).
- **Frutas** aparecem duas vezes por fase, valendo pontos extras.
- Vida extra aos 10.000 pontos. A cada fase o jogo fica mais rápido e o labirinto muda de cor.
- O recorde fica salvo no cartão SD.

## Controles

| Botão | Ação |
|-------|------|
| Direcional ou analógico | mover |
| START (ou A) | começar / pausar |
| SELECT (na pausa) | voltar ao menu |
| SELECT + START | sair do jogo |

## Como instalar no R36S

Requisito: o **PortMaster** (já vem no ArkOS/dArkOS/ROCKNIX). Ele fornece o LÖVE automaticamente.

1. Baixe [`dist/Nhac-Nhac-R36S.zip`](dist/Nhac-Nhac-R36S.zip) deste repositório.
2. Desligue o R36S, tire o cartão SD (o de jogos, partição `EASYROMS` no ArkOS) e coloque no computador.
3. Extraia o zip **dentro da pasta `ports`** do cartão. Deve ficar assim:
   ```
   ports/
   ├── Nhac-Nhac.sh
   └── nhacnhac/
       └── nhacnhac.love
   ```
4. Recoloque o cartão, ligue o console e abra **Ports → Nhac-Nhac**.
   (Se não aparecer, no EmulationStation use *Start → Game Settings → Update Games List* ou reinicie.)

Na primeira execução o PortMaster pode baixar o runtime `love_11.5` — deixe o Wi-Fi ligado
ou instale qualquer outro port de LÖVE antes pelo próprio PortMaster.
Se algo der errado, veja o arquivo `ports/nhacnhac/log.txt`.

## Versão Atari 2600 (`.a26`)

Versão para Atari 2600 com **o mesmo labirinto** da versão LÖVE. Roda no
emulador de Atari do R36S (Stella), como qualquer ROM `.a26`, sem PortMaster.

**Instalar:** copie [`dist/Nhac-Nhac.a26`](dist/Nhac-Nhac.a26) para a pasta
**`atari2600`** do cartão SD de jogos e abra pelo menu **Atari 2600**.

**Como jogar:** direcional para mover, **A** (ou START) para começar.
Coma as 167 pastilhas e fuja dos dois besouros (vermelho e rosa). As 4
**pastilhas que piscam** deixam os besouros azuis por alguns segundos: aí dá
para comê-los (+20 pontos), e eles voltam para a toca. O corredor do meio
atravessa as bordas da tela. No alto: pontos (esquerda) e fase (direita).
Embaixo: vidas. A cada fase os besouros ficam mais rápidos e o labirinto muda de cor.

Detalhes técnicos: cartucho de 8 KB com 128 bytes extras de RAM (formato
F8SC/"Superchip", detectado automaticamente pelo Stella). Como o Atari só
desenha um besouro por vez, os dois aparecem alternadamente (piscando).
O código-fonte está em `atari/` (assembly 6502); o labirinto é lido de
`src/main.lua`. Para montar: `cd atari && python3 gen.py && dasm nhacnhac.asm -f3 -onhacnhac.a26`.

## Jogar no computador

Instale o LÖVE 11.x e rode `love src` (setas/WASD para mover, Enter para começar, Esc para pausar).

## Estrutura

- `src/` – código do jogo (`main.lua`, `conf.lua`); gráficos e sons são gerados pelo código.
- `port/Nhac-Nhac.sh` – inicializador para o PortMaster.
- `build.sh` – gera `port/nhacnhac/nhacnhac.love` e `dist/Nhac-Nhac-R36S.zip`.
