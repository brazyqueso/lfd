#!/usr/bin/env bash
# LFD(1) — LLMs for Dummies. Made by Pakun.
# Usage (after install):  sudo lfd
# Version: 0.7.0
set -euo pipefail

LFD_HOME="${LFD_HOME:-$HOME/.lfd}"
if [[ ! -d $LFD_HOME && -d $HOME/.aicc ]]; then
  LFD_HOME="$HOME/.aicc"
fi
AICC_HOME="$LFD_HOME"
AICC_LOG="$LFD_HOME/lfd.log"
AICC_CONF="$LFD_HOME/config"
AICC_VENV="$LFD_HOME/venv"
AICC_MODELS_DIR="$LFD_HOME/modelfiles"
AICC_BIN="${LFD_BIN:-$HOME/.local/bin}"
AICC_TITLE="LFD"
AICC_VER="0.7.0"
AICC_DIALOGRC="$LFD_HOME/dialogrc"
LFD_AUTHOR="Pakun"

mkdir -p "$LFD_HOME" "$AICC_MODELS_DIR" "$AICC_BIN"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$AICC_LOG"; }

write_dialogrc() {
  cat >"$AICC_DIALOGRC" <<'RC'
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = OFF
use_shadow = OFF
use_colors = ON
screen_color = (RED,BLACK,ON)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (RED,BLACK,OFF)
title_color = (WHITE,BLACK,ON)
border_color = (RED,BLACK,ON)
border2_color = (RED,BLACK,ON)
button_active_color = (BLACK,RED,ON)
button_inactive_color = (RED,BLACK,OFF)
button_key_active_color = (WHITE,RED,ON)
button_key_inactive_color = (WHITE,BLACK,ON)
button_label_active_color = (BLACK,RED,ON)
button_label_inactive_color = (RED,BLACK,OFF)
inputbox_color = (RED,BLACK,OFF)
inputbox_border_color = (RED,BLACK,ON)
searchbox_color = (RED,BLACK,OFF)
searchbox_title_color = (WHITE,BLACK,ON)
searchbox_border_color = (RED,BLACK,ON)
position_indicator_color = (RED,BLACK,ON)
menubox_color = (RED,BLACK,OFF)
menubox_border_color = (RED,BLACK,ON)
menubox_border2_color = (RED,BLACK,ON)
item_color = (RED,BLACK,OFF)
item_selected_color = (BLACK,RED,ON)
tag_color = (WHITE,BLACK,ON)
tag_selected_color = (BLACK,RED,ON)
tag_key_color = (WHITE,BLACK,ON)
tag_key_selected_color = (BLACK,RED,ON)
check_color = (RED,BLACK,OFF)
check_selected_color = (BLACK,RED,ON)
uarrow_color = (RED,BLACK,ON)
darrow_color = (RED,BLACK,ON)
itemhelp_color = (RED,BLACK,OFF)
form_active_text_color = (BLACK,RED,ON)
form_text_color = (RED,BLACK,OFF)
form_item_readonly_color = (WHITE,BLACK,ON)
gauge_color = (BLACK,RED,ON)
RC
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

need_dialog() {
  if ! need_cmd dialog; then
    echo "Installing dialog..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dialog
  fi
  write_dialogrc
  export DIALOGRC="$AICC_DIALOGRC"
  export NEWT_COLORS='root=red,black;border=red,black;window=red,black;title=white,black;checkbox=red,black;actcheckbox=black,red;listbox=red,black;actlistbox=black,red;button=black,red;actbutton=black,red'
}

d() { command dialog --no-shadow --colors "$@"; }

die_dialog() { d --title "[ error ]" --msgbox "${1:-unknown error}" 14 72 || true; }
info_dialog() { d --title "[ ok ]" --msgbox "$1" 14 72 || true; }
yesno() { d --title "[ ? ]" --yesno "$1" 10 70; }

load_conf() {
  [[ -f "$AICC_CONF" ]] && # shellcheck disable=SC1090
    source "$AICC_CONF" || true
  OPENROUTER_KEY="${OPENROUTER_KEY:-}"
  HF_TOKEN="${HF_TOKEN:-}"
  DEFAULT_OLLAMA_MODEL="${DEFAULT_OLLAMA_MODEL:-}"
  LAST_OI_MODEL="${LAST_OI_MODEL:-}"
  OLLAMA_CTX="${OLLAMA_CTX:-8192}"
  PREFERRED_UI="${PREFERRED_UI:-chat}"
}

save_conf() {
  cat >"$AICC_CONF" <<EOF
OPENROUTER_KEY="${OPENROUTER_KEY:-}"
HF_TOKEN="${HF_TOKEN:-}"
DEFAULT_OLLAMA_MODEL="${DEFAULT_OLLAMA_MODEL:-}"
LAST_OI_MODEL="${LAST_OI_MODEL:-}"
OLLAMA_CTX="${OLLAMA_CTX:-8192}"
PREFERRED_UI="${PREFERRED_UI:-chat}"
EOF
  chmod 600 "$AICC_CONF"
}

# ---------- hardware ----------
ram_gb() {
  awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0
}
free_disk_gb() {
  df -BG --output=avail / | awk 'NR==2 {gsub(/G/,""); print $1}'
}
cpu_model() { awk -F: '/model name/ {gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo; }
nproc_n() { nproc 2>/dev/null || echo 1; }

gpu_line() {
  if need_cmd nvidia-smi; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1
  elif [[ -e /dev/dri/renderD128 ]]; then
    echo "DRM GPU present (Intel/AMD — Ollama CPU+Vulkan may work)"
  else
    echo "No discrete GPU detected (CPU inference)"
  fi
}

recommend_model() {
  local gb; gb=$(ram_gb)
  if (( gb >= 48 )); then echo "qwen2.5-coder:32b"
  elif (( gb >= 24 )); then echo "qwen2.5-coder:14b"
  elif (( gb >= 14 )); then echo "qwen2.5-coder:7b"
  elif (( gb >= 8 )); then echo "qwen2.5-coder:3b"
  else echo "qwen2.5:1.5b"
  fi
}

hw_report() {
  cat <<EOF
CPU:     $(cpu_model)
Cores:   $(nproc_n)
RAM:     $(ram_gb) GB
Free disk on /: $(free_disk_gb) GB
GPU:     $(gpu_line)

Suggested first model: $(recommend_model)

Rule of thumb (Q4_K_M):
  1.5–3B  →  6–8 GB RAM
  7–8B    →  10–16 GB
  14B     →  18–24 GB
  32B     →  36–48 GB
Leave ~4 GB for the OS on Kali.
EOF
}

# ---------- packages ----------
have_python() { need_cmd python3; }
have_ollama() { need_cmd ollama; }
have_oi() { [[ -x "$AICC_VENV/bin/interpreter" ]]; }
have_owui() { [[ -x "$AICC_VENV/bin/open-webui" ]] || need_cmd open-webui; }
have_oterm() { [[ -x "$AICC_VENV/bin/oterm" ]] || need_cmd oterm; }
have_docker() { need_cmd docker; }
ollama_up() { have_ollama && curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; }

install_kali_deps() {
  d --infobox "Installing Kali base packages (python, pip, venv, curl, git, build tools)..." 6 70
  sudo apt-get update -qq >>"$AICC_LOG" 2>&1 || true
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-venv python3-pip python3-dev \
    curl wget git ca-certificates \
    build-essential gcc g++ make \
    dialog jq unzip \
    pciutils lshw \
    >>"$AICC_LOG" 2>&1 || {
      die_dialog "apt install failed. Last log:\n$(tail -15 "$AICC_LOG")"
      return 1
    }
  info_dialog "Base packages installed."
}

install_nvidia_hint() {
  d --msgbox "NVIDIA on Kali (optional, big speedup):

1. apt install nvidia-driver nvidia-cuda-toolkit
2. Reboot
3. nvidia-smi should show the card
4. Reinstall / restart Ollama so it picks up CUDA

AMD: try ollama with Vulkan (recent Ollama builds).
No GPU: 7B Q4 is still usable on 16 GB RAM." 18 70
}

# ---------- ollama ----------
install_ollama() {
  if have_ollama; then
    info_dialog "Ollama already installed:\n$(ollama --version 2>/dev/null || true)"
    return 0
  fi
  d --infobox "Installing Ollama from official script..." 5 55
  if curl -fsSL https://ollama.com/install.sh | sh >>"$AICC_LOG" 2>&1; then
    start_ollama_daemon
    info_dialog "Ollama installed."
  else
    die_dialog "Ollama install failed. See log."
    return 1
  fi
}

start_ollama_daemon() {
  if ollama_up; then
    return 0
  fi
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q '^ollama.service'; then
    sudo systemctl enable --now ollama >>"$AICC_LOG" 2>&1 || true
  fi
  if ! ollama_up; then
    nohup ollama serve >>"$AICC_HOME/ollama-serve.log" 2>&1 &
    sleep 2
  fi
  if ollama_up; then
    return 0
  fi
  die_dialog "Could not start Ollama daemon on :11434"
  return 1
}

update_ollama() {
  d --infobox "Re-running official Ollama installer (updates in place)..." 5 60
  curl -fsSL https://ollama.com/install.sh | sh >>"$AICC_LOG" 2>&1 \
    && info_dialog "Update attempted.\n$(ollama --version 2>/dev/null)" \
    || die_dialog "Update failed"
}

list_local_models() {
  have_ollama || return 0
  ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1}'
}

# name|tag|ram|mode|blurb
# OS   = uncensored / agent-style (tools, fewer refusals, meant to DO things)
# CHAT = normal aligned chatbot
MODEL_CATALOG="$(cat <<'CAT'
Qwen2.5 Coder 1.5B|qwen2.5-coder:1.5b|~2G|OS|tiny agent coder
Qwen2.5 Coder 3B|qwen2.5-coder:3b|~3G|OS|small agent coder
Qwen2.5 Coder 7B|qwen2.5-coder:7b|~5G|OS|default agent coder
Qwen2.5 Coder 14B|qwen2.5-coder:14b|~10G|OS|strong agent coder
Qwen2.5 Coder 32B|qwen2.5-coder:32b|~20G|OS|heavy agent coder
DeepSeek Coder V2 16B|deepseek-coder-v2:16b|~12G|OS|agent coder
StarCoder2 7B|starcoder2:7b|~5G|OS|agent coder
StarCoder2 15B|starcoder2:15b|~10G|OS|agent coder
CodeGemma 7B|codegemma:7b|~5G|OS|agent coder
Granite Code 8B|granite-code:8b|~5G|OS|agent coder
Yi Coder 9B|yi-coder:9b|~6G|OS|agent coder
Codestral 22B|codestral:22b|~14G|OS|heavy agent coder
Hermes 3 8B|hermes3:8b|~5G|OS|uncensored agent + tools
Nous Hermes 2 10.7B|nous-hermes2:10.7b|~7G|OS|uncensored agent
OpenHermes 2.5 7B|openhermes:7b-mistral-v2.5-q4_K_M|~5G|OS|uncensored agent
Wizard Vicuna Uncensored 7B|wizard-vicuna-uncensored:7b|~5G|OS|uncensored agent
Wizard Vicuna Uncensored 13B|wizard-vicuna-uncensored:13b|~8G|OS|uncensored agent
Llama2 Uncensored 7B|llama2-uncensored:7b|~5G|OS|uncensored agent
WizardLM Uncensored 13B|wizardlm-uncensored:13b|~8G|OS|uncensored agent
Command-R 35B|command-r:35b|~22G|OS|agent + tools (needs RAM)
Qwen2.5 0.5B|qwen2.5:0.5b|~1G|CHAT|toy chat
Qwen2.5 1.5B|qwen2.5:1.5b|~2G|CHAT|tiny chat
Qwen2.5 3B|qwen2.5:3b|~3G|CHAT|small chat
Qwen2.5 7B|qwen2.5:7b|~5G|CHAT|general chat
Qwen2.5 14B|qwen2.5:14b|~10G|CHAT|strong chat
Llama 3.2 1B|llama3.2:1b|~2G|CHAT|tiny chat
Llama 3.2 3B|llama3.2:3b|~3G|CHAT|fast chat
Llama 3.1 8B|llama3.1:8b|~5G|CHAT|general chat
Llama 3.1 70B|llama3.1:70b|~40G|CHAT|huge chat
Llama 3.3 70B|llama3.3:70b|~40G|CHAT|huge chat
Mistral 7B|mistral:7b|~5G|CHAT|classic chat
Mixtral 8x7B|mixtral:8x7b|~26G|CHAT|moe chat
Phi-3 mini|phi3:mini|~3G|CHAT|small chat
Phi-4 mini|phi4-mini|~4G|CHAT|small chat
Phi-4|phi4|~9G|CHAT|chat
Gemma2 2B|gemma2:2b|~2G|CHAT|tiny chat
Gemma2 9B|gemma2:9b|~6G|CHAT|general chat
Gemma2 27B|gemma2:27b|~16G|CHAT|strong chat
DeepSeek R1 1.5B|deepseek-r1:1.5b|~2G|CHAT|tiny reasoner
DeepSeek R1 7B|deepseek-r1:7b|~5G|CHAT|reasoner chat
DeepSeek R1 8B|deepseek-r1:8b|~6G|CHAT|reasoner chat
DeepSeek R1 14B|deepseek-r1:14b|~10G|CHAT|reasoner chat
Zephyr 7B|zephyr:7b|~5G|CHAT|instruct chat
OpenChat 7B|openchat:7b|~5G|CHAT|instruct chat
Starling 7B|starling-lm:7b|~5G|CHAT|instruct chat
Vicuna 7B|vicuna:7b|~5G|CHAT|classic chat
Orca Mini 3B|orca-mini:3b|~3G|CHAT|tiny chat
Neural Chat 7B|neural-chat:7b|~5G|CHAT|intel chat
SmolLM 1.7B|smollm:1.7b|~2G|CHAT|tiny chat
TinyLlama 1.1B|tinyllama:1.1b|~1G|CHAT|toy chat
Yi 6B|yi:6b|~4G|CHAT|chat
Yi 34B|yi:34b|~20G|CHAT|strong chat
Solar 10.7B|solar:10.7b|~7G|CHAT|chat
GLM4 9B|glm4:9b|~6G|CHAT|chat
Qwen2 7B|qwen2:7b|~5G|CHAT|older qwen chat
Llava 7B|llava:7b|~5G|CHAT|vision + chat
Moondream|moondream|~2G|CHAT|tiny vision chat
CAT
)"

