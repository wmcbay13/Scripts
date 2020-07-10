#!/usr/bin/env bash

################################################################################
# Custom Functions (These functions may need to be edited for specific apps)
################################################################################
extract_latest_version(){
  # used to extract the latest version from a website.
  # /usr/bin/grep -Eo '^.{4}$' can be used to extract a version number of a specific length.
  # generic extraction code: perl -pe 'if(($_)=/([0-9]+([.][0-9]+)+)/){$_.="\n"}' | /usr/bin/sort -Vu | /usr/bin/tail -n 1
  perl -pe 'if(($_)=/([0-9]+([.][0-9]+)+)/){$_.="\n"}' | /usr/bin/sort -Vu | /usr/bin/grep -Eo '^.{5}$' | /usr/bin/tail -n 1
}

################################################################################
# Fuctions (DO NOT EDIT THE BELOW FUNCTIONS, EXCEPT FOR MAIN)
################################################################################
message(){
  # description of what function does.
  local description='Displays a message to the customer if the defined application is running. Allow the customer to cancel if needed.'

  # define local variables.
  local message="${1}"
  local title='IT Support'
  local jamfHelper='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
  local cancelMessage='User chose to cancel the update the process.'

  # data validation.
  [[ -z "${applicationName}" ]] && applicationName='Application'
  [[ -z "${applicationState}" ]] && applicationState=0
  [[ -z "${message}" ]] && message='Press OK to continue'

  # display dialog box message if application is running, otherwise continue silently.
  if [[ -e "${jamfHelper}" && "${applicationState}" -eq 1 ]]; then
    if ! "${jamfHelper}" \
    -windowType hud \
    -title "${title}" \
    -heading "${applicationName} Update" \
    -button1 'OK' \
    -button2 'Cancel' \
    -description "${message}" \
    -defaultButton 1 \
    -lockHUD &>/dev/null
    then
      printf '%s\n' "ERROR: ${cancelMessage}" 1>&2
      exit 1
    fi
  fi
}

error(){
  # description of what function does.
  local description='Displays an error message to the customer if the defined application is running. Otherwise prints to STDERR.'

  # declare local variables.
  local errorMessage="${1}"
  local title='Block.one IT Support'
  local jamfHelper='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
  local defaultMessage='Update Failed.'

  # data validation
  [[ -z "${applicationName}" ]] && applicationName='Application'
  [[ -z "${applicationState}" ]] && applicationState=0
  [[ -z "${errorMessage}" ]] && errorMessage='something went wrong. update failed.'

  # display error message to customer only if application is running, otherwise print to STDERR.
  if [[ -e "${jamfHelper}" && "${applicationState}" -eq 1 ]]; then
    "${jamfHelper}" \
    -windowType hud \
    -title "${title}" \
    -heading "${applicationName} Update" \
    -button1 'OK' \
    -description "${defaultMessage}" \
    -defaultButton 1 \
    -lockHUD &>/dev/null &
    printf '%s\n' "ERROR: ${errorMessage}" 1>&2
    exit 1
  else
    printf '%s\n' "ERROR: ${errorMessage}" 1>&2
    exit 1
  fi
}

get_installed_version(){
  # description of what function does.
  local description='Read and return version information from the Info.plist of the defined application.(aka: obtain version information for currently installed application.)'

  # define local variables.
  local applicationPath="${1}"
  local installedVersion

  # if the application path is defined and is a directory attempt to read and return version information
  [[ -z "${applicationPath}" || ! -d "${applicationPath}" ]] && error 'application not installed or path undefined.'
  installedVersion="$( /usr/bin/defaults read "${applicationPath}"/Contents/Info CFBundleShortVersionString 2> /dev/null )" || error 'could not detect installed version.'
  [[ -z "${installedVersion}" ]] && error 'installed version undefined.'

  # return installed version.
  printf '%s\n' "${installedVersion}"
}

get_latest_version(){
  # description of what function does.
  local description='Extracts latest version information from a URL.'

  # define local variables.
  local latestVersionUrl="${1}"
  local data
  local latestVersion

  # attempt to extract version information from URL and return value.
  [[ -z "${latestVersionUrl}" ]] && error 'URL to search for latest version undefined.'
  data="$( /usr/bin/curl -sLJ "${latestVersionUrl}" )" || error 'failed to download version data.'
  [[ -z "${data}" ]] && error 'failed to download version data.'
  latestVersion="$( printf '%s\n' "${data}" | extract_latest_version )" || error 'failed to extract latest version.'
  [[ -z "${latestVersion}" ]] && error 'latest version undefined.'

  # return latest version.
  printf '%s\n' "${latestVersion}"
}

