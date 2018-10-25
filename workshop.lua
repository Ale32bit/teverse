 -- Copyright (c) 2018 teverse.com
 -- workshop.lua

 -- This script has access to 'engine.workshop' APIs.
 -- Contains everything needed to grow your own workshop.

--
-- Undo/Redo History system
-- 

local history = {}
local dirty = {} -- Records changes made since last action
local currentPoint = 0 -- The current point in the history array that is used to undo
local goingBack = false -- Used to prevent objectChanged from functioning while undoing

local function objectChanged(property)
	-- TODO: self is a reference to an event object
	-- self.object is what the event is about
	-- self:disconnect() is used to disconnect this handler
	if goingBack then return end 
	
	if not dirty[self.object] then 
		dirty[self.object] = {}
	end
	
	if not dirty[self.object][property] then
		-- mark the property as changed  
		dirty[self.object][property] = self.object[property]
	end
end

local function savePoint()
	local newPoint = {}
	
	for object, properties in pairs(dirty) do
		newPoint[object] = properties
	end
	
	if currentPoint < #history then
		-- the user just undoed
		-- lets overwrite the no longer history
		local historySize = #history
		for i = currentpoint+1, historySize do
			table.remove(history, i)
		end
	end
	
	table.insert(history, newPoint)
	currentPoint = #history
	dirty = {}
end

-- hook existing objects
for _,v in pairs(workspace.children) do
	v:changed(objectChanged)
end

workspace:childAdded(function(child)
	child:changed(objectChanged)
	if not goingBack and dirty[child] then
		dirty[child].new = true
	end
end)

function undo()
	if currentPoint == 0 then return end
	
	currentPoint = currentPoint - 1
	local snapShot = history[currentPoint] 
	if not snapShot then snapShot = {} end

	goingBack = true
	
	for object, properties in pairs(snapShot) do
		for property, value in pairs(properties) do
			object[property] = value
		end
	end
	
	goingBack = false
end

function redo()
	if currentPoint >= #history then
		return print("Debug: can't redo.")
	end

	currentPoint = currentPoint + 1
	local snapShot = history[currentPoint] 
	if not snapShot then return print("Debug: no snapshot found") end

	goingBack = true
	
	for object, properties in pairs(snapShot) do
		for property, value in pairs(properties) do
			object[property] = value
		end
	end
	
	goingBack = false
end

-- 
-- UI
--

local normalFontName = "OpenSans-Regular"
local boldFontName = "OpenSans-Bold"
 
-- Menu Bar Creation

local menuBarTop = engine.guiMenuBar()
menuBarTop.size = guiCoord(1, 0, 0, 24)
menuBarTop.position = guiCoord(0, 0, 0, 0)
menuBarTop.parent = engine.workshop.interface

-- File Menu

local menuFile = menuBarTop:createItem("File")

local menuFileNew = menuFile:createItem("New Scene")
local menuFileOpen = menuFile:createItem("Open Scene")
local menuFileSave = menuFile:createItem("Save Scene")
local menuFileSaveAs = menuFile:createItem("Save Scene As")

-- Edit Menu

local menuEdit = menuBarTop:createItem("Edit")
local menuEditUndo = menuEdit:createItem("Undo")
local menuEditRedo = menuEdit:createItem("Redo")

-- Insert Menu

local menuInsert = menuBarTop:createItem("Insert")
local menuInsertBlock = menuInsert:createItem("Block")

menuEditUndo:mouseLeftPressed(undo)
menuEditRedo:mouseLeftPressed(redo)

menuFileNew:mouseLeftPressed(function()
	engine.workshop:newGame()
end)

menuFileOpen:mouseLeftPressed(function()
	-- Tell the Workshop APIs to initate a game load.
	engine.workshop:openFileDialogue()
end)

menuFileSave:mouseLeftPressed(function()
	engine.workshop:saveGame() -- returns boolean
end)

menuFileSaveAs:mouseLeftPressed(function()
	engine.workshop:saveGameAsDialogue()
end)

menuInsertBlock:mouseLeftPressed(function ()
	local newBlock = engine.block("block")
	newBlock.colour = colour(1,0,0)
	newBlock.size = vector3(1,1,1)
	newBlock.parent = workspace

	local camera = workspace.camera
		
	local lookVector = camera.rotation * vector3(0, 0, 1)
	newBlock.position = camera.position - (lookVector * 10)

	savePoint() -- for undo/redo
end)

local windowProperties = engine.guiWindow()
windowProperties.size = guiCoord(0, 240, 0.5, -12)
windowProperties.position = guiCoord(1, -245, 0, 24)
windowProperties.parent = engine.workshop.interface
windowProperties.text = "Properties"
windowProperties.fontSize = 10
windowProperties.fontFile = normalFontName



local function generateLabel(text, parent)
	local lbl = engine.guiTextBox()
	lbl.size = guiCoord(1, 0, 0, 16)
	lbl.position = guiCoord(0, 0, 0, 0)
	lbl.fontSize = 9
	lbl.guiStyle = enums.guiStyle.noBackground
	lbl.fontFile = normalFontName
	lbl.text = tostring(text)
	lbl.wrap = false
	lbl.align = enums.align.middleLeft
	lbl.parent = parent or engine.workshop.interface
	lbl.textColour = colour(1, 1, 1)

	return lbl
