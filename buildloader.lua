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

return {
    LoadBuild = function(_, buildTable, SyncAPI)
        local window = Terminal:Window("ziec's scp: rp build loader")
        window:Log({ Color = Color3.new(1,1,1), Content = "Attempting to initalize." })
        
        -- SYNCAPI CHECK
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)
        
        if not ok then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[FATAL ERROR] SyncAPI blocked or invalid, do you have Building Tools?" })
            window:Complete()
            return
        end
        
        -- COUNT PARTS
        local total = 0
        for _ in pairs(buildTable) do
            total = total + 1
        end
        
        if total == 0 then
            window:Log({ Color = Color3.fromRGB(255,120,120), Content = "[WARN] Nothing to build." })
            window:Complete()
            return
        end
        
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "[INFO] Parts to build: "..total })
        
        -- CREATE PARTS, MESHES, UNIONS, LIGHTS WITH PROPER ORDERING
        local createdParts = {}
        local orderedIndices = {}
        
        -- First pass: collect all indices
        for index in pairs(buildTable) do
            table.insert(orderedIndices, index)
        end
        table.sort(orderedIndices)
        
        -- Second pass: create parts in order
        for _, index in ipairs(orderedIndices) do
            local data = buildTable[index]
            local part = nil
            local partType = data.type or data.shape or "Block"
            
            local success, result = pcall(function()
                if partType == "UnionOperation" then
                    -- Correct union creation
                    part = SyncAPI:InvokeServer("CreateUnion", data.unionData or {}, Workspace)
                    if part then
                        part.CFrame = CFrame.new(unpack(data.cframe or {0,0,0}))
                    end
                    
                elseif partType == "MeshPart" or (data.mesh and data.mesh.meshtype) then
                    -- Correct mesh part creation
                    local meshData = data.mesh or {}
                    local cf = data.cframe or {0,0,0}
                    
                    -- Ensure proper mesh data structure
                    local createData = {
                        meshtype = meshData.meshtype or Enum.MeshType.Head,
                        scale = meshData.scale or {1,1,1},
                        offset = meshData.offset or {0,0,0},
                        vertexcolor = meshData.vertexcolor or {1,1,1},
                        texture = meshData.texture or ""
                    }
                    
                    if meshData.meshtype == Enum.MeshType.FileMesh and meshData.meshid then
                        createData.meshid = meshData.meshid
                    end
                    
                    part = SyncAPI:InvokeServer("CreateMeshPart", createData, CFrame.new(unpack(cf)), Workspace)
                    
                elseif partType == "Light" then
                    -- Light creation
                    local lightType = data.lightType or "PointLight"
                    if lightType == "SpotLight" then
                        part = Instance.new("SpotLight")
                    elseif lightType == "SurfaceLight" then
                        part = Instance.new("SurfaceLight")
                    else
                        part = Instance.new("PointLight")
                    end
                    
                    part.Parent = Workspace
                    part.CFrame = CFrame.new(unpack(data.cframe or {0,0,0}))
                    part.Color = Color3.fromRGB(unpack(data.color or {255,255,255}))
                    part.Brightness = data.brightness or 1
                    part.Range = data.range or 15
                    part.Shadows = data.shadows or false
                    
                    if lightType == "SpotLight" then
                        part.Angle = data.angle or 45
                        part.Face = Enum.NormalId[data.face or "Front"] or Enum.NormalId.Front
                    end
                    
                else
                    -- Regular part creation
                    local shapeType = "Normal"
                    if partType == "Wedge" then shapeType = "Wedge"
                    elseif partType == "CornerWedge" then shapeType = "CornerWedge"
                    elseif partType == "Cylinder" then shapeType = "Cylinder"
                    elseif partType == "Ball" then shapeType = "Ball"
                    end
                    
                    part = SyncAPI:InvokeServer("CreatePart", shapeType, 
                        CFrame.new(unpack(data.cframe or {0,0,0})), Workspace)
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
                    Color = Color3.fromRGB(255,120,120), 
                    Content = "[WARNING] Failed to create "..partType.." at index "..tostring(index)..": "..tostring(result) 
                })
            end
            
            task.wait(0.01) -- Prevent rate limiting
        end
        
        -- BATCH PROPERTY SYNC WITH CORRECT DATA STRUCTURES
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
            SyncMesh = {},
            Lights = {}
        }
        
        for index, data in pairs(buildTable) do
            local part = createdParts[index]
            if not part then continue end
            
            -- Handle BaseParts, MeshParts, and UnionOperations
            if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
                -- Color
                if data.color then
                    table.insert(ops.Colors, {
                        Part = part,
                        Color = Color3.fromRGB(unpack(data.color)),
                        UnionColoring = true
                    })
                end
                
                -- Size/Resize
                if data.size then
                    table.insert(ops.Resize, {
                        Part = part,
                        Size = Vector3.new(unpack(data.size)),
                        CFrame = CFrame.new(unpack(data.cframe or {0,0,0}))
                    })
                end
                
                -- Material properties
                if data.texture or data.transparency or data.reflectance then
                    table.insert(ops.Material, {
                        Part = part,
                        Material = data.texture or Enum.Material.Plastic,
                        Transparency = data.transparency or 0,
                        Reflectance = data.reflectance or 0
                    })
                end
                
                -- Rotation
                table.insert(ops.Rotate, {
                    Part = part,
                    CFrame = CFrame.new(unpack(data.cframe or {0,0,0}))
                })
                
                -- Anchor
                table.insert(ops.Anchor, {
                    Part = part,
                    Anchored = data.anchored ~= false -- Default to true if not specified
                })
                
                -- Locked
                table.insert(ops.Locked, part)
                
                -- Collision
                table.insert(ops.Collision, {
                    Part = part,
                    CanCollide = data.cancollide ~= false -- Default to true
                })
                
                -- Surfaces
                if data.surface then
                    table.insert(ops.Surface, {
                        Part = part,
                        Surfaces = data.surface
                    })
                end
                
                -- Decals
                if data.decal then
                    -- Create decal
                    table.insert(ops.Decal, {
                        Part = part,
                        Face = data.decal.face or "Top",
                        TextureType = "Decal"
                    })
                    
                    -- Sync decal properties
                    table.insert(ops.SyncDecal, {
                        Part = part,
                        Face = data.decal.face or "Top",
                        Texture = data.decal.texture or "",
                        Transparency = data.decal.transparency or 0,
                        TextureType = "Decal"
                    })
                end
                
                -- Meshes
                if data.mesh then
                    -- Create mesh
                    table.insert(ops.Mesh, { Part = part })
                    
                    -- Sync mesh properties
                    local meshOp = {
                        Part = part,
                        TextureId = data.mesh.texture or "",
                        VertexColor = Vector3.new(unpack(data.mesh.vertexcolor or {1,1,1})),
                        MeshType = data.mesh.meshtype or Enum.MeshType.Head,
                        Scale = Vector3.new(unpack(data.mesh.scale or {1,1,1})),
                        Offset = Vector3.new(unpack(data.mesh.offset or {0,0,0})),
                    }
                    
                    if data.mesh.meshtype == Enum.MeshType.FileMesh and data.mesh.meshid then
                        meshOp.MeshId = data.mesh.meshid
                    end
                    
                    table.insert(ops.SyncMesh, meshOp)
                end
                
            -- Handle Lights
            elseif part:IsA("Light") then
                table.insert(ops.Lights, {
                    Light = part,
                    Color = Color3.fromRGB(unpack(data.color or {255,255,255})),
                    Brightness = data.brightness or 1,
                    Range = data.range or 15,
                    Shadows = data.shadows or false
                })
            end
        end
        
        -- EXECUTE BATCH SYNC WITH ERROR HANDLING
        -- Fixed: Removed varargs from safeSync function
        local function safeSync(operation, funcName, args)
            local success, err = pcall(function()
                SyncAPI:InvokeServer(funcName, args)
            end)
            if not success then
                window:Log({ 
                    Color = Color3.fromRGB(255,165,0), 
                    Content = "[WARNING] Failed operation: "..operation..": "..tostring(err) 
                })
            end
        end
        
        -- Execute sync operations in logical order
        if #ops.Colors > 0 then
            safeSync("colors", "SyncColor", ops.Colors)
        end
        
        if #ops.Resize > 0 then
            safeSync("resize", "SyncResize", ops.Resize)
        end
        
        if #ops.Surface > 0 then
            safeSync("surfaces", "SyncSurface", ops.Surface)
        end
        
        if #ops.Material > 0 then
            safeSync("materials", "SyncMaterial", ops.Material)
        end
        
        if #ops.Rotate > 0 then
            safeSync("rotation", "SyncRotate", ops.Rotate)
        end
        
        if #ops.Anchor > 0 then
            safeSync("anchoring", "SyncAnchor", ops.Anchor)
        end
        
        if #ops.Locked > 0 then
            safeSync("locking", "SetLocked", ops.Locked, true)
        end
        
        if #ops.Collision > 0 then
            safeSync("collision", "SyncCollision", ops.Collision)
        end
        
        if #ops.Decal > 0 then
            safeSync("decal creation", "CreateTextures", ops.Decal)
        end
        
        if #ops.SyncDecal > 0 then
            safeSync("decal sync", "SyncTexture", ops.SyncDecal)
        end
        
        if #ops.Mesh > 0 then
            safeSync("mesh creation", "CreateMeshes", ops.Mesh)
        end
        
        if #ops.SyncMesh > 0 then
            safeSync("mesh sync", "SyncMesh", ops.SyncMesh)
        end
        
        -- Apply light properties (no sync needed - these are local)
        for _, lightData in pairs(ops.Lights) do
            local light = lightData.Light
            light.Color = lightData.Color
            light.Brightness = lightData.Brightness
            light.Range = lightData.Range
            light.Shadows = lightData.Shadows
        end
        
        window:Log({ 
            Color = Color3.fromRGB(84,255,84), 
            Content = "The operation was successfully completed. Created "..#orderedIndices.." elements." 
        })
        
        window:Complete()
        
        -- Return created parts for further manipulation
        return createdParts
    end
}
