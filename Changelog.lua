--- @type AddOn
local _, AddOn = ...

AddOn.Changelog = [=[
2026.0.1 (2026-02-13)
* correct issues with clicking buttons not working and improve pulse timers 6ac1de1

2026.0.0 (2026-02-12)
* Increment version to be aligned with year 4458ac1

2022.1.0 (2026-02-12)
* First update for TBC Anniversary 11905ae
* Fix release note generator 82444b3
* Use GitHub actions for build 9565c0c
* Update TOC for TBC Anniversary 583c274

2022.0.7 (2022-04-05)
* update totem bar as totem set(s) are udpated via config UI (doesn't support deletion of active set currently) db96271

2022.0.6 (2022-04-04)
* correct regression with totem flyout size not being handled via configuration UI d44b1fa

2022.0.5 (2022-04-04)
* add support for selecting spells and ordering totems for totem sets via config UI ebfb915

2022.0.4 (2022-04-04)
* add GetMacroIcons as valid API usage f0ea18a
* add support for adding and removing totem sets (missing totem order and spell selection) b9391e8
* defer handling of player login event until addon has been enabled 7cafe5e
* only update macros on a change to active totem set's totems(spells) 7c904fd
* revise initialization of spells and totems to be bound to addon being enabled, not events 996eadc

2022.0.3 (2022-03-31)
* add UI for configuration and add support for totem bar settings 260f19d

2022.0.2 (2022-03-30)
* add support for keybinds and fix cooldown timer intermittently not working on totems ccc014a
* simplify key binding abbreviation for display 0c6a9e9

2022.0.1 (2022-03-29)
* fix lua check errors 0c1a4bf
* cut first beta d4e791a

2022.0.0
* Beta release appropriate for limited testing by users.
]=]