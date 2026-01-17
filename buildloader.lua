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
        window:Log({ Color = Color3.new(1,1,1), Content = "Initalizing . . ." })
        
        -- SYNCAPI CHECK
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)
        
        if not ok then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[FATAL ERROR] SyncAPI invalid, do you have Building Tools?" })
            window:Complete()
            return
        end

        window:Log({ Color = Color3.new(1,1,1), Content = "[INFO] Reading build data . . ." })
        task.wait(0.6)
        -- COUNT PARTS
        local total = #buildTable
        
        if total == 0 then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[ERR] The build data is incorrect or does not have any valid elements." })
            window:Complete()
            return
        end
        
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "[INFO] Parts to place: "..total })
        
        -- CREATE PARTS, MESHES, UNIONS, LIGHTS WITH PROPER ORDERING
        local createdParts = {}
        
        -- Process each part in order
        for index, data in ipairs(buildTable) do
            local part = nil
            local partType = data.type or data.shape or "Block"
            
            local success, result = pcall(function()
                -- Determine CFrame from either position or cframe data
                local cf
                if data.cframe then
                    cf = CFrame.new(unpack(data.cframe))
                elseif data.position then
                    cf = CFrame.new(unpack(data.position))
                else
                    cf = CFrame.new(0, 0, 0)
                end
                
                if partType == "UnionOperation" then
                    -- Union creation with proper error handling
                    local unionData = data.unionData or data.AssetId
                    
                    if not unionData then
                        window:Log({ 
                            Color = Color3.fromRGB(255,165,0), 
                            Content = "[WARN] Union at index "..index.." was missing the correct union data, it has been created as a Part instead" 
                        })
                        
                        -- Fallback to Part
                        part = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                        
                        return
                    end
                    
                    -- Try to create union
                    local unionSuccess, unionResult = pcall(function()
                        return SyncAPI:InvokeServer("CreateUnion", unionData, Workspace)
                    end)
                    
                    if unionSuccess and unionResult then
                        part = unionResult
                        part.CFrame = cf
                    else
                        window:Log({ 
                            Color = Color3.fromRGB(255,165,0), 
                            Content = "[WARN] Failed to create union element at index "..index..", A part was created instead." 
                        })
                        
                        -- Fallback to Part
                        part = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                    end
                    
                elseif partType == "MeshPart" or (data.mesh and data.mesh.meshid and data.mesh.meshid ~= "") then
                    -- MeshPart creation with proper data extraction
                    local meshData = data.mesh or {}
                    
                    -- Extract mesh properties
                    local meshId = meshData.meshid or meshData.MeshId or ""
                    local textureId = meshData.texture or meshData.TextureId or ""
                    local scale = meshData.scale or meshData.Scale or {1,1,1}
                    local offset = meshData.offset or meshData.Offset or {0,0,0}
                    local vertexColor = meshData.vertexcolor or meshData.VertexColor or {1,1,1}
                    
                    -- Try to create MeshPart using F3X's CreateMeshPart
                    local meshSuccess, meshResult = pcall(function()
                        -- For MeshParts from the converter, we need to handle them specially
                        if partType == "MeshPart" then
                            -- Create a regular part first
                            local tempPart = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                            
                            if tempPart then
                                -- Add SpecialMesh to it
                                local meshOp = {
                                    Part = tempPart,
                                    MeshType = Enum.MeshType.FileMesh,
                                    MeshId = meshId,
                                    TextureId = textureId,
                                    Scale = Vector3.new(unpack(scale)),
                                    Offset = Vector3.new(unpack(offset)),
                                    VertexColor = Vector3.new(unpack(vertexColor))
                                }
                                
                                -- Create mesh
                                SyncAPI:InvokeServer("CreateMeshes", {{Part = tempPart}})
                                -- Sync mesh properties
                                SyncAPI:InvokeServer("SyncMesh", {meshOp})
                                
                                return tempPart
                            end
                        else
                            -- Regular mesh handling
                            local createData = {
                                meshtype = Enum.MeshType.FileMesh,
                                meshid = meshId,
                                texture = textureId,
                                scale = scale,
                                offset = offset,
                                vertexcolor = vertexColor
                            }
                            
                            return SyncAPI:InvokeServer("CreateMeshPart", createData, cf, Workspace)
                        end
                    end)
                    
                    if meshSuccess and meshResult then
                        part = meshResult
                    else
                        window:Log({ 
                            Color = Color3.fromRGB(255,165,0), 
                            Content = "[WARN] Unable to create filemesh at index "..index..", it has been replaced with SpecialMesh" 
                        })
                        
                        -- Fallback: Create Part with SpecialMesh
                        part = SyncAPI:InvokeServer("CreatePart", "Normal", cf, Workspace)
                        
                        if part and meshId ~= "" then
                            -- Add mesh to the part
                            pcall(function()
                                SyncAPI:InvokeServer("CreateMeshes", {{Part = part}})
                                SyncAPI:InvokeServer("SyncMesh", {{
                                    Part = part,
                                    MeshType = Enum.MeshType.FileMesh,
                                    MeshId = meshId,
                                    TextureId = textureId,
                                    Scale = Vector3.new(unpack(scale)),
                                    Offset = Vector3.new(unpack(offset)),
                                    VertexColor = Vector3.new(unpack(vertexColor))
                                }})
                            end)
                        end
                    end
                    
                else
                    -- Regular part creation
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
                    elseif shape == "Spawn" or shape == "SpawnLocation" then
                        shapeType = "Normal" -- Spawn is just a normal block
                    end
                    
                    part = SyncAPI:InvokeServer("CreatePart", shapeType, cf, Workspace)
                end
            end)
            
            if success and part then
                createdParts[index] = part
                window:Log({ 
                    Color = Color3.fromRGB(120,255,120), 
                    Content = "Created element part "..partType.." (#"..index..")" 
                })
            else
                window:Log({ 
                    Color = Color3.fromRGB(255,120,120), 
                    Content = "[WARNING] Failed to create part "..partType.." at index "..tostring(index)..": "..tostring(result) 
                })
            end
            
            task.wait(0.01) -- Prevent rate limiting
        end
        
        -- BATCH PROPERTY SYNC WITH CORRECT DATA STRUCTURES
        window:Log({ Color = Color3.new(1,1,1), Content = "[INFO] applying properties to created elements..." })
        
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
            
            -- Handle all BaseParts
            if part:IsA("BasePart") then
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
                    local cf
                    if data.cframe then
                        cf = CFrame.new(unpack(data.cframe))
                    elseif data.position then
                        cf = CFrame.new(unpack(data.position))
                    else
                        cf = part.CFrame
                    end
                    
                    table.insert(ops.Resize, {
                        Part = part,
                        Size = Vector3.new(unpack(data.size)),
                        CFrame = cf
                    })
                end
                
                -- Material properties
                if data.texture or data.material or data.transparency or data.reflectance then
                    -- Convert texture string to Material enum
                    local material = Enum.Material.Plastic
                    if data.texture then
                        local matName = data.texture
                        if Enum.Material[matName] then
                            material = Enum.Material[matName]
                        end
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
                
                -- Rotation (use CFrame)
                local cf
                if data.cframe then
                    cf = CFrame.new(unpack(data.cframe))
                elseif data.position then
                    cf = CFrame.new(unpack(data.position))
                else
                    cf = part.CFrame
                end
                
                table.insert(ops.Rotate, {
                    Part = part,
                    CFrame = cf
                })
                
                -- Anchor
                table.insert(ops.Anchor, {
                    Part = part,
                    Anchored = data.anchored ~= false -- Default to true if not specified
                })
                
                -- Locked
                if data.locked ~= false then
                    table.insert(ops.Locked, part)
                end
                
                -- Collision
                table.insert(ops.Collision, {
                    Part = part,
                    CanCollide = data.cancollide ~= false -- Default to true
                })
                
                -- Surfaces
                if data.surface then
                    local surfaces = {}
                    for face, surfaceType in pairs(data.surface) do
                        if Enum.SurfaceType[surfaceType] then
                            surfaces[face] = Enum.SurfaceType[surfaceType]
                        end
                    end
                    
                    if next(surfaces) then
                        table.insert(ops.Surface, {
                            Part = part,
                            Surfaces = surfaces
                        })
                    end
                end
                
                -- Decals
                if data.decal then
                    local face = data.decal.face or "Top"
                    if type(face) == "string" and face:find("Enum.NormalId") then
                        face = face:match("%.([^%.]+)$") or "Top"
                    end
                    
                    -- Create decal
                    table.insert(ops.Decal, {
                        Part = part,
                        Face = face,
                        TextureType = "Decal"
                    })
                    
                    -- Sync decal properties
                    table.insert(ops.SyncDecal, {
                        Part = part,
                        Face = face,
                        Texture = data.decal.texture or "",
                        Transparency = data.decal.transparency or 0,
                        TextureType = "Decal"
                    })
                end
                
                -- Meshes (only for regular parts with SpecialMesh, not if already handled as MeshPart)
                if data.mesh and not (data.type == "MeshPart") and not part:FindFirstChildOfClass("SpecialMesh") then
                    local meshData = data.mesh
                    
                    -- Only add mesh if we haven't already during creation
                    table.insert(ops.Mesh, { Part = part })
                    
                    -- Sync mesh properties
                    local meshType = meshData.meshtype or meshData.MeshType or Enum.MeshType.Head
                    local meshId = meshData.meshid or meshData.MeshId or ""
                    
                    local meshOp = {
                        Part = part,
                        TextureId = meshData.texture or meshData.TextureId or "",
                        VertexColor = Vector3.new(unpack(meshData.vertexcolor or meshData.VertexColor or {1,1,1})),
                        MeshType = meshType,
                        Scale = Vector3.new(unpack(meshData.scale or meshData.Scale or {1,1,1})),
                        Offset = Vector3.new(unpack(meshData.offset or meshData.Offset or {0,0,0})),
                    }
                    
                    if meshId ~= "" and (meshType == Enum.MeshType.FileMesh or meshType == "FileMesh") then
                        meshOp.MeshId = meshId
                    end
                    
                    table.insert(ops.SyncMesh, meshOp)
                end
            end
        end
        
        -- EXECUTE BATCH SYNC WITH ERROR HANDLING
        local function safeSync(operation, funcName, args)
            local success, err = pcall(function()
                SyncAPI:InvokeServer(funcName, args)
            end)
            if not success then
                window:Log({ 
                    Color = Color3.fromRGB(255,165,0), 
                    Content = "[WARNING] A operation errored: "..operation..": "..tostring(err) 
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
        
        window:Log({ 
            Color = Color3.fromRGB(84,255,84), 
            Content = "The operation was successfully completed. Created "..total.." elements." 
        })
        
        window:Complete()
        
        -- Return created parts for further manipulation
        return createdParts
    end
}
