-- move focus around
-- focus into "main"
-- focus into "split"
-- unfocus
-- rotate "focus" through applications
-- what to do about spaces?

-- Global Data
UNFOCUSED = 0
FOCUSED_SINGLE = 1
FOCUSED_DOUBLE = 2
state = UNFOCUSED
innerPadding = 8
outerPadding = 16
centerPadding = 0
focusedWindow2 = nil

function isWideScreen()
    local screens = hs.screen.allScreens()
    for _, screen in ipairs(screens) do
        local f = screen:frame()
        if f.w > 2560 then
            return true
        end
    end
    return false
end

wideDisplay = isWideScreen()
if wideDisplay then
   workingWidthRatio = (2 / 3)
   workingWidthRatio2 = (1 / 1.7)
else
   workingWidthRatio = 1
   workingWidthRatio2 = 1
end

savedWindows = {}
workingWindowSet = {}

--- Helper Functions
function isIn(list, item)
   for _, listIter in ipairs(list) do
      if listIter == item then
         return true
      end
   end
   return false
end

function isVisible(window)
    local f = window:frame()
    if f.h == 0 or f.w == 0 then
        return false
    end
    if f.w == 0 then
        return false
    end
    if window:role() ~= "AXWindow" then
        return false
    end
    return true
end

function addToSavedWindows(window)
    local frame = window:frame()
    table.insert(savedWindows, {win=window,x=frame.x,y=frame.y,w=frame.w,h=frame.h})
    print("Added '" .. window:application():name() .. "' to saved windows [" .. #savedWindows .. "]")
end

function clearSavedWindows()
    savedWindows = {}
end

function addToWorkingSet(window)
    local frame = window:frame()
    table.insert(workingWindowSet, {win=window,x=frame.x,y=frame.y,w=frame.w,h=frame.h})
    print("Added '" .. window:application():name() .. "' to working set of windows [" .. #workingWindowSet .. "]")
end

function clearWorkingSet()
    workingWindowSet = {}
end

function findWindowInWorkingSetByBundleId(bundleid)
    for id, window in ipairs(workingWindowSet) do
        print("Looking at id " .. id .. " named: " .. window.win:application():name())
        if bundleid == window.win:application():bundleID() then
            print("returning " .. id)
            return id
        end
    end
    return 0
end

-- Swap registryWindow with 'id' with current window. Assume geometry of window as well.
function swapWindowWithRegistryId(window, id)
    if id < 1 or #workingWindowSet < id then
        print("Cannot swap with invalid window registry ID")
        return nil
    end

    print("Minimize and register " .. window:application():name())
    local frame = window:frame()
    addToWorkingSet(window)
    window:minimize()

    window = workingWindowSet[id]
    print("Unminimizing: " .. window.win:application():name())
    print(" x: " .. window.x .. " y: " .. window.y .. " w: " .. window.w .. " h: " .. window.h)
    window.win:setFrame(frame)
    window.win:unminimize()
    window.win:focus()
    window.win:raise()

    table.remove(workingWindowSet, id)
    return window
end

function clearWorkspace(focusedWindows)
    if state == FOCUSED then
        return false
    end
    state = FOCUSED
    hs.alert.show("Focus mode")
 
    local visibles = hs.window.visibleWindows()
    -- Save visible windows as "session"
    for _, window in ipairs(visibles) do
        if isVisible(window) then
            addToSavedWindows(window)
        end
    end

    -- Setup working set. Minimize non-focused windows.
    for _, window in ipairs(visibles) do
        if not isIn(focusedWindows, window) and
           isVisible(window) and
           window:application():name() ~= "Finder" then
            addToWorkingSet(window)
            window:minimize()
        end
    end
    return true
end

function restoreWorkspace()
   if state == UNFOCUSED then
      print("Was already unfocused")
      return
   end
   state = UNFOCUSED
   hs.alert.show("Chaotic mode")

   -- Save off focused window
   local window = hs.window.focusedWindow()

   print("Restore " .. #savedWindows .. " windows...")
   for _, w in ipairs(savedWindows) do
      print("Restore " .. w.win:application():name() .. " from saved windows")
      w.win:setFrame({x=w.x, y=w.y, w=w.w, h=w.h})
      w.win:unminimize()
   end
   clearSavedWindows()
   clearWorkingSet()

   if window then
      print("Update focus")
      window:focus()
      window:raise()
   end
end

function portraitMode()
   local primaryScreen = hs.screen.primaryScreen()
   primaryScreen:rotate(90)
end

function landscapeMode()
   local primaryScreen = hs.screen.primaryScreen()
   primaryScreen:rotate(0)
end

function isPortraitMode()
   local frame = hs.screen.mainScreen():frame()
   return frame.w < frame.h
end

-- Return frame obj with geometry for single focus frame
local function getFocusTargetFrame(window)
   local screenFrame = window:screen():frame()
   local workingWidth = screenFrame.w * workingWidthRatio
   local workingHeight = screenFrame.h
   local newX = (screenFrame.w - workingWidth) / 2
   local frame = { x = newX + outerPadding,
                   y = screenFrame.y + outerPadding,
                   w = workingWidth - (2 * outerPadding),
                   h = screenFrame.h - (2 * outerPadding) }
   return frame
end

-- Return frame obj with geometry for two focus frames
local function getFocusTargetFrames(window)
    local screenFrame = window:screen():frame()
    local workingWidth = screenFrame.w * workingWidthRatio
    local workingHeight = screenFrame.h
    local newX = (screenFrame.w - workingWidth) / 2
    local frameL = { x = newX + outerPadding,
                     y = screenFrame.y + outerPadding,
                     w = (workingWidth / 2) - outerPadding - (innerPadding / 2),
                     h = screenFrame.h - (2 * outerPadding) }
    local frameR = { x = (screenFrame.w / 2) + innerPadding,
                     y = screenFrame.y + outerPadding,
                     w = (workingWidth / 2) - (innerPadding / 2) - outerPadding,
                     h = screenFrame.h - (2 * outerPadding) }
    return frameL, frameR
end

local function getLargestWindow(focusedWindow)
   local largestWindow = nil
   local largestArea = 0
   local allWindows = hs.window.visibleWindows()

   for _, window in ipairs(allWindows) do
      if window ~= focusedWindow and
          isVisible(window) and
          window:application():name() ~= "Finder" then
         local frame = window:frame()
         local area = frame.w * frame.h
         if area > largestArea then
            largestArea = area
            largestWindow = window
         end
      end
   end

   return largestWindow
end

function focusBundleId(bundleId)
   if state == UNFOCUSED then
      hs.application.launchOrFocusByBundleID(bundleId)
   else
      -- Activate from focused windows or swap from registry
      local focused = hs.window.focusedWindow()
      if focused == nil then
         print("No focused window")
         return
      end
      local id = findWindowInWorkingSetByBundleId(bundleId)
      if id < 1 then
         print("No window in registry with bundleID " .. bundleId)
         return
      end
      swapWindowWithRegistryId(focused, id)
   end
end

function centerFocusedWindow2()
    local focusedWindow = hs.window.focusedWindow()
    if not focusedWindow then return end

    -- Get the largest visible window other than the focused one
    local largestWindow = getLargestWindow(focusedWindow)
    if not largestWindow then return end

    -- Minimize all other windows in the space
    local allWindows = hs.window.visibleWindows()
    for _, window in ipairs(allWindows) do
        if window ~= focusedWindow and window ~= largestWindow then
            window:minimize()
        end
    end

    local screenFrame = focusedWindow:screen():frame()

    -- Calculate the width for each window (half of the screen width)
    local windowWidth = (screenFrame.w * workingWidthRatio2) / 2
    local leftPadding = (screenFrame.w - (windowWidth * 2)) / 2

    -- Set the frames for the focused window and the largest window
    focusedWindow:setFrame({
        x = leftPadding,
        y = screenFrame.y + outerPadding,
        w = windowWidth - innerPadding,
        h = screenFrame.h - (2 * outerPadding)
    })

    largestWindow:setFrame({
        x = leftPadding + windowWidth + innerPadding,
        y = screenFrame.y + outerPadding,
        w = windowWidth,
        h = screenFrame.h - (2 * outerPadding)
    })
end

-- Desktop Event methods
function focusSingle()
    local focusedWindow = hs.window.focusedWindow()
    if not focusedWindow then return end
    success = clearWorkspace({focusedWindow,})
    if not success then return end
    focusWindows = 1

    -- Set the new frame for the window
    local focusFrame = getFocusTargetFrame(focusedWindow)
    focusedWindow:setFrame(focusFrame)
end

function focusDouble()
    local focusedWindow = hs.window.focusedWindow()
    clearWorkspace({focusedWindow, focusedWindow2})
    focusWindows = 2

    -- Set the new frame for the window
    local frameL, frameR = getFocusTargetFrames(focusedWindow)
    focusedWindow:setFrame(frameL)
end

function unfocus()
    restoreWorkspace()
end

function focusOther()
end

function pushLeft()
    local focus = hs.window.focusedWindow()
    if focus == nil then return end

    local frame = focus:screen():frame()
    local newFrame = { x = frame.x + outerPadding,
                       y = frame.y + outerPadding,
                       w = (frame.w / 2) - outerPadding - (innerPadding / 2),
                       h = frame.h - (2 * outerPadding) }
    focus:setFrame(newFrame)
end

function pushRight()
    local focus = hs.window.focusedWindow()
    if focus == nil then return end

    local frame = focus:screen():frame()
    local newFrame = { x = (frame.w / 2) + (innerPadding / 2),
                       y = frame.y + outerPadding,
                       w = (frame.w / 2) - (innerPadding / 2) - outerPadding,
                       h = frame.h - (2 * outerPadding) }
    focus:setFrame(newFrame)
end

function pushFull()
    local focus = hs.window.focusedWindow()
    if focus == nil then return end

    local desktop = focus:screen():frame()
    local newFrame = {}
    if isWideScreen then
        newFrame.w = desktop.w - (desktop.w / 3) - (2 * centerPadding)
        newFrame.h = desktop.h - (2 * centerPadding)
        newFrame.x = (desktop.w - newFrame.w) / 2
        newFrame.y = desktop.y + centerPadding
    else
        newFrame.w = desktop.w - (2 * centerPadding)
        newFrame.h = desktop.h - (2 * centerPadding)
        newFrame.x = desktop.x + centerPadding
        newFrame.y = desktop.y + centerPadding
    end
    focus:setFrame(newFrame)
end

function pushTop()
    local focus = hs.window.focusedWindow()
    if focus == nil then return end

    local frame = focus:screen():frame()
    local newFrame = { x = frame.x + outerPadding,
                       y = frame.y + outerPadding,
                       w = frame.w - (2 * outerPadding),
                       h = (frame.h / 2) - outerPadding - (innerPadding / 2) }
    focus:setFrame(newFrame)
end

function pushBottom()
    local focus = hs.window.focusedWindow()
    if focus == nil then return end

    local frame = focus:screen():frame()
    local newFrame = { x = frame.x + outerPadding,
                       y = frame.y + (frame.h / 2) + (innerPadding / 2),
                       w = frame.w - (2 * outerPadding),
                       h = (frame.h / 2) - outerPadding - (innerPadding / 2) }
    focus:setFrame(newFrame)
end

function focusNext()
    if #workingWindowSet < 1 then
        print("No windows in registry")
        return
    end
    local window = hs.window.focusedWindow()
    if window == nil then
        print("No focused window")
        return
    end

    print("Swapping...")
    swapWindowWithRegistryId(window, 1)
end

-- Key bindings
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "D", function()
        print("Dump Visible Windows...")
        local windows = hs.window.visibleWindows()
        for _, w in ipairs(windows) do
            local frame = w:frame()
            print("window with name: " .. w:application():name() .. " x: " .. frame.x .. " y: " .. frame.y .. " w: " .. frame.w .. " h: " .. frame.h .. " visible: " .. tostring(isVisible(w)) .. " bundleID: " .. w:application():bundleID())
        end
        print("Dump Working Set...")
        for _, w in ipairs(workingWindowSet) do
            print("window with name: " .. w.win:application():name() .. " x: " .. w.x .. " y: " .. w.y .. " w: " .. w.w .. " h: " .. w.h .. " role: " .. w:role() .. " sub-role: " .. w:subrole())
        end
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "C", function()
    focusSingle()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "V", function()
    focusDouble()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "N", function()
      focusNext()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "O", function()
      focusOther()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "I", function()
      -- focusBundleId("com.googlecode.iterm2")
      -- focusBundleId("org.alacritty")
      focusBundleId("com.github.wez.wezterm")
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "F", function()
      focusBundleId("org.mozilla.firefox")
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", function()
      focusBundleId("com.microsoft.teams2")
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "U", function()
    unfocus()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "H", function()
      print("left")
      pushLeft()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "J", function()
      print("bottom")
      pushBottom()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "K", function()
      print("top")
      pushTop()
end)
hs.hotkey.bind({"shift", "cmd", "alt", "ctrl"}, "J", function()
        local focus = hs.window.focusedWindow()
        if focus == nil then return end

        if centerPadding > 0 then
            centerPadding = centerPadding - 25
            pushFull()
        end
        hs.alert.show("Center padding: " .. centerPadding)
end)
hs.hotkey.bind({"shift", "cmd", "alt", "ctrl"}, "K", function()
        local focus = hs.window.focusedWindow()
        if focus == nil then return end

        if centerPadding < 1000 then
            centerPadding = centerPadding + 25
            pushFull()
        end
        hs.alert.show("Center padding: " .. centerPadding)
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "L", function()
      print("right")
      pushRight()
end)
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "X", function()
      print("full")
      pushFull()
end)
hyper = {"cmd", "shift", "alt", "ctrl"}
hs.hotkey.bind(hyper, "R", function()
                  hs.reload()
end)
hs.alert.show("Config loaded")

