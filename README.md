# Wine-Byond-help
A collection of tips and tricks for getting byond running on linux<br />

This guide is mostly based on the [Lutris](https://lutris.net/games/byond/) installer for now however more general and other installers are planned (feel free to pr) 

# Please do not use the default Proton-Ge wine provided with lutris
## (The latest ge 10-29 works and so does wine 11.0 also works however wine 11.1 has broken alot of window rendering)
Ill do some testing with em wine and such later you can test it youself using the newly fixed x64byondbeta <br />
webview2 requires patches made to wine in 10.5. Proton is based on 10.0, so until the wine patches are ported to GE or proton gets rebased to 11.0 please use a system wine instead
<br /> <br />
<img width="1047" height="651" alt="image" src="https://github.com/user-attachments/assets/61b333a0-f9cf-48f9-b538-d41d1d5b92af" /><br />
<br /> <br />
to do so in lutris before running the install script please press the wine button on the left side tab and then select system wine as default <br />
make sure the wine is newer then 10.5 if it is not please google your distro's guide for installing wine to update it (we suggest using staging-wine while you are at it)<br />

<img width="850" height="514" alt="image" src="https://github.com/user-attachments/assets/87f50a35-9f87-4842-be2d-cdf022b5d3b3" /><br />
**alternatively if your package manager does not eaisly provide a sufficent wine version**<br />
you can press the small box icon and have lutris install some specfic wine versions. wine-10.8-staging-x86_64, wine-10.8-staging-tkg-ntsync-x86_64, and wine-10.7-staging-tk all work; however wine-10.8-staging-tkg-ntsync-x86_64 is recommended as its provides the best performance enhancing patches and supports NTSync which may (needs testing) improve byond performance in some facets.
TODO: test NTsync and add a guide for setting it up.


TODO: add guides for bottles and other installers<br />
<br />
arch: https://wiki.archlinux.org/title/Wine<br />
others: https://gitlab.winehq.org/wine/wine/-/wikis/Download<br />
TODO: add more links for distros <br />

# Installing a 32-bit prefix with lutris
32-bit prefix support for wine is slowly being deprecated and breaks alot of things. However wow64 doubles webview2's already high RAM usage so this is a temporary workaround until Wine fixes whatever bug causes webview to eat all of the ram<br />
<br />
First install a Wine binary with 32-bit prefix support (The one I previously suggested is no longer up to date if you find a good one please make a merge request to add it here :) )
(no fsync or esync support but they break byond sometimes anyway)<br />
<img width="1661" height="628" alt="image" src="https://github.com/user-attachments/assets/c0e84f00-fa0f-4ede-957f-a3e48ec7cb5e" /><br />
Click the newest one <br />
<img width="1882" height="660" alt="image" src="https://github.com/user-attachments/assets/7ded67f4-61cb-4761-ae99-4827eac8f6c3" /><br />
download the "artifact" you will need to then unzip it twice first a .zip and then a .tar.zst most distros can do this by default.<br />
<img width="1056" height="659" alt="image" src="https://github.com/user-attachments/assets/bb38f10a-dd32-4551-bfce-2f193e092511" /><br />
click on the gear next to Wine then in runner iptions set Wine Version to Custom. Finally select the wine binary from the package you just downloaded<br />
in my case it was at `~/Downloads/wine-tkg-staging-ntsync-git-10.13.r0.ga8a6d7b0-327-x86_64.pkg/usr/bin/wine`<br /> 
You will now be able to Use the 32-bit version of the lutris installer. <br />
<img width="851" height="506" alt="image" src="https://github.com/user-attachments/assets/da3b819e-f7cd-41d8-8b98-66143aa47e09" /><br />
(while we wait for it to be approved by lutris staff please press the + at the top of the lutris screen and then use the `32bitbyond.yaml` found in this repo.)



# Common issues
## Byond is stuck on the loading screen / error code 256
Please make sure you installed the correct byond 64bit byond needs the x64 installer (the x86 is borked on wow64 wine [I should really make an issue when I have the time])<br />
<img width="436" height="358" alt="image" src="https://github.com/user-attachments/assets/828b6515-8dea-4061-a345-dd3c38ed2714" /><br />
if you are using a 32bit prefix you need the x86 install as 32bit prefixes can not run 64 bit programs even when working correctly.


## I dont have audio on arch
install `pipewire-alsa` or some equivalent make sure your audio driver is set to alsa and that should make it work

## Lutris/Wine is not closing/opening after one launch
webview2 brings with it the Microsoft Edge Updater which (randomly) starts itself and has a very peculiar senese of when it wants to close which blocks lutris/wine from closing and therefore opening again<br />
<br />
You have two simple solutions which both boil down to killing the Edge Updater <br />
<img width="1170" height="450" alt="image" src="https://github.com/user-attachments/assets/c2557a67-72f8-4832-8910-03366ce6b7fa" /><br />
1. open the wine task manager (you can do this in lutris by pressing on the wine glass and pressing wine taskmanager) then go to processes and then end `MicrosoftEdgeUpdate.exe*32` <br />
2. using your normal system task manager kill lutris/wine (depening on how you launch it) and then relaunch <br />