end

local function setReadOnly( textbox, value )
	textbox.readOnly = value
	if value then
		textbox.alpha = 0.4
	else
		textbox.alpha = 1
	end
end

local function generateInputBox(text, parent)
	local lbl = engine.guiTextBox()
	lbl.size = guiCoord(1, 0, 0, 21)
	lbl.position = guiCoord(0, 0, 0, 0)
	lbl.backgroundColour = colour(8/255, 8/255, 11/255)
	lbl.fontSize = 9
	lbl.fontFile = normalFontName
	lbl.text = tostring(text)
	lbl.readOnly = false
	lbl.wrap = false
	lbl.align = enums.align.middle
	if parent then
		lbl.parent = parent
	end
	lbl.textColour = colour(1, 1, 1)

	return lbl
end

-- Selected Integer Text

local txtProperty = generateLabel("0 items selected", windowProperties)
txtProperty.name = "txtProperty"
txtProperty.textColour = colour(1,0,0)

local function generateProperties( instance )
	local members = engine.workshop:getMembersOfInstance( instance )

	for _,v in pairs(windowProperties.children) do
		if v.name ~= "txtProperty" then
			v:destroy()
		end
	end

	local y = 16

	table.sort( members, function( a,b ) return a.property < b.property end ) -- alphabetical sort

 	for i, prop in pairs (members) do

		local value = instance[prop.property]
		local propertyType = type(value)
		local readOnly = not prop.writable

		if type(value) == "function" or type(value) == "table" then
			-- Lua doesn't come with a "continue"
			-- Teverse uses LuaJIT,
			-- Here's a fancy functionality:
			-- Jumps to the ::continue:: label
			goto continue 
		end

		local lblProp = generateLabel(prop.property, windowProperties)
		lblProp.position = guiCoord(0,3,0,y)
		lblProp.size = guiCoord(0.46, -6, 0, 15)
		lblProp.name = "Property" 

		
		local propContainer = engine.guiFrame() 
		propContainer.parent = windowProperties
		propContainer.name = "Container"
		propContainer.size = guiCoord(0.54, -9, 0, 21) -- Compensates for the natural padding inside a guiWindow.
		propContainer.position = guiCoord(0.45,0,0,y)
		propContainer.alpha = 0

		if propertyType == "vector2" then

			local txtProp = generateInputBox(value.x, propContainer)
			txtProp.position = guiCoord(0,0,0,0)
			txtProp.size = guiCoord(0.5, -1, 1, 0)
			setReadOnly(txtProp, readOnly)

			local txtProp = generateInputBox(value.y, propContainer)
			txtProp.position = guiCoord(0.5,2,0,0)
			txtProp.size = guiCoord(0.5, -1, 1, 0)
			setReadOnly(txtProp, readOnly)

		elseif propertyType == "colour" then

			local txtProp = generateInputBox(value.r, propContainer)
			txtProp.position = guiCoord(0,0,0,0)
			txtProp.size = guiCoord(0.25, -1, 1, 0)
			setReadOnly(txtProp, readOnly)

			local txtProp = generateInputBox(value.g, propContainer)
			txtProp.position = guiCoord(0.25,1,0,0)
			txtProp.size = guiCoord(0.25, -1, 1, 0)
			setReadOnly(txtProp, readOnly)

			local txtProp = generateInputBox(value.b, propContainer)
			txtProp.position = guiCoord(0.5,2,0,0)
			txtProp.size = guiCoord(0.25, -1, 1, 0)
			setReadOnly(txtProp, readOnly)

			local colourPreview = engine.guiFrame() 
			colourPreview.parent = propContainer
			colourPreview.size = guiCoord(0.25, -10, 1, -12)
			colourPreview.position = guiCoord(0.75, 7, 0, 6)
			colourPreview.backgroundColour = value

		else
			local txtProp = generateInputBox(value, propContainer)
			txtProp.position = guiCoord(0,0,0,0)
			txtProp.size = guiCoord(1, 0, 1, 0)
			setReadOnly(txtProp, readOnly)
		end

		y = y + 22

		::continue::
	end
end

generateProperties(txtProperty)
-- 
-- Workshop Camera
-- Altered from https://wiki.teverse.com/tutorials/base-camera
--

-- The distance the camera is from the target
local target = vector3(0,0,0) -- A virtual point that the camera
local currentDistance = 20

-- The amount the camera moves when you use the scrollwheel
local zoomStep = 3
local rotateStep = -0.0045
local moveStep = 0.5 -- how fast the camera moves

local camera = workspace.camera

-- Setup the initial position of the camera
camera.position = target - vector3(0, -5, currentDistance)
camera:lookAt(target)

-- Camera key input values
local cameraKeyEventLooping = false
local cameraKeyArray = {
	[enums.key.w] = vector3(0, 0, -1),
	[enums.key.s] = vector3(0, 0, 1),
	[enums.key.a] = vector3(-1, 0, 0),
	[enums.key.d] = vector3(1, 0, 0),
	[enums.key.q] = vector3(0, -1, 0),
	[enums.key.e] = vector3(0, 1, 0)
}

