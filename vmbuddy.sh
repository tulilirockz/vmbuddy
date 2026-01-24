#!/usr/bin/env bash

VMBUDDY_VERSION="0.1.0"
VMBUDDY_BINARY_NAME="vmbuddy"

set -eo pipefail

invalid_args_die() {
  printf >&2 "%s" "ERROR: Invalid number of arguments"
  exit 1
}

show_help()
{
	cat <<EOF
vmbuddy version: ${VMBUDDY_VERSION}

Usage:

	${VMBUDDY_BINARY_NAME}
	${VMBUDDY_BINARY_NAME} /path/to/image
	${VMBUDDY_BINARY_NAME} --iso /path/to/iso /path/to/image
	${VMBUDDY_BINARY_NAME} --cpu 8 --ram 16G /path/to/image
	${VMBUDDY_BINARY_NAME} --accel venus --iso /path/to/iso

Options:

	--binary/-b:			QEMU binary to be used (i.e.: qemu-system-$(arch))
	--uefi-binary/-u:		QEMU UEFI binary to be used (i.e.: /path/to/edk2)
	--machine-type/--machine/-m:	Firmware used to boot the virtual machine (uefi/bios)
	--acceleration-type/--accel/-a:	Method for GPU acceleration on the virtual machine (venus/virgl/none)
	--display:			QEMU display type (sdl/gtk/console)
	--ram/-r:			RAM to be allocated to the virtual machine (i.e. 8G, 400M)
	--cpu/-c:			Virtual CPUs to be allocated to the virtual machine (i.e. 8)
	--iso/-i:			ISO file to be mounted (and booted) to the virtual machine (/path/to/iso)
	--audio-type/--audio:		Type of audio device to be allocated to the VM (pulseaudio/ich9/none)
	--dry-run/-d:			Only print the QEMU command generated
	--flatpak/-f:			Run with QEMU flatpak
	--verbose/--debug/-v:		Show more verbosity
	--version:			Show version
	--help/-h:			Show this help
EOF
}

VMBUDDY_AUTODETECT_QEMU="${VMBUDDY_AUTODETECT_QEMU:-1}"
QEMU_RUNNER_BINARY="${QEMU_RUNNER_BINARY:-}"
QEMU_RUNNER_UEFI_BINARY="${QEMU_RUNNER_UEFI_BINARY:-}"
QEMU_RUNNER_CPUS="${QEMU_RUNNER_CPUS:-$(($(nproc) / 2))}"
QEMU_RUNNER_RAM="${QEMU_RUNNER_RAM:-4G}"
QEMU_RUNNER_AUDIO_TYPE="${QEMU_RUNNER_AUDIO_TYPE:-pulseaudio}"
QEMU_RUNNER_ACCELERATION_TYPE="${QEMU_RUNNER_ACCELERATION_TYPE:-venus}"
QEMU_RUNNER_DISPLAY_TYPE="${QEMU_RUNNER_DISPLAY_TYPE:-gtk}"
QEMU_RUNNER_DRY_RUN="${QEMU_RUNNER_DRY_RUN:-0}"
QEMU_RUNNER_MACHINE_TYPE="${QEMU_RUNNER_MACHINE_TYPE:-uefi}"
QEMU_RUNNER_ISO_FILE="${QEMU_RUNNER_ISO_FILE:-}"
QEMU_RUNNER_IMAGE_FILE="${QEMU_RUNNER_IMAGE_FILE:-}"

if [ -z "${QEMU_RUNNER_BINARY}" ]; then
  # We want to use flathub whenever possible, but if the system stack is available then use that
  if [ "${VMBUDDY_AUTODETECT_QEMU}" == "1" ] && command -v "qemu-system-$(arch)" &>/dev/null ; then
    QEMU_RUNNER_BINARY="qemu-system-$(arch)"
    if [ -e "/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2" ] ; then
      QEMU_RUNNER_UEFI_BINARY="/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2"
    fi
  else
    QEMU_RUNNER_BINARY="flatpak run --command=qemu-system-$(arch) org.virt_manager.virt-manager"
    QEMU_RUNNER_UEFI_BINARY="/app/lib/extensions/Qemu/share/qemu/edk2-$(arch)-code.fd"
  fi
fi

