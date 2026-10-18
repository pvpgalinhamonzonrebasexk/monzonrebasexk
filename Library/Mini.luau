local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Carregamento do repositório de ícones
local success, Icons = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Assets/Icons.luau")
end)

local IconTable = {}
if success then
	local fn, err = loadstring(Icons)
	if fn then
		local res = fn()
		if type(res) == "table" then
			IconTable = res.assets or res
		end
	end
end

local Theme = {
	Panel = Color3.fromRGB(20, 20, 20),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(105, 105, 115),
	TitleText = Color3.fromRGB(255, 255, 255),
	Line = Color3.fromRGB(32, 32, 32)
}

local MinimizeIcon = "rbxassetid://9886659276"

-- Suporte Híbrido: Touch (Mobile) e Mouse (PC)
local function isPointerInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMoveInput(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function offsetPosition(startPos, delta)
	return UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local guiName = "DrawerMiniGui"

-- Limpeza de instâncias anteriores
local function cleanupExistingGuis(parent)
	if parent then
		local children = parent:GetChildren()
		for i = 1, #children do
			local child = children[i]
			if child:IsA("ScreenGui") and child.Name == guiName then
				child:Destroy()
			end
		end
	end
end

cleanupExistingGuis(gethui and gethui())
cleanupExistingGuis(game:GetService("CoreGui"))
cleanupExistingGuis(PlayerGui)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = guiName
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.IgnoreGuiInset = true

local parentTarget = (gethui and gethui()) or (syn and syn.protect_gui and syn.protect_gui(screenGui)) or game:GetService("CoreGui") or PlayerGui
screenGui.Parent = parentTarget

-- Sidebar Principal
local drawerFrame = Instance.new("Frame")
drawerFrame.Name = "DrawerSidebar"
drawerFrame.Size = UDim2.new(0, 330, 1, 0)
drawerFrame.Position = UDim2.new(1, -330, 0, 0)
drawerFrame.BackgroundColor3 = Theme.Panel
drawerFrame.BorderSizePixel = 0
drawerFrame.Parent = screenGui

-- Header / Topbar
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 60)
headerFrame.BackgroundColor3 = Theme.Panel
headerFrame.BorderSizePixel = 0
headerFrame.Parent = drawerFrame

