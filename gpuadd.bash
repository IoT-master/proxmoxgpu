#!/bin/bash

cp /etc/default/grub /etc/default/grub.bak
if [ $(lscpu | grep AMD | wc -l) -ge 1 ]; then
    sed -iE 's|GRUB_CMDLINE_LINUX_DEFAULT="[A-Za-z]*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"|' /etc/default/grub.bak
else
    sed -iE 's|GRUB_CMDLINE_LINUX_DEFAULT="[A-Za-z]*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"|' /etc/default/grub.bak
fi
update-grub

cp /etc/modules /etc/modules.bak
echo "vfio" >>/etc/modules
echo "vfio_iommu_type1" >>/etc/modules
echo "vfio_pci" >>/etc/modules
echo "vfio_virqfd" >>/etc/modules
cat /etc/modules

echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" >/etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" >/etc/modprobe.d/kvm.conf
>/etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >>/etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >>/etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >>/etc/modprobe.d/blacklist.conf

deviceid=$(lspci | grep "VGA compatible controller:" | cut -d " " -f 1)
>/etc/modprobe.d/vfio.conf
while read row; do
    cut -d " " -f 3 <<<"$row" | lspci -n -s "$(cat -)" | cut -d " " -f 3 | echo "options vfio-pci ids=$(cat -) disable_vga=1" >>/etc/modprobe.d/vfio.conf
done <<<"$deviceid"
update-initramfs -u
