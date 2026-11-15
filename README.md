# Guloso 🟢

Jogo de labirinto no estilo "come-pastilhas" feito para o console portátil **R36S**
(ArkOS, dArkOS, ROCKNIX, AmberELEC…), escrito em Lua com o [LÖVE](https://love2d.org) 11.5.

Você controla o **Guloso**, um bichinho verde comilão. Coma todas as pastilhas do
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

1. Baixe [`dist/Guloso-R36S.zip`](dist/Guloso-R36S.zip) deste repositório.
2. Desligue o R36S, tire o cartão SD (o de jogos, partição `EASYROMS` no ArkOS) e coloque no computador.
3. Extraia o zip **dentro da pasta `ports`** do cartão. Deve ficar assim:
   ```
   ports/
   ├── Guloso.sh
   └── guloso/
       └── guloso.love
   ```
4. Recoloque o cartão, ligue o console e abra **Ports → Guloso**.
   (Se não aparecer, no EmulationStation use *Start → Game Settings → Update Games List* ou reinicie.)

Na primeira execução o PortMaster pode baixar o runtime `love_11.5` — deixe o Wi-Fi ligado
ou instale qualquer outro port de LÖVE antes pelo próprio PortMaster.
Se algo der errado, veja o arquivo `ports/guloso/log.txt`.

## Jogar no computador

Instale o LÖVE 11.x e rode `love src` (setas/WASD para mover, Enter para começar, Esc para pausar).

## Estrutura

- `src/` – código do jogo (`main.lua`, `conf.lua`); gráficos e sons são gerados pelo código.
- `port/Guloso.sh` – inicializador para o PortMaster.
- `build.sh` – gera `port/guloso/guloso.love` e `dist/Guloso-R36S.zip`.
