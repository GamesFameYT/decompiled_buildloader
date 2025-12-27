-- filename: 
-- version: lua51
-- line: [0, 0] id: 0

local r0_0 = game:GetService("Players")
local r1_0 = game:GetService("RunService")

if not r0_0.LocalPlayer.Character then
    local r2_0 = r0_0.LocalPlayer.CharacterAdded:Wait()
end

local r3_0 = loadstring(game:HttpGet("https://raw.githubusercontent.com/SkireScripts/F3X-Panel/main/Terminal.lua"))()

return {
    LoadBuild = function(r0_1, r1_1, r2_1)
        -- line: [0, 0] id: 1
        local r3_1 = r3_0:Window("Build Loader v1.3")
        local r4_1 = Instance.new("BindableEvent", game)
        local r5_1 = {}

        r4_1.Event:Connect(function(r0_2)
            -- line: [0, 0] id: 2
            local r1_2 = r1_1[r0_2]
            local r2_2 = r1_2.shape

            if r1_2.shape == "Block" then
                r2_2 = "Normal"
            end

            r2_1:InvokeServer("CreatePart", r2_2, CFrame.new(unpack(r1_2.cframe)), game.Workspace)
        end)

        local r6_1 = game.Workspace.ChildAdded:Connect(function(r0_8)
            -- line: [0, 0] id: 8
            r5_1[#r5_1 + 1] = {}
            local r1_8 = r0_8.shape
            if r0_8.shape == "Block" then
                r1_8 = "Normal"
            end
            r5_1[#r5_1] = {
                type = r1_8,
                part = r0_8,
            }
        end)

        local r7_1 = game.Workspace.ChildRemoved:Connect(function(r0_3)
            -- line: [0, 0] id: 3
            if r5_1[r0_3] then
                r4_1:Fire(r5_1[r0_3])
                table.remove(r5_1, r5_1[r0_3])
            end
        end)

        local r8_1 = 0
        local r9_1 = 0
        local r10_1 = 0

        r3_1:Log({
            Color = Color3.fromRGB(255, 255, 255),
            Content = "Mapping build...",
        })

        local r11_1 = r3_1:Log({
            Color = Color3.fromRGB(255, 255, 255),
            Content = "Progress: " .. r10_1 .. "%\n[▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁]",
        })

        for r15_1, r16_1 in pairs(r1_1) do
            r9_1 = r9_1 + 1
        end

        local function r12_1(r0_6, r1_6, r2_6)
            -- line: [0, 0] id: 6
            local r4_6 = math.floor(r2_6 * r0_6 / r1_6)
            return string.format("[%s%s]", string.rep("��", r4_6), string.rep("��", r2_6 - r4_6))
        end

        local r13_1 = tick()
        local r14_1 = {}

        local r15_1, r16_1 = pcall(function()
            -- line: [0, 0] id: 4
            (function()
                -- line: [0, 0] id: 5
                for r3_5, r4_5 in pairs(r1_1) do
                    local r5_5 = r4_5.shape
                    if r4_5.shape == "Block" then
                        r5_5 = "Normal"
                    end

                    if not r3_1[r5_5] then
                        r2_1:InvokeServer("CreatePart", r5_5, CFrame.new(0, -800, 0), game.Workspace)
                        r14_1[#r3_1 + 1] = r5_5
                        break
                    else
                        break
                    end
                end
            end)()

            task.wait()
            local r1_4 = {}

            for r5_4, r6_4 in pairs(r1_1) do
                local r7_4 = r5_1[#r5_1]
                local r8_4 = r7_4.part.shape

                if r7_4.part.shape == "Block" then
                    r8_4 = "Normal"
                end

                for r12_4, r13_4 in pairs(r5_1) do
                    if r13_4.type == r8_4 then
                        r1_4[#r1_4 + 1] = r13_4.part
                    end
                end

                r8_1 = r8_1 + 1
                r10_1 = r8_1

                r11_1:Edit({
                    Color = r11_1:GetColor(),
                    Content = "Progress: " .. math.floor(r10_1 / r9_1 * 100) .. "%\n" .. r12_1(r10_1, r9_1, 20),
                })
            end

            r2_1:InvokeServer("Clone", r1_4, game.Workspace)
            task.wait(2)
        end)

        local r17_1 = {}
        for r21_1, r22_1 in pairs(r5_1) do
            r17_1[r21_1] = r22_1.part
        end
        r5_1 = r17_1

        r6_1:Disconnect()

        if not r15_1 then
            r3_1:Log({
                Color = Color3.fromRGB(255, 65, 65),
                Content = "[ERROR]: " .. r16_1,
            })
            r3_1:Complete()
        else
            r3_1:Log({
                Color = Color3.fromRGB(255, 255, 255),
                Content = "Done Mapping!",
            })

            r3_1:Log({
                Color = Color3.fromRGB(255, 255, 255),
                Content = "Setting Properties...",
            })

            local r18_1 = {
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

            for r22_1, r23_1 in pairs(r1_1) do
                local r24_1 = r5_1[r22_1]

                r18_1.Colors[#r18_1.Colors + 1] = {
                    Color = Color3.fromRGB(unpack(r23_1.color)),
                    Part = r24_1,
                    UnionColoring = true,
                }

                r18_1.Resize[#r18_1.Resize + 1] = {
                    CFrame = CFrame.new(unpack(r23_1.cframe)),
                    Part = r24_1,
                    Size = Vector3.new(unpack(r23_1.size)),
                }

                if r23_1.surface then
                    r18_1.Surface[#r18_1.Surface + 1] = {
                        Part = r24_1,
                        Surfaces = r23_1.surface,
                    }
                end

                r18_1.Material[#r18_1.Material + 1] = {
                    Part = r24_1,
                    Material = r23_1.texture,
                    Transparency = r23_1.transparency,
                    Reflectance = r23_1.reflectance,
                }

                r18_1.Rotate[#r18_1.Rotate + 1] = {
                    CFrame = CFrame.new(unpack(r23_1.cframe)),
                    Part = r24_1,
                }

                r18_1.Anchor[#r18_1.Anchor + 1] = {
                    Anchored = r23_1.anchored,
                    Part = r24_1,
                }

                r18_1.Locked[#r18_1.Locked + 1] = r24_1

                r18_1.Collision[#r18_1.Collision + 1] = {
                    CanCollide = r23_1.cancollide,
                    Part = r24_1,
                }

                if r23_1.decal then
                    r18_1.Decal[#r18_1.Decal + 1] = {
                        Face = r23_1.decal.face,
                        Part = r24_1,
                        TextureType = "Decal",
                    }

                    r18_1.SyncDecal[#r18_1.SyncDecal + 1] = {
                        Face = r23_1.decal.face,
                        Part = r24_1,
                        Texture = r23_1.decal.texture,
                        Transparency = r23_1.decal.transparency,
                        TextureType = "Decal",
                    }
                end

                if r23_1.mesh then
                    local r25_1 = {
                        Part = r24_1,
                        TextureId = r23_1.mesh.texture,
                        VertexColor = Vector3.new(unpack(r23_1.mesh.vertexcolor)),
                        MeshType = r23_1.mesh.meshtype,
                        Scale = Vector3.new(unpack(r23_1.mesh.scale)),
                        Offset = Vector3.new(unpack(r23_1.mesh.offset)),
                    }

                    if r23_1.mesh.meshtype == Enum.MeshType.FileMesh then
                        r25_1.MeshId = r23_1.mesh.meshid
                    end

                    r18_1.Mesh[#r18_1.Mesh + 1] = {
                        Part = r25_1.Part,
                    }

                    r18_1.SyncMesh[#r18_1.SyncMesh + 1] = r25_1
                end
            end

            local r19_1, r20_1 = pcall(function()
                -- line: [0, 0] id: 7
                r2_1:InvokeServer("SyncColor", r18_1.Colors)
                r2_1:InvokeServer("SyncResize", r18_1.Resize)
                r2_1:InvokeServer("SyncSurface", r18_1.Surface)
                r2_1:InvokeServer("SyncMaterial", r18_1.Material)
                r2_1:InvokeServer("SyncRotate", r18_1.Rotate)
                r2_1:InvokeServer("SyncAnchor", r18_1.Anchor)
                r2_1:InvokeServer("SetLocked", r18_1.Locked, true)
                r2_1:InvokeServer("SyncCollision", r18_1.Collision)
                r2_1:InvokeServer("CreateTextures", r18_1.Decal)
                r2_1:InvokeServer("SyncTexture", r18_1.SyncDecal)
                r2_1:InvokeServer("CreateMeshes", r18_1.Mesh)
                r2_1:InvokeServer("SyncMesh", r18_1.SyncMesh)
            end)

            local r22_1 = tick() - r13_1
            local r23_1 = nil

            if r22_1 < 60 then
                r23_1 = string.format("Finished in %.0fs", r22_1)
            elseif r22_1 < 3600 then
                r23_1 = string.format("Finished in %dm %.0fs", math.floor(r22_1 / 60), r22_1 % 60)
            else
                r23_1 = string.format("Finished in %dh %dm", math.floor(r22_1 / 3600), math.floor(r22_1 % 3600 / 60))
            end

            if not r19_1 then
                r3_1:Log({
                    Color = Color3.fromRGB(255, 65, 65),
                    Content = "[IGNORABLE][ERROR]: " .. r20_1,
                })
            end

            r3_1:Log({
                Color = Color3.fromRGB(84, 255, 84),
                Content = "Done! | " .. r23_1,
            })

            r3_1:Complete()
            -- close: r18_1
        end
    end,
}