local function updatePosition()
	local lookVector = camera.rotation * vector3(0, 0, 1)
	
	camera.position = target + (lookVector * currentDistance)
	camera:lookAt(target)
end

engine.input:mouseScrolled(function( input )
	currentDistance = currentDistance - (input.movement.y * zoomStep)
	updatePosition()
end)

engine.input:mouseMoved(function( input )
	if engine.input:isMouseButtonDown( enums.mouseButton.right ) then
		local pitch = quaternion():setEuler(input.movement.y * rotateStep, 0, 0)
		local yaw = quaternion():setEuler(0, input.movement.x * rotateStep, 0)

		-- Applied seperately to avoid camera flipping on the wrong axis.
		camera.rotation = yaw * camera.rotation;
		camera.rotation = camera.rotation * pitch
		
		--updatePosition()
	end
end)

engine.input:keyPressed(function( inputObj )

	if inputObj.systemHandled then return end

	if cameraKeyArray[inputObj.key] and not cameraKeyEventLooping then
		cameraKeyEventLooping = true
		
		repeat
			local cameraPos = camera.position

			for key, vector in pairs(cameraKeyArray) do
				-- check this key is pressed (still)
				if engine.input:isKeyDown(key) then
					cameraPos = cameraPos + (camera.rotation * vector * moveStep)
				end
			end

			cameraKeyEventLooping = (cameraPos ~= camera.position)
			camera.position = cameraPos	

			wait(0.001)

		until not cameraKeyEventLooping
	end
end)

savePoint() -- Create a point.

--
-- Selection System
--

--testing purposes
local newBlock = engine.block("block")
newBlock.colour = colour(1,0,0)
newBlock.size = vector3(1,10,1)
newBlock.position = vector3(0,0,0)
newBlock.parent = workspace
--testing purposes

-- This block is used to show an outline around things we're hovering.
local outlineHoverBlock = engine.block("workshopHoverOutlineWireframe")
outlineHoverBlock.wireframe = true
outlineHoverBlock.anchored = true
outlineHoverBlock.physics = false
outlineHoverBlock.colour = colour(1, 1, 0)
outlineHoverBlock.opacity = 0

-- This block is used to outline selected items
local outlineSelectedBlock = engine.block("workshopSelectedOutlineWireframe")
outlineSelectedBlock.wireframe = true
outlineSelectedBlock.anchored = true
outlineSelectedBlock.physics = false
outlineSelectedBlock.colour = colour(0, 1, 1)
outlineSelectedBlock.opacity = 0


local selectedItems = {}

engine.graphics:frameDrawn(function()	
	local mouseHit = engine.physics:rayTestScreen( engine.input.mousePosition ) -- accepts vector2 or number,number
	if mouseHit then 
		outlineHoverBlock.size = mouseHit.size
		outlineHoverBlock.position = mouseHit.position
		outlineHoverBlock.opacity = 1
	else
		outlineHoverBlock.opacity = 0
	end
end)

engine.input:mouseLeftPressed(function( input )
	local mouseHit = engine.physics:rayTestScreen( engine.input.mousePosition )
	if not mouseHit then
		-- User clicked empty space, deselect everything??
		selectedItems = {}
		outlineSelectedBlock.opacity = 0
		txtProperty.text = "0 items selected"
		return
	end

	local doSelect = true

	if not engine.input:isKeyDown(enums.key.leftShift) then
		-- deselect everything and move on
		selectedItems = {}	
	else
		for i,v in pairs(selectedItems) do
			if v == mouseHit then
				-- deselect
				table.remove(selectedItems, i)
				doSelect = false
			end
		end
	end

	if doSelect then
		table.insert(selectedItems, mouseHit)
	end

	if #selectedItems > 1 then
		outlineSelectedBlock.opacity = 1
		
		-- used to calculate bounding box area...
		local upper = selectedItems[1].position + (selectedItems[1].size/2)
		local lower = selectedItems[1].position - (selectedItems[1].size/2)

		for i, v in pairs(selectedItems) do
			local topLeft = v.position + (v.size/2)
			local btmRight = v.position - (v.size/2)
		
			upper.x = math.max(topLeft.x, upper.x)
			upper.y = math.max(topLeft.y, upper.y)
			upper.z = math.max(topLeft.z, upper.z)

			lower.x = math.min(btmRight.x, lower.x)
			lower.y = math.min(btmRight.y, lower.y)
			lower.z = math.min(btmRight.z, lower.z)
		end

		outlineSelectedBlock.position = (upper+lower)/2
		outlineSelectedBlock.size = upper-lower
	elseif #selectedItems == 1 then
		outlineSelectedBlock.opacity = 1
		outlineSelectedBlock.position = selectedItems[1].position
		outlineSelectedBlock.size = selectedItems[1].size
	elseif #selectedItems == 0 then
		outlineSelectedBlock.opacity = 0
	end

	txtProperty.text = #selectedItems .. " item" .. (#selectedItems == 1 and "" or "s") .. " selected"
end)