compare_versions(){
  # description of what function does.
  local description='Determines if the installed and latest versions are equal or not.'

  # define local variables.
  local latestVersion="${1}"
  local installedVersion="${2}"

  # data validation.
  [[ -z "${latestVersion}" ]] && error 'latest version undefined.'
  [[ -z "${installedVersion}" ]] && error 'installed version undefined.'

  # use the sort commands built-in ability to sort version numbers.
  if [[ "$( printf '%s\n' "${latestVersion}" "${installedVersion}" | /usr/bin/sort -V | /usr/bin/head -n 1 )" != "${latestVersion}" ]]; then
    printf '%s\n' 'application needs to be updated.'
  elif [[ "${latestVersion}" != "${installedVersion}" ]]; then
    error 'installed version is newer. latest version URL may need to be updated.'
  else
    printf '%s\n' 'application is on the latest version.'
    exit 0
  fi
}

download(){
  # description of what function does.
  local description='Downloads a file from a given URL to a temporary directory and returns the full path to the download.'

  # define local variables.
  local dlURL="${1}"
  dlDir=''
  local dlName
  local productVer
  local userAgent
  downloadPath=''

  # if the download URL was provided. Build the effective URL (this helps if the given URL redirects to a specific download URL.)
  [[ -z "${dlURL}" ]] && error 'download url undefined.'
  dlURL="$( /usr/bin/curl "${dlURL}" -s -L -I -o /dev/null -w '%{url_effective}' )" || error 'failed to determine effective URL.'

  # create temporary directory for the download.
  dlDir="$( /usr/bin/mktemp -d 2> /dev/null )" || error 'failed to create temporary download directory.'
  [[ ! -d "${dlDir}" ]] && error 'temporary download directory does not exist.'
  export dlDir

  # build user agent for curl.
  productVer="$( /usr/bin/sw_vers -productVersion | /usr/bin/tr '.' '_' )" || error 'could not detect product version needed for user agent.'
  [[ -z "${productVer}" ]] && error 'product version undefined'
  userAgent='Mozilla/5.0 (Macintosh; Intel Mac OS X '"${productVer})"' AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2'

  # change the present working directory to the temporary download directory and attempt download.
  cd "${dlDir}" || error 'could not change pwd to temporary download directory.'
  dlName="$( /usr/bin/curl -sLJO -A "${userAgent}" -w "%{filename_effective}" --retry 10 "${dlURL}" )" || error 'failed to download latest version.'
  [[ -z "${dlName}" ]] && error 'download filename undefined.'
  downloadPath="${dlDir}/${dlName}"
  [[ ! -e "${downloadPath}" ]] && error 'download filename undefined. can not locate download.'

  # export full path to the downloaded file including extension.
  export downloadPath
}

detect_running(){
  # description of what function does.
  local description='Detect if the defined application is currently running. Export the application state so it is available globally.'

  # define variables.
  applicationState=0

  # determine if application is running and return result.
  # 1 = running , 0 = not running.
  if /usr/bin/pgrep -q "${applicationName}"; then
    applicationState=1
    export applicationState
  else
    export applicationState
  fi
}

kill_running(){
  # description of what function does.
  local description='If the defined application is running. Give customer option to close it or cancel the update process.'

  # notify customer and get input. attempt killing application if it is running and customer has agreed.
  message "${applicationName} needs to be updated. The application will close if you continue."
  if [[ "${applicationState}" -eq 1 ]]; then
    /usr/bin/pkill -9 "${applicationName}" &>/dev/null
  fi
}

uninstall(){
  # description of what function does.
  local description='Uninstalls the defined application.'

  # define local variables.
  local applicationPath="${1}"

  # data validation.
  [[ ! -d "${applicationPath}" ]] && error 'app path undefined or not a directory.'

  # attempt uninstall.
  /bin/mv "${applicationPath}" "${applicationPath}.old" &> /dev/null || error "failed to uninstall application."
  sleep 2
}

install(){
  # description of what function does.
  local description='Determines what kind of installer the download is. Attempts install accordingly.'

  # determine download installer type. (dmg, pkg, zip)
  if [[ "$( printf '%s\n' "${downloadPath}" | /usr/bin/grep -c '.dmg$' )" -eq 1 ]]; then
    install_dmg
  elif [[ "$( printf '%s\n' "${downloadPath}" | /usr/bin/grep -c '.pkg$' )" -eq 1 ]]; then
    install_pkg
  elif [[ "$( printf '%s\n' "${downloadPath}" | /usr/bin/grep -c '.zip$' )" -eq 1 ]]; then
    install_zip
  else
    error 'could not detect install type.'
  fi
}

install_pkg(){
  # description of what function does.
  local description='Silently install pkg.'

  # define local variables.
  local pkg="${1}"

  if [[ -z "${pkg}" ]]; then
    pkg="${downloadPath}"
  fi

  # use installer command line tool to silently install pkg.
  /usr/sbin/installer -allowUntrusted -pkg "${pkg}" -target / &> /dev/null || error 'failed to install latest version pkg.'
}

