# Wine-Byond-help
A collection of tips and tricks for getting byond running on linux

# Please do not use the default Proton-Ge wine provided with lutris
webview2 requires patches made to wine in 10.5. Proton is based on 10.0, so until the wine patches are ported to GE or proton gets rebased to 11.0 please use a system wine instead
to do so in lutris before running the install script please press the wine button on the left side tab<br />
TODO: Add a picture for this 
and then select system wine as default<br />
make sure the wine is newer then 10.5 if it is not please google your distro's guide for installing wine to update it (we suggest using staging-wine while you are at it)<br />
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
1. open the wine task manager (you can do this in lutris by pressing on the wine glass and pressing wine taskmanager) then go to processes and then end `MicrosoftEdgeUpdate.exe*32` <br />
2. using your normal system task manager kill lutris/wine (depening on how you launch it) and then relaunch<br />
after doing either of these you will be able to launch byond again without issue

## If you dont see your issue here please open a issue on this repo 
I and others really dont mind helping people getting this setup

# TODO: guide for setting up default prefix and vscode dev enviroment