local headerDivider = Instance.new("Frame")
headerDivider.Name = "HeaderDivider"
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.Position = UDim2.new(0, 0, 1, -1)
headerDivider.BackgroundColor3 = Theme.Line
headerDivider.BorderSizePixel = 0
headerDivider.Parent = headerFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -60, 0, 24)
titleLabel.Position = UDim2.new(0, 15, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Mini"
titleLabel.TextColor3 = Theme.TitleText
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "SubtitleLabel"
subtitleLabel.Size = UDim2.new(1, -60, 0, 18)
subtitleLabel.Position = UDim2.new(0, 15, 0, 32)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Painel Lateral"
subtitleLabel.TextColor3 = Theme.TextSecondary
subtitleLabel.TextSize = 13
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = headerFrame

local closeBtn = Instance.new("ImageButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -35, 0, 18)
closeBtn.BackgroundTransparency = 1
closeBtn.Image = MinimizeIcon
closeBtn.ImageColor3 = Theme.TextPrimary
closeBtn.AutoButtonColor = false
closeBtn.Parent = headerFrame

-- Área de Conteúdo
local mainContentArea = Instance.new("Frame")
mainContentArea.Name = "MainContentArea"
mainContentArea.Size = UDim2.new(1, 0, 1, -125)
mainContentArea.Position = UDim2.new(0, 0, 0, 60)
mainContentArea.BackgroundTransparency = 1
mainContentArea.BorderSizePixel = 0
mainContentArea.Parent = drawerFrame

-- Linha Divisória Inferior
local lineDivider = Instance.new("Frame")
lineDivider.Name = "Divider"
lineDivider.Size = UDim2.new(1, 0, 0, 1)
lineDivider.Position = UDim2.new(0, 0, 1, -65)
lineDivider.BackgroundColor3 = Theme.Line
lineDivider.BorderSizePixel = 0
lineDivider.Parent = drawerFrame

-- Contêiner Horizontal de Tabs (Scrolling)
local tabContainer = Instance.new("ScrollingFrame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, 0, 0, 64)
tabContainer.Position = UDim2.new(0, 0, 1, -64)
tabContainer.BackgroundTransparency = 1
tabContainer.BorderSizePixel = 0
tabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
tabContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
tabContainer.ScrollingDirection = Enum.ScrollingDirection.X
tabContainer.ScrollBarThickness = 3
tabContainer.ScrollBarImageColor3 = Theme.Line
tabContainer.Active = true
tabContainer.Parent = drawerFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabContainer

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft = UDim.new(0, 10)
tabPadding.PaddingRight = UDim.new(0, 10)
tabPadding.PaddingTop = UDim.new(0, 6)
tabPadding.PaddingBottom = UDim.new(0, 6)
tabPadding.Parent = tabContainer

local activeCard = nil
local activeTabButton = nil

-- Mensagem de aviso caso não haja conteúdo na aba selecionada
local function showEmptyNotice()
	mainContentArea:ClearAllChildren()

	local noticeFrame = Instance.new("Frame")
	noticeFrame.Name = "NoticeFrame"
	noticeFrame.Size = UDim2.new(1, -40, 0, 100)
	noticeFrame.Position = UDim2.new(0.5, -135, 0.5, -50)
	noticeFrame.BackgroundTransparency = 1
	noticeFrame.Parent = mainContentArea

	local noticeLayout = Instance.new("UIListLayout")
	noticeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	noticeLayout.FillDirection = Enum.FillDirection.Vertical
	noticeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	noticeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	noticeLayout.Padding = UDim.new(0, 8)
	noticeLayout.Parent = noticeFrame

	local warningIconAsset = IconTable["lucide-alert-circle"] or "rbxassetid://10709752996"
	local warnIcon = Instance.new("ImageLabel")
	warnIcon.Name = "WarningIcon"
	warnIcon.Size = UDim2.new(0, 36, 0, 36)
	warnIcon.BackgroundTransparency = 1
	warnIcon.Image = warningIconAsset
	warnIcon.ImageColor3 = Theme.TextSecondary
	warnIcon.Parent = noticeFrame

	local warnText = Instance.new("TextLabel")
	warnText.Name = "WarningText"
	warnText.Size = UDim2.new(1, 0, 0, 20)
	warnText.BackgroundTransparency = 1
	warnText.Text = "Não tem nadinha por aqui"
	warnText.TextColor3 = Theme.TextSecondary
	warnText.TextSize = 13
	warnText.Font = Enum.Font.GothamMedium
	warnText.TextXAlignment = Enum.TextXAlignment.Center
	warnText.Parent = noticeFrame
end

local function showTabContent(nameText, descText, cardBtn)
	if activeCard == cardBtn then
		activeCard = nil
		if activeTabButton then
			TweenService:Create(activeTabButton, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 48, 0, 48)}):Play()
			local tc = activeTabButton:FindFirstChild("TextContainer")
			if tc then tc.Visible = false end
		end
		activeTabButton = nil
		mainContentArea:ClearAllChildren()
		return
	end

	if activeTabButton then
		TweenService:Create(activeTabButton, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 48, 0, 48)}):Play()
		local tc = activeTabButton:FindFirstChild("TextContainer")
		if tc then tc.Visible = false end
	end

	activeCard = cardBtn
	activeTabButton = cardBtn

	TweenService:Create(cardBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 160, 0, 48)}):Play()
	local newTc = cardBtn:FindFirstChild("TextContainer")
	if newTc then newTc.Visible = true end

	showEmptyNotice()
end

local function createTabCard(nameText, descText, iconKey)
	local card = Instance.new("TextButton")
	card.Name = "TabCard"
	card.Size = UDim2.new(0, 48, 0, 48)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.ClipsDescendants = true
	card.Parent = tabContainer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Theme.Line
	cardStroke.Thickness = 1
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = card

	local iconAsset = ""
	if iconKey then
		if IconTable[iconKey] then
			iconAsset = IconTable[iconKey]
		elseif type(iconKey) == "string" and (iconKey:match("^rbxassetid://") or iconKey:match("^http")) then
			iconAsset = iconKey
		end
	end

	if iconAsset ~= "" then
		local iconImg = Instance.new("ImageLabel")
		iconImg.Name = "Icon"
		iconImg.Size = UDim2.new(0, 22, 0, 22)
		iconImg.Position = UDim2.new(0, 13, 0.5, -11)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = iconAsset
		iconImg.ImageColor3 = Theme.TextPrimary
		iconImg.Parent = card
	end

	local textContainer = Instance.new("Frame")
	textContainer.Name = "TextContainer"
	textContainer.Size = UDim2.new(0, 110, 1, 0)
	textContainer.Position = UDim2.new(0, 44, 0, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.Visible = false
	textContainer.Parent = card

	local titleLabelText = Instance.new("TextLabel")
	titleLabelText.Name = "Title"
	titleLabelText.Size = UDim2.new(1, -5, 0, 18)
	titleLabelText.Position = UDim2.new(0, 0, 0, 7)
	titleLabelText.BackgroundTransparency = 1
	titleLabelText.Text = nameText
	titleLabelText.TextColor3 = Theme.TextPrimary
	titleLabelText.TextSize = 12
	titleLabelText.Font = Enum.Font.GothamBold
	titleLabelText.TextXAlignment = Enum.TextXAlignment.Left
	titleLabelText.Parent = textContainer

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -5, 0, 18)
	descLabel.Position = UDim2.new(0, 0, 0, 23)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Theme.TextSecondary
	descLabel.TextSize = 9
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = textContainer

	card.MouseButton1Click:Connect(function()
		showTabContent(nameText, descText, card)
	end)
