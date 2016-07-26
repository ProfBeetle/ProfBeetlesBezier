local plugin = PluginManager():CreatePlugin()

print("Loading Prof Beetle's Bezier-O-Matic...")

-----------------------------------------------------------------------------------------------------
-- Utility Functions
-----------------------------------------------------------------------------------------------------

function makeModel(parent, name)
	local base = Instance.new("Model")
	base.Parent = parent
	base.Name = name
	return base
end

function makeSetting(parent, type, name, value)
	local setting = Instance.new(type)
	setting.Name = name
	setting.Value = value
	setting.Parent = parent	
	return setting
end

function makePart(parent, name, location, color)
	local base = Instance.new("Part")
	base.FormFactor = Enum.FormFactor.Custom
	base.Size = Vector3.new(1, 1, 1)
	base.Position = location
	base.Parent = parent
	base.Anchored = true
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.BrickColor = color or BrickColor.Gray()
	base.Name = name
	return base
end

function makeLineSegment(parent, name, location, color)
	local lineSegment = makePart(nil, name, location, color)
	lineSegment.Shape = Enum.PartType.Block
	lineSegment.FormFactor = Enum.FormFactor.Custom
	lineSegment.Transparency = 0
	lineSegment.CanCollide = false
	lineSegment.Locked = true
	lineSegment.Parent = parent
	return lineSegment
end

function makeNode(parent, name, nodePos, headHandlePos, headColor, tailHandlePos, tailColor, rotation)
	local node = makePart(nil, name, nodePos, BrickColor.new(1020))
	node.Shape = Enum.PartType.Ball
	node.CanCollide = false
	node.Transparency = 0.25
	node.Size = Vector3.new(2, 2, 2)
	node.Parent = parent

	makeSetting(node, "NumberValue", "Resolution", 0).Changed:connect(function() nodeValueChanged(node) end)
	makeSetting(node, "NumberValue", "Rotation", rotation).Changed:connect(function() nodeValueChanged(node) end)
	makeSetting(node, "BoolValue", "LinkHandles", true).Changed:connect(function() nodeValueChanged(node) end)
	makeSetting(node, "StringValue", "RenderMode", "").Changed:connect(function() nodeValueChanged(node) end)
	
	local hhandle = makePart(nil, "HeadHandle", headHandlePos, headColor)
	hhandle.Size = Vector3.new(.5, .5, .5)
	hhandle.CanCollide = false
	hhandle.Transparency = 0.25
	hhandle.Parent = node
	
	local thandle = makePart(nil, "TailHandle", tailHandlePos, tailColor)
	thandle.Size = Vector3.new(.5, .5, .5)
	thandle.CanCollide = false
	thandle.Transparency = 0.25
	thandle.Parent = node
	
	local handleBar = makePart(nil, "HandleBar", nodePos, BrickColor.White())
	handleBar.Shape = Enum.PartType.Block
	handleBar.FormFactor = Enum.FormFactor.Custom
	handleBar.Transparency = 0.25
	handleBar.CanCollide = false
	handleBar.Locked = true
	handleBar.Parent = node

	return node
end

function startsWith(s, start)
   return string.sub(s, 1, string.len(start)) == start
end

function endsWith(s, endString)
	local sLen = string.len(s)
	local endLen = string.len(endString)
	if (endLen > sLen) then return false end
	return string.sub(s, sLen - endLen + 1, sLen) == endString
end

function isNode(part)
	if (part.Parent and part.Parent:FindFirstChild("BezierVersion") and startsWith(part.Name, "Node")) then
		return true
	end
	return false
end

function isHandle(part)
	if (part.Parent and isNode(part.Parent) and endsWith(part.Name, "Handle")) then
		return true
	end
	return false
end

function isLinePart(part)
	if (part.Parent and part.Parent.Name == "Points" and part.Parent.Parent and part.Parent.Parent:FindFirstChild("BezierVersion")) then
		return true
	end
	return false
end

function isPartOfBezier(part)
	return isNode(part) or isHandle(part) or isLinePart(part)
end

function isNode(part)
	if (part.Parent and part.Parent:FindFirstChild("BezierVersion") and startsWith(part.Name, "Node")) then
		return true
	end
	return false
end

