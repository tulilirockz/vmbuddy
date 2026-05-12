# vmbuddy

QEMU wrapper written in Bash with sensible defaults

```bash
vmbuddy /path/to/disk-image
```
<img width="3438" height="1440" alt="Screenshot of a host Zirconium system running a GNOME OS virtual machine through vmbuddy, at the left, there is a terminal running `glxgears`, running at 3351 FPS, in the middle, there is a VKCube window at 120FPS, and at the right there is a sample GNOME OS fastfetch run." src="https://github.com/user-attachments/assets/e22b75c9-bbc1-44fe-964a-724879ab81f9" />

This will autodetect a valid QEMU binary on your system and launch a VM for you with Venus, UEFI and other
virtualization goodies

If you don't have any QEMU binary on your system, you can install the
[`virt-manager` flatpak](https://flathub.org/en/apps/org.virt_manager.virt-manager) and
[`QEMU` extension](https://flathub.org/en/apps/org.virt_manager.virt_manager.Extension.Qemu) from
[Flathub](https://flathub.org/) to run your VMs

## Installation

### Git repository

Clone this git repository somewhere in your filesystem

```bash
mkdir -p "${HOME}/opt/tulilirockz"
git clone "https://github.com/tulilirockz/vmbuddy" "${HOME}/opt/tulilirockz/vmbuddy"
```

Then you can symlink the vmbuddy script into somewhere in your `$PATH` variable:

```bash
ln -s "${PWD}/vmbuddy.sh" "${HOME}/.local/bin/vmbuddy"
```

This allows you to get updates by `git pull`.

### Curl (not recommended)

You can also `curl` vmbuddy into your `$PATH`:

```bash
curl -fsSL "https://raw.githubusercontent.com/tulilirockz/vmbuddy/refs/heads/main/vmbuddy.sh" | install -Dpm0755 /dev/stdin "${HOME}/.local/bin/vmbuddy"
```

Make sure that the script was properly fetched and has the expected contents by examining the installed script on `${HOME}/.local/bin/vmbuddy` or wherever else you've installed it to.

## Flatpak Fixes

### Pipewire

The virt-manager flatpak doesn't currently expose the pipewire socket, so if you want to use the pipewire audio backend you'll need to add an override for it.

```bash
flatpak override org.virt_manager.virt-manager --filesystem=xdg-run/pipewire-0:ro
```

## Final note

This is maintained and used primarily on x86_64, virtualizing other x86_64 systems. A few things may not work well when _not_ on those architectures right now. Please make bug reports for those!
