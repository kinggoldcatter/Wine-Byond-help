# Wine-Byond-help
A collection of tips and tricks for getting byond running on linux

This guide is mostly based on [Lutris](https://lutris.net/games/byond/) for now however more general and other installers are planned (feel free to pr) 

# Please do not use the default Proton-Ge wine provided with lutris
## (note: the current lutris script should do this for you)
if not please log an issue and attempt the manuel download as described<br />
webview2 requires patches made to wine in 10.5. Proton is based on 10.0, so until the wine patches are ported to GE or proton gets rebased to 11.0 please use a system wine instead
<br /> <br />
<img width="1047" height="651" alt="image" src="https://github.com/user-attachments/assets/61b333a0-f9cf-48f9-b538-d41d1d5b92af" />
<br /> <br />
to do so in lutris before running the install script please press the wine button on the left side tab and then select system wine as default <br />
make sure the wine is newer then 10.5 if it is not please google your distro's guide for installing wine to update it (we suggest using staging-wine while you are at it)<br />

<img width="850" height="514" alt="image" src="https://github.com/user-attachments/assets/87f50a35-9f87-4842-be2d-cdf022b5d3b3" />
**alternatively if your package manager does not eaisly provide a sufficent wine version**<br />
you can press the small box icon and have lutris install some specfic wine versions. wine-10.8-staging-x86_64, wine-10.8-staging-tkg-ntsync-x86_64, and wine-10.7-staging-tk all work; however wine-10.8-staging-tkg-ntsync-x86_64 is recommended as its provides the best performance enhancing patches and supports NTSync which may (needs testing) improve byond performance in some facets.
TODO: test NTsync and add a guide for setting it up.


TODO: add guides for bottles and other installers<br />
<br />
arch: https://wiki.archlinux.org/title/Wine<br />
others: https://gitlab.winehq.org/wine/wine/-/wikis/Download<br />
TODO: add more links for distros <br />

# Common issues
## I dont have audio on arch
install `pipewire-alsa` or some equivalent make sure your audio driver is set to alsa and that should make it work

## Lutris/Wine is not closing/opening after one launch
webview2 brings with it the Microsoft Edge Updater which (randomly) starts itself and has a very peculiar senese of when it wants to close which blocks lutris/wine from closing and therefore opening again<br />
<br />
You have two simple solutions which both boil down to killing the Edge Updater <br />
<img width="1170" height="450" alt="image" src="https://github.com/user-attachments/assets/c2557a67-72f8-4832-8910-03366ce6b7fa" />
1. open the wine task manager (you can do this in lutris by pressing on the wine glass and pressing wine taskmanager) then go to processes and then end `MicrosoftEdgeUpdate.exe*32` <br />
2. using your normal system task manager kill lutris/wine (depening on how you launch it) and then relaunch <br />


<br /><br />
after doing either of these you will be able to launch byond again without issue
<br /><br />
TODO: there is a script and some other ways to deal with this look into it and add them as the "hard way"

## mangohud does not work!
byond is 32 bit you need the 32 bit mango hud to have it work<br />
if you have it installed make sure dxvk is enabled some older installers disable it for byond

## If you dont see your issue here please open a issue on this repo 
I and others really dont mind helping people getting this setup

# TODO: guide for setting up default prefix and vscode dev enviroment
