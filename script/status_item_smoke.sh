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
NAGBAR_WINDOW_PROBE="$SMOKE_DIR/nagbar_window_probe.swift"
NAGBAR_NAMED_WINDOW_PROBE="$SMOKE_DIR/nagbar_named_window_probe.swift"
cat >"$NAGBAR_WINDOW_PROBE" <<'SWIFT'
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let visiblePanel = windows.contains { window in
    guard (window[kCGWindowOwnerName as String] as? String) == "NagBar" else {
        return false
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    guard layer == 0 else {
        return false
    }

    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else {
        return false
    }

    return width > 300 && height > 50
}

exit(visiblePanel ? 0 : 1)
SWIFT
cat >"$NAGBAR_NAMED_WINDOW_PROBE" <<'SWIFT'
import CoreGraphics
import Foundation

let expectedName = ProcessInfo.processInfo.environment["NAGBAR_EXPECTED_WINDOW_NAME"] ?? ""
let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let visibleWindow = windows.contains { window in
    guard (window[kCGWindowOwnerName as String] as? String) == "NagBar" else {
        return false
    }

    guard (window[kCGWindowName as String] as? String) == expectedName else {
        return false
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    guard layer == 0 else {
        return false
    }

    return (window[kCGWindowIsOnscreen as String] as? Int ?? 0) == 1
}

exit(visibleWindow ? 0 : 1)
SWIFT
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
export NAGBAR_WINDOW_PROBE
export NAGBAR_NAMED_WINDOW_PROBE

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

on statusPanelWindowVisible()
  try
    do shell script "/usr/bin/swift " & quoted form of (system attribute "NAGBAR_WINDOW_PROBE")
    return true
  on error
    return false
  end try
end statusPanelWindowVisible

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
        perform action "AXPress" of menu item "Show Status" of menu 1 of itemRef
        delay 1

        if my statusPanelWindowVisible() then return
        delay 0.5
      end repeat

      error "Show Status did not open an onscreen NagBar status panel"
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

        if my statusPanelWindowVisible() then return
        delay 0.5
      end repeat

      error "Keyboard Down/Return did not open an onscreen NagBar status panel"
    end tell
  end tell
end assertKeyboardShowStatusOpensPanel

on assertRefreshKeepsAppAlive()
  tell application "System Events"
    tell process "NagBar"
      set itemRef to my openStatusMenu()
      perform action "AXPress" of menu item "Refresh" of menu 1 of itemRef
      delay 1
      my assertTrue(my statusMenuItem() is not missing value, "Refresh removed the status item")
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

on statusPanelWindowVisible()
  try
    do shell script "/usr/bin/swift " & quoted form of (system attribute "NAGBAR_WINDOW_PROBE")
    return true
  on error
    return false
  end try
end statusPanelWindowVisible

tell application "System Events"
  tell process "NagBar"
    set itemRef to my statusMenuItem()
    perform action "AXPress" of itemRef
    delay 0.3
    perform action "AXPress" of menu item "Show Status" of menu 1 of itemRef
    repeat with attemptNumber from 1 to 20
      if my statusPanelWindowVisible() then return
      delay 0.25
    end repeat
  end tell
end tell

error "Status panel did not open onscreen"
APPLESCRIPT

if [ -n "$SCREENSHOT_PATH" ]; then
  mkdir -p "$(dirname -- "$SCREENSHOT_PATH")"
  screencapture -x "$SCREENSHOT_PATH"
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
  error "NagBar status menu accessibility item was not found for Preferences"
end statusMenuItem

on namedWindowVisible(windowName)
  try
    do shell script "NAGBAR_EXPECTED_WINDOW_NAME=" & quoted form of windowName & " /usr/bin/swift " & quoted form of (system attribute "NAGBAR_NAMED_WINDOW_PROBE")
    return true
  on error
    return false
  end try
end namedWindowVisible

tell application "System Events"
  tell process "NagBar"
    set itemRef to my statusMenuItem()
    perform action "AXPress" of itemRef
    delay 0.3
    perform action "AXPress" of menu item "Preferences" of menu 1 of itemRef

    repeat with attemptNumber from 1 to 20
      if my namedWindowVisible("Preferences") then return
      delay 0.25
    end repeat
  end tell
end tell

error "Preferences did not open from the status item"
APPLESCRIPT

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
    perform action "AXPress" of menu item "Quit" of menu 1 of itemRef
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
