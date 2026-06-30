#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME=NagBar
SCREENSHOT_PATH=
SETTINGS_SCREENSHOT_PATH=
SMOKE_DIR=
DEFAULTS_SUITE="com.volendavidov.NagBar.status-smoke.$$"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --screenshot)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --screenshot\n' >&2
        exit 2
      fi
      SCREENSHOT_PATH=$1
      ;;
    --settings-screenshot)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --settings-screenshot\n' >&2
        exit 2
      fi
      SETTINGS_SCREENSHOT_PATH=$1
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

SMOKE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nagbar-status-smoke.XXXXXX")
cleanup() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  launchctl unsetenv NAGBAR_APPLICATION_SUPPORT_DIR >/dev/null 2>&1 || true
  launchctl unsetenv NAGBAR_USER_DEFAULTS_SUITE >/dev/null 2>&1 || true
  launchctl unsetenv TESTS_RUNNING >/dev/null 2>&1 || true
  defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
  if [ -n "$SMOKE_DIR" ]; then
    rm -rf "$SMOKE_DIR"
  fi
}
trap cleanup EXIT INT TERM

defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
defaults write "$DEFAULTS_SUITE" savePassword -string 0
launchctl setenv NAGBAR_APPLICATION_SUPPORT_DIR "$SMOKE_DIR/ApplicationSupport"
launchctl setenv NAGBAR_USER_DEFAULTS_SUITE "$DEFAULTS_SUITE"
launchctl setenv TESTS_RUNNING YES

"$ROOT_DIR/script/build_and_run.sh" --release --verify >/tmp/nagbar-status-item-build.log

if [ -n "$SETTINGS_SCREENSHOT_PATH" ]; then
  mkdir -p "$(dirname -- "$SETTINGS_SCREENSHOT_PATH")"
fi
export SETTINGS_SCREENSHOT_PATH

osascript <<'APPLESCRIPT'
on assertTrue(conditionValue, messageText)
  if conditionValue is false then error messageText
end assertTrue

on countIdentifier(theElement, targetIdentifier)
  tell application "System Events"
    set total to 0
    try
      if (value of attribute "AXIdentifier" of theElement as text) is targetIdentifier then set total to total + 1
    end try
    try
      repeat with childElement in UI elements of theElement
        set total to total + my countIdentifier(childElement, targetIdentifier)
      end repeat
    end try
    return total
  end tell
end countIdentifier

on statusMenuItem()
  tell application "System Events"
    repeat with attemptNumber from 1 to 40
      if exists process "NagBar" then
        tell process "NagBar"
          repeat with menuBarRef in menu bars
            repeat with menuBarItemRef in menu bar items of menuBarRef
              try
                if (value of attribute "AXTitle" of menuBarItemRef as text) is "NagBar status menu" then
                  return menuBarItemRef
                end if
              end try
            end repeat
          end repeat
        end tell
      end if
      delay 0.25
    end repeat
  end tell
  error "NagBar status menu accessibility item was not found"
end statusMenuItem

on openStatusMenu()
  tell application "System Events"
    tell process "NagBar"
      set itemRef to my statusMenuItem()
      perform action "AXPress" of itemRef
      delay 0.3
      return itemRef
    end tell
  end tell
end openStatusMenu

on assertStatusMenuShape()
  tell application "System Events"
    tell process "NagBar"
      set itemRef to my openStatusMenu()
      set labels to {}
      repeat with menuItemRef in menu items of menu 1 of itemRef
        try
          set end of labels to name of menuItemRef as text
        on error
          set end of labels to ""
        end try
      end repeat

      my assertTrue(labels contains "Show Status", "Status menu missing Show Status")
      my assertTrue(labels contains "About NagBar", "Status menu missing About NagBar")
      my assertTrue(labels contains "Preferences", "Status menu missing Preferences")
      my assertTrue(labels contains "Refresh", "Status menu missing Refresh")
      my assertTrue(labels contains "Quit", "Status menu missing Quit")
    end tell
  end tell
end assertStatusMenuShape

on assertShowStatusOpensPanel()
  tell application "System Events"
    tell process "NagBar"
      repeat with attemptNumber from 1 to 12
        set itemRef to my openStatusMenu()
        click menu item "Show Status" of menu 1 of itemRef
        delay 1

        set panelCount to 0
        set tableCount to 0
        repeat with windowRef in windows
          try
            if (value of attribute "AXIdentifier" of windowRef as text) is "nagbar.statusPanel" then
              set panelCount to panelCount + 1
              set tableCount to tableCount + my countIdentifier(windowRef, "nagbar.statusPanel.table")
            end if
          end try
        end repeat

        if panelCount > 0 and tableCount > 0 then return
        delay 0.5
      end repeat

      error "Show Status did not open nagbar.statusPanel with nagbar.statusPanel.table"
    end tell
  end tell
end assertShowStatusOpensPanel

