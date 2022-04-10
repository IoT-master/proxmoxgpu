#https://pve.proxmox.com/wiki/Pci_passthrough#How_to_know_if_a_Graphics_Card_is_UEFI_.28OVMF.29_compatible

#Also try disabling "legacy boot" (sometimes called "CSM") in your BIOS, to avoid legacy VGA initialization and instead force the newer UEFI compatible way.

We are editing the bootloader
vi /etc/default/grub

GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"
#Prevents host OS from utilizing your primary GPU vesafb:off
#iommu=pt enables the IOMMU translation only when necessary, the adapter does not need to use DMA translation to the memory, and can thus improve performance for hypervisor PCIe devices (which are not passthroughed to a VM)
#efifb:off is for this issue: vfio-pci 0000:04:00.0: BAR 3: can't reserve [mem 0xca000000-0xcbffffff 64bit]
#Disabling the Framebuffer FYI:
https://passthroughpo.st/explaining-csm-efifboff-setting-boot-gpu-manually/

#ACS Override for IOMMU groups FYI:
http://vfio.blogspot.com/2014/08/vfiovga-faq.html

update-grub
Output:
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-5.13.19-2-pve
Found initrd image: /boot/initrd.img-5.13.19-2-pve
Found memtest86+ image: /boot/memtest86+.bin
Found memtest86+ multiboot image: /boot/memtest86+_multiboot.bin
Adding boot menu entry for EFI firmware configuration
done

#Verify IOMMU is enabled
dmesg | grep -e DMAR -e IOMMU
Output:
[    0.221442] pci 0000:00:00.2: AMD-Vi: IOMMU performance counters supported
[    0.225882] pci 0000:00:00.2: AMD-Vi: Found IOMMU cap 0x40
[    0.226421] perf/amd_iommu: Detected AMD IOMMU #0 (2 banks, 4 counters/bank).
[    3.794275] AMD-Vi: AMD IOMMUv2 driver by Joerg Roedel <jroedel@suse.de>

#You'll need to add a few VFIO modules to your Proxmox system.
vi /etc/modules

vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd

reboot

#Remap System to Accept... and ignore unsafe operation without panicing
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
#Ignore KVM. We want to use vfio
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf

#Create Blacklist, so the host system cannot use these cards
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf

lspci -v
lspci -nnk | grep "VGA\|Audio"
lspci -nnk | grep "AMD\|nvidia"

lspci -n -s 09:00
lspci -n -v -s 09:00
echo "options vfio-pci ids=<>,<> disable_vga=1"> /etc/modprobe.d/vfio.conf
echo "options vfio-pci ids=1002:67df,1002:aaf0 disable_vga=1"> /etc/modprobe.d/vfio.conf
#or try this one:
echo "options vfio-pci ids=<>,<>" > /etc/modprobe.d/vfio.conf
update-initramfs -u
Output:
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.

Windows10
Create VM
General: Windows
    OS:
    Storage: local
    ISO: ISOimage
    Type: Microsoft
System:
    Graphics card: Default
    SCSI: VirtIO SCSI
    BIOS: UEFI
    storage: local-lvm
    Machine: q35
Hard Disk:
    Bus/Device: SATA
    Storage: local-lvm
    Disk size: 100G
CPU:
Memory:
Network: 
    Bridge: vmbr0
    Model: Intel E1000

Start up and press key
remote desktop

#Only add PCI
hostpci0: 01:00,x-vga=on
#or try
hostpci0: 01:00,pcie=1,x-vga=on
#Check all except BAR
#Give it a few seconds to start up


#restart
reset
#shutdown
halt -p
runas /u:MicrosoftAccount\[my account] cmd.exe
runas /u:MicrosoftAccount\username@host.com cmd.exe
ps aux | grep "/usr/bin/kvm -id VMID"
ps aux | grep "/usr/bin/kvm -id 101"