end

-- Criando as 11 abas
createTabCard("Home", "Início e funções principais.", "lucide-home")
createTabCard("Combat", "Ajustes de combate e pvp.", "lucide-swords")
createTabCard("Player", "Modificadores do jogador.", "lucide-user")
createTabCard("Visuals", "Funções de visão e ESP.", "lucide-eye")
createTabCard("Movement", "Velocidade e pulo estendido.", "lucide-zap")
createTabCard("Teleport", "Locais e marcadores de mapa.", "lucide-map-pin")
createTabCard("Shop", "Itens e compras rápidas.", "lucide-shopping-cart")
createTabCard("Stats", "Estatísticas em tempo real.", "lucide-activity")
createTabCard("Scripts", "Execução de rotinas locais.", "lucide-code")
createTabCard("Configs", "Perfis e salvar definições.", "lucide-file-text")
createTabCard("Settings", "Ajustes e definições gerais.", "lucide-settings")

-- Botão Flutuante Móvel (Drag & Toggle)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 48, 0, 48)
toggleButton.Position = UDim2.new(0, 20, 0.5, -24)
toggleButton.BackgroundColor3 = Theme.Panel
toggleButton.BorderSizePixel = 0
toggleButton.Text = ""
toggleButton.AutoButtonColor = false
toggleButton.ClipsDescendants = true
toggleButton.Visible = false
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Theme.Line
toggleStroke.Thickness = 1.5
toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
toggleStroke.Parent = toggleButton

local texture = Instance.new("ImageLabel")
texture.Name = "Texture"
texture.Size = UDim2.new(1, 0, 1, 0)
texture.Position = UDim2.new(0.5, 0, 0.5, 0)
texture.AnchorPoint = Vector2.new(0.5, 0.5)
texture.BackgroundTransparency = 1
texture.Image = "rbxassetid://77526194033506"
texture.ImageTransparency = 0.3
texture.ScaleType = Enum.ScaleType.Crop
texture.ZIndex = 1
texture.Parent = toggleButton

local textureCorner = Instance.new("UICorner")
textureCorner.CornerRadius = UDim.new(0, 10)
textureCorner.Parent = texture

-- Lógica de Animação e Minimização Estável (Sem bugs nem flicker)
local isOpen = true
local isAnimating = false
local currentTween = nil
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function setToggleState(state)
	if isAnimating and isOpen == state then return end
	isOpen = state
	isAnimating = true

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	if isOpen then
		toggleButton.Visible = false
		drawerFrame.Visible = true
		currentTween = TweenService:Create(drawerFrame, tweenInfo, {Position = UDim2.new(1, -330, 0, 0)})
		currentTween:Play()
		currentTween.Completed:Connect(function()
			isAnimating = false
		end)
	else
		toggleButton.Visible = true
		currentTween = TweenService:Create(drawerFrame, tweenInfo, {Position = UDim2.new(1, 0, 0, 0)})
		currentTween:Play()
		currentTween.Completed:Connect(function()
			if not isOpen then
				drawerFrame.Visible = false
			end
			isAnimating = false
		end)
	end
end

closeBtn.MouseButton1Click:Connect(function()
	setToggleState(false)
end)

-- Sistema de Drag para Mobile Touch e PC Mouse no botão de alternância
local isActualDrag = false
local dragStart = Vector3.zero
local startPosition = toggleButton.Position
local moveConnection = nil
local endConnection = nil

local function stopTracking()
	if moveConnection then
		moveConnection:Disconnect()
		moveConnection = nil
	end
	if endConnection then
		endConnection:Disconnect()
		endConnection = nil
	end
end

toggleButton.InputBegan:Connect(function(input)
	if not isPointerInput(input) then
		return
	end
	isActualDrag = false
	dragStart = input.Position
	startPosition = toggleButton.Position
	stopTracking()

	moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
		if not isMoveInput(moveInput) then
			return
		end
		local delta = moveInput.Position - dragStart
		if delta.Magnitude > 7 then
			isActualDrag = true
		end
		if isActualDrag then
			toggleButton.Position = offsetPosition(startPosition, delta)
		end
	end)

	endConnection = UserInputService.InputEnded:Connect(function(endInput)
		if not isPointerInput(endInput) then
			return
		end
		stopTracking()
		if not isActualDrag then
			setToggleState(true)
		end
		isActualDrag = false
	end)
end)