#!/bin/bash

cd /Library/Preferences
sudo rm -r com.sophos.*
sudo /Library/Application\ Support/Sophos/saas/Installer.app/Contents/MacOS/tools/InstallationDeployer --force_remove