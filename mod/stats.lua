local CharacterBuilder = include("lib.CharacterTemplateLib")

local amp = CharacterBuilder.newCharacterSet("Amp")

local normalStats = CharacterBuilder.newStatTable()
normalStats.Speed = 1.10
normalStats.Firedelay = 2.73
normalStats.Damage = 2
normalStats.Range = 6.5
normalStats.Shotspeed = 1.00
normalStats.Luck = -1
normalStats.Tearcolor = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
normalStats.Tearflags = TearFlags.TEAR_JACOBS
normalStats.Flying = false
amp:setStats(normalStats);

local taintedStats = CharacterBuilder.newStatTable();
taintedStats.Speed = 1.00
taintedStats.Firedelay = 2.73
taintedStats.Damage = 1.5
taintedStats.Range = 6.5
taintedStats.Shotspeed = 1.0
taintedStats.Luck = -3
taintedStats.Tearcolor = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
taintedStats.Tearflags = TearFlags.TEAR_JACOBS | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_LASER
taintedStats.Flying = true
amp:setStats(taintedStats, true)

return CharacterBuilder.build()