install_dmg(){
  # description of what function does.
  local description='Silently install dmg.'

  # define variables.
  mnt=''
  local dmg="${1}"
  local app
  local pkg


  if [[ -z "${dmg}" ]]; then
    dmg="${downloadPath}"
  fi

  # create temporary mount directory for dmg and export path if exists.
  mnt="$( /usr/bin/mktemp -d 2> /dev/null )" || error 'failed to create temporary mount point for dmg.'
  [[ ! -d "${mnt}" ]] && error 'failed to verify temporary mount point for dmg exists.'
  export mnt

  # silently attach the dmg download to the temporary mount directory and determine what it contains (app or pkg)
  sleep 2
  /usr/bin/hdiutil attach "${dmg}" -quiet -nobrowse -mountpoint ${mnt} &> /dev/null || error 'failed to mount dmg.'
  app="$( /bin/ls "${mnt}" | /usr/bin/grep '.app$' | head -n 1 )"
  pkg="$( /bin/ls "${mnt}" | /usr/bin/grep '.pkg$' | head -n 1 )"

  # attempt install based on contents of dmg.
  if [[ ! -z "${app}" && -e "${mnt}/${app}" ]]; then
    cp -Rf "${mnt}/${app}" '/Applications' &> /dev/null || error "failed to copy the latest version to the applications directory."
  elif [[ ! -z "${pkg}" && -e "${mnt}/${pkg}" ]]; then
    install_pkg "${mnt}/${pkg}"
  else
    error 'could not detect installation type in mounted dmg.'
  fi
}

install_zip(){

  # define variables.
  uz=''
  local app
  local pkg
  local dmg

  # create temporary unzip directory and export globally if exists.
  uz="$( /usr/bin/mktemp -d 2> /dev/null )" || error 'failed to create temporary unzip directory for zip.'
  [[ ! -d "${uz}" ]] && error 'failed to verify temporary unzip directory exists.'
  export uz

  # unzip zip file and determine installer type. (app, pkg, dmg)
  /usr/bin/unzip "${downloadPath}" -d "${uz}" &> /dev/null || error 'failed to unzip download.'
  app="$( /bin/ls ${uz} | /usr/bin/grep '.app$' | head -n 1 )"
  pkg="$( /bin/ls ${uz} | /usr/bin/grep '.pkg$' | head -n 1 )"
  dmg="$( /bin/ls ${uz} | /usr/bin/grep '.dmg$' | head -n 1 )"

  # attempt install based on contents of zip file.
  if [[ ! -z "${app}" && -e "${uz}/${app}" ]]; then
    cp -Rf "${uz}/${app}" '/Applications' &> /dev/null || error "failed to copy the latest version to the applications directory."
  elif [[ ! -z "${pkg}" && -e "${uz}/${pkg}" ]]; then
    install_pkg "${uz}/${pkg}"
  elif [[ ! -z "${dmg}" && -e "${uz}/${dmg}" ]]; then
    install_dmg "${uz}/${dmg}"
  else
    error 'could not detect installation type in unzipped download.'
  fi
}

cleanup(){
  # description of what function does.
  local description='Removes temporary items created during the download and installation processes.'

  local applicationPath="/Applications/${applicationName}.app"

  # if a temporary mount directory has been created, force unmount and remove the directory.
  if [[ -d "${mnt}" ]]; then
    /usr/bin/hdiutil detach -force -quiet "${mnt}"
    /sbin/umount -f "${mnt}" &> /dev/null
    /bin/rm -rf "${mnt}" &> /dev/null
  fi

  # if temporary unzip directory exists, remove it.
  if [[ -d "${uz}" ]]; then
    /bin/rm -rf "${uz}" &> /dev/null
  fi

  # if the defined application does not exist restore the original to the apps directory.
  if [[ ! -d "${applicationPath}" ]]; then
    printf '%s\n' 'Update failed. Restoring original application...'
    /bin/mv "${applicationPath}.old" "${applicationPath}" &> /dev/null
  elif [[ -d "${applicationPath}.old" ]]; then
    /bin/rm -rf "${applicationPath}.old" &> /dev/null
  fi

  # if a temporary download directory has been created. remove it.
  if [[ -d "${dlDir}" ]]; then
    /bin/rm -rf "${dlDir}" &> /dev/null
  fi
}

main(){

  # declare local variables
  applicationName='Slack'
  local latestVersionUrl='https://slack.com/downloads/mac'
  local latestDownloadUrl='https://slack.com/ssb/download-osx'
  local applicationPath="/Applications/${applicationName}.app"
  local installedVersion
  local latestVersion

  # ensure cleanup runs on exit or error.
  trap cleanup EXIT ERR

  # export global variables
  export applicationName

  # determine if the application needs to be updated.
  installedVersion="$( get_installed_version "${applicationPath}" )" || exit 1
  latestVersion="$( get_latest_version "${latestVersionUrl}" )" || exit 1
  compare_versions "${latestVersion}" "${installedVersion}"

  # download latest version of the application and export full path to the temporary download location for the cleanup function.
  download "${latestDownloadUrl}"

  # determine if application is running and notify customer before attempting kill.
  detect_running
  kill_running

  # uninstall the application if neeeded for the update.
  uninstall "${applicationPath}"

  # install latest version of the application.
  install
  message 'Update Successful'
  exit 0
}
main "$@"
