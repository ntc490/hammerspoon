innerPadding = 8
outerPadding = 16
focusColumn = 40
focusColumnDelta = 5
focusColumnMin = 10
focusColumnMax = 100

--- Hook to reload config
hyper = {"cmd", "shift", "alt", "ctrl"}
hs.hotkey.bind(hyper, "R", function()
      hs.reload()
end)
hs.alert.show("Config loaded")

--- Helper Functions
local previousApp = ""
function switchToAndFromApp(bundleID)
   local focusedWindow = hs.window.focusedWindow()  if focusedWindow == nil then
      hs.application.launchOrFocusByBundleID(bundleID)
   elseif focusedWindow:application():bundleID() == bundleID then
      if previousApp == nil then
         hs.window.switcher.nextWindow()
      else
         previousApp:activate()
      end
   else
      previousApp = focusedWindow:application()
      hs.application.launchOrFocusByBundleID(bundleID)
   end
end

function incFocusColumn()
   focusColumn = focusColumn + focusColumnDelta
   if focusColumn >= focusColumnMax then
      focusColumn = focusColumnMax
   end
   sample = "focus column percentage: " .. tostring(focusColumn)
   hs.alert.show(sample)
end

function decFocusColumn()
   focusColumn = focusColumn - focusColumnDelta
   if focusColumn <= focusColumnMin then
      focusColumn = focusColumnMin
   end
   sample = "focus column percentage: " .. tostring(focusColumn)
   hs.alert.show(sample)
end

-- Divvy Strategy
function getColumns(rect)
   local focusColWidth = rect.w * focusColumn / 100

   cols = {}
   cols[0] = rect.x
   cols[1] = rect.x + ((rect.w - focusColWidth) / 2)
   cols[2] = cols[1] + focusColWidth
   cols[3] = focusColWidth

   return cols
end

function getRows(rect)
   rows = {}
   rows[0] = rect.y
   rows[1] = rows[0] + (rect.h / 2)

   return rows
end

function getX(cols, col)
   local x

   if col == 0 then
      x = cols[0] + outerPadding
   elseif col == 1 then
      x = cols[1] + innerPadding / 2
   elseif col >= 2 then
      x = cols[2] + innerPadding / 2
   end

   return x
end

function getY(rows, row)
   local y
   if row == 0 or row == 2 then
      y = rows[0] + outerPadding
   elseif row == 1 then
      y = rows[1] + innerPadding / 2
   end

   return y
end

function getW(cols, col)
   local w

   if col == 0 then
      w = cols[1] - outerPadding - innerPadding/2
   elseif col == 1 then
      w = cols[3] - innerPadding
   elseif col >= 2 then
      w = cols[1] - outerPadding - innerPadding/2
   end

   return w
end

function getH(rows, row)
   local h
   h = getY(rows, 1) - getY(rows, 0) - innerPadding
   if row == 2 then
      h = h * 2 + innerPadding
   end
   return h
end

function makeSpot(cols, rows, c, r, num)
   local spot = {}
   spot.num = num
   spot.x = getX(cols, c)
   spot.y = getY(rows, r)
   spot.w = getW(cols, c)
   spot.h = getH(rows, r)
   return spot
end

-- API function: return screenmap
function divvy(screen)
   local map = {}
   map.len = 5
   map.spots = {}

   local r = screen:frame()
   local cols = getColumns(r)
   local rows = getRows(r)

   map.spots[0] = makeSpot(cols, rows, 1, 2, 0)
   map.spots[1] = makeSpot(cols, rows, 0, 0, 1)
   map.spots[2] = makeSpot(cols, rows, 0, 1, 2)
   map.spots[3] = makeSpot(cols, rows, 3, 0, 3)
   map.spots[4] = makeSpot(cols, rows, 3, 1, 4)
   return map
end

function driver(spotNum)
   local cwin = hs.window.focusedWindow()
   local screen = cwin:screen()

   local map = divvy(screen)
   local s = map.spots[spotNum]

   local f = cwin:frame()
   f.x = s.x
   f.y = s.y
   f.w = s.w
   f.h = s.h
   cwin:setFrame(f)
end

function useSpot(win, spot)
   local f = win:frame()
   f.x = spot.x
   f.y = spot.y
   f.w = spot.w
   f.h = spot.h
   win:setFrame(f)
end

function layoutIterm(app, spots, focus)
   local iTermWindows = app:visibleWindows()
   local itermSpots = { spots[1], spots[3], spots[4] }

   for i,win in ipairs(iTermWindows) do
      if win ~= focus then
         local spot = table.remove(itermSpots, 1)
         if spot then
            print("Using spot " .. tostring(spot.num) .. " for iterm window " .. tostring(i))
            useSpot(win, spot)
         end
      end
   end
end

function layoutSlack(app, spots)
   local slackWindows = app:visibleWindows()
   for i,win in ipairs(slackWindows) do
      useSpot(win, spots[2])
   end
end

function workLayout()
   local focus = hs.window.focusedWindow()
   local screen = focus:screen()
   local spots = divvy(screen).spots

   print("Use spot 0 for focused iTerm2 window")
   useSpot(focus, spots[0])

   local app = hs.application.get("iTerm2")
   if app then
      layoutIterm(app, spots, focus)
   end

   local app = hs.application.get("Slack")
   if app then
      layoutSlack(app, spots)
   end
end

function wperfTest()
   local windows = hs.window.visibleWindows()
   for i,win in ipairs(windows) do
      local title = win:application():title()
      print("Iterated over window for " .. title)
   end
   print("done")
end

function aperfTest()
   local app = hs.application.get("iTerm2")
   if app == nil then
      print("App not found")
   else
      print("apps WAS found")
      local windows = app:visibleWindows()
      print(#windows)
   end
   print("done")
end

hs.window.animationDuration = 0

--- Keyboard Bindings
hs.hotkey.bind(hyper, "j", function()
      decFocusColumn()
      workLayout()
end)

hs.hotkey.bind(hyper, "k", function()
      incFocusColumn()
      workLayout()
end)

hs.hotkey.bind(hyper, "l", function()
      workLayout()
end)

hs.hotkey.bind(hyper, "p", function()
      aperfTest()
end)

hs.hotkey.bind(hyper, "5", function()
      driver(0)
end)

hs.hotkey.bind(hyper, "1", function()
      driver(1)
end)

hs.hotkey.bind(hyper, "2", function()
      driver(2)
end)

hs.hotkey.bind(hyper, "3", function()
      driver(3)
end)

hs.hotkey.bind(hyper, "4", function()
      driver(4)
end)

-- iterm
hs.hotkey.bind(hyper, "i", function()
      switchToAndFromApp("com.googlecode.iterm2")
end)

-- Teams
hs.hotkey.bind(hyper, "t", function()
      switchToAndFromApp("com.microsoft.teams")
end)

-- Web browser
hs.hotkey.bind(hyper, "w", function()
      switchToAndFromApp("org.mozilla.firefox")
end)

-- Temp function to get the active bundle id
hs.hotkey.bind(hyper, "b", function()
      local bundleid = hs.window.focusedWindow():application():bundleID()
      hs.alert.show(bundleid)
      hs.pasteboard.setContents(bundleid)
end)

end)
