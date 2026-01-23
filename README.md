# vmbuddy

QEMU wrapper written in Bash with sensible defaults

```
vmbuddy /path/to/disk-image
```

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
