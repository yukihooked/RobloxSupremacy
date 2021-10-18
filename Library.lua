local UserInputService = game:GetService("UserInputService") -- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer -- Locals
local currentCamera = Workspace.CurrentCamera

local wrap = coroutine.wrap -- Cache
local insert = table.insert
local remove = table.remove
local find = table.find
local getMouseLocation = UserInputService.GetMouseLocation
local HttpGet = game.HttpGet
local type = type
local genv = getgenv
local nVector3 = Vector3.new
local nVector2 = Vector2.new
local nRGB = Color3.fromRGB
local nHSV = Color3.fromHSV
local nInstance = Instance.new
local nDrawing = Drawing.new

local screenSize = nVector2(currentCamera.ViewportSize.X, currentCamera.ViewportSize.Y) -- Screen
local screenCenter = nVector2(currentCamera.ViewportSize.X/2, currentCamera.ViewportSize.Y/2)

local frameworkHook
local framework = {
    connections = {},
    imgCache = {},
    notifications = {},
    labels = {},
    theme = {
        accent = nHSV(28,100,99),
        font = Drawing.Fonts.Plex,
        fontSize = 13
    },
    menu = {
        open = true,
        fading = false,
        cursor = nil,
        colorClipboard = nil,
        currentTab = nil,
        dragStart = nVector2(),
        accents = {},
        hiddenDrawings = {},
        sliderDragging = false,
        bindingKey = false,
        currentKeybind = nil,
        currentSlider = nil,
        currentDropdown = nil,
        keybinds = {},
        reservedKeybinds = {
            menuKey = Enum.KeyCode.Home,
            panicKey = Enum.KeyCode.End
        },
        flags = {},
        tabs = {},
        drawings = {},
        initialized = false
    }
}

