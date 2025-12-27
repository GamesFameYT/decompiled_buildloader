-- filename:
-- version: lua51

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

-- Terminal UI
local Terminal = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/SkireScripts/F3X-Panel/main/Terminal.lua")
)()

return {
    LoadBuild = function(_, buildTable, SyncAPI)
        ------------------------------------------------------------
        -- UI INIT
        ------------------------------------------------------------
        local window = Terminal:Window("Build Loader v1.3 (No Placeholder / Lightning)")
        window:Log({ Color = Color3.new(1,1,1), Content = "Initializing..." })

        ------------------------------------------------------------
        -- SYNCAPI CHECK
        ------------------------------------------------------------
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)
        if not ok then
            window:Log({
                Color = Color3.fromRGB(255,65,65),
                Content = "[FATAL] SyncAPI blocked or invalid."
            })
            window:Complete()
            return
        end

        ------------------------------------------------------------
        -- COUNT PARTS
        ------------------------------------------------------------
        local total = 0
        for _ in pairs(buildTable) do total = total + 1 end
        if total == 0 then
            window:Log({ Color = Color3.fromRGB(255,120,120), Content = "Nothing to build." })
            window:Complete()
            return
        end
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "Parts to build: "..total })

        ------------------------------------------------------------
        -- BATCH CREATE PARTS DIRECTLY AT TARGET CFRAME
        ------------------------------------------------------------
        local createdParts = {}

        for index, data in pairs(buildTable) do
            local shape = (data.shape == "Block") and "Normal" or data.shape
            local part = nil

            local success, result = pcall(function()
                -- Directly create part at target CFrame
                part = SyncAPI:InvokeServer("CreatePart", shape, CFrame.new(unpack(data.cframe)), Workspace)
            end)

            if success and part then
                createdParts[index] = part
            else
                window:Log({
                    Color = Color3.fromRGB(255,120,120),
                    Content = "[WARN] Failed to create part at index "..tostring(index)
                })
            end
        end

        ------------------------------------------------------------
        -- BATCH PROPERTY SYNC
        ------------------------------------------------------------
        window:Log({ Color = Color3.new(1,1,1), Content = "Applying properties..." })

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
        }

        for index, data in pairs(buildTable) do
            local part = createdParts[index]
            if not part then continue end

            ops.Colors[#ops.Colors+1] = {
                Part = part,
                Color = Color3.fromRGB(unpack(data.color)),
                UnionColoring = true,
            }

            ops.Resize[#ops.Resize+1] = {
                Part = part,
                Size = Vector3.new(unpack(data.size)),
                CFrame = CFrame.new(unpack(data.cframe)),
            }

            ops.Material[#ops.Material+1] = {
                Part = part,
                Material = data.texture,
                Transparency = data.transparency,
                Reflectance = data.reflectance,
            }

            ops.Rotate[#ops.Rotate+1] = {
                Part = part,
                CFrame = CFrame.new(unpack(data.cframe)),
            }

            ops.Anchor[#ops.Anchor+1] = {
                Part = part,
                Anchored = data.anchored,
            }

            ops.Locked[#ops.Locked+1] = part

            ops.Collision[#ops.Collision+1] = {
                Part = part,
                CanCollide = data.cancollide,
            }

            if data.surface then
                ops.Surface[#ops.Surface+1] = {
                    Part = part,
                    Surfaces = data.surface,
                }
            end

            if data.decal then
                ops.Decal[#ops.Decal+1] = {
                    Part = part,
                    Face = data.decal.face,
                    TextureType = "Decal",
                }
                ops.SyncDecal[#ops.SyncDecal+1] = {
                    Part = part,
                    Face = data.decal.face,
                    Texture = data.decal.texture,
                    Transparency = data.decal.transparency,
                    TextureType = "Decal",
                }
            end

            if data.mesh then
                ops.Mesh[#ops.Mesh+1] = { Part = part }
                local meshOp = {
                    Part = part,
                    TextureId = data.mesh.texture,
                    VertexColor = Vector3.new(unpack(data.mesh.vertexcolor)),
                    MeshType = data.mesh.meshtype,
                    Scale = Vector3.new(unpack(data.mesh.scale)),
                    Offset = Vector3.new(unpack(data.mesh.offset)),
                }
                if data.mesh.meshtype == Enum.MeshType.FileMesh then
                    meshOp.MeshId = data.mesh.meshid
                end
                ops.SyncMesh[#ops.SyncMesh+1] = meshOp
            end
        end

        ------------------------------------------------------------
        -- EXECUTE BATCH SYNC
        ------------------------------------------------------------
        pcall(function()
            if #ops.Colors     > 0 then SyncAPI:InvokeServer("SyncColor",     ops.Colors)     end
            if #ops.Resize     > 0 then SyncAPI:InvokeServer("SyncResize",    ops.Resize)     end
            if #ops.Surface    > 0 then SyncAPI:InvokeServer("SyncSurface",   ops.Surface)    end
            if #ops.Material   > 0 then SyncAPI:InvokeServer("SyncMaterial",  ops.Material)   end
            if #ops.Rotate     > 0 then SyncAPI:InvokeServer("SyncRotate",    ops.Rotate)     end
            if #ops.Anchor     > 0 then SyncAPI:InvokeServer("SyncAnchor",    ops.Anchor)     end
            if #ops.Locked     > 0 then SyncAPI:InvokeServer("SetLocked",     ops.Locked, true) end
            if #ops.Collision  > 0 then SyncAPI:InvokeServer("SyncCollision", ops.Collision)  end
            if #ops.Decal      > 0 then SyncAPI:InvokeServer("CreateTextures",ops.Decal)      end
            if #ops.SyncDecal  > 0 then SyncAPI:InvokeServer("SyncTexture",   ops.SyncDecal)  end
            if #ops.Mesh       > 0 then SyncAPI:InvokeServer("CreateMeshes",  ops.Mesh)       end
            if #ops.SyncMesh   > 0 then SyncAPI:InvokeServer("SyncMesh",      ops.SyncMesh)   end
        end)

        ------------------------------------------------------------
        -- COMPLETE
        ------------------------------------------------------------
        window:Log({
            Color = Color3.fromRGB(84,255,84),
            Content = "Build complete (no placeholder, lightning fast)."
        })
        window:Complete()
    end
}
