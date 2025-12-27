-- filename:
-- version: lua51

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

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
        local window = Terminal:Window("Build Loader v1.3 (Fast)")
        window:Log({ Color = Color3.new(1,1,1), Content = "Initializing..." })

        ------------------------------------------------------------
        -- SYNCAPI CHECK
        ------------------------------------------------------------
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)

        if not ok then
            window:Log({
                Color = Color3.fromRGB(255, 65, 65),
                Content = "[FATAL] SyncAPI blocked or invalid."
            })
            window:Complete()
            return
        end

        ------------------------------------------------------------
        -- COUNT PARTS
        ------------------------------------------------------------
        local total = 0
        for _ in pairs(buildTable) do
            total = total + 1
        end

        window:Log({
            Color = Color3.fromRGB(200,200,200),
            Content = "Parts to create: " .. total
        })

        ------------------------------------------------------------
        -- WORKSPACE SNAPSHOT (BEFORE)
        ------------------------------------------------------------
        local before = Workspace:GetChildren()
        local beforeSet = {}
        for _, obj in ipairs(before) do
            beforeSet[obj] = true
        end

        ------------------------------------------------------------
        -- BATCH CREATE PARTS (FAST)
        ------------------------------------------------------------
        for _, data in pairs(buildTable) do
            local shape = data.shape
            if shape == "Block" then
                shape = "Normal"
            end

            SyncAPI:InvokeServer(
                "CreatePart",
                shape,
                CFrame.new(unpack(data.cframe)),
                Workspace
            )
        end

        -- Small yield to let server replicate
        task.wait(0.15)

        ------------------------------------------------------------
        -- WORKSPACE DIFF (AFTER)
        ------------------------------------------------------------
        local createdParts = {}
        local newParts = {}

        for _, obj in ipairs(Workspace:GetChildren()) do
            if not beforeSet[obj] and obj:IsA("BasePart") then
                table.insert(newParts, obj)
            end
        end

        if #newParts == 0 then
            window:Log({
                Color = Color3.fromRGB(255, 65, 65),
                Content = "[FATAL] No parts detected. Server likely blocks F3X."
            })
            window:Complete()
            return
        end

        -- Map parts 1:1 in creation order
        local i = 1
        for index in pairs(buildTable) do
            createdParts[index] = newParts[i]
            i = i + 1
        end

        window:Log({
            Color = Color3.fromRGB(84, 255, 84),
            Content = "Created " .. #newParts .. " parts."
        })

        ------------------------------------------------------------
        -- PROPERTY COLLECTION (BATCHED)
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
        -- EXECUTE SYNC (ONE PASS)
        ------------------------------------------------------------
        pcall(function()
            SyncAPI:InvokeServer("SyncColor", ops.Colors)
            SyncAPI:InvokeServer("SyncResize", ops.Resize)
            SyncAPI:InvokeServer("SyncSurface", ops.Surface)
            SyncAPI:InvokeServer("SyncMaterial", ops.Material)
            SyncAPI:InvokeServer("SyncRotate", ops.Rotate)
            SyncAPI:InvokeServer("SyncAnchor", ops.Anchor)
            SyncAPI:InvokeServer("SetLocked", ops.Locked, true)
            SyncAPI:InvokeServer("SyncCollision", ops.Collision)
            SyncAPI:InvokeServer("CreateTextures", ops.Decal)
            SyncAPI:InvokeServer("SyncTexture", ops.SyncDecal)
            SyncAPI:InvokeServer("CreateMeshes", ops.Mesh)
            SyncAPI:InvokeServer("SyncMesh", ops.SyncMesh)
        end)

        ------------------------------------------------------------
        -- DONE
        ------------------------------------------------------------
        window:Log({
            Color = Color3.fromRGB(84, 255, 84),
            Content = "Build completed successfully (fast mode)."
        })
        window:Complete()
    end
}
