# Wine-Byond-help
A collection of tips and tricks for getting byond running on linux

# Please do not use the default Proton-Ge wine provided with lutris
webview2 requires patches made to wine in 10.5 proton is based on 10.0 so until the wine patches are ported to GE or proton gets rebased to 11.0 please use a system wine instead
to do so in lutris before running the install script please press the wine button on the left side tab TODO: Add a picture for this 
and then select system wine as default 
make sure the wine is newer then 10.5 if it is not please google your distro's guide for installing wine to update it (we suggest using staging-wine while you are at it)
TODO: add guides for bottles and other installers

arch: https://wiki.archlinux.org/title/Wine
others: https://gitlab.winehq.org/wine/wine/-/wikis/Download
TODO: add more links for distros 

# Common issues
## I dont have audio on arch
install `pipewire-alsa` or some equivalent make sure your audio driver is set to alsa and that should make it work

## If you dont see your issue here please open a issue on this repo 
I and others really dont mind helping people getting this setup

# TODO: guide for setting up default prefix and vscode dev enviroment