mode_tag() {
  case "$1" in
    OS) echo "[OS controlled]" ;;
    CHAT) echo "[Chat only]" ;;
    *) echo "" ;;
  esac
}

guess_mode() {
  local t="${1,,}"
  case "$t" in
    *uncensored*|*hermes*|*openhermes*|*wizard-vicuna*|*command-r*) echo OS ;;
    *coder*|*codestral*|*starcoder*|*granite-code*|*codegemma*) echo OS ;;
    clean-coder|purple-coder|silent-coder|lfd-os|lfd-agent) echo OS ;;
    *) echo CHAT ;;
  esac
}

pick_from_catalog() {
  local items=() name tag ram mode blurb
  while IFS='|' read -r name tag ram mode blurb; do
    [[ -z ${name:-} ]] && continue
    items+=("$tag" "$(mode_tag "$mode")  $name  $ram  $blurb")
  done <<<"$MODEL_CATALOG"
  items+=("custom" "type any ollama library tag")
  d --stdout --title "[ catalog ]" --menu "OS controlled = uncensored agent (does things, few refusals)\nChat only = normal filtered chatbot" 22 88 14 "${items[@]}"
}

pull_model() {
  local tag="${1:-}"
  [[ -z $tag ]] && tag=$(pick_from_catalog) || true
  [[ -z ${tag:-} ]] && return 1
  if [[ $tag == custom ]]; then
    tag=$(d --stdout --inputbox "Ollama library tag (example: llama3.2:3b):" 8 70) || return 1
  fi
  [[ -z $tag ]] && return 1
  start_ollama_daemon || return 1
  clear
  echo "=== Pulling $tag ==="
  echo "This is the slow part. First time downloads several GB."
  echo
  if ollama pull "$tag"; then
    DEFAULT_OLLAMA_MODEL="$tag"
    save_conf
    echo
    echo "OK. Default model set to $tag"
    read -r -p "Enter to continue..."
    return 0
  fi
  echo "Pull failed."
  read -r -p "Enter to continue..."
  return 1
}