<br /><br />
after doing either of these you will be able to launch byond again without issue
<br /><br />
TODO: there is a script and some other ways to deal with this look into it and add them as the "hard way"

## Horrible flickering on the panels!
this seems to be caused by a bug in the wine window manager that causes wine to not understand how window decorations work.<br />

There is two solutions.<br />

1. Use proton-ge-12 or newer (maybe not 13 it seems a bit buggy) as I was searching for a complex window manager patch solution gabe and his arch angel glorious eggroll backported the fix to the webview2 installer!<br />
- ~~it just works! Im not sure if its proton's custom vkd3d or what but it works!~~ it might work in some cases give it a try!
2. the issue is only present if the wine window manager is allowed to mess up eaither force your window manager to use decorations on wine (gnome seems to hate this) or get a window manager who wants too I suggest kwin as it allows you to run it inside of your normal window manager.
- just install kwin and then add the command prefix `kwin_wayland --xwayland` (warning this is mostly just theoretical as I was unable to recreate the bug with any of the window managers I installed so you should just use ge tbh)
- kwin also sometimes refuses to apply window decoration controls sometimes (steam deck kwin specifically it seems?) 


## Mangohud does not work!
byond is 32 bit you need the 32 bit mango hud to have it work<br />
if you have it installed make sure dxvk is enabled some older installers disable it for byond

## Bad FPS on Nividia cards
enabling dxvk has helped alot with fixing fps issues on team green cards but others have reported it breaking Byond completely so try it and see which one are you!<br />
this has also been noted to sometimes cause flickering in tguis

## Nothing is rendering!!
not sure the cause of this but the easiest try disabling esync and fsync; exiting full-screen also seems to help sometimes. <br />
If those did not fix it or if you want a more stable solution [ntsync](https://docs.kernel.org/next/userspace-api/ntsync.html) has been found to a fix it as well. <br />
If your kernel is newer then 6.15 it is as simple as `# modprobe ntsync` and having a ntsync patched wine (the lutris script has this by default.) this will only enable it until you restart your computer but all distros have solutions for permanent module loading <br />
<br />
Here is some instructions for working with modules:<br />
[Arch](https://wiki.archlinux.org/title/Kernel_module)<br />
[Fedora](https://docs.fedoraproject.org/en-US/fedora/f40/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/)<br />
[Mint](https://forums.linuxmint.com/viewtopic.php?t=449946)<br />
(Note: if you use a kenel newer then 6.15 you only need to use modprobe and the ntsync.conf; The udev rules are not needed)<br />
TODO: add more for more distros

## Byond is using a ton of memory!
### Update: wines newer then 10.17 ish have mostly sloved this if you use the newest wine it should mostly be fine

Webview 2 under Wine suffers from some sort of bug that causes it to max out on ram usage no matter what. This is exacerbated by wow64 where the previous 32-bit webview would take 4.5 gb the new 64-bit now takes around 9.5 (tested on tgmc)
Ill post a bug report on wine but for now we only have work arounds. <br />
There is two "solutions." <br />
1. (Recommended) Just add more swap. A swap file uses your hard-drive as ram as webview is being buggy this wont even slow you down as most of the bloated ram wont even be used. If you have 16 Gibs, 20 Gibs of swap is suggested and plenty (increase the swap as needed or as you want more browser tabs open while you are playing)
- Here are some guides for setting up/increasing swap.<br />
[Arch](https://wiki.archlinux.org/title/Swap)<br />
[Fedora](https://discuss.techlore.tech/t/how-to-increase-swap-size-in-fedora-linux/5802/2)<br />
[Mint](https://forums.linuxmint.com/viewtopic.php?t=284301)<br />
<br />

2. if you dont care about spaceman dm breaking or using deprecated features using a 32-bit prefix will cut that 9.5 gib ram footprint in half! This may still not be enough but it is a nice savings.<br />
scroll up to 'Installing a 32-bit prefix with lutris' and follow that.<br />

TODO: add manuel install instructions for 32-bit<br />
TODO: make winehq bug report<br />

## I Cant reach the Client/Server/Reconnect menu!
The button is windows only, for (some) tg and bay forks you can just press F1 on your keyboard to open it (Works in full screen as well!) 
<br /> 
For CM you should be able to use .options (may work for other forks? just try it)

## I run byond on a tiling WM (niri/hyperland/sway/ect) but all that appears is a small white window with a blue icon!!!
This is kinda a bug with wine where the byond pager dosent open by default luckily that small window 
<br />(pictured here)<br />
<img width="265" height="132" alt="image" src="https://github.com/user-attachments/assets/b666e741-eb86-494d-bdd1-9e7e5b20821e" />
<br />is actully a bar icon for opening the pager just click the small blue icon and the pager will open allowing you to play your games

## I run byond on a traditional WM (Plasma/Gnome/Cosmic/ect) but all that apperas is an Icon on the task bar!!!
is is kinda a bug with wine where the byond pager dosent open by default luckily that small icon lets you open the pager by just pressing it so just press it and you can play!


## If you dont see your issue here please open a issue on this repo 
I and others really dont mind helping people getting this setup


# TODO: guide for setting up default prefix and vscode dev enviroment
