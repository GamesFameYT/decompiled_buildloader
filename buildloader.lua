-- filename: BuildLoader.lua
-- version: lua51
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local Terminal = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/SkireScripts/F3X-Panel/main/Terminal.lua")
)()

-- ONLY ADDITION: force mesh scale so meshes don't take the whole map
local FORCED_MESH_SCALE = Vector3.new(0.01, 0.12, 0.01)

return {
    LoadBuild = function(_, buildTable, SyncAPI)
        local window = Terminal:Window("ziec's scp: rp build loader")
        window:Log({ Color = Color3.new(1,1,1), Content = "Intializing . . ." })
        
        -- SYNCAPI CHECK
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)
        
        if not ok then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[FATAL] SyncAPI is invalid, do you have Building Tools?" })
            window:Complete()
            return
        end
        
        -- COUNT PARTS
        local total = #buildTable

        window:Log({ Color = Color3.new(200,200,200), Content = "[INFO] Reading build data . . ." })
        wait(0.6)
        
        if total == 0 then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[ERROR] Invalid build data or there is nothing to build." })
            window:Complete()
            return
        end
        
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "[INFO] Parts to build: "..total })
        
        local createdParts = {}
        
        for index, data in ipairs(buildTable) do
            local part = nil
            local partType = data.type or data.shape or "Block"
            
            local success, result = pcall(function()
                local cf
                if data.cframe then
                    cf = CFrame.new(unpack(data.cframe))
                elseif data.position then
                    cf = CFrame.new(unpack(data.position))
                else
                    cf = CFrame.new(0,0,0)
                end
                
                if partType == "UnionOperation" then
                    local unionData = data.unionData or data.AssetId
                    
                    if unionData then
                        local ok2, res = pcall(function()
                            return SyncAPI:InvokeServer("CreateUnion", unionData, Workspace)
                        end)
                        if ok2 and res then
                            part = res
                            part.CFrame = cf
                            return
                        end
                    end
                    
                    part = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                    
                elseif partType == "MeshPart" or (data.mesh and data.mesh.meshid and data.mesh.meshid ~= "") then
                    local meshData = data.mesh or {}
                    local meshId = meshData.meshid or meshData.MeshId or ""
                    local textureId = meshData.texture or meshData.TextureId or ""
                    local offset = meshData.offset or meshData.Offset or {0,0,0}
                    local vertexColor = meshData.vertexcolor or meshData.VertexColor or {1,1,1}
                    
                    local ok2, res = pcall(function()
                        local tempPart = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                        if not tempPart then return end
                        
                        SyncAPI:InvokeServer("CreateMeshes", {{ Part = tempPart }})
                        SyncAPI:InvokeServer("SyncMesh", {{
                            Part = tempPart,
                            MeshType = Enum.MeshType.FileMesh,
                            MeshId = meshId,
                            TextureId = textureId,
                            Scale = FORCED_MESH_SCALE,
                            Offset = Vector3.new(unpack(offset)),
                            VertexColor = Vector3.new(unpack(vertexColor))
                        }})
                        
                        return tempPart
                    end)
                    
                    if ok2 and res then
                        part = res
                    else
                        part = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                    end
                    
                else
                    local shapeType = "Normal"
                    local shape = data.shape or "Block"
                    
                    if shape == "Wedge" then
                        shapeType = "Wedge"
                    elseif shape == "Corner" or shape == "CornerWedge" then
                        shapeType = "CornerWedge"
                    elseif shape == "Cylinder" then
                        shapeType = "Cylinder"
                    elseif shape == "Ball" or shape == "Sphere" then
                        shapeType = "Ball"
                    end
                    
                    part = SyncAPI:InvokeServer("CreatePart", shapeType, cf, Workspace)
                end
            end)
            
            if success and part then
                createdParts[index] = part
                window:Log({
                    Color = Color3.fromRGB(120,255,120),
                    Content = "Element created: "..partType.." (#"..index..")"
                })
            else
                window:Log({
                    Color = Color3.fromRGB(153,153,0),
                    Content = "[WARN] Failed to create "..partType.." at index "..tostring(index)..": "..tostring(result)
                })
            end
            
            task.wait(0.01)
        end
        
        window:Log({ Color = Color3.new(1,1,1), Content = "[INFO] Attempting to apply properties..." })
        
        local ops = {
            Colors = {},
            Resize = {},
            Surface = {},
            Material = {},
            Rotate = {},
            Anchor = {},
            Locked = {},
            Collision = {},
            Decal = {},
            SyncDecal = {},
            Mesh = {},
            SyncMesh = {}
        }
        
        for index, data in ipairs(buildTable) do
            local part = createdParts[index]
            if not part then continue end
            
            if part:IsA("BasePart") then
                if data.color then
                    table.insert(ops.Colors, {
                        Part = part,
                        Color = Color3.fromRGB(unpack(data.color)),
                        UnionColoring = true
                    })
                end
                
                if data.size then
                    table.insert(ops.Resize, {
                        Part = part,
                        Size = Vector3.new(unpack(data.size)),
                        CFrame = part.CFrame
                    })
                end
                
                if data.texture or data.material or data.transparency or data.reflectance then
                    local material = Enum.Material.Plastic
                    if data.texture and Enum.Material[data.texture] then
                        material = Enum.Material[data.texture]
                    elseif data.material then
                        material = data.material
                    end
                    
                    table.insert(ops.Material, {
                        Part = part,
                        Material = material,
                        Transparency = data.transparency or 0,
                        Reflectance = data.reflectance or 0
                    })
                end
                
                table.insert(ops.Rotate, { Part = part, CFrame = part.CFrame })
                table.insert(ops.Anchor, { Part = part, Anchored = data.anchored ~= false })
                table.insert(ops.Collision, { Part = part, CanCollide = data.cancollide ~= false })
                
                if data.locked ~= false then
                    table.insert(ops.Locked, part)
                end
                
                if data.mesh and not (data.type == "MeshPart") and not part:FindFirstChildOfClass("SpecialMesh") then
                    table.insert(ops.Mesh, { Part = part })
                    
                    table.insert(ops.SyncMesh, {
                        Part = part,
                        MeshType = data.mesh.meshtype or Enum.MeshType.FileMesh,
                        MeshId = data.mesh.meshid or "",
                        TextureId = data.mesh.texture or "",
                        Scale = FORCED_MESH_SCALE,
                        Offset = Vector3.new(unpack(data.mesh.offset or {0,0,0})),
                        VertexColor = Vector3.new(unpack(data.mesh.vertexcolor or {1,1,1}))
                    })
                end
            end
        end
        
        local function safeSync(_, funcName, args)
            pcall(function()
                SyncAPI:InvokeServer(funcName, args)
            end)
        end
        
        if #ops.Colors > 0 then safeSync("colors", "SyncColor", ops.Colors) end
        if #ops.Resize > 0 then safeSync("resize", "SyncResize", ops.Resize) end
        if #ops.Surface > 0 then safeSync("surface", "SyncSurface", ops.Surface) end
        if #ops.Material > 0 then safeSync("material", "SyncMaterial", ops.Material) end
        if #ops.Rotate > 0 then safeSync("rotate", "SyncRotate", ops.Rotate) end
        if #ops.Anchor > 0 then safeSync("anchor", "SyncAnchor", ops.Anchor) end
        if #ops.Locked > 0 then safeSync("locked", "SetLocked", ops.Locked) end
        if #ops.Collision > 0 then safeSync("collision", "SyncCollision", ops.Collision) end
        if #ops.Decal > 0 then safeSync("decal", "CreateTextures", ops.Decal) end
        if #ops.SyncDecal > 0 then safeSync("decalSync", "SyncTexture", ops.SyncDecal) end
        if #ops.Mesh > 0 then safeSync("mesh", "CreateMeshes", ops.Mesh) end
        if #ops.SyncMesh > 0 then safeSync("meshSync", "SyncMesh", ops.SyncMesh) end
        
        window:Log({
            Color = Color3.fromRGB(84,255,84),
            Content = "The operation was successfully completed. Created "..total.." elements."
        })
        
        window:Complete()
        return createdParts
    end
}
