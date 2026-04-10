local function loadCascade()
	local scriptObject = typeof(script) == "Instance" and script or nil

	if scriptObject then
		local embeddedModule = scriptObject:FindFirstChild("Cascade")
		if embeddedModule and embeddedModule:IsA("ModuleScript") then
			return require(embeddedModule)
		end
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local replicatedModule = ReplicatedStorage:FindFirstChild("Cascade")
	if replicatedModule and replicatedModule:IsA("ModuleScript") then
		return require(replicatedModule)
	end

	if type(loadstring) == "function" then
		local url = "https://github.com/biggaboy212/Cascade/releases/latest/download/dist.luau"
		for _, fetchSource in ipairs({
			function()
				return game:HttpGet(url)
			end,
			function()
				return game:HttpGetAsync(url)
			end,
		}) do
			local success, result = pcall(function()
				local source = fetchSource()
				return loadstring(source, "Cascade")()
			end)

			if success then
				return result
			end
		end
	end

	error("Cascade could not be loaded. Add a ModuleScript named 'Cascade' under this script or ReplicatedStorage, or run this in an environment with loadstring and HTTP import support.")
end

local cascade = loadCascade()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function cloneList(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function roundToPlaces(value, places)
	local decimals = math.max(0, tonumber(places) or 0)
	local factor = 10 ^ decimals
	return math.round(value * factor) / factor
end

local function formatSliderValue(value, places, suffix)
	local decimals = math.max(0, tonumber(places) or 0)
	local numericValue = tonumber(value) or 0
	local valueText

	if decimals > 0 then
		valueText = string.format("%." .. tostring(decimals) .. "f", numericValue)
	else
		valueText = tostring(math.round(numericValue))
	end

	return valueText .. (suffix or "")
end

local function parseIndexedLabel(text)
	local title, value = tostring(text or ""):match("^(.-):%s*(.*)$")
	if title then
		return title, value, true
	end

	return "", tostring(text or ""), false
end

local function makeSingleSelection(values, defaultValue)
	if type(defaultValue) == "number" then
		return values[defaultValue] or values[1]
	end

	if type(defaultValue) == "string" and table.find(values, defaultValue) then
		return defaultValue
	end

	return values[1]
end

local function makeMultiSelection(values, defaultValue)
	local selections = {}

	if type(defaultValue) == "number" then
		local name = values[defaultValue]
		if name and name ~= "---" then
			selections[name] = true
		end
	elseif type(defaultValue) == "table" then
		if #defaultValue > 0 then
			for _, entry in ipairs(defaultValue) do
				local name = type(entry) == "number" and values[entry] or entry
				if type(name) == "string" and table.find(values, name) and name ~= "---" then
					selections[name] = true
				end
			end
		else
			for name, enabled in pairs(defaultValue) do
				if enabled and table.find(values, name) and name ~= "---" then
					selections[name] = true
				end
			end
		end
	end

	return selections
end

local function shallowEquals(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return left == right
	end

	for key, value in pairs(left) do
		if right[key] ~= value then
			return false
		end
	end

	for key, value in pairs(right) do
		if left[key] ~= value then
			return false
		end
	end

	return true
end

local Library = {
	Options = {},
	Toggles = {},
	Unloaded = false,
}

local function emitChanged(control)
	for _, callback in ipairs(control._listeners or {}) do
		task.spawn(function()
			local ok, err = pcall(callback, control.Value)
			if not ok then
				warn("cascade_menu_showcase: option callback failed:", err)
			end
		end)
	end
end

local function addListener(control, callback)
	control._listeners = control._listeners or {}
	table.insert(control._listeners, callback)
	return callback
end

local function syncComponent(control, component, propertyName, value)
	if not component or component[propertyName] == value then
		return
	end

	control._syncing = true
	component[propertyName] = value
	control._syncing = false
end

local function mapWindowIcon(iconName)
	local symbols = cascade.Symbols
	local known = {
		user = symbols.person,
		zap = symbols.bolt,
		settings = symbols.gear,
	}

	return known[iconName]
end

function Library:Notify(config)
	if self.Unloaded or not self._App then
		return
	end

	pcall(function()
		self._App:Notification({
			App = self._AppName or "Cascade",
			Title = config.Title or "Notice",
			Subtitle = config.Description or config.Subtitle or "",
			Icon = cascade.Symbols.bell,
			Duration = config.Time or config.Duration or 4,
		})
	end)
end

function Library:Unload()
	if self.Unloaded then
		return
	end

	self.Unloaded = true
	if self._App then
		self._App:Destroy()
		self._App = nil
	end
end

function Library:CreateWindow(config)
	local app = cascade.New({
		Theme = cascade.Themes.Dark,
		Accent = cascade.Accents and cascade.Accents.Graphite or nil,
		WindowPill = true,
	})

	local window = app:Window({
		Title = config.Title or "Cascade Window",
		Subtitle = config.Footer or "",
		Searching = true,
		Draggable = true,
		Resizable = true,
		Dropshadow = true,
		UIBlur = false,
	})

	local section = window:Section({
		Title = "Menu",
	})

	self._App = app
	self._Window = window
	self._Section = section
	self._AppName = config.Title or "Cascade"

	local windowWrapper = {
		_window = window,
		_section = section,
		_selectedTab = false,
	}

	local function makeRow(form, title, subtitle)
		local row = form:Row({
			SearchIndex = title,
		})

		local titleStack = row:Left():TitleStack({
			Title = title,
			Subtitle = subtitle or "",
		})

		return row, row:Right(), titleStack
	end

	local function makeOptionControl(store, id, initialValue)
		local control = {
			Value = initialValue,
			_listeners = {},
		}

		function control:OnChanged(callback)
			return addListener(self, callback)
		end

		store[id] = control
		return control
	end

	local function buildGroupbox(tabObject, title)
		local form = tabObject:PageSection({
			Title = title,
		}):Form()

		local groupbox = {}

		function groupbox:AddToggle(id, config)
			local row, right = makeRow(form, config.Text or id, config.Tooltip)
			local control = makeOptionControl(Library.Toggles, id, config.Default == true)
			local component

			function control:SetValue(value, silent)
				local normalized = value == true
				if self.Value == normalized then
					syncComponent(self, component, "Value", normalized)
					return
				end

				self.Value = normalized
				syncComponent(self, component, "Value", normalized)
				if not silent then
					emitChanged(self)
				end
			end

			component = right:Toggle({
				Value = control.Value,
				ValueChanged = function(_, value)
					if control._syncing then
						return
					end

					control:SetValue(value, false)
				end,
			})

			control._component = component
			return control
		end

		function groupbox:AddSlider(id, config)
			local title = config.Text or id
			local tooltip = config.Tooltip
			local row, right = makeRow(form, title, tooltip)
			local control = makeOptionControl(
				Library.Options,
				id,
				roundToPlaces(config.Default or config.Min or 0, config.Rounding)
			)
			local stack = right:VStack({
				Padding = UDim.new(0, 4),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			})
			local valueLabel = stack:Label({
				Text = formatSliderValue(control.Value, config.Rounding, config.Suffix),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			local component

			function control:SetValue(value, silent)
				local numericValue = roundToPlaces(tonumber(value) or 0, config.Rounding)
				numericValue = math.clamp(numericValue, config.Min or 0, config.Max or 100)

				if self.Value == numericValue then
					valueLabel.Text = formatSliderValue(numericValue, config.Rounding, config.Suffix)
					syncComponent(self, component, "Value", numericValue)
					return
				end

				self.Value = numericValue
				valueLabel.Text = formatSliderValue(numericValue, config.Rounding, config.Suffix)
				syncComponent(self, component, "Value", numericValue)
				if not silent then
					emitChanged(self)
				end
			end

			component = stack:Slider({
				Minimum = config.Min or 0,
				Maximum = config.Max or 100,
				Value = control.Value,
				ValueChanged = function(_, value)
					if control._syncing then
						return
					end

					control:SetValue(value, false)
				end,
			})

			control._component = component
			return control
		end

		function groupbox:AddDropdown(id, config)
			local values = cloneList(config.Values)
			if #values == 0 then
				values = { "---" }
			end

			local isMulti = config.Multi == true
			local title = config.Text or id
			local tooltip = config.Tooltip
			local row, right = makeRow(form, title, tooltip)
			local initialValue = isMulti
				and makeMultiSelection(values, config.Default)
				or makeSingleSelection(values, config.Default)
			local control = makeOptionControl(Library.Options, id, initialValue)
			control.Values = values
			local component

			local function selectionToIndices(selection)
				if not isMulti then
					return table.find(control.Values, selection) or 1
				end

				local indices = {}
				for index, name in ipairs(control.Values) do
					if selection[name] then
						table.insert(indices, index)
					end
				end
				return indices
			end

			local function indicesToSelection(value)
				if not isMulti then
					local index = tonumber(value) or 1
					return control.Values[index] or control.Values[1]
				end

				local selection = {}
				for _, index in ipairs(value or {}) do
					local name = control.Values[index]
					if name and name ~= "---" then
						selection[name] = true
					end
				end
				return selection
			end

			function control:SetValue(value, silent)
				local normalized
				if isMulti then
					normalized = makeMultiSelection(control.Values, value)
				else
					normalized = type(value) == "number" and (control.Values[value] or control.Values[1]) or value
					if type(normalized) ~= "string" or not table.find(control.Values, normalized) then
						normalized = control.Values[1]
					end
				end

				if shallowEquals(self.Value, normalized) then
					syncComponent(self, component, "Value", selectionToIndices(normalized))
					return
				end

				self.Value = normalized
				syncComponent(self, component, "Value", selectionToIndices(normalized))
				if not silent then
					emitChanged(self)
				end
			end

			function control:SetValues(newValues)
				local nextValues = cloneList(newValues)
				if #nextValues == 0 then
					nextValues = { "---" }
				end

				self.Values = nextValues
				syncComponent(self, component, "Options", cloneList(nextValues))
				syncComponent(self, component, "Maximum", isMulti and math.max(1, #nextValues) or 1)

				if isMulti then
					local retained = {}
					for name, enabled in pairs(self.Value or {}) do
						if enabled and table.find(nextValues, name) then
							retained[name] = true
						end
					end
					self:SetValue(retained, true)
				else
					local nextValue = self.Value
					if not table.find(nextValues, nextValue) then
						nextValue = nextValues[1]
					end
					self:SetValue(nextValue, true)
				end
			end

			component = right:PopUpButton({
				Options = cloneList(values),
				Maximum = isMulti and math.max(1, #values) or 1,
				Value = selectionToIndices(control.Value),
				ValueChanged = function(_, value)
					if control._syncing then
						return
					end

					control:SetValue(indicesToSelection(value), false)
				end,
			})

			control._component = component
			return control
		end

		function groupbox:AddButton(text, callback)
			local row, right = makeRow(form, text, nil)
			return right:Button({
				Label = text,
				State = "Secondary",
				Pushed = function()
					if callback then
						callback()
					end
				end,
			})
		end

		function groupbox:AddDivider()
			local row = form:Row()
			row:Left():Label({
				Text = string.rep("-", 28),
			})
		end

		function groupbox:AddLabel(text)
			local title, value = parseIndexedLabel(text)
			local _, right, titleStack = makeRow(form, title, nil)
			local component = right:Label({
				Text = value,
			})

			local labelWrapper = {}

			function labelWrapper:SetText(nextText)
				local nextTitle, nextValue = parseIndexedLabel(nextText)
				if titleStack and titleStack.Title ~= nil then
					titleStack.Title = nextTitle
				end
				component.Text = nextValue
			end

			function labelWrapper:AddKeyPicker(id, config)
				if component then
					component:Destroy()
				end
				if titleStack and titleStack.Title ~= nil and titleStack.Title == "" then
					titleStack.Title = value ~= "" and value or config.Text or id
				end

				local defaultValue = config.Default
				if type(defaultValue) == "string" then
					defaultValue = Enum.KeyCode[defaultValue]
				end
				if typeof(defaultValue) ~= "EnumItem" then
					defaultValue = Enum.KeyCode.RightShift
				end

				local control = makeOptionControl(Library.Options, id, defaultValue)
				local field

				function control:SetValue(nextValue, silent)
					local normalized = nextValue
					if type(normalized) == "string" then
						normalized = Enum.KeyCode[normalized]
					end
					if typeof(normalized) ~= "EnumItem" then
						return
					end

					if self.Value == normalized then
						syncComponent(self, field, "Value", normalized)
						return
					end

					self.Value = normalized
					syncComponent(self, field, "Value", normalized)
					if not silent then
						emitChanged(self)
					end
				end

				field = right:KeybindField({
					Placeholder = config.Text or "Select keybind",
					Value = control.Value,
					ValueChanged = function(_, nextValue)
						if control._syncing then
							return
						end

						control:SetValue(nextValue, false)
					end,
					BindPressed = function(_, value, inputComplete, gameProcessedEvent)
						if Library.ToggleKeybind == control and inputComplete and not gameProcessedEvent and Library._App then
							Library._App.Enabled = not Library._App.Enabled
						end
					end,
				})

				control._component = field
				return control
			end

			return labelWrapper
		end

		return groupbox
	end

	function windowWrapper:AddTab(title, iconName)
		local tab = self._section:Tab({
			Selected = not self._selectedTab,
			Title = title,
			Icon = mapWindowIcon(iconName),
		})
		self._selectedTab = true

		local tabWrapper = {}

		function tabWrapper:AddLeftGroupbox(groupTitle)
			return buildGroupbox(tab, groupTitle)
		end

		function tabWrapper:AddRightGroupbox(groupTitle)
			return buildGroupbox(tab, groupTitle)
		end

		return tabWrapper
	end

	return windowWrapper
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local getValidTarget
local lastAttachState = false
local lastAttachAutoRotate
local savedPositionCFrame
local currentZoneName = "Open Sea"
local bossBillboards = {}
local lastBossAnnouncements = {}
local attachNoClipState = {}
local attachNoClipEnabled = false
local attachVelocityName = "CascadeAttachVelocity"
local weaponOptions = { "---" }
local lastSeenWeaponName
local lockedBossFarmId
local timedBossPortalMinDistance = 250
local timedBossPortalRetryInterval = 1.5
local timedBossPortalPendingTime = 1.1
local timedBossAttachStepDistance = 42
local timedBossAttachStepInterval = 0.14
local timedBossAttachFinalApproachDistance = 65
local timedBossAttachFinalTweenSpeed = 85
local timedBossAttachAnchorDistance = 6
local timedBossAttachUiSettleTime = 0.45
local attachTravelState = {
	TargetKey = nil,
	LastStepAt = 0,
	CachedGoalCFrame = nil,
	UiVisibleSince = 0,
	LastPortalAt = 0,
	PendingPortalId = nil,
	PortalPendingUntil = 0,
}
local TravelConfig
local IslandsConfig
local TimedBossConfig
local TeleportToPortalRemote
local travelZoneOptions = { "---" }
local travelZonesByDisplayName = {}
local portalIdByDisplayName = {}
local timedBossConfigById = {}

local function tryRequire(instance)
	if not instance then
		return nil
	end

	local ok, result = pcall(require, instance)
	if ok then
		return result
	end

	return nil
end

local function waitForPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:WaitForChild(name, 5)
		if not current then
			return nil
		end
	end

	return current
end

local function getCharacterRoot(character)
	local char = character or LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getToolDisplayName(tool)
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	return tool:GetAttribute("_ToolName") or tool.Name
end

local function collectWeaponOptions()
	local names = {}
	local seen = {}

	local function addTool(tool)
		local toolName = getToolDisplayName(tool)
		if toolName and not seen[toolName] then
			seen[toolName] = true
			table.insert(names, toolName)
		end
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			addTool(child)
		end
	end

	local char = LocalPlayer.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			addTool(child)
		end
	end

	table.sort(names)
	if #names == 0 then
		table.insert(names, "---")
	end

	return names, seen
end

local function refreshWeaponOptions()
	local names, seen = collectWeaponOptions()
	weaponOptions = names

	if not (Library and Library.Options and Library.Options.WeaponSelect) then
		return
	end

	local currentValue = Library.Options.WeaponSelect.Value
	Library.Options.WeaponSelect:SetValues(names)

	if currentValue and currentValue ~= "---" and not seen[currentValue] then
		local fallbackValue = lastSeenWeaponName and seen[lastSeenWeaponName] and lastSeenWeaponName or names[1]
		pcall(function()
			Library.Options.WeaponSelect:SetValue(fallbackValue)
		end)
	end
end

local function findWeaponToolByName(toolName)
	if not toolName or toolName == "---" then
		return nil
	end

	local char = LocalPlayer.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") and getToolDisplayName(child) == toolName then
				return child
			end
		end
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and getToolDisplayName(child) == toolName then
				return child
			end
		end
	end

	return nil
end

local function getPreferredWeaponName()
	local selectedName = Library and Library.Options and Library.Options.WeaponSelect and Library.Options.WeaponSelect.Value
	if selectedName and selectedName ~= "---" then
		return selectedName
	end

	return lastSeenWeaponName
end

local function equipPreferredWeapon()
	local weaponName = getPreferredWeaponName()
	if not weaponName then
		return false
	end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not hum then
		return false
	end

	local currentTool = char:FindFirstChildOfClass("Tool")
	if currentTool and getToolDisplayName(currentTool) == weaponName then
		return true
	end

	local tool = findWeaponToolByName(weaponName)
	if not tool then
		return false
	end

	hum:EquipTool(tool)
	return true
end

local function flattenDirection(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude > 0.001 then
		return flat.Unit
	end

	return fallback or Vector3.new(0, 0, -1)
end

local function buildHorizontalCFrame(position, preferredLook, fallbackLook)
	local fallbackDirection = flattenDirection(fallbackLook or Vector3.new(0, 0, -1), Vector3.new(0, 0, -1))
	local lookVector = flattenDirection(preferredLook or fallbackDirection, fallbackDirection)
	return CFrame.lookAt(position, position + lookVector)
end

local function buildDownwardAttachCFrame(position)
	return CFrame.new(position) * CFrame.Angles(math.rad(-90), 0, 0)
end

local function replaceCFramePosition(sourceCFrame, position)
	return CFrame.fromMatrix(position, sourceCFrame.XVector, sourceCFrame.YVector, sourceCFrame.ZVector)
end

local function setAttachNoClipState(enabled)
	local char = LocalPlayer.Character
	if not char then
		attachNoClipEnabled = false
		table.clear(attachNoClipState)
		return
	end

	if enabled then
		for _, descendant in ipairs(char:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if attachNoClipState[descendant] == nil then
					attachNoClipState[descendant] = descendant.CanCollide
				end
				descendant.CanCollide = false
			end
		end
		attachNoClipEnabled = true
		return
	end

	if not attachNoClipEnabled and next(attachNoClipState) == nil then
		return
	end

	for part, originalCanCollide in pairs(attachNoClipState) do
		if part and part.Parent then
			part.CanCollide = originalCanCollide
		end
		attachNoClipState[part] = nil
	end

	attachNoClipEnabled = false
end

local function pivotCharacter(destinationCFrame, resetVelocity)
	local char = LocalPlayer.Character
	local root = getCharacterRoot(char)
	if not char or not root then
		return false
	end

	if resetVelocity then
		local attachVelocity = root:FindFirstChild(attachVelocityName)
		if attachVelocity then
			attachVelocity:Destroy()
		end
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	root.CFrame = destinationCFrame
	return true
end

local function clearAttachVelocity(root, resetMotion)
	local currentRoot = root or getCharacterRoot()
	if not currentRoot then
		return
	end

	local attachVelocity = currentRoot:FindFirstChild(attachVelocityName)
	if attachVelocity then
		attachVelocity:Destroy()
	end

	if resetMotion then
		currentRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		currentRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
end

local function ensureAttachVelocity(root)
	if not root then
		return nil
	end

	local attachVelocity = root:FindFirstChild(attachVelocityName)
	if attachVelocity and not attachVelocity:IsA("BodyVelocity") then
		attachVelocity:Destroy()
		attachVelocity = nil
	end

	if not attachVelocity then
		attachVelocity = Instance.new("BodyVelocity")
		attachVelocity.Name = attachVelocityName
		attachVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		attachVelocity.P = 12500
		attachVelocity.Velocity = Vector3.new(0, 0, 0)
		attachVelocity.Parent = root
	end

	return attachVelocity
end

local function driveCharacterVelocity(goalCFrame, speed, dt)
	local root = getCharacterRoot()
	if not root or not goalCFrame then
		return false
	end

	local delta = goalCFrame.Position - root.Position
	local distance = delta.Magnitude
	if distance <= 3 then
		clearAttachVelocity(root)
		return pivotCharacter(goalCFrame, true)
	end

	local bodyVelocity = ensureAttachVelocity(root)
	if not bodyVelocity then
		return false
	end

	local movementSpeed = math.max(1, speed)
	bodyVelocity.Velocity = delta.Unit * movementSpeed
	root.CFrame = replaceCFramePosition(goalCFrame, root.Position)

	if dt and distance <= movementSpeed * dt * 1.35 then
		return pivotCharacter(goalCFrame, true)
	end

	return true
end

local function getAttachGoalCFrame(targetRoot, currentRoot)
	if not targetRoot then
		return nil
	end

	local offsetX = Library.Options.OffsetX and Library.Options.OffsetX.Value or 0
	local offsetY = Library.Options.OffsetY and Library.Options.OffsetY.Value or 8
	local offsetZ = Library.Options.OffsetZ and Library.Options.OffsetZ.Value or 0

	-- Ignore pitch/roll from combat animations so offsets stay stable while targets animate.
	local fallbackFacing = currentRoot and currentRoot.CFrame.LookVector or Vector3.new(0, 0, -1)
	local targetBasis = buildHorizontalCFrame(
		targetRoot.Position,
		targetRoot.CFrame.LookVector,
		fallbackFacing
	)
	local goalPosition = (targetBasis * CFrame.new(offsetX, offsetY, offsetZ)).Position

	return buildDownwardAttachCFrame(goalPosition)
end

local function notify(title, description, duration)
	pcall(function()
		Library:Notify({
			Title = title,
			Description = description,
			Time = duration or 4,
		})
	end)
end

local function resetAttachTravelState()
	attachTravelState.TargetKey = nil
	attachTravelState.LastStepAt = 0
	attachTravelState.CachedGoalCFrame = nil
	attachTravelState.UiVisibleSince = 0
	attachTravelState.LastPortalAt = 0
	attachTravelState.PendingPortalId = nil
	attachTravelState.PortalPendingUntil = 0
end

local function normalizeBossName(name)
	if type(name) ~= "string" then
		return nil
	end

	local normalized = name:gsub("%s*%[.-%]%s*", "")
	normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
	if normalized == "" then
		return nil
	end

	return string.lower(normalized)
end

local function getZoneDisplayNameAt(position)
	if TravelConfig and TravelConfig.GetZoneAt and position then
		local _, zoneData = TravelConfig.GetZoneAt(position)
		return zoneData and zoneData.DisplayName or nil
	end

	return nil
end

local function formatDuration(seconds)
	local totalSeconds = math.max(0, math.floor(seconds or 0))
	local minutes = math.floor(totalSeconds / 60)
	local remainder = totalSeconds % 60

	if minutes > 0 then
		return string.format("%d:%02d", minutes, remainder)
	end

	return string.format("0:%02d", remainder)
end

local function teleportCharacter(destinationCFrame)
	return pivotCharacter(destinationCFrame, true)
end

local function setAntiKnockbackState(enabled, humanoid)
	local hum = humanoid or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"))
	if not hum then
		return
	end

	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled)
end

local function setAttachState(enabled, force)
	if not force and lastAttachState == enabled then
		return
	end

	lastAttachState = enabled
	if not enabled then
		setAttachNoClipState(false)
	end

	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")

	if root then
		root.Anchored = enabled
		clearAttachVelocity(root)
	end

	if hum then
		if enabled then
			if lastAttachAutoRotate == nil then
				lastAttachAutoRotate = hum.AutoRotate
			end
			hum.AutoRotate = false
		else
			hum.AutoRotate = lastAttachAutoRotate ~= nil and lastAttachAutoRotate or true
			lastAttachAutoRotate = nil
		end

		if hum.PlatformStand then
			hum.PlatformStand = false
		end
	end
end

clearAttachVelocity()

TravelConfig = tryRequire(ReplicatedStorage:FindFirstChild("TravelConfig") or ReplicatedStorage:FindFirstChild("TravelConfig", true))
IslandsConfig = tryRequire(ReplicatedStorage:FindFirstChild("IslandsConfig") or ReplicatedStorage:FindFirstChild("IslandsConfig", true))
TimedBossConfig = tryRequire(ReplicatedStorage:FindFirstChild("TimedBossConfig") or ReplicatedStorage:FindFirstChild("TimedBossConfig", true))
TeleportToPortalRemote = waitForPath(ReplicatedStorage, { "Remotes", "TeleportToPortal" })

if IslandsConfig then
	for displayName, islandData in pairs(IslandsConfig) do
		if type(islandData) == "table" and islandData.PortalId then
			portalIdByDisplayName[displayName] = islandData.PortalId
		end
	end
end

if TimedBossConfig and TimedBossConfig.Bosses then
	for bossId, bossData in pairs(TimedBossConfig.Bosses) do
		if type(bossData) == "table" then
			timedBossConfigById[bossId] = bossData
		end
	end
end

if TravelConfig and TravelConfig.Zones then
	travelZoneOptions = {}
	for zoneKey, zoneData in pairs(TravelConfig.Zones) do
		local displayName = zoneData.DisplayName or zoneKey
		travelZonesByDisplayName[displayName] = {
			Key = zoneKey,
			Data = zoneData,
		}
		table.insert(travelZoneOptions, displayName)
	end

	table.sort(travelZoneOptions)
	if #travelZoneOptions == 0 then
		table.insert(travelZoneOptions, "---")
	end
end

local Window = Library:CreateWindow({
	Title = "antigravity",
	Footer = "Made By Antigravity",
	Icon = 0,
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Overview = Window:AddTab("Overview", "user"),
	Travel = Window:AddTab("Travel", "user"),
	Bosses = Window:AddTab("Bosses", "zap"),
	Combat = Window:AddTab("Combat", "zap"),
	Attach = Window:AddTab("Attach", "zap"),
	Settings = Window:AddTab("Settings", "settings"),
}
local MainGroup = Tabs.Overview:AddLeftGroupbox("Player")

MainGroup:AddToggle("AntiKnockbackToggle", {
	Text = "Anti-Knockback",
	Default = false,
	Tooltip = "Removes knockback forces from your character"
})

Library.Toggles.AntiKnockbackToggle:OnChanged(function()
	pcall(function()
		setAntiKnockbackState(Library.Toggles.AntiKnockbackToggle.Value)
	end)
end)

-- Event-driven Anti-Knockback that preserves dashes 99% of the time
task.spawn(function()
	local HitVFX = waitForPath(ReplicatedStorage, { "RemoteEvents", "HitVFX" })
	if not HitVFX then
		warn("ui_starter: HitVFX remote not found; Anti-Knockback listener disabled.")
		return
	end

	HitVFX.OnClientEvent:Connect(function(targetChar)
		if Library.Toggles.AntiKnockbackToggle and Library.Toggles.AntiKnockbackToggle.Value then
			local lpChar = LocalPlayer.Character
			if targetChar == lpChar then
				task.spawn(function()
					-- Knockback usually lasts 0.2-0.3s. We clear motion briefly after the hit event.
					for _ = 1, 10 do
						if not lpChar then
							break
						end

						for _, v in pairs(lpChar:GetDescendants()) do
							if v:IsA("BodyVelocity") or v:IsA("LinearVelocity") or v:IsA("BodyPosition") then
								v:Destroy()
							end
						end

						local hrp = lpChar:FindFirstChild("HumanoidRootPart")
						if hrp then
							hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
						end
						task.wait(0.03)
					end
				end)

				setAntiKnockbackState(true, lpChar and lpChar:FindFirstChild("Humanoid"))
			end
		end
	end)
end)

MainGroup:AddToggle("BypassTweenToggle", {
	Text = "Legacy Tween Patch",
	Default = false,
	Tooltip = "Legacy toggle kept for compatibility. Attach movement now uses velocity instead of tween stepping."
})

Library.Toggles.BypassTweenToggle:OnChanged(function()
	if Library.Toggles.BypassTweenToggle.Value then
		notify("Attach", "Velocity mode is active. No TweenService patch is needed.", 4)
	end
end)

local InfoGroupbox = Tabs.Overview:AddRightGroupbox("Info")
local LabelLevel = InfoGroupbox:AddLabel("Level: ...")
local LabelStatPoints = InfoGroupbox:AddLabel("Stat Points: ...")
local LabelMoney = InfoGroupbox:AddLabel("Money: ...")
local LabelClan = InfoGroupbox:AddLabel("Clan: ...")
local LabelZone = InfoGroupbox:AddLabel("Zone: ...")
local LabelTool = InfoGroupbox:AddLabel("Tool: ...")

local TravelGroup = Tabs.Travel:AddLeftGroupbox("Travel")
TravelGroup:AddDropdown("TravelZone", {
	Text = "Select Zone",
	Values = travelZoneOptions,
	Default = 1,
})

TravelGroup:AddButton("Teleport To Zone", function()
	local selectedZoneName = Library.Options.TravelZone and Library.Options.TravelZone.Value
	local selectedZone = selectedZoneName and travelZonesByDisplayName[selectedZoneName]
	if not selectedZone then
		notify("Travel", "No zone selected.")
		return
	end

	local zoneData = selectedZone.Data
	local zoneHeight = zoneData.Size and (zoneData.Size.Y / 2) or 0
	local destination = CFrame.new(zoneData.Center + Vector3.new(0, zoneHeight + 8, 0))
	if teleportCharacter(destination) then
		notify("Travel", "Teleported to " .. selectedZoneName .. ".", 3)
	else
		notify("Travel", "Your character is not ready yet.")
	end
end)

TravelGroup:AddButton("Save Current Position", function()
	local root = getCharacterRoot()
	if not root then
		notify("Travel", "Your character is not ready yet.")
		return
	end

	savedPositionCFrame = root.CFrame
	notify("Travel", "Saved your current position.", 3)
end)

TravelGroup:AddButton("Return To Saved Position", function()
	if not savedPositionCFrame then
		notify("Travel", "No saved position yet.")
		return
	end

	if teleportCharacter(savedPositionCFrame) then
		notify("Travel", "Returned to your saved position.", 3)
	else
		notify("Travel", "Your character is not ready yet.")
	end
end)

task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then break end

		pcall(function()
			local p = LocalPlayer
			LabelLevel:SetText("Level: " .. tostring(p.Data.Level.Value))
		end)

		pcall(function()
			local p = LocalPlayer
			LabelStatPoints:SetText("Stat Points: " .. tostring(p.Data.StatPoints.Value))
		end)

		pcall(function()
			local p = LocalPlayer
			LabelMoney:SetText("Money: " .. tostring(p.Data.Money.Value))
		end)

		pcall(function()
			local p = LocalPlayer
			LabelClan:SetText("Clan: " .. tostring(p:GetAttribute("CurrentClan") or "N/A"))
		end)

		pcall(function()
			local root = getCharacterRoot()
			if TravelConfig and TravelConfig.GetZoneAt and root then
				local _, zoneData = TravelConfig.GetZoneAt(root.Position)
				currentZoneName = zoneData and zoneData.DisplayName or "Open Sea"
				LabelZone:SetText("Zone: " .. currentZoneName)
			else
				LabelZone:SetText("Zone: " .. currentZoneName)
			end
		end)

		pcall(function()
			local char = LocalPlayer.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			local toolName = tool and (tool:GetAttribute("_ToolName") or tool.Name) or "None"
			if tool and toolName ~= "None" then
				lastSeenWeaponName = toolName
			end
			LabelTool:SetText("Tool: " .. tostring(toolName))
		end)
	end
end)

local BossTrackerGroup = Tabs.Bosses:AddLeftGroupbox("Boss Tracker")
local BossLabel = BossTrackerGroup:AddLabel("Searching for bosses...")
BossTrackerGroup:AddToggle("BossSpawnAlertsToggle", { Text = "Boss Spawn Alerts", Default = true })
BossTrackerGroup:AddToggle("BossBillboardToggle", { Text = "World Boss Billboards", Default = false })

local bosses = {}
local function getBossPart(bossData)
	if not bossData or not bossData.spawnPointName then return nil end
	return workspace:FindFirstChild(bossData.spawnPointName, true)
end

local function getTimedBossTargetData(targetRoot)
	if not targetRoot then
		return nil, nil
	end

	local targetModel = targetRoot:FindFirstAncestorOfClass("Model")
	local function buildTimedBossFallback(bossId, baseData)
		local bossData = {}
		if type(baseData) == "table" then
			for key, value in pairs(baseData) do
				bossData[key] = value
			end
		end
		bossData.displayName = bossData.displayName or bossId
		bossData.spawnPointName = bossData.spawnPointName or ("TimedBossSpawn_" .. tostring(bossId))
		bossData.spawnLocation = bossData.spawnLocation or (timedBossConfigById[bossId] and timedBossConfigById[bossId].spawnLocation)
		bossData.portalId = bossData.portalId or portalIdByDisplayName[bossData.spawnLocation]
		return bossData
	end

	for id, bossData in pairs(bosses) do
		if bossData and type(bossData.spawnPointName) == "string" and bossData.spawnPointName:find("TimedBossSpawn_", 1, true) == 1 then
			local spawnPart = getBossPart(bossData)
			if spawnPart == targetRoot then
				return id, buildTimedBossFallback(id, bossData)
			end

			if targetModel then
				local displayName = bossData.displayName or id
				if targetModel.Name == id
					or targetModel.Name == displayName
					or targetModel:GetAttribute("DisplayName") == displayName then
					return id, buildTimedBossFallback(id, bossData)
				end
			end
		end
	end

	if targetRoot.Name:find("TimedBossSpawn_", 1, true) == 1 then
		local bossId = targetRoot.Name:gsub("^TimedBossSpawn_", "")
		return bossId, buildTimedBossFallback(bossId, {
			displayName = bossId,
			spawnPointName = targetRoot.Name,
		})
	end

	if targetModel and targetModel:GetAttribute("_IsTimedBoss") then
		local bossId = targetModel.Name
		return bossId, buildTimedBossFallback(bossId, {
			displayName = targetModel:GetAttribute("DisplayName") or targetModel.Name,
			spawnPointName = "TimedBossSpawn_" .. targetModel.Name,
		})
	end

	return nil, nil
end

local function isTimedBossTarget(targetRoot)
	return getTimedBossTargetData(targetRoot) ~= nil
end

local function isTimedBossUiVisibleForTarget(targetRoot)
	local bossId, bossData = getTimedBossTargetData(targetRoot)
	if not bossId then
		return false
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local bossUI = playerGui and playerGui:FindFirstChild("BossUI")
	local mainFrame = bossUI and bossUI:FindFirstChild("MainFrame")
	if not (mainFrame and mainFrame.Visible) then
		return false
	end

	local bossNameLabel = mainFrame:FindFirstChild("BossName")
	local shownName = normalizeBossName(bossNameLabel and bossNameLabel.Text)
	if not shownName then
		return true
	end

	local expectedNames = {
		normalizeBossName(bossData and bossData.displayName),
		normalizeBossName(bossId),
		normalizeBossName(targetRoot.Name),
		normalizeBossName(targetRoot.Parent and targetRoot.Parent.Name),
	}

	for _, expectedName in ipairs(expectedNames) do
		if expectedName and shownName:find(expectedName, 1, true) then
			return true
		end
	end

	return false
end

local function updateTimedBossUiVisibility(targetRoot)
	if not targetRoot or not isTimedBossTarget(targetRoot) then
		attachTravelState.UiVisibleSince = 0
		return false, false
	end

	local visible = isTimedBossUiVisibleForTarget(targetRoot)
	if visible then
		if attachTravelState.UiVisibleSince == 0 then
			attachTravelState.UiVisibleSince = os.clock()
		end
	else
		attachTravelState.UiVisibleSince = 0
	end

	local settled = attachTravelState.UiVisibleSince > 0
		and (os.clock() - attachTravelState.UiVisibleSince) >= timedBossAttachUiSettleTime

	return visible, settled
end

local function shouldPortalToTimedBoss(targetRoot, currentRoot)
	local _, bossData = getTimedBossTargetData(targetRoot)
	if not (targetRoot and currentRoot and bossData and TeleportToPortalRemote) then
		return false
	end

	local spawnLocation = bossData.spawnLocation
	local portalId = bossData.portalId or portalIdByDisplayName[spawnLocation]
	if not (spawnLocation and portalId) then
		return false
	end

	local currentZoneDisplayName = getZoneDisplayNameAt(currentRoot.Position)
	local distanceToTarget = (targetRoot.Position - currentRoot.Position).Magnitude
	if currentZoneDisplayName == spawnLocation or distanceToTarget < timedBossPortalMinDistance then
		attachTravelState.PendingPortalId = nil
		attachTravelState.PortalPendingUntil = 0
		return false
	end

	local now = os.clock()
	if attachTravelState.PendingPortalId == portalId and now < attachTravelState.PortalPendingUntil then
		return true
	end

	if now - attachTravelState.LastPortalAt < timedBossPortalRetryInterval then
		return true
	end

	attachTravelState.LastPortalAt = now
	attachTravelState.PendingPortalId = portalId
	attachTravelState.PortalPendingUntil = now + timedBossPortalPendingTime
	TeleportToPortalRemote:FireServer(portalId)
	return true
end

local function getBossTravelGoalCFrame(targetRoot, currentRoot, goalCFrame)
	if not targetRoot or not currentRoot or not goalCFrame or not isTimedBossTarget(targetRoot) then
		resetAttachTravelState()
		return goalCFrame
	end

	local targetKey = select(1, getTimedBossTargetData(targetRoot)) or targetRoot:GetFullName()
	if attachTravelState.TargetKey ~= targetKey then
		resetAttachTravelState()
		attachTravelState.TargetKey = targetKey
	end

	local delta = goalCFrame.Position - currentRoot.Position
	local distance = delta.Magnitude
	if distance <= timedBossAttachFinalApproachDistance then
		attachTravelState.CachedGoalCFrame = nil
		return goalCFrame
	end

	local now = os.clock()
	if not attachTravelState.CachedGoalCFrame or now - attachTravelState.LastStepAt >= timedBossAttachStepInterval then
		attachTravelState.LastStepAt = now
		local stepDistance = math.min(timedBossAttachStepDistance, distance)
		local steppedPosition = currentRoot.Position + delta.Unit * stepDistance
		attachTravelState.CachedGoalCFrame = replaceCFramePosition(goalCFrame, steppedPosition)
	end

	return attachTravelState.CachedGoalCFrame or goalCFrame
end

local function shouldAnchorTimedBossAttach(targetRoot, currentRoot, goalCFrame)
	if not targetRoot or not currentRoot or not goalCFrame or not isTimedBossTarget(targetRoot) then
		return true
	end

	local distance = (goalCFrame.Position - currentRoot.Position).Magnitude
	if distance > timedBossAttachAnchorDistance then
		return false
	end

	local _, uiSettled = updateTimedBossUiVisibility(targetRoot)
	return uiSettled
end

local function isBossSelectedForFarm(bossId, bossData, selectedBosses)
	local selected = selectedBosses or {}
	local displayName = bossData and bossData.displayName or bossId
	return selected[displayName] or selected[bossId] or false
end

local function getBossFarmTargetRootById(bossId)
	local bossData = bossId and bosses[bossId]
	if not (bossId and bossData and bossData.isAlive) then
		return nil, bossData
	end

	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, npc in pairs(npcs:GetChildren()) do
			if npc.Name == bossId or npc.Name == (bossData.displayName or "") or npc:GetAttribute("DisplayName") == bossData.displayName then
				local root = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if root and hum and hum.Health > 0 then
					return root, bossData
				end
			end
		end
	end

	local spawnPart = getBossPart(bossData)
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart, bossData
	end

	return nil, bossData
end

local function getLockedBossFarmTarget(selectedBosses)
	if not lockedBossFarmId then
		return nil
	end

	local bossData = bosses[lockedBossFarmId]
	if not bossData or not bossData.isAlive or not isBossSelectedForFarm(lockedBossFarmId, bossData, selectedBosses) then
		lockedBossFarmId = nil
		return nil
	end

	local targetRoot = getBossFarmTargetRootById(lockedBossFarmId)
	if not targetRoot then
		lockedBossFarmId = nil
		return nil
	end

	return targetRoot
end

local function clearBossBillboards()
	for id, billboardData in pairs(bossBillboards) do
		if billboardData.Gui then
			billboardData.Gui:Destroy()
		end
		bossBillboards[id] = nil
	end
end

local function ensureBossBillboard(id, bossData)
	local spawnPart = getBossPart(bossData)
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return nil
	end

	local existing = bossBillboards[id]
	if existing and existing.Gui and existing.Gui.Parent and existing.Adornee == spawnPart then
		return existing
	end

	if existing and existing.Gui then
		existing.Gui:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "AntigravityBossBillboard"
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Size = UDim2.new(0, 180, 0, 44)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Adornee = spawnPart
	gui.Parent = spawnPart

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 0.25
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(236, 145, 39)
	stroke.Thickness = 1
	stroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Size = UDim2.new(1, -12, 0.5, -2)
	nameLabel.Position = UDim2.new(0, 6, 0, 2)
	nameLabel.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	statusLabel.TextScaled = true
	statusLabel.Size = UDim2.new(1, -12, 0.5, -2)
	statusLabel.Position = UDim2.new(0, 6, 0.5, 0)
	statusLabel.Parent = frame

	bossBillboards[id] = {
		Adornee = spawnPart,
		Gui = gui,
		NameLabel = nameLabel,
		StatusLabel = statusLabel,
	}

	return bossBillboards[id]
end

local function updateBossBillboard(id, bossData)
	local billboard = ensureBossBillboard(id, bossData)
	if not billboard then
		return
	end

	billboard.NameLabel.Text = bossData.displayName or tostring(id)

	if bossData.isAlive then
		billboard.StatusLabel.Text = "[ALIVE]"
		billboard.StatusLabel.TextColor3 = Color3.fromRGB(94, 236, 114)
	elseif bossData.isRotationWaiting then
		billboard.StatusLabel.Text = "[ROTATION]"
		billboard.StatusLabel.TextColor3 = Color3.fromRGB(255, 214, 102)
	elseif bossData.timer and bossData.timer > 0 then
		billboard.StatusLabel.Text = formatDuration(bossData.timer)
		billboard.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		billboard.StatusLabel.Text = "Spawning..."
		billboard.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

Library.Toggles.BossBillboardToggle:OnChanged(function()
	if not Library.Toggles.BossBillboardToggle.Value then
		clearBossBillboards()
	end
end)

-- Official Event-Driven Boss Tracking Logic
pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
	if not Remotes then
		warn("ui_starter: Remotes folder not found; Boss Tracker disabled.")
		return
	end

	local BossTimerSync = Remotes:WaitForChild("BossTimerSync", 5)
	if not BossTimerSync then
		warn("ui_starter: BossTimerSync remote not found; Boss Tracker disabled.")
		return
	end
	local BossTimerEvent = Remotes:FindFirstChild("BossTimerEvent")

	local function updateBoss(id, data)
		local timedConfig = timedBossConfigById[id]
		bosses[id] = bosses[id] or {}
		bosses[id].displayName = data.displayName
		bosses[id].spawnPointName = data.spawnPointName
		bosses[id].spawnLocation = data.spawnLocation or (timedConfig and timedConfig.spawnLocation)
		bosses[id].portalId = bosses[id].spawnLocation and portalIdByDisplayName[bosses[id].spawnLocation] or nil
		bosses[id].isAlive = data.isAlive
		bosses[id].isRotationWaiting = data.isRotationWaiting or false
		bosses[id].timer = data.timer
	end

	BossTimerSync.OnClientEvent:Connect(function(allBosses)
		if not allBosses then 
			warn("No boss data received from BossTimerSync.")
			return 
		end

		local names = {}
		print("=== All Bosses In Game ===")
		for id, data in pairs(allBosses) do
			updateBoss(id, data)
			
			-- Matching the user's requested discovery print format
			print(string.format(
				"ID: %s | Name: %s | Spawn: %s | Alive: %s | Timer: %s",
				tostring(id),
				tostring(data.displayName),
				tostring(data.spawnPointName),
				tostring(data.isAlive),
				tostring(data.timer)
			))
			
			table.insert(names, data.displayName or tostring(id))
		end
		
		table.sort(names)
		if #names == 0 then
			table.insert(names, "---")
		end

		if Library.Options.BossFarmTargets then
			Library.Options.BossFarmTargets:SetValues(names)
		end
	end)

	if BossTimerEvent then
		BossTimerEvent.OnClientEvent:Connect(function(id, state, timer)
			local boss = bosses[id]
			if not boss then return end
			
			if state == "SPAWNED" then
				boss.isAlive = true
				boss.isRotationWaiting = false
				boss.timer = 0
				if Library.Toggles.BossSpawnAlertsToggle and Library.Toggles.BossSpawnAlertsToggle.Value then
					local now = os.clock()
					if not lastBossAnnouncements[id] or now - lastBossAnnouncements[id] > 5 then
						lastBossAnnouncements[id] = now
						notify("Boss Spawned", (boss.displayName or tostring(id)) .. " is alive.", 5)
					end
				end
			elseif state == "DIED" or state == "WAITING" or state == "ROTATION_WAITING" then
				boss.isAlive = false
				boss.isRotationWaiting = state == "ROTATION_WAITING"
				boss.timer = state == "ROTATION_WAITING" and 0 or (timer or 0)
				lastBossAnnouncements[id] = nil
				if lockedBossFarmId == id then
					lockedBossFarmId = nil
				end
			end
		end)
	end
end)

-- Background loop to refresh the UI labels efficiently (includes distance/countdown)
task.spawn(function()
	while task.wait(0.1) do
		if Library.Unloaded then break end
		pcall(function()
			local lpRoot = getCharacterRoot()
			local aliveData = {}
			local timerData = {}
			local rotationData = {}

			-- ONLY use official server data to ensure zero false positives
			for id, boss in pairs(bosses) do
				local dName = boss.displayName or tostring(id)
				if boss.isAlive then
					local part = getBossPart(boss)
					local dist = lpRoot and part and math.floor((part.Position - lpRoot.Position).Magnitude) or nil
					table.insert(aliveData, {name = dName, dist = dist})
				elseif boss.isRotationWaiting then
					table.insert(rotationData, {name = dName})
				elseif boss.timer and boss.timer > 0 then
					table.insert(timerData, {name = dName, timer = boss.timer})
				end
			end

			table.sort(aliveData, function(a, b)
				if a.dist and b.dist then
					return a.dist < b.dist
				end
				if a.dist then
					return true
				end
				if b.dist then
					return false
				end
				return a.name < b.name
			end)

			-- Sort timers by soonest first
			table.sort(timerData, function(a, b) return a.timer < b.timer end)

			local finalLines = {}
			if #aliveData > 0 then
				table.insert(finalLines, "🟢 [ALIVE]")
				finalLines[#finalLines] = "[ALIVE]"
				for i = 1, math.min(#aliveData, 5) do
					local b = aliveData[i]
					if b.dist then
						table.insert(finalLines, string.format(" %s (%d studs)", b.name, b.dist))
					else
						table.insert(finalLines, " " .. b.name)
					end
				end
				if #aliveData > 5 then table.insert(finalLines, " ... +"..(#aliveData-5).." more") end
			end

			if #timerData > 0 then
				if #finalLines > 0 then table.insert(finalLines, "") end
				table.insert(finalLines, "🕒 [UPCOMING]")
				finalLines[#finalLines] = "[UPCOMING]"
				for i = 1, math.min(#timerData, 5) do
					local b = timerData[i]
					table.insert(finalLines, string.format(" %s: %s", b.name, formatDuration(b.timer)))
				end
				if #timerData > 5 then table.insert(finalLines, " ... +"..(#timerData-5).." more") end
			end

			if #rotationData > 0 then
				if #finalLines > 0 then table.insert(finalLines, "") end
				table.insert(finalLines, "[ROTATION]")
				for i = 1, math.min(#rotationData, 5) do
					table.insert(finalLines, " " .. rotationData[i].name)
				end
				if #rotationData > 5 then table.insert(finalLines, " ... +"..(#rotationData-5).." more") end
			end

			if Library.Toggles.BossBillboardToggle and Library.Toggles.BossBillboardToggle.Value then
				for id, boss in pairs(bosses) do
					updateBossBillboard(id, boss)
				end
			else
				clearBossBillboards()
			end

			if #finalLines == 0 then
				BossLabel:SetText("Searching for signals...")
			else
				BossLabel:SetText(table.concat(finalLines, "\n"))
			end
		end)
	end
end)

-- Second small loop for the 1s tick-down logic
task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then break end
		for _, boss in pairs(bosses) do
			if not boss.isAlive and boss.timer and boss.timer > 0 then
				boss.timer = math.max(0, boss.timer - 1)
			end
		end
	end
end)

local BossFarmGroup = Tabs.Bosses:AddRightGroupbox("Boss Farm")
BossFarmGroup:AddToggle("BossFarmToggle", { Text = "Enable Boss Farm", Default = false })
BossFarmGroup:AddDropdown("BossFarmTargets", { Text = "Target Bosses", Values = {"---"}, Default = 1, Multi = true })
BossFarmGroup:AddToggle("AutoConnectAttach", { Text = "Auto-Attach to Boss", Default = true })

local AutoSkillsGroup = Tabs.Combat:AddLeftGroupbox("Auto Skills")
AutoSkillsGroup:AddDropdown("AutoSkillsSelected", {
	Text = "Auto Skills",
	Values = {
		"Skill 1",
		"Skill 2",
		"Skill 3",
		"Skill 4",
		"Skill 5",
		"Skill 6",
	},
	Default = {},
	Multi = true,
})
AutoSkillsGroup:AddSlider("SkillDelay", { Text = "Skill Delay", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

local WeaponGroup = Tabs.Combat:AddRightGroupbox("Weapon")
WeaponGroup:AddDropdown("WeaponSelect", { Text = "Weapon", Values = weaponOptions, Default = 1 })
WeaponGroup:AddButton("Refresh Weapons", function()
	refreshWeaponOptions()
end)
WeaponGroup:AddToggle("AutoReequipWeaponToggle", { Text = "Auto Re-Equip Weapon", Default = false })

task.spawn(function()
	local RequestAbility = waitForPath(ReplicatedStorage, { "AbilitySystem", "Remotes", "RequestAbility" })
	if not RequestAbility then
		warn("ui_starter: RequestAbility remote not found; Auto Skills disabled.")
		return
	end

	while task.wait(0.1) do
		if Library.Unloaded then break end
		pcall(function()
			local target = getValidTarget()
			if target then
				local skillDelay = math.max(0.05, Library.Options.SkillDelay.Value)
				local selectedSkills = Library.Options.AutoSkillsSelected and Library.Options.AutoSkillsSelected.Value or {}
				for slot = 1, 6 do
					if selectedSkills["Skill " .. slot] then
						RequestAbility:FireServer(slot)
						task.wait(skillDelay)
					end
				end
			end
		end)
	end
end)

local CombatGroup = Tabs.Combat:AddLeftGroupbox("Combat")
CombatGroup:AddToggle("KillAuraToggle", { Text = "Kill Aura", Default = false })
CombatGroup:AddDropdown("AuraTargetMode", { Text = "Target Mode", Values = {"NPCs", "Players", "Both"}, Default = 1 })
CombatGroup:AddSlider("AuraRange", { Text = "Aura Range", Default = 150, Min = 10, Max = 500, Rounding = 0, Suffix = " studs" })
CombatGroup:AddToggle("AuraMultiTarget", { Text = "Multi-Target", Default = false })
CombatGroup:AddDivider()
CombatGroup:AddToggle("FastAttackToggle", { Text = "Fast Attack (Instakill)", Default = false })
CombatGroup:AddSlider("FastAttackSpeed", { Text = "Attack Speed", Default = 3, Min = 1, Max = 10, Rounding = 0, Suffix = "x" })

task.spawn(function()
	local RequestHit = waitForPath(ReplicatedStorage, { "CombatSystem", "Remotes", "RequestHit" })
	if not RequestHit then
		warn("ui_starter: RequestHit remote not found; Kill Aura disabled.")
		return
	end
	
	while task.wait(0.1) do
		if Library.Unloaded then break end
		if Library.Toggles.KillAuraToggle and Library.Toggles.KillAuraToggle.Value then
			pcall(function()
				local lp = LocalPlayer
				local char = lp.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				local range = Library.Options.AuraRange.Value
				local mode = Library.Options.AuraTargetMode.Value
				local multi = Library.Toggles.AuraMultiTarget.Value
				local fastAttack = Library.Toggles.FastAttackToggle.Value
				local spamCount = Library.Options.FastAttackSpeed.Value

				local targets = {}
				
				local function check(entity)
					if entity == char then return end
					local ehrp = entity:FindFirstChild("HumanoidRootPart")
					local hum = entity:FindFirstChild("Humanoid")
					if ehrp and hum and hum.Health > 0 then
						local dist = (ehrp.Position - hrp.Position).Magnitude
						if dist <= range then
							table.insert(targets, {
								Root = ehrp,
								Health = hum.Health,
								Distance = dist,
							})
						end
					end
				end

				if mode == "NPCs" or mode == "Both" then
					local npcs = workspace:FindFirstChild("NPCs")
					if npcs then
						for _, npc in pairs(npcs:GetChildren()) do
							check(npc)
						end
					end
				end

				if mode == "Players" or mode == "Both" then
					for _, player in pairs(game.Players:GetPlayers()) do
						if player ~= lp and player.Character then
							check(player.Character)
						end
					end
				end

				if #targets > 0 then
					table.sort(targets, function(a, b)
						if a.Health ~= b.Health then
							return a.Health < b.Health
						end
						return a.Distance < b.Distance
					end)

					if multi then
						for _, t in pairs(targets) do
							local count = fastAttack and spamCount or 1
							for i = 1, count do
								RequestHit:FireServer(t.Root.Position)
							end
						end
					else
						local t = targets[1]
						local count = fastAttack and spamCount or 1
						for i = 1, count do
							RequestHit:FireServer(t.Root.Position)
						end
					end
				end
			end)
		end
	end
end)

local AttachGroup = Tabs.Attach:AddLeftGroupbox("Attach")
AttachGroup:AddToggle("EnableAttach", { Text = "Enable Attach", Default = false })

Library.Toggles.EnableAttach:OnChanged(function()
	pcall(function()
		if not Library.Toggles.EnableAttach.Value then
			clearAttachVelocity(nil, true)
			setAttachState(false, true)
		end
	end)
end)
AttachGroup:AddDropdown("ApproachMode", { Text = "Approach Mode", Values = {"Velocity", "Teleport"}, Default = 1 })
AttachGroup:AddDropdown("RetargetCondition", { Text = "Retarget Condition", Values = {"Removed", "Dead"}, Default = 1 })
AttachGroup:AddToggle("WholeCategory", { Text = "Whole Category", Default = false })

AttachGroup:AddSlider("TweenSpeed", { Text = "Attach Speed", Default = 250, Min = 50, Max = 1200, Rounding = 0, Suffix = " studs/s" })

AttachGroup:AddLabel("Relative Offset")
AttachGroup:AddSlider("OffsetX", { Text = "Right / Left", Default = 0, Min = -50, Max = 50, Rounding = 0, Suffix = " studs" })
AttachGroup:AddSlider("OffsetY", { Text = "Up / Down", Default = 8, Min = -50, Max = 50, Rounding = 0, Suffix = " studs" })
AttachGroup:AddSlider("OffsetZ", { Text = "Forward / Back", Default = 0, Min = -50, Max = 50, Rounding = 0, Suffix = " studs" })

AttachGroup:AddButton("Reset Offsets To Default", function()
	Library.Options.OffsetX:SetValue(0)
	Library.Options.OffsetY:SetValue(8)
	Library.Options.OffsetZ:SetValue(0)
end)

local TargetGroup = Tabs.Attach:AddRightGroupbox("Attach Targets")
TargetGroup:AddDropdown("TargetCategory", { Text = "Target Category", Values = {"Players", "NPCs"}, Default = 1 })
TargetGroup:AddDropdown("AttachTargets", { Text = "Targets", Values = {"---"}, Default = 1, Multi = true })

local function refreshAttachTargets()
	pcall(function()
		local names = {}
		local found = {}
		local selectedTargets = Library.Options.AttachTargets and Library.Options.AttachTargets.Value or {}
		
		local category = Library.Options.TargetCategory and Library.Options.TargetCategory.Value or "Players"
		if category == "Players" then
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= LocalPlayer then
					if not found[p.Name] then
						found[p.Name] = true
						table.insert(names, p.Name)
					end
				end
			end
		elseif category == "NPCs" then
			local npcs = game:GetService("Workspace"):FindFirstChild("NPCs")
			if npcs then
				for _, npc in pairs(npcs:GetChildren()) do
					if npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChild("Humanoid") then
						if not found[npc.Name] then
							found[npc.Name] = true
							table.insert(names, npc.Name)
						end
					end
				end
			end
		end

		for name, enabled in pairs(selectedTargets) do
			if enabled and type(name) == "string" and name ~= "---" and not found[name] then
				found[name] = true
				table.insert(names, name)
			end
		end
		
		table.sort(names)
		if #names == 0 then table.insert(names, "---") end
		if Library.Options.AttachTargets then
			Library.Options.AttachTargets:SetValues(names)
		end
	end)
end

Library.Options.TargetCategory:OnChanged(function()
	refreshAttachTargets()
end)

refreshAttachTargets()

task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then
			break
		end

		refreshAttachTargets()
	end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 5)
		resetAttachTravelState()
		clearAttachVelocity()
		setAttachNoClipState(false)
		refreshWeaponOptions()
		setAntiKnockbackState(Library.Toggles.AntiKnockbackToggle and Library.Toggles.AntiKnockbackToggle.Value, hum)
		setAttachState(lastAttachState, true)
	end)
end)

getValidTarget = function()
	local lpChar = LocalPlayer.Character
	if not lpChar or not lpChar:FindFirstChild("HumanoidRootPart") then return nil end
	local lpPos = lpChar.HumanoidRootPart.Position

	-- 1. SEARCH FOR SELECTED BOSSES (TOP PRIORITY)
	if Library.Toggles.BossFarmToggle and Library.Toggles.BossFarmToggle.Value then
		local selectedBosses = Library.Options.BossFarmTargets.Value or {}

		local lockedTargetRoot = getLockedBossFarmTarget(selectedBosses)
		if lockedTargetRoot then
			return lockedTargetRoot
		end

		local bossCandidates = {}
		for id, boss in pairs(bosses) do
			if boss.isAlive and isBossSelectedForFarm(id, boss, selectedBosses) then
				local spawnPart = getBossPart(boss)
				local candidateDistance = spawnPart and (spawnPart.Position - lpPos).Magnitude or math.huge
				table.insert(bossCandidates, {
					Id = id,
					Boss = boss,
					Distance = candidateDistance,
				})
			end
		end

		table.sort(bossCandidates, function(a, b)
			if a.Distance ~= b.Distance then
				return a.Distance < b.Distance
			end
			return tostring(a.Boss.displayName or a.Id) < tostring(b.Boss.displayName or b.Id)
		end)

		for _, candidate in ipairs(bossCandidates) do
			local targetRoot = getBossFarmTargetRootById(candidate.Id)
			if targetRoot then
				lockedBossFarmId = candidate.Id
				return targetRoot
			end
		end

		lockedBossFarmId = nil
		-- FALL THROUGH to manual targets if no selected boss is alive
	else
		lockedBossFarmId = nil
	end

	-- 2. SEARCH FOR MANUAL TARGETS (FALLBACK)
	local category = Library.Options.TargetCategory.Value
	local targetName = Library.Options.AttachTargets.Value
	local wholeCat = Library.Toggles.WholeCategory.Value

	local bestTarget = nil
	local closestDist = math.huge

	local function checkEntity(entity)
		if entity == lpChar then return end
		local root = entity:FindFirstChild("HumanoidRootPart")
		local hum = entity:FindFirstChild("Humanoid")
		if root and hum and hum.Health > 0 then
			local isMatch = wholeCat
			if not isMatch then
				if type(targetName) == "table" then
					isMatch = targetName[entity.Name]
				elseif type(targetName) == "string" then
					isMatch = (entity.Name == targetName)
				end
			end

			if isMatch then
				local dist = (root.Position - lpPos).Magnitude
				if dist < closestDist then
					closestDist = dist
					bestTarget = root
				end
			end
		end
	end

	if category == "Players" then
		for _, p in pairs(Players:GetPlayers()) do
			if p.Character then checkEntity(p.Character) end
		end
	elseif category == "NPCs" then
		local npcs = workspace:FindFirstChild("NPCs")
		if npcs then
			for _, npc in pairs(npcs:GetChildren()) do
				checkEntity(npc)
			end
		end
	end

	return bestTarget
end

RunService.Heartbeat:Connect(function(dt)
	if Library.Unloaded then return end

	local manualAttach = Library.Toggles.EnableAttach and Library.Toggles.EnableAttach.Value
	local bossAutoAttach = Library.Toggles.BossFarmToggle
		and Library.Toggles.BossFarmToggle.Value
		and Library.Toggles.AutoConnectAttach
		and Library.Toggles.AutoConnectAttach.Value

	if not manualAttach and not bossAutoAttach then
		resetAttachTravelState()
		clearAttachVelocity()
		setAttachNoClipState(false)
		setAttachState(false)
		return
	end

	local targetRoot = getValidTarget()
	local attachActive = manualAttach or (bossAutoAttach and targetRoot ~= nil)
	local attachLocked = attachActive and targetRoot ~= nil
	if not targetRoot then
		resetAttachTravelState()
		clearAttachVelocity()
		setAttachNoClipState(false)
		setAttachState(false)
		return
	end

	if attachLocked then
		local lpChar = LocalPlayer.Character
		local lpRoot = lpChar and lpChar:FindFirstChild("HumanoidRootPart")

		if targetRoot and lpRoot then
			local goalCFrame = getAttachGoalCFrame(targetRoot, lpRoot)
			local isTimedBossAutoAttach = bossAutoAttach and isTimedBossTarget(targetRoot)
			local forceFinalVelocity = false
			if isTimedBossAutoAttach then
				if shouldPortalToTimedBoss(targetRoot, lpRoot) then
					clearAttachVelocity(lpRoot)
					setAttachNoClipState(false)
					setAttachState(false, true)
					return
				end
				goalCFrame = getBossTravelGoalCFrame(targetRoot, lpRoot, goalCFrame)
				local distanceToGoal = goalCFrame and (goalCFrame.Position - lpRoot.Position).Magnitude or math.huge
				forceFinalVelocity = distanceToGoal <= timedBossAttachFinalApproachDistance
				updateTimedBossUiVisibility(targetRoot)
			else
				resetAttachTravelState()
			end

			local useTeleport = bossAutoAttach or Library.Options.ApproachMode.Value == "Teleport"
			if isTimedBossAutoAttach and forceFinalVelocity then
				useTeleport = false
			end

			local distanceToGoal = goalCFrame and (goalCFrame.Position - lpRoot.Position).Magnitude or math.huge
			local shouldAnchor = attachLocked
			if isTimedBossAutoAttach and goalCFrame then
				shouldAnchor = shouldAnchorTimedBossAttach(targetRoot, lpRoot, goalCFrame)
			elseif not useTeleport then
				shouldAnchor = distanceToGoal <= timedBossAttachAnchorDistance
			end
			setAttachState(shouldAnchor)

			local shouldNoClip = goalCFrame
				and not useTeleport
				and not shouldAnchor
				and not lpRoot.Anchored
			setAttachNoClipState(shouldNoClip)

			if goalCFrame and useTeleport then
				pivotCharacter(goalCFrame, true)
			elseif goalCFrame and not shouldAnchor then
				local speed = forceFinalVelocity and timedBossAttachFinalTweenSpeed or math.max(1, Library.Options.TweenSpeed.Value)
				driveCharacterVelocity(goalCFrame, speed, dt)
			elseif goalCFrame then
				clearAttachVelocity(lpRoot)
				pivotCharacter(goalCFrame, distanceToGoal > 6)
			end
		else
			clearAttachVelocity(lpRoot)
			setAttachNoClipState(false)
		end
	else
		resetAttachTravelState()
		clearAttachVelocity()
		setAttachNoClipState(false)
		setAttachState(false)
	end
end)

task.spawn(function()
	task.wait(1)
	refreshWeaponOptions()

	local refreshCounter = 0
	while task.wait(0.25) do
		if Library.Unloaded then
			break
		end

		pcall(function()
			refreshCounter += 1
			if refreshCounter >= 4 then
				refreshCounter = 0
				refreshWeaponOptions()
			end

			if not (Library.Toggles.AutoReequipWeaponToggle and Library.Toggles.AutoReequipWeaponToggle.Value) then
				return
			end

			equipPreferredWeapon()
		end)
	end
end)

local AutoStatsGroup = Tabs.Combat:AddRightGroupbox("Auto Stats")
AutoStatsGroup:AddDropdown("AutoStatSelected", {
	Values = {"Melee", "Defense", "Sword", "Fruit"},
	Default = 1,
	Text = "Select Stat",
	Tooltip = "Stat to automatically upgrade"
})

AutoStatsGroup:AddToggle("AutoStatToggle", {
	Text = "Enable Auto Stats",
	Default = false,
	Tooltip = "Automatically allocates stat points"
})

task.spawn(function()
	while task.wait(0.25) do
		if Library.Unloaded then break end
		if Library.Toggles.AutoStatToggle and Library.Toggles.AutoStatToggle.Value then
			pcall(function()
				local player = LocalPlayer
				if tonumber(player.Data.StatPoints.Value) > 0 then
					local statToUpgrade = Library.Options.AutoStatSelected.Value
					local remotes = ReplicatedStorage:FindFirstChild("Remotes")
					local allocateRemote = remotes and remotes:FindFirstChild("AllocateStats")
					
					if allocateRemote then
						allocateRemote:FireServer(statToUpgrade, 1)
					end
				end
			end)
		end
	end
end)

local function uninject()
	setAntiKnockbackState(false)
	resetAttachTravelState()
	lockedBossFarmId = nil
	clearAttachVelocity(nil, true)
	setAttachNoClipState(false)
	setAttachState(false, true)
	Library:Unload()
end

local QuickActionsGroup = Tabs.Overview:AddLeftGroupbox("Session")
QuickActionsGroup:AddButton("Uninject", uninject)

local SettingsGroupbox = Tabs.Settings:AddLeftGroupbox("Settings")
SettingsGroupbox:AddButton("Uninject", uninject)

SettingsGroupbox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Library.Options.MenuKeybind 