function getParentBezier(part)
	print(part.Name)
	if (part.ClassName == "Model" and part:FindFirstChild("BezierVersion")) then
		return part
	end
	if (part.Parent) then
		return getParentBezier(part.Parent)
	end
	return nil
end

function getCurveForSelection()
	_selection = game.Selection:Get()
	if (_selection == nil) then
		return nil
	end
	for _, selected in ipairs(_selection) do
		local curve = getParentBezier(selected)
		if (curve) then
			return curve
		end
	end
	return nil
end

function getNodeNumber(node)
	return tonumber(string.sub(node.Name, 5, string.len(node.Name)))
end

------------------------------------------------------
--
--------------------------------- table_print
--
------------------------------------------------------

-- Print anything - including nested tables
-- pulled off some website, I forget which one

function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, "{\n");
        table.insert(sb, table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s = \"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function toString( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end


function hasNodes(curve)
	for _, node in next, curve:GetChildren() do
		if (node and startsWith(node.Name, "Node")) then
			return true
		 end
	end
	return false
end


-----------------------------------------------------------------------------------------------------
-- The Bezier
-----------------------------------------------------------------------------------------------------

local Point = {}
Point.__index = Point
function Point.new(x, y, z)
  local self = setmetatable({}, Point)
  self.x = x
	self.y = y
	self.z = z
  return self
end
function Point.newFromV3(v3)
  local self = setmetatable({}, Point)
  self.x = v3.x
	self.y = v3.y
	self.z = v3.z
  return self
end

local Line = {}
Line.__index = Line
function Line.new(startV, endV, midV)
	local self = setmetatable({}, Line)
	self.startV = startV
	self.endV = endV
	self.midV = midV
	return self
end
function Line:lerp(t)
	-- local lp = self.startV:Lerp(self.endV, t)
	self.midV.x = self.startV.x + t * (self.endV.x - self.startV.x)
	self.midV.y = self.startV.y + t * (self.endV.y - self.startV.y)
	self.midV.z = self.startV.z + t * (self.endV.z - self.startV.z)
end

local Bezier = {}
Bezier.__index = Bezier
function Bezier.new(head, tail)
	local self = setmetatable({}, Bezier)
	self.head = head
	self.tail = tail
	self:init()
	return self
end

function Bezier:init()
	local head = self.head
	local tail = self.tail
	local root1 = Point.newFromV3(head.Position)
	local handle1 = Point.newFromV3(head.HeadHandle.Position)
	local root2 = Point.newFromV3(tail.Position)
	local handle2 = Point.newFromV3(tail.TailHandle.Position)
	self.line1 = Line.new(root1, handle1, Point.new(0, 0, 0))
	self.line2 = Line.new(handle1, handle2, Point.new(0, 0, 0))
	self.line3 = Line.new(handle2, root2, Point.new(0, 0, 0))
	self.innerLine1 = Line.new(self.line1.midV, self.line2.midV, Point.new(0, 0, 0))
	self.innerLine2 = Line.new(self.line2.midV, self.line3.midV, Point.new(0, 0, 0))
	self.pointLine = Line.new(self.innerLine1.midV, self.innerLine2.midV, Point.new(0, 0, 0))
end

function Bezier:getPointAt(t)
	self.line1:lerp(t)
	self.line2:lerp(t)
	self.line3:lerp(t)
	self.innerLine1:lerp(t)
	self.innerLine2:lerp(t)
	self.pointLine:lerp(t)
	return self.pointLine.midV, self.pointLine.startV, self.pointLine.endV, self.innerLine2.endV, self.innerLine1.startV
end

function Bezier:getV3PointAt(t)
	local point = self:getPointAt(t)
	return Vector3.new(point.x, point.y, point.z)
end

function Bezier:getV3SplitPointsAt(t)
	local point, point1, point2, point3, point4 = self:getPointAt(t)
	return Vector3.new(point.x, point.y, point.z), Vector3.new(point1.x, point1.y, point1.z), Vector3.new(point2.x, point2.y, point2.z), Vector3.new(point3.x, point3.y, point3.z), Vector3.new(point4.x, point4.y, point4.z)
end

-----------------------------------------------------------------------------------------------------
-- Rendering Functions
-----------------------------------------------------------------------------------------------------

function buildLineSegment(line, lastPoint, point, count, size, color, rotationCF)
	local distance = (lastPoint.Position - point).magnitude
	-- point might be on the node it's trying to connect to, ignore this
	if (distance == 0) then return end
	local linePart = line:FindFirstChild("LineSegment" .. count)
	if (linePart) then
		linePart.Position = point
	else
		linePart = makeLineSegment(line, "LineSegment" .. count, lastPoint.Position, BrickColor.Black())
		linePart.CanCollide = false
		linePart.Locked = true
	end
	linePart.Size = Vector3.new(size.x, size.y, distance)
	linePart.BrickColor  = BrickColor.new(Color3.new(color.x, color.y, color.z))
	linePart.CFrame = (CFrame.new(lastPoint.Position, point) * CFrame.new(0, 0, -distance / 2)) * rotationCF
end

function renderBezier(head, tail)
	local bezier = Bezier.new(head, tail)
	local mode = head.RenderMode.Value
	local nodeCount = head.Resolution.Value
	local count = 1
	local line = head:FindFirstChild("Points") or makeModel(head, "Points")
	local lastPoint = head
	local curve = head.Parent
	
	if (mode == "") then mode = curve.MasterRenderMode.Value end
	if (nodeCount == 0) then nodeCount = curve.MasterResolution.Value end
	
	local lineSize = curve.LineSettings.Size.Value
	local lineColor = curve.LineSettings.Colour.Value
	
	local headRotationValue = head:FindFirstChild("Rotation")
	local currentRotation = 0
	if (headRotationValue) then
		currentRotation = (math.pi * 2) * (headRotationValue.Value / 360)
	end
	local tailRotationValue = tail:FindFirstChild("Rotation")
	local tailRotation = 0
	if (tailRotationValue) then
		tailRotation = (math.pi * 2) * (tailRotationValue.Value / 360)
	end

	-- remove existing line segments if we're not in Line mode
	if (mode ~= "Line") then
		for _, part in next, line:GetChildren() do
			if (startsWith(part.Name, "LineSegment")) then
				part:Remove()
			end
		end
	end

	local rotationCF = CFrame.Angles(0, 0, currentRotation)

	local step = 1 / nodeCount
	local rotationStep = (tailRotation - currentRotation) / nodeCount
	for i = 0, 1, step do
		local point = bezier:getV3PointAt(i)
		local pointPart = line:FindFirstChild("Point" .. count)
		rotationCF = CFrame.Angles(0, 0, currentRotation)
		if (pointPart) then
			pointPart.Position = point
		else
			pointPart = makePart(line, "Point" .. count, point)
			pointPart.CanCollide = false
			pointPart.Locked = true
		end
		if (lastPoint ~= head) then
			local tanStep = i + .01
			local halfStep = bezier:getV3PointAt(tanStep)
			pointPart.CFrame = CFrame.new(point, halfStep) * rotationCF
			-- lastPoint.CFrame = CFrame.new(lastPoint.Position, pointPart.Position)
		end
		if (mode == "Line" and count ~= 1) then
			pointPart.Transparency = 1
			buildLineSegment(line, lastPoint, point, count, lineSize, lineColor, rotationCF)
		else
			pointPart.Transparency = .25
		end
		
		lastPoint = pointPart
		count = count + 1
		currentRotation = currentRotation + rotationStep
	end
	if (lastPoint) then
		if (mode == "Line") then
			currentRotation = currentRotation + rotationStep
			rotationCF = CFrame.Angles(0, 0, currentRotation)
			buildLineSegment(line, lastPoint, tail.Position, count, lineSize, lineColor, rotationCF)
		end
	end
	-- clean up any remaining parts
	-- points are one less than lines (line must connect to tail node)
	local pointPart = line:FindFirstChild("Point" .. count)
	if (pointPart) then pointPart:Remove() end
	count = count + 1
	pointPart = line:FindFirstChild("Point" .. count)
	local linePart = line:FindFirstChild("LineSegment" .. count)
	while (pointPart or linePart) do
		if (pointPart) then pointPart:Remove() end
		if (linePart) then linePart:Remove() end
		count = count + 1
		pointPart = line:FindFirstChild("Point" .. count)
		linePart = line:FindFirstChild("LineSegment" .. count)
	end
end

function renderCurve(curve)
	local lastNode = nil
	local maxNodeNumber = getNodeNumber(getLastNode(curve))

	for i = 1, maxNodeNumber, 1 do
		local node = curve:FindFirstChild("Node" .. i)
		if (lastNode) then
			renderBezier(lastNode, node)
		end
		wait()
		lastNode = node
	end	
end


-----------------------------------------------------------------------------------------------------
-- Init
-----------------------------------------------------------------------------------------------------

local _active = false
local _mouse = plugin:GetMouse()
local _mouseConnection = nil

local _userInputService = game:GetService("UserInputService")
local _inputBeganConnection = nil
local _inputEndedConnection = nil
local _selectConnection = nil

local _isInCreateMode = false

local _selection = nil
local _selectionConnections = {}

local _scratchpad = nil

-- Check if user has loaded plugin before
local hasLoaded = plugin:GetSetting("pluginHasLoaded")
if not hasLoaded then
	print("Welcome to Prof Beetle's Bezier-O-Matic")
	plugin:SetSetting("pluginHasLoaded", true)
end
 
-- Setup Toolbar
local toolbar = plugin:CreateToolbar("Bezier-O-Matic")
 
-- Setup button
local button = toolbar:CreateButton(
	"Make Bezier",
	"Press me to make awesome curves",
	"Bezier.jpg"
)
button.Click:connect(function()
	if (_active) then
		_active = false
		-- clean out our lines
		for _, curve in next, _scratchpad:GetChildren() do
			if (hasNodes(curve)) then
				for _, node in next, curve:GetChildren() do
					if (startsWith(node.Name, "Node")) then
						node.HeadHandle.Transparency = 1
						node.TailHandle.Transparency = 1
						node.HandleBar.Transparency = 1
					end
				end
			end
		end

		_mouseConnection:disconnect()
		_inputBeganConnection:disconnect()
		_inputEndedConnection:disconnect()
		_selectConnection:disconnect()
		print("Bezier-O-Matic is now deactivated.")
	else
		_active = true
		_scratchpad = workspace:FindFirstChild("Bezier-O-Matic") or makeModel(workspace, "Bezier-O-Matic")
		print("Bezier-O-Matic is now active.")
		plugin:Activate(true) -- Necessary to listen to mouse input
		-- watch the selection set
		attachSelection()
		_selectConnection = game.Selection.SelectionChanged:connect(function()
			attachSelection()
		end)
		
		-- Setup keyboard
		_inputBeganConnection = _userInputService.InputBegan:connect(function(inputObject)
			if inputObject.KeyCode == Enum.KeyCode.B then
				_isInCreateMode = true
				print("Bezier Create Mode ON")
			elseif inputObject.KeyCode == Enum.KeyCode.N then
				addNodeToCurve()
			elseif inputObject.KeyCode == Enum.KeyCode.P then
				insertNode()
			elseif inputObject.KeyCode == Enum.KeyCode.M then
				switchBezierRenderMode()
			elseif inputObject.KeyCode == Enum.KeyCode.X then
				exportBezierCurve()
			end

		end)
		_inputEndedConnection = _userInputService.InputEnded:connect(function(inputObject)
			if inputObject.KeyCode == Enum.KeyCode.B then
				_isInCreateMode = false
				print("Bezier Create Mode OFF")
			end
		end)
		
		-- Setup mouse
		_mouseConnection = _mouse.Button1Down:connect(function() -- Binds function to left click
			local target = _mouse.Target
			
			if target and _isInCreateMode then
				newBezierCurve(target)
			end
		end)
		
		-- Render any pre existing curves
		for _, curve in next, _scratchpad:GetChildren() do
			if (curve:FindFirstChild("BezierVersion")) then
				-- attach our update functions
				curve:FindFirstChild("MasterResolution").Changed:connect(function()
					masterValueChanged()
				end)
				curve:FindFirstChild("MasterRenderMode").Changed:connect(function()
					masterValueChanged()
				end)
				for _, node in next, curve:GetChildren() do
					if (startsWith(node.Name, "Node")) then
						node.HeadHandle.Transparency = .25
						node.TailHandle.Transparency = .25
						node.HandleBar.Transparency = .25
					end
				end
				renderCurve(curve)
			end
		end
	end
end)


-----------------------------------------------------------------------------------------------------
-- Handle Studio Actions
-----------------------------------------------------------------------------------------------------

function positionHandleBar(node)
	local handleBar = node.HandleBar
	local headPos = node.HeadHandle.Position
	local tailPos = node.TailHandle.Position
	local distance = (headPos - tailPos).magnitude
	handleBar.Size = Vector3.new(.1, .1, distance)
	handleBar.CFrame = CFrame.new(headPos, tailPos) * CFrame.new(0, 0, -distance / 2)
end

function orientNodeToTailHandle(node)
	node.CFrame = CFrame.new(node.Position, node.TailHandle.Position)
end

function updateNodeView(node)
	positionHandleBar(node)
	orientNodeToTailHandle(node)
	local bezier = node.Parent
	local nodeNumber = getNodeNumber(node)
	local head = bezier:FindFirstChild("Node" .. nodeNumber - 1) 
	local tail = bezier:FindFirstChild("Node" .. nodeNumber + 1)
	if (head) then
		renderBezier(head, node)
	end
	if (tail) then
		renderBezier(node, tail)
	end
end

function nodeValueChanged(node)
	updateNodeView(node)
end

function handleMovedControl()
	for _, selected in ipairs(_selection) do
		-- find the part of the curve this belongs to and force an update
		if (isHandle(selected)) then
			local linkedHandles = selected.Parent:FindFirstChild("LinkHandles").Value
			if (linkedHandles) then
				-- make sure the other handle is in the opposite location of this one
				local other = nil
				if (startsWith(selected.Name, "Head")) then
					other = selected.Parent:FindFirstChild("TailHandle")
				else
					other = selected.Parent:FindFirstChild("HeadHandle")
				end
				local invert = -(selected.Position - selected.Parent.Position)
				other.Position = selected.Parent.Position + invert
			end
			selected = selected.Parent
		end
		updateNodeView(selected)
	end
end

function switchBezierRenderMode()
	_selection = game.Selection:Get()
	if (_selection == nil) then
		return
	end
	local done = {}
	for _, selected in ipairs(_selection) do
		local curve = getParentBezier(selected)
		if (curve and not done[curve.Name]) then
			if (curve.MasterRenderMode.Value == "Line") then
				curve.MasterRenderMode.Value = "Nodes"
			else
				curve.MasterRenderMode.Value = "Line"
			end
			done[curve.Name] = true
		end
	end
end

function attachSelection()
	_selection = game.Selection:Get()
	for _, connection in ipairs(_selectionConnections) do
		connection:disconnect()
	end
	_selectionConnections = {}
	for _, selected in ipairs(_selection) do
		-- is this selection part of a Bezier?
		if (selected.ClassName == "Part" and (isNode(selected) or isHandle(selected))) then
			_selectionConnections[#_selectionConnections+1] = selected.Changed:connect(function(property)
				if (property == "Position") then
					handleMovedControl()
				end
			end)
			-- we only need to track one of the items
			return
		end
	end
end

function getLastNode(curve)
	local nodeCount = 1
	local maxNumber = 0
	local currentNode = nil
	for _, node in next, curve:GetChildren() do
		if (startsWith(node.Name, "Node")) then
			local number = getNodeNumber(node)
			if (number > maxNumber) then
				currentNode = node
				maxNumber = number
			end
		end
	end
	return currentNode
end

function checkForMissingNodes(curve)
	local nodeCount = 1
	local children = curve:GetChildren()
	local maxNodeNumber = getNodeNumber(getLastNode(curve))

	for i = 1, maxNodeNumber + 1, 1 do
		local node = curve:FindFirstChild("Node" .. i)
		if (node) then
			local nodeNumber = i
			if (nodeNumber ~= nodeCount) then
				node.Name = "Node" .. nodeCount
			end
			nodeCount = nodeCount + 1
		end
	end	
	renderCurve(curve)
end

function addNode(curve, number, pos, hPos, tPos, rotation)
	local newNode = makeNode(curve, "Node" .. number, pos, hPos, BrickColor.new(1009), tPos, BrickColor.Red(), rotation)
	positionHandleBar(newNode)
	renderCurve(curve)
	newNode.AncestryChanged:connect(function()
		checkForMissingNodes(curve)
	end)
end

function insertNode()
	_selection = game.Selection:Get()
	if (_selection == nil) then
		return
	end
	for _, selected in ipairs(_selection) do
		if (isNode(selected)) then
			local head = selected
			local curve = getParentBezier(head)
			local nodeNumber = getNodeNumber(head)
			local tail = curve:FindFirstChild("Node" .. (nodeNumber + 1))
			if (tail == nil) then
				return addNodeToCurve()
			end
			
			local bezier = Bezier.new(head, tail)
			local newNodePos, newTHandlePos, newHHandlePos, newTailTHandlePos, newHeadHHandlePos = bezier:getV3SplitPointsAt(.5)
			
			local bumpNode = getLastNode(curve)
			while(bumpNode ~= tail) do
				local bumpNodeNumber = getNodeNumber(bumpNode)
				bumpNode.Name = "Node" .. (bumpNodeNumber + 1)
				bumpNode = curve:FindFirstChild("Node" .. (bumpNodeNumber - 1))
			end
			
			local headRotationValue = head:FindFirstChild("Rotation")
			local headRotation = 0
			if (headRotationValue) then
				headRotation = headRotationValue.Value
			end
			local tailRotationValue = tail:FindFirstChild("Rotation")
			local tailRotation = 0
			if (tailRotationValue) then
				tailRotation = tailRotationValue.Value
			end
			
			local newNodeRotation = headRotation + (tailRotation - headRotation) / 2
			
			tail.Name = "Node" .. (nodeNumber + 2)
			head.LinkHandles.Value = false
			tail.LinkHandles.Value = false
			head.HeadHandle.Position = newHeadHHandlePos
			tail.TailHandle.Position = newTailTHandlePos
			positionHandleBar(head)
			positionHandleBar(tail)
			addNode(curve, nodeNumber + 1, newNodePos, newHHandlePos, newTHandlePos, newNodeRotation)
			return
		end
	end
end

function addNodeToCurve()
	local curve = getCurveForSelection()
	local offset = Vector3.new(10,0,10)
	local hoffset = Vector3.new(20,0,10)
	local toffset = Vector3.new(-10,0,10)
	-- TODO: Replace this linear interpolation with something better
	if (curve ~= null) then
		-- get the last node
		local last = getLastNode(curve)
		local lastNumber = getNodeNumber(last)
		local penultimate = curve:FindFirstChild("Node" .. (lastNumber - 1))
		local antepenultimate = curve:FindFirstChild("Node" .. (lastNumber - 2))
		-- there is absolutely no reason not to do this in a loop except I got to use the word
		-- antepenultimate, which doesn't happen nearly often enough
		if (last) then
			if (penultimate) then
				offset = (last.Position - penultimate.Position)
				hoffset = ((last.HeadHandle.Position - last.Position) + (penultimate.HeadHandle.Position - penultimate.Position)) / 2
				toffset = ((last.TailHandle.Position - last.Position) + (penultimate.TailHandle.Position - penultimate.Position)) / 2
				if (antepenultimate) then
					offset = (offset + (penultimate.Position - antepenultimate.Position)) / 2
					hoffset = (hoffset + ((penultimate.HeadHandle.Position - penultimate.Position) + (antepenultimate.HeadHandle.Position - antepenultimate.Position)) / 2) / 2
					toffset = (toffset + ((penultimate.TailHandle.Position - penultimate.Position) + (antepenultimate.TailHandle.Position - antepenultimate.Position)) / 2) / 2
				end
			end
			offset = offset + last.Position
			hoffset = hoffset + offset
			toffset = toffset + offset
		end
		addNode(curve, lastNumber + 1, offset, hoffset, toffset, 0)
	end
end

function masterValueChanged()
	local curves = _scratchpad:GetChildren()
	for _, curve in next, curves do
		if (startsWith(curve.Name, "BezierCurve")) then
			renderCurve(curve)
		end
	end
end


-----------------------------------------------------------------------------------------------------
-- Make New Bezier
-----------------------------------------------------------------------------------------------------

function newBezierCurve(startPart)
	local curves = _scratchpad:GetChildren()
	local count = #curves + 1
	local curveName = "BezierCurve" .. count
	local curve = _scratchpad:FindFirstChild(curveName)
	while (curve) do
		count = count + 1
		curveName = "BezierCurve" .. count
		curve = _scratchpad:FindFirstChild(curveName)
	end
	local curve = makeModel(_scratchpad, curveName)
	local version = makeSetting(curve, "NumberValue", "BezierVersion", 1.0)
	local masterResolution = makeSetting(curve, "NumberValue", "MasterResolution", 10)
	local masterRenderMode = makeSetting(curve, "StringValue", "MasterRenderMode", "Line")
			
	local lineSettings = makeModel(curve, "LineSettings")
	local sizeSetting = makeSetting(lineSettings, "Vector3Value", "Size", Vector3.new(.1, .1, 1))
	local colorSetting = makeSetting(lineSettings, "Vector3Value", "Colour", Vector3.new(0, 0, 0))
	local nameSetting = makeSetting(lineSettings, "StringValue", "Name", "Line")

	
	-- attach our update functions
	masterResolution.Changed:connect(function() masterValueChanged() end)
	masterRenderMode.Changed:connect(function() masterValueChanged() end)
	sizeSetting.Changed:connect(function() masterValueChanged() end)
	colorSetting.Changed:connect(function() masterValueChanged() end)
	nameSetting.Changed:connect(function() masterValueChanged() end)
	
	-- create the default curve
	addNode(curve, 1, startPart.Position, startPart.Position + Vector3.new(10, 10, 0), startPart.Position + Vector3.new(-10, -10, 0), 0)
	addNode(curve, 2, startPart.Position + Vector3.new(30, 0, 0), startPart.Position + Vector3.new(40, -10, 0), startPart.Position + Vector3.new(20, 10, 0), 0)
	
	game.Selection:Set({curve})
end
 

-----------------------------------------------------------------------------------------------------
-- Export Bezier
-----------------------------------------------------------------------------------------------------

function exportBezierCurve()
	local curve = getCurveForSelection()
	if (not curve) then return end
	local exportName = curve.Name
	local newExportName = exportName
	local newExport = workspace:FindFirstChild(newExportName)
	local count = 0
	while (newExport) do
		count = count + 1
		newExportName = exportName .. "-" .. count
		wait()
		newExport = workspace:FindFirstChild(newExportName)
	end
	local newExport = makeModel(workspace, newExportName)

	if hasNodes(curve) then
		renderCurve(curve)
		curve.Parent = nil
		local isMasterLine = curve.MasterRenderMode.Value == "Line"
		local pointCount = 1
		for _, node in next, curve:GetChildren() do
			local points = node:FindFirstChild("Points")
			if (startsWith(node.Name, "Node") and points) then
				local isBezierLine = isMasterLine
				if (node.RenderMode == "Line") then
					isBezierLine = true
				elseif (node.RenderMode == "Nodes") then
					isBezierLine = false
				end
				for _, point in next, points:GetChildren() do
					local toClone = nil
					local name = nil
					if (startsWith(point.Name, "Point") and not isBezierLine) then
						toClone = point
						name = "Point"
					elseif (startsWith(point.Name, "Line") and isBezierLine) then
						toClone = point
						name = "Line"
					end
					if (toClone) then
						local clone = toClone:Clone()
						clone.Name = name .. pointCount 
						clone.Transparency = 0
						clone.Locked = false
						pointCount = pointCount + 1
						clone.Parent = newExport
					end
				end
			end
		end
	end
	
	local archive = game.ServerStorage:FindFirstChild("Bezier-O-Matic Archive") or makeModel(game.ServerStorage, "Bezier-O-Matic Archive")
	local archiveName = curve.Name
	local newArchiveName = archiveName
	local newArchive = archive:FindFirstChild(newArchiveName)
	count = 0
	while (newArchive) do
		count = count + 1
		newArchiveName = archiveName .. "-" .. count
		wait()
		newArchive = archive:FindFirstChild(newArchiveName)
	end
	curve.Name = newArchiveName
	curve.Parent = archive
end

plugin.Deactivation:connect(function()
end)
 
print("Prof Beetle's Bezier-O-Matic")

