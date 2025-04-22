# DHCPSERVER => DHCP server name
# DHCPPool => DHCP server pool name
# NEXTSERVER => IP address of the netboot.xyz server
# NUMBER-DHCP-NETWORK => Number of DHCP network
# Source https://linkarzu.com/posts/docker-practical/windows11-netbootxyz/#configure-router-after-setting-up-container
/ip dhcp-server/set DHCPSERVER bootp-support=none
/ip dhcp-server option add code=67 name=pxe-bios-netboot.xyz value="'netboot.xyz.kpxe'"
/ip dhcp-server/option/sets add name="pxe-bios" options=pxe-bios-netboot.xyz
/ip dhcp-server/set DHCPSERVER dhcp-option-set=pxe-bios

/ip dhcp-server option add code=67 name=pxe-uefi-netboot.xyz value="'netboot.xyz.efi'"
/ip dhcp-server option add code=67 name=pxe-uefi-snp-netboot.xyz value="'netboot.xyz-snp.efi'"
/ip dhcp-server/option/sets add name="pxe-uefi" options=pxe-uefi-netboot.xyz
/ip dhcp-server/matcher/add name="pxe-uefi-matcher" server=DHCPSERVER address-pool=DHCPPool option-set=pxe-uefi code=93 value="0x0007" matching-type=substring
/ip/dhcp-server/network/set NUMBER-DHCP-NETWORK dhcp-option=pxe-uefi-netboot.xyz,pxe-bios-netboot.xyz,pxe-uefi-snp-netboot.xyz next-server=NEXTSERVER

# Cache ubuntu images
/ip firewall address-list
add address=archive.ubuntu.com list=ubuntu
add address=releases.ubuntu.com list=ubuntu
add address=cdimage.ubuntu.com list=ubuntu
/ip proxy
set enabled=yes cache-on-disk=yes max-cache-size=unlimited max-cache-object-size=1000000000 cache-path=/disk1/web-proxy
/ip proxy access
add action=allow
/ip firewall nat
add chain=dstnat action=redirect to-ports=8080 dst-address-list=ubuntu place-before=0 
/ip firewall mangle
add chain=prerouting action=accept dst-address-list=ubuntu place-before=0
add chain=output action=mark-routing routing-mark=VPN dst-address-list=ubuntu place-before=0


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
