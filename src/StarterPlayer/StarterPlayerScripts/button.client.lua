local UIS = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

UIS.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.V and not gameProcessedEvent then
        game:GetService("ReplicatedStorage").Pathfind:FireServer()
    elseif input.KeyCode == Enum.KeyCode.B and not gameProcessedEvent then
        game:GetService("ReplicatedStorage").Move:FireServer(player:GetMouse().Hit.Position + Vector3.new(0,2,0)) 
    end
end)