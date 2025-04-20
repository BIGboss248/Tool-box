# DHCPSERVER => DHCP server name
# DHCPPool => DHCP server pool name
# NEXTSERVER => IP address of the netboot.xyz server
# Source https://technotim.live/posts/netbootxyz-tutorial/
/ip dhcp-server/set DHCPSERVER bootp-support=none
/ip dhcp-server option add code=67 name=pxe-bios-netboot.xyz value="'netboot.xyz.kpxe'"
/ip dhcp-server/option/sets add name="pxe-bios" options=pxe-bios-netboot.xyz
/ip dhcp-server/set DHCPSERVER dhcp-option-set=pxe-bios

/ip dhcp-server option add code=67 name=pxe-uefi-netboot.xyz value="'netboot.xyz.efi'"
/ip dhcp-server/option/sets add name="pxe-uefi" options=pxe-uefi-netboot.xyz
/ip dhcp-server/matcher/add name="pxe-uefi-matcher" server=DHCPSERVER address-pool=DHCPPool option-set=pxe-uefi code=93 value="0x0007" matching-type=substring
/ip/dhcp-server/network/set 0 dhcp-option=pxe-uefi-netboot.xyz,pxe-bios-netboot.xyz next-server=NEXTSERVER

/container mounts
add dst=/assets name=pxe-assets src=/disk1/docker_volumes/pxe/assets
/container
add interface=veth4-PXE mounts=pxe-assets root-dir=disk1/pxe start-on-boot=yes\
    Remote-image=linuxserver/netbootxyz:latest

# SMB is necessary if you want to add WinPE image in docker volume of the container
# SMB setup
/ip smb users
add name=amin
/ip smb shares
add directory=/disk1/docker_volumes/pxe/assets name=your_user
