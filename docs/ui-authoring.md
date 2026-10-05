# Editing UI layouts

Fixed UI geometry lives in Godot scenes. Scripts connect signals, populate data,
change visibility and animate controls; they do not rebuild the fixed screens.
Anchors and containers keep the authored layout responsive to the window size.

| UI | Scene to edit |
| --- | --- |
| Main menu, mode selection and Hotseat setup | `scenes/entities/UI/MainMenu.tscn` and its instanced setup/card scenes |
| LAN selection, browser and lobby | `scenes/network/LanChoice.tscn`, `LanBrowser.tscn`, `LanRoom.tscn`, `LanPlayerRow.tscn` |
| Technology tree positions and center tribe button | `scenes/UI/TurnNavbar.tscn` → `TechnologyTree/Nodes` and `TechnologyTree/TribeNode` |
| Technology button icon/cost layout | `scenes/UI/TechnologyNode.tscn` |
| Resource-action popup panel and Close button | `scenes/UI/resource_choices.tscn` |
| Resource-action and structure-information templates | `scenes/UI/ResourceAction.tscn`, `scenes/UI/StructureInfo.tscn` |
| Hotseat pass-to-player cover | `scenes/UI/HotseatHandoff.tscn` |
| Victory overlay | `scenes/UI/MatchResult.tscn` |
| Map-generation error message | `scenes/UI/MapSetupError.tscn` |
| LAN loading, disconnect and leave controls | `scenes/network/LanMatchStatus.tscn` |

The handoff, result, map-error and LAN-status scenes are already instanced in
`scenes/main/Main.tscn`. They start hidden and become visible when needed. Use
the editor's visibility control to preview hidden overlays, then restore their
initial hidden state before saving. Open an instanced scene to edit its contents.

Technology buttons are authored instances with an assigned TechnologyData
resource. Their icons and costs preview in the editor. Positions use anchors,
and the connecting lines follow the buttons when moved. Runtime ownership and
affordability still change their appearance and purchase controls.

Data-dependent UI stays dynamic: player rows, nearby-room lists, resource action
counts, unlocked recruitment choices and radial spacing, town EXP segments,
center-control progress, floating damage/reward numbers, and popups following
map entities. The menu's background scaling and responsive card columns also
follow the current window size. Resource-action entries use the editable
templates above; only their count and content come from gameplay.