on assertKeyboardShowStatusOpensPanel()
  tell application "System Events"
    tell process "NagBar"
      repeat with attemptNumber from 1 to 12
        set itemRef to my openStatusMenu()
        key code 125
        delay 0.1
        key code 36
        delay 1

        set panelCount to 0
        set tableCount to 0
        repeat with windowRef in windows
          try
            if (value of attribute "AXIdentifier" of windowRef as text) is "nagbar.statusPanel" then
              set panelCount to panelCount + 1
              set tableCount to tableCount + my countIdentifier(windowRef, "nagbar.statusPanel.table")
            end if
          end try
        end repeat

        if panelCount > 0 and tableCount > 0 then return
        delay 0.5
      end repeat

      error "Keyboard Down/Return did not open nagbar.statusPanel with nagbar.statusPanel.table"
    end tell
  end tell
end assertKeyboardShowStatusOpensPanel

on assertRefreshKeepsAppAlive()
  tell application "System Events"
    tell process "NagBar"
      set itemRef to my openStatusMenu()
      click menu item "Refresh" of menu 1 of itemRef
      delay 1
      my assertTrue(exists menu bar item 1 of menu bar 2, "Refresh removed the status item")
    end tell
  end tell
end assertRefreshKeepsAppAlive

on assertApplicationMenuHasNoProductEntrypoints()
  tell application "System Events"
    tell process "NagBar"
      set appMenuRef to missing value
      repeat with menuBarItemRef in menu bar items of menu bar 1
        try
          if (name of menuBarItemRef as text) is "NagBar" then
            set appMenuRef to menu 1 of menuBarItemRef
            exit repeat
          end if
        end try
      end repeat

      my assertTrue(appMenuRef is not missing value, "NagBar application menu was not found")

      set labels to {}
      repeat with menuItemRef in menu items of appMenuRef
        try
          set end of labels to name of menuItemRef as text
        on error
          set end of labels to ""
        end try
      end repeat

      my assertTrue(labels does not contain "About NagBar", "Application menu still exposes About NagBar")
      my assertTrue(labels does not contain "Preferences", "Application menu still exposes Preferences")
    end tell
  end tell
end assertApplicationMenuHasNoProductEntrypoints

assertStatusMenuShape()
assertShowStatusOpensPanel()
assertKeyboardShowStatusOpensPanel()
assertRefreshKeepsAppAlive()
assertApplicationMenuHasNoProductEntrypoints()
APPLESCRIPT

osascript <<'APPLESCRIPT'
on countIdentifier(theElement, targetIdentifier)
  tell application "System Events"
    set total to 0
    try
      if (value of attribute "AXIdentifier" of theElement as text) is targetIdentifier then set total to total + 1
    end try
    try
      repeat with childElement in UI elements of theElement
        set total to total + my countIdentifier(childElement, targetIdentifier)
      end repeat
    end try
    return total
  end tell
end countIdentifier

on statusMenuItem()
  tell application "System Events"
    tell process "NagBar"
      repeat with menuBarRef in menu bars
        repeat with menuBarItemRef in menu bar items of menuBarRef
          try
            if (value of attribute "AXTitle" of menuBarItemRef as text) is "NagBar status menu" then return menuBarItemRef
          end try
        end repeat
      end repeat
    end tell
  end tell
  error "NagBar status menu accessibility item was not found"
end statusMenuItem

tell application "System Events"
  tell process "NagBar"
    set itemRef to my statusMenuItem()
    perform action "AXPress" of itemRef
    delay 0.3
    click menu item "Show Status" of menu 1 of itemRef
    repeat with attemptNumber from 1 to 20
      repeat with windowRef in windows
        try
          if (value of attribute "AXIdentifier" of windowRef as text) is "nagbar.statusPanel" then return
        end try
      end repeat
      delay 0.25
    end repeat
  end tell
end tell

error "Status panel did not open"
APPLESCRIPT

if [ -n "$SCREENSHOT_PATH" ]; then
  mkdir -p "$(dirname -- "$SCREENSHOT_PATH")"
  screencapture -x "$SCREENSHOT_PATH"
fi

osascript <<'APPLESCRIPT'
on assertTrue(conditionValue, messageText)
  if conditionValue is false then error messageText
end assertTrue

on countIdentifier(theElement, targetIdentifier)
  tell application "System Events"
    set total to 0
    try
      if (value of attribute "AXIdentifier" of theElement as text) is targetIdentifier then set total to total + 1
    end try
    try
      repeat with childElement in UI elements of theElement
        set total to total + my countIdentifier(childElement, targetIdentifier)
      end repeat
    end try
    return total
  end tell
end countIdentifier

on statusMenuItem()
  tell application "System Events"
    tell process "NagBar"
      repeat with menuBarRef in menu bars
        repeat with menuBarItemRef in menu bar items of menuBarRef
          try
            if (value of attribute "AXTitle" of menuBarItemRef as text) is "NagBar status menu" then
              return menuBarItemRef
            end if
          end try
        end repeat
      end repeat
    end tell
  end tell
  error "NagBar status menu accessibility item was not found for Preferences"
end statusMenuItem

