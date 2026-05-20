#!/usr/bin/env bash

VMBUDDY_BINARY_NAME="vmbuddy"

set -eo pipefail

invalid_args_die() {
  printf >&2 "%s" "ERROR: Invalid number of arguments"
  exit 1
}

invalid_args_check() {
  USER_VALUE="${1}"
  shift
  INVALID=1
  for expected_value in "${@}"; do
    [ "${expected_value}" == "${USER_VALUE}" ] && INVALID=0
  done

  if [ "${INVALID}" == 1 ] ; then
    printf >&2 "%s" "ERROR: Invalid argument specified for flag, expected: ${*}"
    exit 1
  fi
}

show_help()
{
	cat <<EOF
Usage:

	${VMBUDDY_BINARY_NAME}
	${VMBUDDY_BINARY_NAME} [IMAGE...]
	${VMBUDDY_BINARY_NAME} --iso /path/to/iso /path/to/image
	${VMBUDDY_BINARY_NAME} --cpu 8 --ram 16G /path/to/image
	${VMBUDDY_BINARY_NAME} --accel native-drm --iso /path/to/iso

Options:

	--binary/-b:			QEMU binary to be used (i.e.: qemu-system-$(uname -m))
	--uefi-binary/-u:		QEMU UEFI binary to be used (i.e.: /path/to/edk2)
	--machine-type/--machine/-m:	Firmware used to boot the virtual machine (uefi/bios)
	--acceleration-type/--accel/-a:	Method for GPU acceleration on the virtual machine (native-drm/venus/virgl/none)
	--display/-d:			QEMU display type (sdl/gtk/curses)
	--ram/-r:			RAM to be allocated to the virtual machine (i.e. 8G, 400M)
	--cpu/-c:			Virtual CPUs to be allocated to the virtual machine (i.e. 8)
	--iso/-i:			ISO file to be mounted (and booted) to the virtual machine (/path/to/iso)
	--audio-type/--audio:		Type of audio device to be allocated to the VM (pipewire/pulseaudio/ich9/none)
	--dry-run:			Only print the QEMU command generated
	--flatpak/-f:			Run with QEMU flatpak
	--tpm/-t:			Launch with TPM2 software emulation
	--tpm-swtpm-binary:		Binary to be used for swtpm (i.e.: swtpm)
	--tpm-swtpm-setup-binary:	Binary to be used for swtpm_setup (i.e.: swtpm_setup)
	--tpm-state-dir:		Directory to be used to store TPM2 state (default: ${XDG_DATA_DIR:-${HOME}/.local/share}/vmbuddy/tpmstate)
	--verbose/--debug/-v:		Show more verbosity
	--version:			Show version
	--help/-h:			Show this help
EOF
}

system_or_fallback() {
  BINARY_TO_CHECK=$1
  FALLBACK_BINARY=$2
  shift
  shift
  if [ "$VMBUDDY_AUTODETECT_QEMU" == "1" ] && command -v "$BINARY_TO_CHECK" &>/dev/null ; then
    echo "$BINARY_TO_CHECK"
    return
  fi
  echo "$FALLBACK_BINARY"
}