quick_test() {
  local tag="${DEFAULT_OLLAMA_MODEL:-}"
  if [[ -z $tag ]]; then
    tag=$(list_local_models | head -1)
  fi
  [[ -n $tag ]] || { die_dialog "No model pulled yet."; return 1; }
  start_ollama_daemon || return 1
  clear
  echo "Testing $tag with a one-line prompt..."
  ollama run "$tag" "Reply with exactly: READY"
  echo
  read -r -p "Enter to continue..."
}

pick_local_model() {
  local models=() m
  while IFS= read -r m; do
    [[ -n $m ]] && models+=("$m" "$(mode_tag "$(guess_mode "$m")")")
  done < <(list_local_models)
  if [[ ${#models[@]} -eq 0 ]]; then
    yesno "No local models. Pull $(recommend_model) now?" || return 1
    pull_model "$(recommend_model)" || return 1
    models=("$(recommend_model)" "$(mode_tag OS)")
  fi
  d --stdout --title "[ model ]" --menu "pick a model" 18 72 12 "${models[@]}"
}

run_ollama_chat() {
  have_ollama || { die_dialog "Install Ollama first."; return; }
  start_ollama_daemon || return
  local pick
  pick=$(pick_local_model) || return
  [[ -z $pick ]] && return
  DEFAULT_OLLAMA_MODEL="$pick"
  save_conf
  if [[ $(guess_mode "$pick") == OS ]]; then
    local how
    how=$(d --stdout --title "[ $pick ]" --menu \
      "OS controlled models are uncensored agents.\nTo actually execute on Kali, pick the agent runtime." 14 74 4 \
      os "[OS controlled]  agent runtime" \
      chat "[Chat only]  just talk") || return
    if [[ $how == os ]]; then
      launch_os_agent "$pick"
      return
    fi
  fi
  clear
  echo "CHAT ONLY — $pick cannot touch the OS from here."
  echo "/bye to quit"
  echo
  ollama run "$pick" || true
  read -r -p "Enter to return to menu..."
}

launch_os_agent() {
  local pick="${1:-}"
  have_ollama || { die_dialog "Install Ollama first."; return; }
  start_ollama_daemon || return
  if [[ -z $pick ]]; then
    pick=$(pick_local_model) || return
  fi
  [[ -z $pick ]] && return
  DEFAULT_OLLAMA_MODEL="$pick"
  save_conf
  have_oi || {
    yesno "OS control needs Open Interpreter (local, no API key).\nInstall it into $AICC_VENV now?" || return
    pip_tool open-interpreter || { die_dialog "install failed — see log"; return; }
  }
  # shellcheck disable=SC1091
  source "$AICC_VENV/bin/activate"
  clear
  echo "=============================================="
  echo " LFD  —  LLMs for Dummies   made by $LFD_AUTHOR"
  echo " OS CONTROLLED agent   model=$pick"
  echo " Uncensored agent runtime on THIS Kali box."
  echo " Example:  open firefox"
  echo " No API key. Local Ollama."
  echo "=============================================="
  echo
  # newer OI: --os  older: --local
  if interpreter --help 2>/dev/null | grep -q -- '--os'; then
    interpreter --os --offline --model "ollama/$pick" || true
  else
    interpreter --local --offline --model "ollama/$pick" || interpreter --local --model "ollama/$pick" || true
  fi
  echo
  read -r -p "Enter to return to menu..."
}

write_modelfile() {
  local name="$1" from="$2" system="$3"
  mkdir -p "$AICC_MODELS_DIR/$name"
  cat >"$AICC_MODELS_DIR/$name/Modelfile" <<EOF
FROM $from

PARAMETER num_ctx ${OLLAMA_CTX}

SYSTEM """
$system
"""
EOF
}

create_helper_models() {
  have_ollama || { die_dialog "Install Ollama first."; return; }
  local base
  base=$(d --stdout --inputbox "Base model (must already be pulled):" 8 72 \
    "${DEFAULT_OLLAMA_MODEL:-qwen2.5-coder:7b}") || return
  [[ -z $base ]] && return
  write_modelfile clean-coder "$base" \
'You are a helpful coding assistant.
When the user asks for code:
- Output ONLY the pure code
- Do NOT wrap it in markdown code blocks (no triple backticks)
- Do NOT add explanations unless the user asks
Be concise.'
  write_modelfile purple-coder "$base" \
'You are a helpful coding assistant.
When outputting code, wrap ONLY the code between ANSI magenta and reset:
start with ESC[35m and end with ESC[0m.
No markdown triple backticks. Explanations stay unstyled.'
  write_modelfile silent-coder "$base" \
'You output code and nothing else. No greetings, no markdown fences, no commentary.'

  start_ollama_daemon || return
  local n
  for n in clean-coder purple-coder silent-coder; do
    d --infobox "Creating $n ..." 5 40
    if ! (cd "$AICC_MODELS_DIR/$n" && ollama create "$n" -f Modelfile >>"$AICC_LOG" 2>&1); then
      die_dialog "Failed creating $n"
      return
    fi
  done
  info_dialog "Created:\n- clean-coder\n- purple-coder\n- silent-coder\n\nLaunch from Ollama chat."
}

delete_model() {
  local models=() m pick
  while IFS= read -r m; do
    [[ -n $m ]] && models+=("$m" "")
  done < <(list_local_models)
  [[ ${#models[@]} -eq 0 ]] && { die_dialog "No models."; return; }
  pick=$(d --stdout --menu "Delete model (frees disk)" 18 70 12 "${models[@]}") || return
  yesno "Delete $pick ?" || return
  ollama rm "$pick" >>"$AICC_LOG" 2>&1 || die_dialog "Delete failed"
}

# ---------- python stack ----------
ensure_venv() {
  have_python || { die_dialog "Install base packages first."; return 1; }
  if [[ ! -d $AICC_VENV ]]; then
    d --infobox "Creating Python venv in $AICC_VENV" 5 60
    python3 -m venv "$AICC_VENV" >>"$AICC_LOG" 2>&1 || { die_dialog "venv failed"; return 1; }
  fi
  # shellcheck disable=SC1091
  source "$AICC_VENV/bin/activate"
  pip install -U pip wheel setuptools >>"$AICC_LOG" 2>&1 || true
}

pip_tool() {
  ensure_venv || return 1
  local pkg="$1"
  d --infobox "pip install $pkg ..." 5 50
  pip install "$pkg" >>"$AICC_LOG" 2>&1
}

save_key() {
  local var="$1" label="$2"
  local cur="${!var:-}"
  local k
  k=$(d --stdout --insecure --passwordbox "$label" 8 72 "$cur") || return
  printf -v "$var" '%s' "$k"
  save_conf
  info_dialog "Saved."
}

launch_open_interpreter() {
  have_oi || { yesno "Open Interpreter not installed. Install now?" && pip_tool open-interpreter || return; }
  # shellcheck disable=SC1091
  source "$AICC_VENV/bin/activate"
  local mode
  mode=$(d --stdout --menu "Open Interpreter" 13 70 5 \
    local "Local Ollama" \
    openrouter "OpenRouter cloud" \
    default "Plain interpreter") || return
  case "$mode" in
    local)
      local model
      model=$(d --stdout --inputbox "ollama model:" 8 60 "${DEFAULT_OLLAMA_MODEL:-llama3.1:8b}") || return
      clear
      interpreter --local --model "ollama/$model" || true
      ;;
    openrouter)
      [[ -n ${OPENROUTER_KEY:-} ]] || { die_dialog "Save an OpenRouter key first."; return; }
      export OPENAI_API_KEY="$OPENROUTER_KEY"
      export OPENAI_API_BASE="https://openrouter.ai/api/v1"
      local model
      model=$(d --stdout --inputbox "OpenRouter model id:" 8 72 \
        "${LAST_OI_MODEL:-meta-llama/llama-3.1-8b-instruct}") || return
      LAST_OI_MODEL="$model"; save_conf
      clear
      interpreter --model "$model" || true
      ;;
    default) clear; interpreter || true ;;
  esac
  read -r -p "Enter to return..."
}

launch_open_webui() {
  have_owui || { yesno "Install Open WebUI into the venv?" && pip_tool open-webui || return; }
  start_ollama_daemon || true
  # shellcheck disable=SC1091
  source "$AICC_VENV/bin/activate"
  clear
  echo "Open WebUI → http://127.0.0.1:8080"
  echo "First visit creates an admin account (local only)."
  echo "Ctrl+C stops it."
  echo
  open-webui serve --host 127.0.0.1 --port 8080 || true
  read -r -p "Enter to return..."
}

launch_oterm() {
  have_oterm || { yesno "Install oterm?" && pip_tool oterm || return; }
  # shellcheck disable=SC1091
  source "$AICC_VENV/bin/activate"
  clear
  oterm || true
  read -r -p "Enter to return..."
}

launch_webui_docker() {
  if ! have_docker; then
    die_dialog "Docker is not installed.

Kali:
  sudo apt install docker.io
  sudo usermod -aG docker \$USER
  newgrp docker   # or log out/in"
    return
  fi
  start_ollama_daemon || true
  clear
  echo "Starting Open WebUI container (port 3000) talking to local Ollama..."
  docker rm -f open-webui >/dev/null 2>&1 || true
  docker run -d --name open-webui \
    --add-host=host.docker.internal:host-gateway \
    -p 3000:8080 \
    -v open-webui:/app/backend/data \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    ghcr.io/open-webui/open-webui:main
  echo
  echo "Browser: http://127.0.0.1:3000"
  read -r -p "Enter to return..."
}

# ---------- one-click wizard ----------
wizard_get_llm() {
  d --msgbox "LFD — LLMs for Dummies
Made by $LFD_AUTHOR

1. Kali packages
2. Ollama
3. Model for $(ram_gb) GB RAM → $(recommend_model)
4. Optional smoke test
5. Chat or OS agent

No API key. Cancel anytime." 16 70 || return

  install_kali_deps || return
  install_ollama || return
  start_ollama_daemon || return

  local rec choice
  rec=$(recommend_model)
  choice=$(d --stdout --title "[ pull ]" --menu "Which model?" 16 78 6 \
    "$rec" "[OS controlled]  recommended for this box" \
    "qwen2.5-coder:7b" "[OS controlled]  coding 7B" \
    "llama3.2:3b" "[Chat only]  small + fast" \
    "custom" "open full catalog") || return
  if [[ $choice == custom ]]; then
    pull_model || return
  else
    pull_model "$choice" || return
  fi
  yesno "Create clean-coder / purple-coder wrapper models?" && create_helper_models
  yesno "Run a 1-line smoke test?" && quick_test
  local how
  how=$(d --stdout --menu "How do you want to talk to it?" 14 70 5 \
    os "[OS controlled] agent that runs commands" \
    chat "[Chat only] ollama run" \
    oterm "oterm (still chat only)" \
    webui "Open WebUI (still chat only)") || return
  case "$how" in
    os) launch_os_agent "${DEFAULT_OLLAMA_MODEL:-}" ;;
    chat) run_ollama_chat ;;
    oterm) pip_tool oterm; launch_oterm ;;
    webui) pip_tool open-webui; launch_open_webui ;;
  esac
}

self_path() {
  readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0"
}

install_path_alias() {
  local dest
  if [[ ${EUID} -eq 0 ]]; then
    dest="/usr/local/bin/lfd"
  else
    dest="$AICC_BIN/lfd"
    mkdir -p "$AICC_BIN"
  fi
  local src
  src="$(self_path)"
  install -m 0755 "$src" "$dest"
  if [[ ${EUID} -ne 0 && -f $HOME/.bashrc ]] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
  fi
  if [[ -t 1 ]] && need_cmd dialog; then
    info_dialog "Installed as:\n$dest\n\nLaunch:  sudo lfd"
  else
    echo "Installed $dest"
    echo "Launch: sudo lfd"
  fi
}

status_text() {
  cat <<EOF
LFD $AICC_VER — LLMs for Dummies
Made by $LFD_AUTHOR
Home: $AICC_HOME

$(hw_report)

--- software ---
python3:          $(have_python && python3 --version || echo MISSING)
venv:             $([[ -d $AICC_VENV ]] && echo yes || echo no)
Ollama:           $(have_ollama && ollama --version 2>/dev/null | head -1 || echo MISSING)
Ollama API :11434 $(ollama_up && echo UP || echo DOWN)
Open Interpreter: $(have_oi && echo yes || echo no)
Open WebUI:       $(have_owui && echo yes || echo no)
oterm:            $(have_oterm && echo yes || echo no)
docker:           $(have_docker && docker --version | head -1 || echo no)
OpenRouter key:   $([[ -n ${OPENROUTER_KEY:-} ]] && echo set || echo no)
Default model:    ${DEFAULT_OLLAMA_MODEL:-none}

--- ollama models ---
$(have_ollama && ollama list 2>/dev/null || echo none)
EOF
}

view_log() {
  d --title "Log" --textbox <(tail -n 100 "$AICC_LOG" 2>/dev/null || echo empty) 22 80
}

about() {
  d --msgbox "LFD $AICC_VER
LLMs for Dummies
Made by $LFD_AUTHOR

Local models. No API key required.

[OS controlled] = uncensored agent models
[Chat only]     = normal chat models

First run: GET ME AN LLM

Data: $AICC_HOME
" 20 72
}

# ---------- menus ----------
menu_ollama() {
  while true; do
    local c
    c=$(d --stdout --title "[ ollama ]" --menu "engine" 22 74 14 \
      1 "Install Ollama" \
      2 "Start daemon" \
      3 "Update Ollama" \
      4 "Pull from catalog" \
      5 "Chat only (ollama run)" \
      a "OS agent (actually runs commands)" \
      6 "Smoke test default model" \
      7 "Create clean/purple/silent coder mods" \
      8 "Delete a model" \
      9 "Show ollama list" \
      0 "Back") || return
    case "$c" in
      1) install_ollama ;;
      2) start_ollama_daemon && info_dialog "Daemon is up." ;;
      3) update_ollama ;;
      4) pull_model ;;
      5) run_ollama_chat ;;
      a) launch_os_agent ;;
      6) quick_test ;;
      7) create_helper_models ;;
      8) delete_model ;;
      9) d --msgbox "$(ollama list 2>&1 || true)" 20 78 ;;
      0) return ;;
    esac
  done
}

