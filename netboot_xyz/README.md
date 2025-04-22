
# netboot.xyz

This read me is about configuring netboot xyz to be able to install windows and other operating systems

The main source is this webpage [linkarzu netbootxyz guide](https://linkarzu.com/posts/docker-practical/windows11-netbootxyz/#configure-router-after-setting-up-container)

## setup enviroment

We need to setup some requirements before going forward

### Setup netboot.xyz via docker

run netboot.xyz with docker as shown in docker compose file in this folder

### File share netboot.xyz assets file

Samba share netboot.xyz assets file so windows files can be accessible for install via windows pe later

## configure local downloading

In boot.cfg set live_endpoint to http://{container IP}:{nginx port} so the assets don't be
downloaded everytime on every install

## Configure windows pe address

In boot.cfg set win_base_url http://{container IP}:{nginx port}/{Path to x64 folder with windows pe iso extracted in it}

## (Optional) add custom dns entry to point to netboot.xyz and samba share

## Configure router

While for every router configuring pxe boot is diffrent the rsc file in this folder will help
configuring router to point to netbootxyz for pxe requests

## Install Linux

Installing Linux is straight forward just pull the assets and you can use them via boot menu

## Install Windows

We can't directly point to windows install file we have to point to windows pe and then with
that install windows itself by attaching a shared network drive this means settings up a
shared folder named x64 with windows iso extracted in it and creating a windows pe iso

### Windows pe

Creating a windows pe iso can be complicated still this part in source will guide u on how to do it

[Windows pe guide](https://linkarzu.com/posts/docker-practical/windows11-netbootxyz/#create-windows-winpe-iso)

still if done once you can save the iso and use it for other projects or you can download custom iso like
hirenbootcd from but it is important to know the larger the windowspe the longer it takes and
since it runs on RAM u need to have as much RAM as the size of windowspe and more
[hiren boot](https://www.hirensbootcd.org/)

after you created windowspe iso extract it in a folder named x64

### Download windows and extract to samba drive

after we setup windowspe we need to put the extracted iso file to a samba shared folder to later
execute setup.exe via windowspe and install windows

### Configure auto install windows when windowspe launches

now when we boot to windowspe we need to run some command to install windows this process can be
automated using scripts and telling windowspe to run the script on launch the script files are in
configs folder be sure to change the variables at the start of auto.bat and config.ini to
ur enviroment variables and if you're not using autoattend.xml remove the command argument to prevent
errors
after you modified enviroment variables copy configs folder to windows pe folder beside x64 folder

### Auto attend and skip windows user setup

If you want to skip the user setup you can either create an answer file go to <https://www.windowsafg.com>
or you can edit windows iso with ntlite and then extract it to samba drive