while :; do
  case $1 in
    -f | --flatpak)
      shift
      QEMU_RUNNER_BINARY="flatpak run --command=qemu-system-$(arch) org.virt_manager.virt-manager"
      QEMU_RUNNER_UEFI_BINARY="/app/lib/extensions/Qemu/share/qemu/edk2-$(arch)-code.fd"
      ;;
    -b | --binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_BINARY="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -u | --uefi | --uefi-binary)
      if [ -n "$2" ]; then
        QEMU_RUNNER_UEFI_BINARY="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -m | --machine | --machine-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_MACHINE_TYPE="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    --audio | --audio-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_AUDIO_TYPE="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    -a | --accel | --acceleration-type)
      if [ -n "$2" ]; then
        QEMU_RUNNER_ACCELERATION_TYPE="${2}"
        shift
        shift
      else
        invalid_args_die
      fi
      ;;
    --display)
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
    -d | --dry-run)
      shift
      QEMU_RUNNER_DRY_RUN="1"
      ;;
    -v | --verbose | --debug)
      set -x
      shift
      ;;
    --version)
      printf "${VMBUDDY_BINARY_NAME}: %s\n" "${VMBUDDY_VERSION}"
      exit 0
      ;;
  	--)
      shift
      break
      ;;
    -*)
      printf >&2 "ERROR: Invalid flag '%s'\n\n" "$1"
      show_help
      exit 1
      ;;
    *)
      if [ -n "$1" ]; then
        QEMU_RUNNER_IMAGE_FILE="$1"
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
if [ "${QEMU_RUNNER_ACCELERATION_TYPE}" == "venus" ] ; then
  VENUS_ARGUMENTS=(
    "-display" "${QEMU_RUNNER_DISPLAY_TYPE:-gtk},gl=on,show-cursor=off"
    "-object" "memory-backend-memfd,id=mem1,size=${QEMU_RUNNER_RAM}"
    "-machine" "memory-backend=mem1"
    "-device" "virtio-vga-gl,hostmem=${QEMU_RUNNER_RAM},blob=true,venus=true"
    "-vga" "none"
  )
  SANDBOX_ARGUMENTS=()
fi

if [ "${QEMU_RUNNER_DRY_RUN}" == "1" ] ; then
  DRY_RUN_ARGUMENTS=("echo")
fi

if [ -n "${QEMU_RUNNER_ISO_FILE}" ] ; then
  ISO_FILE_ARGUMENTS=(
     "-boot" "d"
     "-drive" "media=cdrom,file=${QEMU_RUNNER_ISO_FILE},readonly=on" 
  )
fi

if [ -n "${QEMU_RUNNER_IMAGE_FILE}" ] ; then
  IMAGE_FILE_ARGUMENTS=("-drive" "file=${QEMU_RUNNER_IMAGE_FILE},format=${QEMU_RUNNER_IMAGE_FILE##*.},if=virtio")
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

if [ "${QEMU_RUNNER_AUDIO_TYPE}" == "pulseaudio" ] ; then
  AUDIO_ARGUMENTS=(
    "-audiodev" "pa,id=snd0,server=unix:${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
    "-device" "ich9-intel-hda,id=sound0,bus=pcie.0,addr=0x1b"
    "-device" "hda-duplex,id=sound0-codec0,audiodev=snd0"
    "-global" "ICH9-LPC.disable_s3=1"
    "-global" "ICH9-LPC.disable_s4=1"
    "-global" "ICH9-LPC.noreboot=off"
  )
fi

MACHINE_ARGUMENTS=(
  "-machine" "q35,accel=kvm:tcg"
)
if [ "${QEMU_RUNNER_MACHINE_TYPE}" == "uefi" ] ; then
  MACHINE_ARGUMENTS=(
    "${MACHINE_ARGUMENTS[@]}"
    "-drive" "if=pflash,format=raw,readonly=on,file=${QEMU_RUNNER_UEFI_BINARY}"
  )
fi


${DRY_RUN_ARGUMENTS} ${QEMU_RUNNER_BINARY} \
  -enable-kvm \
  -cpu host \
  -usb -device usb-tablet \
  -rtc base=utc,driftfix=slew \
  -m "${QEMU_RUNNER_RAM}" \
  -smp "${QEMU_RUNNER_CPUS}" \
  -net user \
  -object qom-type=rng-random,id=objrng0,filename=/dev/urandom \
  -net nic,model=virtio \
  "${AUDIO_ARGUMENTS[@]}" \
  "${MACHINE_ARGUMENTS[@]}" \
  "${DISPLAY_ARGUMENTS[@]}" \
  "${VIRGL_ARGUMENTS[@]}" \
  "${VENUS_ARGUMENTS[@]}" \
  "${ISO_FILE_ARGUMENTS[@]}" \
  "${IMAGE_FILE_ARGUMENTS[@]}" \
  "${SANDBOX_ARGUMENTS[@]}"