menu_apps() {
  while true; do
    local c
    c=$(d --stdout --title "[ apps ]" --menu "frontends / keys" 20 72 12 \
      1 "Install Open Interpreter" \
      2 "Launch Open Interpreter" \
      3 "Install Open WebUI (pip)" \
      4 "Launch Open WebUI :8080" \
      5 "Open WebUI via Docker :3000" \
      6 "Install + launch oterm" \
      7 "Save OpenRouter API key" \
      8 "Save Hugging Face token" \
      0 "Back") || return
    case "$c" in
      1) pip_tool open-interpreter && info_dialog "Installed." ;;
      2) launch_open_interpreter ;;
      3) pip_tool open-webui && info_dialog "Installed." ;;
      4) launch_open_webui ;;
      5) launch_webui_docker ;;
      6) pip_tool oterm; launch_oterm ;;
      7) save_key OPENROUTER_KEY "OpenRouter API key" ;;
      8) save_key HF_TOKEN "Hugging Face token" ;;
      0) return ;;
    esac
  done
}

main_menu() {
  while true; do
    local c
    c=$(d --stdout --title "[ LFD $AICC_VER | Pakun ]" --menu \
      "LLMs for Dummies   RAM $(ram_gb)G   $(recommend_model)\n[OS controlled]=uncensored agent   [Chat only]=chatbot" 22 76 14 \
      1 "GET ME AN LLM" \
      2 "status / hardware" \
      3 "ollama" \
      4 "apps" \
      5 "launch chat only" \
      B "launch OS agent" \
      6 "kali packages" \
      7 "gpu notes" \
      8 "install lfd on PATH" \
      9 "log" \
      A "about" \
      0 "quit") || exit 0
    case "$c" in
      1) wizard_get_llm ;;
      2) d --title "Status" --msgbox "$(status_text)" 24 78 ;;
      3) menu_ollama ;;
      4) menu_apps ;;
      5) run_ollama_chat ;;
      B) launch_os_agent ;;
      6) install_kali_deps ;;
      7) install_nvidia_hint ;;
      8) install_path_alias ;;
      9) view_log ;;
      A) about ;;
      0) clear; exit 0 ;;
    esac
  done
}

usage() {
  cat <<EOF
LFD — LLMs for Dummies. Made by Pakun.

  chmod +x lfd.sh
  ./lfd.sh
  ./lfd.sh wizard
  ./lfd.sh status
  ./lfd.sh chat
  ./lfd.sh pull [tag]
  ./lfd.sh install
EOF
}

main() {
  load_conf
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    install) install_path_alias; exit 0 ;;
    wizard) need_dialog; wizard_get_llm; exit 0 ;;
    status) status_text; exit 0 ;;
    chat) need_dialog; run_ollama_chat; exit 0 ;;
    pull) need_dialog; pull_model "${2:-}"; exit 0 ;;
    *) need_dialog; main_menu ;;
  esac
}

main "$@"