setmetatable(framework, {
    __call = function(self, key, args)
        if key == "draw" then
            local i = nDrawing(args.class)
            for prop, val in next, args.properties do
                if prop == "Color" then
                    if val == self.theme.accent then
                        insert(self.menu.accents, i)
                    end
                end
                i[prop] = val
            end
            if not args.hidden then
                insert(self.menu.drawings, {i, args.offset})
            else
                insert(self.menu.hiddenDrawings, i)
            end
            return i
        elseif key == "setImage" then
            wrap(function()
                if framework.imgCache[args.url] then
                    args.drawing["Data"] = framework.imgCache[args.url]
                else
                    local Data = HttpGet(game, args.url) or args.url
                    framework.imgCache[args.url] = Data;
                    args.drawing["Data"] = framework.imgCache[args.url]
                end
            end)()
        elseif key == "isInDrawing" then -- (drawing)
            local MouseLocation = getMouseLocation(UserInputService)
            local X1, Y1 = args.drawing.Position.X, args.drawing.Position.Y
            local X2, Y2 = (args.drawing.Position.X + args.drawing.Size.X), (args.drawing.Position.Y + args.drawing.Size.Y)
            
            return (MouseLocation.X >= X1 and MouseLocation.X <= (X1 + (X2 - X1))) and (MouseLocation.Y >= Y1 and MouseLocation.Y <= (Y1 + (Y2 - Y1)))
        elseif key == "isInArea" then -- (x1,x2,y1,y2)
            local MouseLocation = getMouseLocation(UserInputService)
            local X1, Y1 = args.x1, args.y1
            local X2, Y2 = args.x2, args.y2
            
            return (MouseLocation.X >= X1 and MouseLocation.X <= (X1 + (X2 - X1))) and (MouseLocation.Y >= Y1 and MouseLocation.Y <= (Y1 + (Y2 - Y1)))
        elseif key == "doesDrawingExist" then -- (drawing)
            if args.drawing then
                if rawget(args.drawing, '__OBJECT_EXISTS') then
                    return true
                else
                    return false
                end
            else
                return false
            end
        elseif key == "findDrawingInTable" then
            local found = false

            local function lookThroughTable(table, depth)
                depth = depth or 0
                for i,v in next, table do

                    if v == args.drawing then
                        found = true
                        break
                    end

                    if type(v) == "table" and not find(v, "Color") then
                        lookThroughTable(table, depth+1)
                    end
                end
            end
            lookThroughTable(args.table)

            return found
        elseif key == "udim" then -- (type, xScale, xOffset, yScale, yOffset, relativeFrom)
            if args.type == "size" then
                local x
                local y
                if args.relativeFrom then
                    x = args.xScale*args.relativeFrom.Size.X+args.xOffset
                    y = args.yScale*args.relativeFrom.Size.Y+args.yOffset
                else
                    x = args.xScale*screenSize.X+args.xOffset
                    y = args.yScale*screenSize.Y+args.yOffset
                end
                return nVector2(x,y)
            elseif args.type == "position" then
                local x
                local y

                if args.relativeFrom then
                    if find(args.relativeFrom, "Font") then
                        x = args.relativeFrom.Position.X + args.xScale * args.relativeFrom.Size.X + args.xOffset
                        y = args.relativeFrom.Position.y + args.yScale * args.relativeFrom.Size.y + args.yOffset
                    else
                        x = args.relativeFrom.Position.x + args.xOffset
                        y = args.relativeFrom.Position.y + args.yOffset
                    end
                else
                    x = args.xScale * screenSize.X + args.xOffset
                    y = args.yScale * screenSize.Y + args.yOffset
                end
                return nVector2(x,y)
            else
                return "Non Valid Argument [1]"
            end
        elseif key == "lerp" then -- (item, to, time)
            local elapsedTime = 0
            local startIndex = {}
            local connection

            for i, __ in next, args.to do
                startIndex[i] = args.item[i]
            end

            local function lerp()
                for i, v in next, args.to do
                    args.item[i] = ((v - startIndex[i]) * elapsedTime / args.time) + startIndex[i]
                end
            end

            connection = RunService.RenderStepped:Connect(function(delta)
                if elapsedTime < args.time then
                    elapsedTime = elapsedTime + delta
                    lerp()
                else
                    connection:Disconnect()
                end
            end)
            return args.item
        elseif key == "createConnection" then -- (name, connection, callback)
            if not self.connections[args.name] then
                self.connections[args.name] = args.connection:Connect(args.callback)
                return self.connections[args.name]
            end
        elseif key == "destroyConnection" then -- (name)
            if self.connections[args.name] then
                self.connections[args.name]:Disconnect()
                self.connections[args.name] = nil
            end
        elseif key == "changeAccent" then
            self.theme.accent = args.accent
            for i,v in next, self.menu.accents do

                v.Color = args.accent
            end
        elseif key == "offset" then -- (int, offset)
            local start = 0
            if args.int == 0 then
                return start
            else 
                for i = 1, args.int, 1 do
                    start += args.offset
                end
            return start
            end
        elseif key == "drag" then
            local mousePosition = getMouseLocation(UserInputService)
            local position = nVector2(mousePosition.X-self.menu.dragStart.X, mousePosition.Y-self.menu.dragStart.Y)
            for _,v in next, self.menu.drawings do
                if v ~= self.menu.cursor then
                    if v[2] then
                        if v[2][2] then
                            v[1].Position = nVector2(v[2][2].Position.X + v[2][1].X, v[2][2].Position.Y+ v[2][1].Y)
                        else
                            v[1].Position = nVector2(position.X + v[2][1].X, position.Y + v[2][1].Y)
                        end
                    end
                end
            end
        elseif key == "initialize" then
            framework.menu.initialized = true
            framework.menu.cursor = self("draw", {class = "Triangle", properties = {
                ZIndex = 999,
                Filled = true,
                Visible = self.menu.open,
                Transparency = 1,
                Color = nRGB(255,255,255)
            }})
            self("createConnection", {name = "cursorChanged", connection = RunService.RenderStepped, callback = function(Input)
                local mousePosition = getMouseLocation(UserInputService)
                self.menu.cursor.PointA = nVector2(mousePosition.X, mousePosition.Y)
                self.menu.cursor.PointB = nVector2(mousePosition.X + 12, mousePosition.Y + 23)
                self.menu.cursor.PointC = nVector2(mousePosition.X + 23, mousePosition.Y + 12)
            end})
        elseif key == "unload" then
            for i,v in next, framework.connections do
                v:Disconnect()
                framework.connections[i] = nil
            end

            for i,v in next, framework.menu.drawings do
                if self("doesDrawingExist", {drawing = v[1]}) then
                    v[1]:Remove()
                    framework.menu.drawings[i][1] = nil
                    framework.menu.drawings[i] = nil
                end
            end

            for i,v in next, framework.menu.hiddenDrawings do
                if self("doesDrawingExist", {drawing = v}) then
                    v:Remove()
                    framework.menu.hiddenDrawings[i] = nil
                end
            end
        end
    end
})