QEMU_RUNNER_UEFI_BINARY="${QEMU_RUNNER_UEFI_BINARY:-}"
QEMU_RUNNER_CPUS="${QEMU_RUNNER_CPUS:-$(($(nproc) / 2))}"
QEMU_RUNNER_RAM="${QEMU_RUNNER_RAM:-4G}"
QEMU_RUNNER_AUDIO_TYPE="${QEMU_RUNNER_AUDIO_TYPE:-pipewire}"
QEMU_RUNNER_ACCELERATION_TYPE="${QEMU_RUNNER_ACCELERATION_TYPE:-"native-drm"}"
QEMU_RUNNER_DISPLAY_TYPE="${QEMU_RUNNER_DISPLAY_TYPE:-gtk}"
QEMU_RUNNER_DRY_RUN="${QEMU_RUNNER_DRY_RUN:-0}"
QEMU_RUNNER_MACHINE_TYPE="${QEMU_RUNNER_MACHINE_TYPE:-uefi}"
QEMU_EXTRA_ARGS="${QEMU_EXTRA_ARGS:-}"
QEMU_RUNNER_ISO_FILE="${QEMU_RUNNER_ISO_FILE:-}"
QEMU_RUNNER_IMAGE_FILES=( ${QEMU_RUNNER_IMAGE_FILES} )
VMBUDDY_AUTODETECT_QEMU="${VMBUDDY_AUTODETECT_QEMU:-1}"
QEMU_RUNNER_BINARY="${QEMU_RUNNER_BINARY:-$(system_or_fallback "qemu-system-$(uname -m)" "flatpak run --command=qemu-system-$(uname -m) org.virt_manager.virt-manager")}"
QEMU_RUNNER_TPM2="${QEMU_RUNNER_TPM2:-}"
QEMU_RUNNER_TPM_STATE_DIR="${QEMU_RUNNER_TPM_STATE_DIR:-${XDG_DATA_DIR:-$HOME/.local/share}/vmbuddy/tpmstate}"
QEMU_RUNNER_SWTPM_BINARY="${QEMU_RUNNER_SWTPM_BINARY:-$(system_or_fallback "swtpm" "flatpak run --command=swtpm org.virt_manager.virt-manager")}"
QEMU_RUNNER_SWTPM_SETUP_BINARY="${QEMU_RUNNER_SWTPM_SETUP_BINARY:-$(system_or_fallback "swtpm_setup" "flatpak run --command=swtpm_setup org.virt_manager.virt-manager")}"

# We want to use flathub whenever possible, but if the system stack is available then use that
if [ "${VMBUDDY_AUTODETECT_QEMU}" == "1" ] && command -v "qemu-system-$(uname -m)" &>/dev/null && [ -e "/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2" ] ; then
  QEMU_RUNNER_UEFI_BINARY="/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2"
else
  QEMU_RUNNER_UEFI_BINARY="/app/lib/extensions/Qemu/share/qemu/edk2-$(uname -m)-code.fd"
fi

while :; do
  case $1 in
    -f | --flatpak)
      shift
      QEMU_RUNNER_BINARY="flatpak run --command=qemu-system-$(uname -m) org.virt_manager.virt-manager"
      QEMU_RUNNER_UEFI_BINARY="/app/lib/extensions/Qemu/share/qemu/edk2-$(uname -m)-code.fd"
      ;;
    -t | --tpm)
      shift
      QEMU_RUNNER_TPM2="1"
      ;;
    --tpm-swtpm-binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_SWTPM_BINARY="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    --tpm-swtpm-setup-binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_SWTPM_SETUP_BINARY="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    --tpm-state-dir)
      if [ -n "$2" ]; then
        QEMU_RUNNER_TPM_STATE_DIR="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -b | --binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_BINARY="${2}"
        [ ! -e "$2" ] && printf >&2 "%s" "Warning: QEMU binary not found in filesystem"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -u | --uefi | --uefi-binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_UEFI_BINARY="${2}"
        [ ! -e "$2" ] && printf >&2 "%s" "Warning: UEFI binary not found in filesystem"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -m | --machine | --machine-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_MACHINE_TYPE="${2}"
        invalid_args_check "${2}" "bios" "uefi"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    --audio | --audio-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_AUDIO_TYPE="${2}"
        invalid_args_check "${2}" "pipewire" "pulseaudio" "ich9" "none"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -a | --accel | --acceleration-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_ACCELERATION_TYPE="${2}"
        invalid_args_check "${2}" "native-drm" "virgl" "venus" "none"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -d | --display)
      if [ -n "$2" ]; then
        QEMU_RUNNER_DISPLAY_TYPE="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -r | --ram)
      if [ -n "$2" ]; then
        QEMU_RUNNER_RAM="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -i | --iso)
      if [ -n "$2" ]; then
        QEMU_RUNNER_ISO_FILE="$2"
        shift
        shift
      fi
      ;;
    -c | --cpu)
      if [ -n "$2" ]; then
        QEMU_RUNNER_CPUS="${2}"
        [ "${QEMU_RUNNER_CPUS}" == 0 ] && invalid_args_die
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    --dry-run)
      shift
      QEMU_RUNNER_DRY_RUN="1"
      ;;
    -v | --verbose | --debug)
      set -x
      shift
      ;;
  	--)
      shift
      QEMU_EXTRA_ARGS="$*"
      break
      ;;
    -*)
      printf >&2 "ERROR: Invalid flag '%s'\n\n" "$1"
      show_help
      exit 1
      ;;
    *)
      if [ -n "$1" ]; then
        QEMU_RUNNER_IMAGE_FILES+=("$1")
        shift
      else
      	break
      fi
      ;;
  esac
