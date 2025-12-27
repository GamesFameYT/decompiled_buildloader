-- filename:
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
        local window = Terminal:Window("Build Loader v2.0 (Full Support)")

        window:Log({ Color = Color3.new(1,1,1), Content = "Initializing..." })

        -- SYNCAPI CHECK
        local ok = pcall(function() SyncAPI:InvokeServer("GetSelection") end)
        if not ok then
            window:Log({ Color = Color3.fromRGB(255,65,65), Content = "[FATAL] SyncAPI blocked or invalid." })
            window:Complete()
            return
        end

        -- COUNT PARTS
        local total = 0
        for _ in pairs(buildTable) do total = total + 1 end
        if total == 0 then
            window:Log({ Color = Color3.fromRGB(255,120,120), Content = "Nothing to build." })
            window:Complete()
            return
        end
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "Parts to build: "..total })

        -- CREATE PARTS, MESHES, UNIONS, LIGHTS
        local createdParts = {}

        for index, data in pairs(buildTable) do
            local part = nil
            local partType = data.type or data.shape or "Block"

            local success, result = pcall(function()
                if partType == "UnionOperation" then
                    part = SyncAPI:InvokeServer("CreateUnion", data.unionData, Workspace)
                elseif partType == "MeshPart" or (data.mesh and data.mesh.meshtype) then
                    part = SyncAPI:InvokeServer("CreateMeshPart", data.mesh, data.cframe, Workspace)
                elseif partType == "Light" then
                    part = Instance.new(data.lightType or "PointLight")
                    part.Parent = Workspace
                    part.CFrame = CFrame.new(unpack(data.cframe))
                    part.Color = Color3.fromRGB(unpack(data.color or {255,255,255}))
                    part.Brightness = data.brightness or 1
                    part.Range = data.range or 15
                    part.Shadows = data.shadows or false
                else
                    part = SyncAPI:InvokeServer("CreatePart", (partType=="Block") and "Normal" or partType, CFrame.new(unpack(data.cframe)), Workspace)
                end
            end)

            if success and part then
                createdParts[index] = part
            else
                window:Log({
                    Color = Color3.fromRGB(255,120,120),
                    Content = "[WARN] Failed to create element at index "..tostring(index)
                })
            end
        end

        -- BATCH PROPERTY SYNC
        window:Log({ Color = Color3.new(1,1,1), Content = "Applying properties..." })
        local ops = { Colors={}, Resize={}, Surface={}, Material={}, Rotate={}, Anchor={}, Locked={}, Collision={}, Decal={}, SyncDecal={}, Mesh={}, SyncMesh={}, Lights={} }

        for index, data in pairs(buildTable) do
            local part = createdParts[index]
            if not part then continue end

            if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
                ops.Colors[#ops.Colors+1] = { Part=part, Color=Color3.fromRGB(unpack(data.color or {255,255,255})), UnionColoring=true }
                ops.Resize[#ops.Resize+1] = { Part=part, Size=Vector3.new(unpack(data.size or {4,1,2})), CFrame=CFrame.new(unpack(data.cframe)) }
                ops.Material[#ops.Material+1] = { Part=part, Material=data.texture, Transparency=data.transparency, Reflectance=data.reflectance }
                ops.Rotate[#ops.Rotate+1] = { Part=part, CFrame=CFrame.new(unpack(data.cframe)) }
                ops.Anchor[#ops.Anchor+1] = { Part=part, Anchored=data.anchored }
                ops.Locked[#ops.Locked+1] = part
                ops.Collision[#ops.Collision+1] = { Part=part, CanCollide=data.cancollide }

                if data.surface then ops.Surface[#ops.Surface+1] = { Part=part, Surfaces=data.surface } end
                if data.decal then
                    ops.Decal[#ops.Decal+1] = { Part=part, Face=data.decal.face, TextureType="Decal" }
                    ops.SyncDecal[#ops.SyncDecal+1] = { Part=part, Face=data.decal.face, Texture=data.decal.texture, Transparency=data.decal.transparency, TextureType="Decal" }
                end
                if data.mesh then
                    ops.Mesh[#ops.Mesh+1] = { Part=part }
                    local meshOp = {
                        Part = part,
                        TextureId = data.mesh.texture,
                        VertexColor = Vector3.new(unpack(data.mesh.vertexcolor or {1,1,1})),
                        MeshType = data.mesh.meshtype,
                        Scale = Vector3.new(unpack(data.mesh.scale or {1,1,1})),
                        Offset = Vector3.new(unpack(data.mesh.offset or {0,0,0})),
                    }
                    if data.mesh.meshtype == Enum.MeshType.FileMesh then
                        meshOp.MeshId = data.mesh.meshid
                    end
                    ops.SyncMesh[#ops.SyncMesh+1] = meshOp
                end
            elseif part:IsA("Light") then
                ops.Lights[#ops.Lights+1] = { Light=part, Color=Color3.fromRGB(unpack(data.color or {255,255,255})), Brightness=data.brightness or 1, Range=data.range or 15, Shadows=data.shadows or false }
            end
        end

        -- EXECUTE BATCH SYNC
        pcall(function()
            if #ops.Colors     >0 then SyncAPI:InvokeServer("SyncColor", ops.Colors) end
            if #ops.Resize     >0 then SyncAPI:InvokeServer("SyncResize", ops.Resize) end
            if #ops.Surface    >0 then SyncAPI:InvokeServer("SyncSurface", ops.Surface) end
            if #ops.Material   >0 then SyncAPI:InvokeServer("SyncMaterial", ops.Material) end
            if #ops.Rotate     >0 then SyncAPI:InvokeServer("SyncRotate", ops.Rotate) end
            if #ops.Anchor     >0 then SyncAPI:InvokeServer("SyncAnchor", ops.Anchor) end
            if #ops.Locked     >0 then SyncAPI:InvokeServer("SetLocked", ops.Locked, true) end
            if #ops.Collision  >0 then SyncAPI:InvokeServer("SyncCollision", ops.Collision) end
            if #ops.Decal      >0 then SyncAPI:InvokeServer("CreateTextures", ops.Decal) end
            if #ops.SyncDecal  >0 then SyncAPI:InvokeServer("SyncTexture", ops.SyncDecal) end
            if #ops.Mesh       >0 then SyncAPI:InvokeServer("CreateMeshes", ops.Mesh) end
            if #ops.SyncMesh   >0 then SyncAPI:InvokeServer("SyncMesh", ops.SyncMesh) end
            -- Lights
            for _, l in pairs(ops.Lights) do
                local light = l.Light
                light.Color = l.Color
                light.Brightness = l.Brightness
                light.Range = l.Range
                light.Shadows = l.Shadows
            end
        end)

        window:Log({ Color = Color3.fromRGB(84,255,84), Content = "Build complete (supports meshes, unions, lights)." })
        window:Complete()
    end
}
