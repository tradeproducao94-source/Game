#!/bin/bash
# Nhac-Nhac - inicializador para R36S (ArkOS, dArkOS, ROCKNIX, AmberELEC...) via PortMaster

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/nhacnhac"
cd "$GAMEDIR" || exit 1
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Recorde fica salvo dentro da pasta do jogo
export XDG_DATA_HOME="$GAMEDIR/savedata"
mkdir -p "$XDG_DATA_HOME"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Usa o runtime LÖVE 11.5 do PortMaster (baixa automaticamente se faltar)
runtime="love_11.5"
LOVE_BINARY=""
if [ ! -f "$controlfolder/libs/${runtime}.squashfs" ] && [ -f "$controlfolder/harbourmaster" ]; then
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${runtime}.squashfs"
fi
if [ -f "$controlfolder/libs/${runtime}.squashfs" ]; then
  $ESUDO mkdir -p "$controlfolder/libs/${runtime}"
  if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "$controlfolder/libs/${runtime}" 2>/dev/null
  fi
  $ESUDO mount "$controlfolder/libs/${runtime}.squashfs" "$controlfolder/libs/${runtime}"
  LOVE_BINARY="$controlfolder/libs/${runtime}/love"
  export LD_LIBRARY_PATH="$controlfolder/libs/${runtime}/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"
fi

# Alternativa: LÖVE instalado no sistema
if [ -z "$LOVE_BINARY" ] || [ ! -x "$LOVE_BINARY" ]; then
  LOVE_BINARY="$(command -v love)"
fi
if [ -z "$LOVE_BINARY" ]; then
  echo "LOVE nao encontrado. Instale/atualize o PortMaster."
  type pm_message >/dev/null 2>&1 && pm_message "LOVE nao encontrado. Atualize o PortMaster."
  sleep 5
  exit 1
fi

$GPTOKEYB "love" &
type pm_platform_helper >/dev/null 2>&1 && pm_platform_helper "$LOVE_BINARY"
"$LOVE_BINARY" "$GAMEDIR/nhacnhac.love"

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$controlfolder/libs/${runtime}" 2>/dev/null
fi
type pm_finish >/dev/null 2>&1 && pm_finish