done

if [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "" ] || [ -z "${QEMU_RUNNER_ACCELERATION_TYPE}" ] ; then
  DISPLAY_ARGUMENTS=("-display" "${QEMU_RUNNER_DISPLAY_TYPE:-gtk}")
fi

if [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "virgl" ] ; then
  VIRGL_ARGUMENTS=(
    "-vga" "virtio"
    "-display" "gtk,gl=on"
  )
fi

SANDBOX_ARGUMENTS=(
  "-sandbox" "on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny"
)
if [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "venus" ] || [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "native-drm" ] ; then
  VENUS_ARGUMENTS=(
    "-display" "${QEMU_RUNNER_DISPLAY_TYPE:-gtk},gl=on,show-cursor=off"
    "-object" "memory-backend-memfd,id=mem1,size=${QEMU_RUNNER_RAM}"
    "-machine" "memory-backend=mem1"
    "-vga" "none"
  )

  if [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "venus" ] ; then
    VENUS_ARGUMENTS+=("-device" "virtio-vga-gl,hostmem=${QEMU_RUNNER_RAM},blob=true,venus=true")
  else
    VENUS_ARGUMENTS+=("-device" "virtio-vga-gl,drm_native_context=on,hostmem=${QEMU_RUNNER_RAM},blob=true,venus=true")
  fi

  SANDBOX_ARGUMENTS=()
fi

if [ "${QEMU_RUNNER_DRY_RUN}" == "1" ] ; then
  DRY_RUN_ARGUMENTS=("echo")
fi

if [ "${QEMU_RUNNER_TPM2}" == "1" ] ; then
  pkill swtpm || true
  pkill swtpm_setup || true

  mkdir -p "${QEMU_RUNNER_TPM_STATE_DIR}"
  if ! ${QEMU_RUNNER_SWTPM_SETUP_BINARY} --tpmstate "${QEMU_RUNNER_TPM_STATE_DIR}" \
    --create-ek-cert \
    --create-platform-cert \
    --create-spk \
    --tpm2 \
    --create-config-files \
    --overwrite &>/dev/null ; then
    echo "Failed setting up TPM state, setting to temporary directory."
    QEMU_RUNNER_TPM_STATE_DIR="$(mktemp -d)"
    ${QEMU_RUNNER_SWTPM_SETUP_BINARY} --tpmstate "${QEMU_RUNNER_TPM_STATE_DIR}" \
      --create-ek-cert \
      --create-platform-cert \
      --create-spk \
      --tpm2 \
      --create-config-files \
      --overwrite &>/dev/null
  fi

  ${QEMU_RUNNER_SWTPM_BINARY} socket --tpmstate "dir=${QEMU_RUNNER_TPM_STATE_DIR}" \
    --ctrl type=unixio,path="${QEMU_RUNNER_TPM_STATE_DIR}/swtpm-sock" \
    --tpm2 \
    --log level=20 &>/dev/null &

  TPM2_ARGUMENTS=(
    "-chardev" "socket,id=chrtpm,path=${QEMU_RUNNER_TPM_STATE_DIR}/swtpm-sock"
    "-tpmdev" "emulator,id=tpm0,chardev=chrtpm"
    "-device" "tpm-tis,tpmdev=tpm0"
  )