function framework:createWindow(args)
    local window = {size = type(args.size) == "Vector2" and args.size or nVector2(630,500), footer = args.footer or ""}
    
    window.ring0 = self("draw", {class = "Square", offset = {nVector2(0,0)}, properties = {
        Size = window.size,
        Position = nVector2(screenCenter.X - window.size.X/2, screenCenter.Y - window.size.Y/2),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(86,86,86)
    }})

    window.ring1 = self("draw", {class = "Square", offset = {nVector2(1,1), window.ring0}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.ring0}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.ring0}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(1,1,1)
    }})

    window.ring2 = self("draw", {class = "Square", offset = {nVector2(1,1), window.ring1}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.ring1}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.ring1}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(57,57,57)
    }})

    window.ring3 = self("draw", {class = "Square", offset = {nVector2(1,1), window.ring2}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.ring2}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.ring2}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(35,35,35)
    }})
    
    window.ring4 = self("draw", {class = "Square", offset = {nVector2(3,3), window.ring3}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -6, yScale = 1, yOffset = -6, relativeFrom = window.ring3}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 3, yScale = 0, yOffset = 3, relativeFrom = window.ring3}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(57,57,57)
    }})
    
    window.base = self("draw", {class = "Square", offset = {nVector2(1,1), window.ring4}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -1, yScale = 1, yOffset = -1, relativeFrom = window.ring4}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.ring4}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(4,4,4)
    }})

    window.menuAccent = self("draw", {class = "Square", offset = {nVector2(0,0), window.base}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = 0, yScale = 0, yOffset = 1, relativeFrom = window.base}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = 0, relativeFrom = window.base}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = framework.theme.accent
    }})
    
    window.tabListRing0 = self("draw", {class = "Square", offset = {nVector2(16,16), window.base}, properties = {
        Size = framework("udim", {type = "size", xScale = 0, xOffset = 100, yScale = 0, yOffset = 460, relativeFrom = window.base}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 16, yScale = 0, yOffset = 16, relativeFrom = window.base}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(0,0,0)
    }})
    
    window.tabListRing1 = self("draw", {class = "Square", offset = {nVector2(1,1), window.tabListRing0},  properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.tabListRing0}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.tabListRing0}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(44,44,44)
    }})
    
    window.tabListBase = self("draw", {class = "Square", offset = {nVector2(1,1), window.tabListRing1}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.tabListRing1}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.tabListRing1}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(9,9,9)
    }})
    
    window.tabContainerRing0 = self("draw", {class = "Square", offset = {nVector2(137,16), window.base}, properties = {
        Size = framework("udim", {type = "size", xScale = 0, xOffset = 466, yScale = 0, yOffset = 460, relativeFrom = window.base}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 137, yScale = 0, yOffset = 16, relativeFrom = window.base}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(0,0,0)
    }})
    
    window.tabContainerRing1 = self("draw", {class = "Square", offset = {nVector2(1,1), window.tabContainerRing0}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.tabContainerRing0}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.tabContainerRing0}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(44,44,44)
    }})
    
    window.tabContainerBase = self("draw", {class = "Square", offset = {nVector2(1,1), window.tabContainerRing1}, properties = {
        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = window.tabContainerRing1}),
        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = window.tabContainerRing1}),
        Filled = true,
        Visible = self.menu.open,
        Transparency = 1,
        Color = nRGB(9,9,9)
    }})

    function window:showTab(tab)
        if tab == framework.menu.currentTab then 
            return
        end
        
        if framework.menu.currentTab then
            local indexCurrent = find(framework.menu.accents, framework.menu.currentTab.title) 
            remove(framework.menu.accents, indexCurrent)
            framework.menu.currentTab.title.Color = nRGB(153,153,153)
            framework.menu.currentTab.open = false

            for _,v in next, framework.menu.currentTab.content do -- Turn everything false
                for d,k in next, v.drawings do
                    k.Visible = false
                end
            end
        end

        framework.menu.currentTab = tab
        framework.menu.currentTab.open = true
        framework.menu.currentTab.title.Color = framework.theme.accent
        insert(framework.menu.accents, framework.menu.currentTab.title)

        for _,v in next, framework.menu.currentTab.content do -- Turn everything false
            for d,k in next, v.drawings do
                k.Visible = true
            end
        end
    end
    
    function window:createTab(args)
        local tab = {name = type(args.name) == "string" and args.name or "placeholder", interactables = {}, content = {}, open = false, axis = {left = 20, right = 20}}

        tab.button = framework("draw", {class = "Square", offset = {nVector2(0, framework("offset", {int = #framework.menu.tabs, offset = 20})), window.tabListBase}, properties = {
            Size = framework("udim", {type = "size", xScale = 1, xOffset = 0, yScale = 0, yOffset = 20, relativeFrom = window.tabListBase}),
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = framework("offset", {int = #framework.menu.tabs, offset = 20}), relativeFrom = window.tabListBase}),
            Filled = true,
            Visible = false,
            Transparency = .6,
            Color = nRGB(255,255,255)
        }})

        tab.titleShadow = framework("draw", {class = "Text", offset = {nVector2(11,4), tab.button}, properties = {
            Text = tab.name,
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 11, yScale = 0, yOffset = 4, relativeFrom = tab.button}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(0,0,0)
        }})

        tab.title = framework("draw", {class = "Text", offset = {nVector2(10,3), tab.button}, properties = {
            Text = tab.name,
            Font = framework.theme.font,
            Size = framework.theme.fontSize,
            Position = framework("udim", {type = "position", xScale = 0, xOffset = 10, yScale = 0, yOffset = 3, relativeFrom = tab.button}),
            Visible = framework.menu.open,
            Transparency = 1,
            Color = nRGB(153,153,153)
        }})

        function tab:createLabel(args)
            local label = {side = args.side or "left", text = args.text or "", type = "label", drawings = {}}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = label.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[label.side], relativeFrom = window.tabContainerBase})

            label.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = label.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            label.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), label.drawings.textLabelShadow}, properties = {
                Text = label.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = label.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            tab.axis[label.side] += 20

            function label:set(text)
                label.text.Text = text
                label.textShadow.Text = text
            end

            insert(tab.content, label)
            return label
        end

        function tab:createButton(args)
            local button = {side = args.side or "left", text = args.text or "", drawings = {}, type = "button", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = button.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[button.side], relativeFrom = window.tabContainerBase})

            button.drawings.ring0 = framework("draw", {class = "Square", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 155, yScale = 0, yOffset = 20, relativeFrom = window.tabContainerBase}),
                Position = offset,
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            button.drawings.interact = framework("draw", {class = "Square", offset = {nVector2(1,1), button.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = button.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = button.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(36,36,36)
            }})

            button.drawings.textLabel =  framework("draw", {class = "Text", offset = {nVector2(button.drawings.interact.Size.X/2,2), button.drawings.interact}, properties = {
                Text = button.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Center = true,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = button.drawings.interact.Size.X/2, yScale = 0, yOffset = 2, relativeFrom = button.drawings.interact}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            function button:setText(text)
                button.text.Text = text
                button.textShadow.Text = text
            end

            tab.axis[button.side] += 25

            insert(tab.interactables, button)
            insert(tab.content, button)
            return button
        end

        function tab:createToggle(args)
            local toggle = {side = args.side or "left", text = args.text or "", state = args.default or false, drawings = {}, type = "toggle", flag = args.flag or "", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = toggle.side == "left" and 20 or 20 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[toggle.side], relativeFrom = window.tabContainerBase})
            
            toggle.drawings.ring0 = framework("draw", {class = "Square", offset = {offset + nVector2(0,2) -window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 8, yScale = 0, yOffset = 8, relativeFrom = window.tabContainerBase}),
                Position = offset + nVector2(0,2),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            toggle.drawings.button = framework("draw", {class = "Square", offset = {nVector2(1,1), toggle.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = toggle.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset =1, relativeFrom = toggle.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(36,36,36)
            }})
            
            toggle.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset+nVector2(20,0)-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = toggle.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset + nVector2(20,0),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            toggle.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), toggle.drawings.textLabelShadow}, properties = {
                Text = toggle.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = toggle.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            function toggle:setText(text)
                toggle.drawings.textLabel.Text = text
                toggle.drawings.textLabelShadow.Text = text
            end

            function toggle:set(val)
                toggle.state = val
                if toggle.state then
                    toggle.drawings.button.Color = framework.theme.accent
                    insert(framework.menu.accents, toggle.drawings.button)
                else
                    local IDX = find(framework.menu.accents, toggle.drawings.button)
                    if IDX then
                        remove(framework.menu.accents, IDX)
                    end
                    toggle.drawings.button.Color = nRGB(36,36,36)
                end
                toggle.callback(toggle.state)
            end
            toggle:set(toggle.state)

            function toggle:toggle()
                toggle.state = not toggle.state
                if toggle.state then
                    toggle.drawings.button.Color = framework.theme.accent
                    insert(framework.menu.accents, toggle.drawings.button)
                else
                    local IDX = find(framework.menu.accents, toggle.drawings.button)
                    if IDX then
                        remove(framework.menu.accents, IDX)
                    end
                    toggle.drawings.button.Color = nRGB(36,36,36)
                end
                toggle.callback(toggle.state)
            end

            function toggle:get()
                return toggle.state
            end

            tab.axis[toggle.side] += 20

            insert(tab.interactables, toggle)
            insert(tab.content, toggle)
            return toggle
        end

        function tab:createSlider(args)
            local slider = {side = args.side or "left", text = args.text or "", type = "slider", min = args.min or -1, value = args.default or 0, unit = args.unit or "", max = args.max or 1, precision = args.precision or 1, drawings = {}, flag = args.flag or "", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = slider.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[slider.side], relativeFrom = window.tabContainerBase})
            
            slider.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = slider.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            slider.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), slider.drawings.textLabelShadow}, properties = {
                Text = slider.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = slider.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            slider.drawings.ring0 = framework("draw", {class = "Square", offset = {offset+ nVector2(0,15)-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 155, yScale = 0, yOffset = 8, relativeFrom = window.tabContainerBase}),
                Position = offset + nVector2(0,15),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            slider.drawings.backfill = framework("draw", {class = "Square", offset = {nVector2(1,1), slider.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = slider.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = slider.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(36,36,36)
            }})

            slider.drawings.color = framework("draw", {class = "Square", offset = {nVector2(1,1), slider.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = .5, xOffset = 0, yScale = 1, yOffset = -2, relativeFrom = slider.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = slider.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = framework.theme.accent
            }})

            slider.drawings.textValue = framework("draw", {class = "Text", offset = {nVector2(slider.drawings.backfill.Size.X - 5,3), slider.drawings.color}, properties = {
                Text = tostring(slider.value..slider.unit),
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = slider.drawings.backfill.Size.X - 5, yScale = 0, yOffset = 3, relativeFrom = slider.drawings.backfill}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            function slider:setText(text)
                toggle.drawings.textLabel.Text = text
                toggle.drawings.textLabelShadow.Text = text
            end

            function slider:set(value)
                if slider.precision < 2 then
                    value = math.floor(value)
                end
                value = tonumber(string.format("%."..slider.precision.."f", value))
                local spercent = 1 - ((slider.max - value) / (slider.max - slider.min))
                slider.drawings.color.Size = framework("udim", {type = "size", xScale = spercent, xOffset = 0, yScale = 1, yOffset = -2, relativeFrom = slider.drawings.ring0})
                slider.drawings.textValue.Position = framework("udim", {type = "position", xScale = 0, xOffset = slider.drawings.backfill.Size.X - 5, yScale = 0, yOffset = 3, relativeFrom = slider.drawings.backfill})
                slider.drawings.textValue.Text = tostring(value)..slider.unit
                slider.value = value
                framework.menu.flags[slider.flag] = slider.value
                slider.callback(slider.value)
            end
            slider:set(slider.value)

            function slider:refresh()
                local mousePosition = getMouseLocation(UserInputService)
                local rpercent = math.clamp((mousePosition.X - slider.drawings.ring0.Position.X) / (slider.drawings.ring0.Size.X), 0, 1)
                local rvalue = slider.min + (slider.max - slider.min) * rpercent
                slider:set(rvalue)
            end

            function slider:get()
                return slider.value
            end

            tab.axis[slider.side] += 30 

            insert(tab.interactables, slider)
            insert(tab.content, slider)
            return slider
        end

        function tab:createKeybind(args)
            local keybind = {side = args.side or "left", text = args.text or "", key = args.defaultKey or "", track = args.trackType or "Toggle", state = false, drawings = {}, type = "keybind", flag = args.flag or "", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = keybind.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[keybind.side], relativeFrom = window.tabContainerBase})

            framework.menu.flags[keybind.flag] = {keybind.key, keybind.state}

            keybind.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = keybind.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            keybind.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), keybind.drawings.textLabelShadow}, properties = {
                Text = keybind.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = keybind.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            keybind.drawings.ring0 = framework("draw", {class = "Square", offset = {offset+nVector2(0,15)-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 155, yScale = 0, yOffset = 20, relativeFrom = window.tabContainerBase}),
                Position = offset + nVector2(0,15),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            keybind.drawings.base = framework("draw", {class = "Square", offset = {nVector2(1,1), keybind.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = keybind.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = keybind.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(36,36,36)
            }})

            keybind.drawings.buttonText =  framework("draw", {class = "Text", offset = {nVector2(5,2), keybind.drawings.base}, properties = {
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 5, yScale = 0, yOffset = 2, relativeFrom = keybind.drawings.base}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            function keybind:setKey(Input)
                if Input and Input ~= ""  then
                    local idx = find(framework.menu.accents, keybind.drawings.buttonText)
                    if idx then
                        remove(framework.menu.accents, idx)
                    end
                    keybind.key = Input.KeyCode.Name ~= "Unknown" and Input.KeyCode.Name or Input.UserInputType.Name
                    keybind.drawings.buttonText.Text = keybind.key
                    keybind.drawings.buttonText.Color = nRGB(206,206,206)
                    framework.menu.flags[keybind.flag][1] = keybind.key
                else
                    local idx = find(framework.menu.accents, keybind.drawings.buttonText)
                    if idx then
                        remove(framework.menu.accents, idx)
                    end
                    keybind.key = "unbound"
                    keybind.state = false
                    keybind.drawings.buttonText.Text = ""
                    keybind.drawings.buttonText.Color = nRGB(206,206,206)
                    framework.menu.flags[keybind.flag][1] = keybind.key
                end
            end
            keybind:setKey(keybind.key)

            function keybind:get()
                return keybind.key, keybind.state
            end

            tab.axis[keybind.side] += 40

            insert(framework.menu.keybinds, keybind)
            insert(tab.interactables, keybind)
            insert(tab.content, keybind)
            return keybind
        end

        function tab:createDropdown(args)
            local dropdown = {side = args.side or "left", text = args.text or "", value = args.default or "", options = args.options or {}, content = {}, drawings = {}, flag = args.flag or "", type = "dropdown", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = dropdown.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[dropdown.side], relativeFrom = window.tabContainerBase})

            dropdown.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = dropdown.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            dropdown.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), dropdown.drawings.textLabelShadow}, properties = {
                Text = dropdown.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = dropdown.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            dropdown.drawings.ring0 = framework("draw", {class = "Square", offset = {offset+nVector2(0,15)-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 155, yScale = 0, yOffset = 20, relativeFrom = window.tabContainerBase}),
                Position = offset + nVector2(0,15),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            dropdown.drawings.base = framework("draw", {class = "Square", offset = {nVector2(1,1), dropdown.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = dropdown.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = dropdown.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(36,36,36)
            }})

            dropdown.drawings.buttonText =  framework("draw", {class = "Text", offset = {nVector2(5,2), dropdown.drawings.base}, properties = {
                Text = "none",
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 5, yScale = 0, yOffset = 2, relativeFrom = dropdown.drawings.base}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            dropdown.drawings.triangle =  framework("draw", {class = "Image", offset = {nVector2(140,8), dropdown.drawings.base}, properties = {
                Size = nVector2(5,3),
                Position = framework("udim", {type = "position", xScale = 2, xOffset = 140, yScale = 0, yOffset = 8, relativeFrom = dropdown.drawings.base}),
                Visible = tab.open,
                Transparency = 1,
            }})
            framework("setImage", {drawing = dropdown.drawings.triangle, url = "https://raw.githubusercontent.com/yukihooked/DATA/main/triangle2.png"})

            function dropdown:select(val)
                dropdown.value = val
                dropdown.drawings.buttonText.Text = val
                dropdown.callback(val)
            end
            dropdown:select(dropdown.value)

            function dropdown:open()
                framework("setImage", {drawing = dropdown.drawings.triangle, url = "https://raw.githubusercontent.com/yukihooked/DATA/main/triangle2down.png"})
                for i,v in next, dropdown.options do
                    dropdown.content[i.."Ring"] = framework("draw", {class = "Square", offset = {nVector2(0,0), dropdown.drawings.ring0}, properties = {
                        Size = framework("udim", {type = "size", xScale = 0, xOffset = 155, yScale = 0, yOffset = 20, relativeFrom = dropdown.drawings.ring0}),
                        Position = framework("udim", {type = "position", xScale = 0, xOffset = 0, yScale = 0, yOffset = 20*i, relativeFrom = dropdown.drawings.ring0}),
                        Filled = true,
                        Visible = tab.open,
                        Transparency = 1,
                        Color = nRGB(0,0,0)
                    }})

                    dropdown.content[i.."Button"] = framework("draw", {class = "Square", offset = {nVector2(1,1), dropdown.content[i.."Ring"]}, properties = {
                        Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = dropdown.content[i.."Ring"]}),
                        Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = dropdown.content[i.."Ring"]}),
                        Filled = true,
                        Visible = tab.open,
                        Transparency = 1,
                        Color = nRGB(36,36,36)
                    }})

                    dropdown.content[i.."Text"]= framework("draw", {class = "Text", offset = {nVector2(1,1), dropdown.content[i.."Button"]}, properties = {
                        Text = v,
                        Font = framework.theme.font,
                        Size = framework.theme.fontSize,
                        Position = framework("udim", {type = "position", xScale = 0, xOffset = 5, yScale = 0, yOffset = 2, relativeFrom = dropdown.content[i.."Button"]}),
                        Visible = tab.open,
                        Transparency = 1,
                        Color = nRGB(206,206,206)
                    }})
                end
                framework("refreshCursor")
            end

            function dropdown:close()
                for i,v in next, dropdown.content do
                    v:Remove()
                    dropdown.content[i] = nil
                end
                framework("setImage", {drawing = dropdown.drawings.triangle, url = "https://raw.githubusercontent.com/yukihooked/DATA/main/triangle2.png"})
            end

            tab.axis[dropdown.side] += 40

            insert(tab.interactables, dropdown)
            insert(tab.content, dropdown)
            return dropdown
        end

        function tab:createColorpicker(args)
            local colorpicker = {side = args.side or "left", text = args.text or "", value = args.default or nRGB(255,255,255), state = args.default or false, drawings = {}, flag = args.flag or "", type = "colorpicker", callback = args.callback or function() end}
            local offset = framework("udim", {type = "position", xScale = 0, xOffset = colorpicker.side == "left" and 40 or 40 + window.tabContainerBase.Size.X/2, yScale = 0, yOffset = tab.axis[colorpicker.side], relativeFrom = window.tabContainerBase})

            colorpicker.drawings.textLabelShadow = framework("draw", {class = "Text", offset = {offset-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Text = colorpicker.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = offset,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            colorpicker.drawings.textLabel = framework("draw", {class = "Text", offset = {nVector2(-1,-1), colorpicker.drawings.textLabelShadow}, properties = {
                Text = colorpicker.text,
                Font = framework.theme.font,
                Size = framework.theme.fontSize,
                Position = framework("udim", {type = "position", xScale = 0, xOffset = -1, yScale = 0, yOffset = -1, relativeFrom = colorpicker.drawings.textLabelShadow}),
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(206,206,206)
            }})

            colorpicker.drawings.ring0 = framework("draw", {class = "Square", offset = {offset+nVector2(135,4)-window.tabContainerBase.Position, window.tabContainerBase}, properties = {
                Size = framework("udim", {type = "size", xScale = 0, xOffset = 20, yScale = 0, yOffset = 8, relativeFrom = window.tabContainerBase}),
                Position = offset + nVector2(135,4),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(0,0,0)
            }})

            colorpicker.drawings.base = framework("draw", {class = "Square", offset = {nVector2(1,1), colorpicker.drawings.ring0}, properties = {
                Size = framework("udim", {type = "size", xScale = 1, xOffset = -2, yScale = 1, yOffset = -2, relativeFrom = colorpicker.drawings.ring0}),
                Position = framework("udim", {type = "position", xScale = 0, xOffset = 1, yScale = 0, yOffset = 1, relativeFrom = colorpicker.drawings.ring0}),
                Filled = true,
                Visible = tab.open,
                Transparency = 1,
                Color = nRGB(255,255,255)
            }})

            function colorpicker:show()
            end

            function colorpicker:hide()
            end

            function colorpicker:think()
            end


            tab.axis[colorpicker.side] += 20

            insert(tab.interactables, colorpicker)
            insert(tab.content, colorpicker)
            return colorpicker
        end
        
        if #framework.menu.tabs == 0 then
            insert(framework.menu.tabs, tab)
            window:showTab(tab)
        else
            insert(framework.menu.tabs, tab)
        end
        return tab
    end

    self("createConnection", {connection = UserInputService.InputBegan, name = "MenuInputBegan", callback = function(Input)
        if not self.menu.fading then
            if self.menu.bindingKey then
                if Input.KeyCode.Name ~= "Unknown" and Input.KeyCode.Name:upper() or Input.UserInputType.Name:upper() then
                    if Input.KeyCode.Name == "Delete" then
                        self.menu.currentKeybind:setKey()
                        self.menu.bindingKey = false
                    else
                        if find(self.menu.reservedKeybinds, Input.KeyCode) then
                            return
                        else
                            self.menu.currentKeybind:setKey(Input)
                            self.menu.bindingKey = false
                        end
                    end
                end
            else
                if Input.KeyCode == self.menu.reservedKeybinds.menuKey then
                    self.menu.fading = true
                    for _,v in next, self.menu.drawings do
                        if self("doesDrawingExist", {drawing = v[1]}) then
                            self("lerp", {item = v[1], time = .25, to = {Transparency = self.menu.open and 0 or 1}})
                        end
                    end
                    self.menu.fading = false
                    self.menu.open = not self.menu.open
                elseif Input.KeyCode == self.menu.reservedKeybinds.panicKey then
                    self("unload")
                end
                for _,v in next, self.menu.keybinds do
                    if v.key ~= "unbound" then 
                        if string.find(v.key, "Mouse") then
                            if Input.UserInputType == Enum.UserInputType[v.key] then
                                if v.track == "Hold" then
                                    v.state = true
                                    self.flags[v.flag][2] = true
                                    v.callback(v)
                                elseif v.track == "Toggle" then
                                    v.state = not v.state
                                    v.callback(v)
                                end
                            end
                        else
                            if Input.KeyCode == Enum.KeyCode[v.key] then
                                if v.track == "Hold" then
                                    v.state = true
                                    self.flags[v.flag][2] = true
                                    v.callback(v)
                                elseif v.track == "Toggle" then
                                    v.state = not v.state
                                    v.callback(v)
                                end
                            end
                        end
                    end
                end
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if self.menu.currentDropdown then
                        local hit = false
                        for i,v in next, self.menu.currentDropdown.content do
                            local idxByte = tonumber(string.byte(i))
                            if framework("isInDrawing", {drawing = self.menu.currentDropdown.content[string.char(idxByte).."Button"]}) then
                                self.menu.currentDropdown:select(self.menu.currentDropdown.content[string.char(idxByte).."Text"].Text)
                                hit = true
                                break
                            end
                            
                        end
                        if not hit then 
                            self.menu.currentDropdown:close()
                            self.menu.currentDropdown = nil
                        end
                    end
                    if framework("isInArea", {x1 = window.base.Position.X, x2 = window.ring0.Position.X + window.ring0.Size.X, y1 = window.ring0.Position.Y, y2 = window.ring0.Position.Y + 24}) and self.menu.open then
                        local mousePosition = getMouseLocation(UserInputService)
                        self.menu.dragging = true
                        self.menu.dragStart = nVector2(mousePosition.X - window.ring0.Position.X, mousePosition.Y - window.ring0.Position.Y)
                    end
                    for i,v in next, framework.menu.tabs do
                        if framework("isInDrawing", {drawing = v.button}) then
                            window:showTab(v)
                        end
                    end
                    for _,v in next, framework.menu.currentTab.interactables do
                        if v.type == "button" then
                            if framework("isInDrawing", {drawing = v.drawings.interact}) then
                                v.callback()
                            end
                        elseif v.type == "toggle" then
                            if framework("isInArea", {x1 = v.drawings.ring0.Position.X, x2 = v.drawings.ring0.Position.X + 175, y1 = v.drawings.ring0.Position.Y,  y2 = v.drawings.ring0.Position.Y + 10}) then
                                v:toggle()
                            end
                        elseif v.type == "slider" then
                            if framework("isInArea", {x1 = v.drawings.ring0.Position.X, x2 = v.drawings.ring0.Position.X + 175, y1 = v.drawings.ring0.Position.Y,  y2 = v.drawings.ring0.Position.Y + 10}) then
                                framework.menu.sliderDragging = true
                                framework.menu.currentSlider = v
                                framework.menu.currentSlider = v
                                framework.menu.currentSlider:refresh()
                            end
                        elseif v.type == "keybind" then
                            if framework("isInDrawing", {drawing = v.drawings.base}) then
                                framework.menu.bindingKey = true
                                framework.menu.currentKeybind = v
                                framework.menu.currentKeybind.drawings.buttonText.Text = "Press any key"
                                framework.menu.currentKeybind.drawings.buttonText.Color = framework.theme.accent
                                insert(framework.menu.accents, framework.menu.currentKeybind.drawings.buttonText)
                            end
                        elseif v.type == "dropdown" then
                            if framework("isInDrawing", {drawing = v.drawings.base}) then
                                if framework.menu.currentDropdown == v then
                                    v:close()
                                    framework.menu.currentDropdown = nil
                                else
                                    framework.menu.currentDropdown = v
                                    v:open()
                                end
                            end
                        elseif v.type == "colorpicker" then
                        end
                    end

                end
            end
        end
    end})

    self("createConnection", {connection = UserInputService.InputEnded, name = "MenuInputEnded", callback = function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.menu.dragging = false
            self.menu.sliderDragging = false
            self.menu.currentSlider = nil
            self.menu.dragStart = nVector2()
        end
    end})

    self("createConnection", {connection = UserInputService.InputChanged, name = "MenuInputChanged", callback = function(Input)
        if not self.menu.fading then
            if self.menu.open and self.menu.dragging then
                self("drag")
            end
            if self.menu.sliderDragging and self.menu.currentSlider then
                self.menu.currentSlider:refresh()
            end
        end
    end})

    return window
end

function framework:createScreenLabel(args)
    local screenLabel = {text = args.text or "Screen Label", position = args.position or nVector2(95,15), drawings = {}}

    screenLabel.drawings.labelShadow = framework("draw", {hidden = true, class = "Text", properties = {
        Text = screenLabel.text,
        Font = framework.theme.font,
        Size = framework.theme.fontSize,
        Position = framework("udim", {type = "position", xScale = 0, xOffset = screenLabel.position.X+1, yScale = 0, yOffset = screenLabel.position.Y+1}),
        Visible = true,
        Transparency = 1,
        Color = nRGB(0,0,0)
    }})

    screenLabel.drawings.label = framework("draw", {hidden = true, class = "Text", properties = {
        Text = screenLabel.text,
        Font = framework.theme.font,
        Size = framework.theme.fontSize,
        Position = framework("udim", {type = "position", xScale = 0, xOffset = screenLabel.position.X, yScale = 0, yOffset = screenLabel.position.Y}),
        Visible = true,
        Transparency = 1,
        Color = nRGB(255,255,255)
    }})
    
    function screenLabel:changeText(text)
        screenLabel.text = text
        screenLabel.drawings.labelShadow.Text = text
        screenLabel.drawings.label.Text = text
    end

    insert(self.labels, screenLabel)
    return screenLabel
end

local watermark = framework:createScreenLabel{text = "YUKIHOOK | " .. os.date("%X") .. " | YUKINO"}
local watermarkConnection = framework("createConnection", {name = "watermark", connection = RunService.Heartbeat, callback = function()
    watermark:changeText("YUKIHOOK | " .. os.date("%X") .. " | YUKINO")
end})
local window = framework:createWindow{}
local tab = window:createTab{name = "aimbot"}
local label = tab:createLabel{text = "Soon"}

local antiaim = window:createTab{name = "anti-aim"}
local label = antiaim:createLabel{text = "textLabel"}
local button = antiaim:createButton{text = "button", callback = function()
    framework("changeAccent", {accent = nHSV(math.random(0, 360)/360, math.random(50,100)/100, 1)})
end}

local toggle = antiaim:createToggle{text = "toggle", side = "right", callback = function(val)
    print(val)
end}

local slider = antiaim:createSlider{text = "slider", side = "right", min = -100, default = 0, max = 100, callback = function(val)
    print(val)
end}

local keybind = antiaim:createKeybind{text = "keybind", side = "right", flag = "keybind", callback = function(val)
    print('Pressed a keybind')
end}

local dropdown = antiaim:createDropdown{text = "dropdown", default = "hi Default", options = {"aaaa","bbbb", "cccc"}, callback = function(val)
    print(val)
end}

local colorpicker = antiaim:createColorpicker{text = "colorpicker", callback = function(val)
end}


local players = window:createTab{name = "players"}
local visuals = window:createTab{name = "visuals"}
local movement = window:createTab{name = "movement"}
local skins = window:createTab{name = "skins"}
local misc = window:createTab{name = "misc"}
local config = window:createTab{name = "config"}
local lua = window:createTab{name = "lua"}


framework("initialize")
return framework
