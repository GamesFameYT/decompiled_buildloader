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
        local window = Terminal:Window("Build Loader v1.3 (Lightning)")
        window:Log({ Color = Color3.new(1,1,1), Content = "Initializing (bulk mode)..." })

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
        window:Log({ Color = Color3.fromRGB(200,200,200), Content = "Parts: "..total })

        ------------------------------------------------------------
        -- CREATE ONE PLACEHOLDER (OFF-MAP)
        ------------------------------------------------------------
        local placeholderCF = CFrame.new(0, 10000, 0)
        SyncAPI:InvokeServer("CreatePart", "Normal", placeholderCF, Workspace)

        -- tiny yield to ensure replication of the placeholder
        task.wait(0.05)

        ------------------------------------------------------------
        -- GET THE PLACEHOLDER VIA WORKSPACE DIFF
        ------------------------------------------------------------
        local before = {}
        for _, o in ipairs(Workspace:GetChildren()) do before[o] = true end

        -- Force a benign selection change so Clone path is stable on some forks
        pcall(function() SyncAPI:InvokeServer("GetSelection") end)

        -- Snapshot after creating placeholder
        local placeholder
        for _, o in ipairs(Workspace:GetChildren()) do
            if not before[o] and o:IsA("BasePart") then
                placeholder = o
                break
            end
        end

        if not placeholder then
            window:Log({
                Color = Color3.fromRGB(255,65,65),
                Content = "[FATAL] Failed to resolve placeholder part."
            })
            window:Complete()
            return
        end

        ------------------------------------------------------------
        -- BULK CLONE (ONE CALL)
        ------------------------------------------------------------
        -- Build an array of the placeholder repeated N times
        local clones = {}
        for i = 1, total do
            clones[i] = placeholder
        end

        -- Snapshot before clone to diff new parts
        local beforeClone = {}
        for _, o in ipairs(Workspace:GetChildren()) do beforeClone[o] = true end

        -- ONE SERVER CALL
        SyncAPI:InvokeServer("Clone", clones, Workspace)

        -- minimal yield for replication
        task.wait(0.05)

        ------------------------------------------------------------
        -- DIFF TO GET ALL NEW PARTS (FAST)
        ------------------------------------------------------------
        local createdParts = {}
        for _, o in ipairs(Workspace:GetChildren()) do
            if not beforeClone[o] and o:IsA("BasePart") then
                createdParts[#createdParts+1] = o
            end
        end

        if #createdParts < total then
            window:Log({
                Color = Color3.fromRGB(255,120,120),
                Content = "[WARN] Expected "..total.." parts, detected "..#createdParts..". Continuing."
            })
        end

        -- Map parts to build indices in insertion order
        local ordered = {}
        local i = 1
        for idx in pairs(buildTable) do
            ordered[idx] = createdParts[i]
            i = i + 1
        end

        ------------------------------------------------------------
        -- PREPARE BATCH PROPERTY OPS (NO LOOPS WITH REMOTES)
        ------------------------------------------------------------
        window:Log({ Color = Color3.new(1,1,1), Content = "Applying properties (batched)..." })

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

        for idx, data in pairs(buildTable) do
            local part = ordered[idx]
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
        -- EXECUTE BATCH SYNC (MINIMUM CALLS)
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
        -- CLEANUP PLACEHOLDER (OPTIONAL)
        ------------------------------------------------------------
        pcall(function()
            SyncAPI:InvokeServer("Remove", { placeholder })
        end)

        ------------------------------------------------------------
        -- DONE
        ------------------------------------------------------------
        window:Log({
            Color = Color3.fromRGB(84,255,84),
            Content = "Build complete (lightning mode)."
        })
        window:Complete()
    end
}