fi

if [ -n "${QEMU_RUNNER_ISO_FILE}" ] ; then
  ISO_FILE_ARGUMENTS=(
     "-boot" "d"
     "-drive" "media=cdrom,file=${QEMU_RUNNER_ISO_FILE},readonly=on" 
  )
fi

if [ -n "${QEMU_RUNNER_IMAGE_FILES[*]}" ] ; then
  IMAGE_FILE_ARGUMENTS=(
    "-device" "virtio-scsi-pci,id=scsi"
  )
  HD_NUMBER=1
  for IMAGE_FILE in "${QEMU_RUNNER_IMAGE_FILES[@]}" ; do
    FILETYPE="$(sed "s/img/raw/" <<< "${IMAGE_FILE##*.}")"
    IMAGE_FILE_ARGUMENTS+=(
      "-device" "scsi-hd,drive=hd${HD_NUMBER}"
      "-drive" "if=none,id=hd${HD_NUMBER},file=${IMAGE_FILE},media=disk,snapshot=off,format=${FILETYPE}"
    )
    HD_NUMBER=$(( HD_NUMBER + 1))
  done
fi

if [ "${QEMU_RUNNER_AUDIO_TYPE}" == "ich9" ] ; then
  AUDIO_ARGUMENTS=(
    "-device" "ich9-intel-hda,id=sound0,bus=pcie.0,addr=0x1b"
    "-device" "hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0"
    "-global" "ICH9-LPC.disable_s3=1"
    "-global" "ICH9-LPC.disable_s4=1"
    "-global" "ICH9-LPC.noreboot=off"
  )
fi


if [ "${QEMU_RUNNER_AUDIO_TYPE}" == "pipewire" ] ; then
  AUDIO_ARGUMENTS=(
    "-audio" "driver=pipewire,id=snd0,model=virtio"
  )
fi

if [ "${QEMU_RUNNER_AUDIO_TYPE}" == "pulseaudio" ] ; then
  AUDIO_ARGUMENTS=(
    "-audio" "driver=pa,model=virtio,server=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
  )
fi

MACHINE_ARGUMENTS=(
  "-machine" "q35,accel=kvm:tcg,smm=on,hpet=off"
)
if [ "${QEMU_RUNNER_MACHINE_TYPE}" == "uefi" ] ; then
  MACHINE_ARGUMENTS=(
    "${MACHINE_ARGUMENTS[@]}"
    "-drive" "if=pflash,format=raw,readonly=on,file=${QEMU_RUNNER_UEFI_BINARY}"
  )
fi


exec ${DRY_RUN_ARGUMENTS} ${QEMU_RUNNER_BINARY} \
  -enable-kvm \
  -cpu host \
  -device driver=qemu-xhci \
  -usb -device usb-tablet \
  -rtc base=utc,driftfix=slew \
  -m "${QEMU_RUNNER_RAM}" \
  -smp "${QEMU_RUNNER_CPUS}" \
  -net user \
  -net nic,model=virtio \
  -device "vmgenid,guid=$(uuidgen)" \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0,id=rng-device0 \
  -device virtio-balloon,free-page-reporting=on \
  "${TPM2_ARGUMENTS[@]}" \
  "${AUDIO_ARGUMENTS[@]}" \
  "${MACHINE_ARGUMENTS[@]}" \
  "${DISPLAY_ARGUMENTS[@]}" \
  "${VIRGL_ARGUMENTS[@]}" \
  "${VENUS_ARGUMENTS[@]}" \
  "${ISO_FILE_ARGUMENTS[@]}" \
  "${IMAGE_FILE_ARGUMENTS[@]}" \
  "${SANDBOX_ARGUMENTS[@]}" \
  ${QEMU_EXTRA_ARGS}
