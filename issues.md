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

## I run byond on a traditional WM (Plasma/Gnome/Cosmic/ect) and all that appears is an Icon on the task bar/BYOND fades out and doesn't open a new window after loading screen!!!
It is kinda a bug with wine where the BYOND pager dosent open by default. Luckily, that small icon lets you open the pager by just pressing it, so just press it and you can play!
<img width="581" height="135" alt="image" src="https://github.com/user-attachments/assets/688a4e07-c7c7-4a1f-9380-fc5ee4ac50ec" />

## The Script just fails when installing byond/VCrun!!! 
we do not have a real good solution for this if we are honsest but most of the time it appears this is usally an issue with your proton/wine version or your winetricks version. so try swapping between proton and wine versions I try to keep the note at the top of this file up to date with a version of proton ge that works. winetricks is a bit more tricky try updating it first in your package manager and then enable system wine tricks in lutris <br />
<img width="848" height="640" alt="Pasted image (5)" src="https://github.com/user-attachments/assets/982ec9c7-ad22-4335-b7d1-c172b106fe70" />
<br /> then make sure you have the latest wine tricks ***USUALLY*** your package manager of choice will have it but please look on their [github](https://github.com/Winetricks/winetricks) to make sure if the one your system provides does not work, manully place the winetricks from thier git in your bin folder.

## There are extra black unclosable windows on Goon / Other!!
this is a bug in wine (https://bugs.winehq.org/show_bug.cgi?id=59932) fixed in verison 11.13. It was apprently not present in wine 9.0 but due to the lack of webview2 fixes in older versions I suggest just trying to change to a version with the nessary 11.13 fix.

## If you dont see your issue here please open a issue on this repo 
I and others really dont mind helping people getting this setup