on pressIdentifier(parentElement, targetIdentifier)
  tell application "System Events"
    try
      if (value of attribute "AXIdentifier" of parentElement as text) is targetIdentifier then
        perform action "AXPress" of parentElement
        return true
      end if
    end try
    try
      repeat with childElement in UI elements of parentElement
        if my pressIdentifier(childElement, targetIdentifier) then return true
      end repeat
    end try
    return false
  end tell
end pressIdentifier

tell application "System Events"
  tell process "NagBar"
    set itemRef to my statusMenuItem()
    perform action "AXPress" of itemRef
    delay 0.3
    click menu item "Preferences" of menu 1 of itemRef

    repeat with attemptNumber from 1 to 20
      if exists window "Preferences" then exit repeat
      delay 0.25
    end repeat
    my assertTrue(exists window "Preferences", "Preferences did not open from the status item")

    tell window "Preferences"
      click radio button "Monitoring Instances" of tab group 1
      delay 0.3
      my assertTrue(my pressIdentifier(tab group 1, "monitoringInstancesButton"), "Monitoring Instances button was not found")
    end tell

    repeat with attemptNumber from 1 to 20
      set tableCount to 0
      repeat with windowRef in windows
        try
          if (name of windowRef as text) is "Monitoring Instances" then
            set tableCount to tableCount + my countIdentifier(windowRef, "nagbar.monitoringInstances.table")
          end if
        end try
      end repeat
      if tableCount > 0 then return
      delay 0.25
    end repeat

    error "Monitoring Instances table did not open from Preferences"
  end tell
end tell
APPLESCRIPT

osascript <<'APPLESCRIPT'
on assertTrue(conditionValue, messageText)
  if conditionValue is false then error messageText
end assertTrue

on countIdentifier(theElement, targetIdentifier)
  tell application "System Events"
    set total to 0
    try
      if (value of attribute "AXIdentifier" of theElement as text) is targetIdentifier then set total to total + 1
    end try
    try
      repeat with childElement in UI elements of theElement
        set total to total + my countIdentifier(childElement, targetIdentifier)
      end repeat
    end try
    return total
  end tell
end countIdentifier

tell application "System Events"
  tell process "NagBar"
    repeat with attemptNumber from 1 to 20
      if exists window "Monitoring Instances" then exit repeat
      delay 0.25
    end repeat
    my assertTrue(exists window "Monitoring Instances", "Monitoring Instances window was not available for add-row proof")

    tell window "Monitoring Instances"
      click button 1 of group 1
      delay 0.5
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.name.0") > 0, "Monitoring Instances row did not expose name cell")
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.enabled.0") > 0, "Monitoring Instances row did not expose enabled cell")
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.type.0") > 0, "Monitoring Instances row did not expose type cell")
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.url.0") > 0, "Monitoring Instances row did not expose URL cell")
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.username.0") > 0, "Monitoring Instances row did not expose username cell")
      my assertTrue(my countIdentifier(it, "nagbar.monitoringInstances.cell.password.0") > 0, "Monitoring Instances row did not expose password cell")
      if (system attribute "SETTINGS_SCREENSHOT_PATH") is not "" then
        do shell script "/usr/sbin/screencapture -x " & quoted form of (system attribute "SETTINGS_SCREENSHOT_PATH")
      end if
    end tell
  end tell
end tell
APPLESCRIPT

STORAGE_FILE="$SMOKE_DIR/ApplicationSupport/com.volendavidov.NagBar/monitoring-instances.json"
if [ ! -s "$STORAGE_FILE" ]; then
  printf 'Monitoring Instances add-row smoke did not write isolated storage: %s\n' "$STORAGE_FILE" >&2
  exit 1
fi

if ! grep -q '"name":"New"' "$STORAGE_FILE"; then
  printf 'Monitoring Instances add-row smoke wrote unexpected storage:\n' >&2
  cat "$STORAGE_FILE" >&2
  exit 1
fi

osascript <<'APPLESCRIPT'
on statusMenuItem()
  tell application "System Events"
    tell process "NagBar"
      repeat with menuBarRef in menu bars
        repeat with menuBarItemRef in menu bar items of menuBarRef
          try
            if (value of attribute "AXTitle" of menuBarItemRef as text) is "NagBar status menu" then
              return menuBarItemRef
            end if
          end try
        end repeat
      end repeat
    end tell
  end tell
  error "NagBar status menu accessibility item was not found for Quit"
end statusMenuItem

tell application "System Events"
  tell process "NagBar"
    set itemRef to my statusMenuItem()
    perform action "AXPress" of itemRef
    delay 0.3
    repeat 5 times
      key code 125
      delay 0.05
    end repeat
    key code 36
  end tell
end tell
APPLESCRIPT

i=0
while [ "$i" -lt 20 ]; do
  if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    printf 'Status item smoke passed\n'
    exit 0
  fi
  i=$((i + 1))
  sleep 0.5
done

printf '%s did not quit through the status item menu\n' "$APP_NAME" >&2
exit 1
