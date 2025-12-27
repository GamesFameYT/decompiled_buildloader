-- filename:
-- version: lua51

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

-- Terminal UI
local Terminal = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/SkireScripts/F3X-Panel/main/Terminal.lua")
)()

-- MAIN MODULE
return {
    LoadBuild = function(_, buildTable, SyncAPI)
        -- UI
        local window = Terminal:Window("Build Loader v1.3 (Fixed)")
        window:Log({ Color = Color3.new(1,1,1), Content = "Starting build loader..." })

        -- SAFETY CHECK
        local ok = pcall(function()
            SyncAPI:InvokeServer("GetSelection")
        end)

        if not ok then
            window:Log({
                Color = Color3.fromRGB(255, 65, 65),
                Content = "[FATAL] SyncAPI exists but is blocked by server."
            })
            window:Complete()
            return
        end

        ------------------------------------------------------------
        -- UTILS
        ------------------------------------------------------------

        local function getSelectionSet()
            local sel = SyncAPI:InvokeServer("GetSelection")
            local set = {}
            for _, p in ipairs(sel) do
                set[p] = true
            end
            return sel, set
        end

        local function getNewParts(beforeSet)
            local after = SyncAPI:InvokeServer("GetSelection")
            local new = {}

            for _, p in ipairs(after) do
                if not beforeSet[p] then
                    table.insert(new, p)
                end
            end

            return new
        end

        ------------------------------------------------------------
        -- CREATE PARTS (SAFE)
        ------------------------------------------------------------

        local createdParts = {}
        local total = 0

        for _ in pairs(buildTable) do
            total = total + 1
        end

        local done = 0
        local progressLog = window:Log({
            Color = Color3.new(1,1,1),
            Content = "Progress: 0%"
        })

        for index, data in pairs(buildTable) do
            local shape = data.shape
            if shape == "Block" then
                shape = "Normal"
            end

            local _, beforeSet = getSelectionSet()

            SyncAPI:InvokeServer(
                "CreatePart",
                shape,
                CFrame.new(unpack(data.cframe)),
                workspace
            )

            task.wait()

            local newParts = getNewParts(beforeSet)

            if #newParts == 0 then
                window:Log({
                    Color = Color3.fromRGB(255, 120, 120),
                    Content = "[WARN] No part created for index " .. tostring(index)
                })
            else
                -- F3X sometimes creates more than one; we take the first
                createdParts[index] = newParts[1]
            end

            done = done + 1
            progressLog:Edit({
                Color = progressLog:GetColor(),
                Content = ("Progress: %d%%"):format(math.floor(done / total * 100))
            })
        end

        ------------------------------------------------------------
        -- PROPERTY SYNC (SAFE, NIL-PROOF)
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

            if not part then
                window:Log({
                    Color = Color3.fromRGB(255, 65, 65),
                    Content = "[SKIP] Missing part at index " .. tostring(index)
                })
                continue
            end

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
        -- EXECUTE SYNC
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

        window:Log({
            Color = Color3.fromRGB(84, 255, 84),
            Content = "Build completed successfully."
        })

        window:Complete()
    end
}
