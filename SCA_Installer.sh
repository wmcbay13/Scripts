#!/bin/bash

###Script to automate SCA upgrade process on MacOSX scanners
##12/8/20 FortifyonDemand 2020
##Will McBay
##Used for SCA Upgrade 20.2.1.0010
###

#Copy license file to new location
mkdir /Users/wiscanner/TEMP
cp /Applications/Fortify_SCA_and_Apps.20.1.x.x/fortify.license /Users/wiscanner/TEMP


#Install new SCA Version
installer -pkg /Downloads/Fortify_SCA_and_Apps_20.2.1.mpkg -target /Applications/Fortify_SCA_and_Apps.20.2.1.0010/ -dumplog ~/TEMP

#Uninstall previous SCA version
installer -pkg /Applications/Fortify_SCA_and_Apps_20.1.0.0005/Uninstall_FortifySCAandApps_20.1.xx.xx


#Remove symbolic link
rm -rf /Applications/Fortify

#Create new symbolic link
ln -s /Applications/Fortify_SCA_and_Apps.20.2.1.0100 /Applications/Fortify

#Verify installation
sudo find / -iname *Fortify_SCA_and_Apps.app
