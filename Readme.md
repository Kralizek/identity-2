# Identity 2

This addon allows you to specify your main character's name, an identity format string, and which channels will have your identity tag prepended. It also allows you to specify a nickname for use in Raid and Party channels.

## Compatibility

Version 4.3.0 targets World of Warcraft: Midnight 12.1.0 (interface 120100).
Release packages must include current Ace3 libraries with Midnight Settings support
and the category ID return value from `AceConfigDialog:AddToBlizOptions`.
The packager fetches the latest tagged libraries using `.pkgmeta`; a source checkout
does not include the embedded `Libs` directory.

Chat sending remains subject to Blizzard's hardware-event and security restrictions.
Identity 2 does not bypass those restrictions. Inaccessible chat arguments are passed
to the original API without adding an identity tag.

## Validation

Run the mocked API regression tests from the repository root with Lua 5.1 or later:

```sh
lua tests/run.lua
lua tests/run.lua legacy
```

With Node.js installed, Fengari can run the same tests without a local Lua executable:

```sh
npx --yes --package=fengari-node-cli fengari tests/run.lua
npx --yes --package=fengari-node-cli fengari tests/run.lua legacy
```

These tests cover settings navigation, chat hooks, argument and return-value
forwarding, community IDs, and inaccessible-argument handling using mocks. They do
not emulate WoW's taint system, hardware events, or actual secret values.

Before releasing, test a packaged build in the 12.1 client with Lua errors enabled:

1. Load the addon without enabling "Load out of date AddOns".
2. Open `/id` and `/identity`, and check the Profiles category and saved settings.
3. Verify default identities, overrides, and disabled settings in all supported chat channels.
4. Test custom channels, community streams, and Battle.net whispers. Confirm each message sends once.
5. Repeat in combat and instances. Check for taint, blocked actions, and long-message errors.

## Basic instructions:

use `/id` to go the configuration window

Enable
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Active/Deactive Identity2

    
Fun
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Enable/Disable Fun mode in special days
    
Format
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The base for witch the Identity will be generated on the chat. The tokens you can use are:
 - %s -> Will be replaced by the appropriate identity
 - %z -> Will be replaced by the name of the current zone
 - %l -> Will be replaced by the character level
 - %g -> Will be replaced by the character guild
 - %r -> Will be replaced by the realm name.

Any other character will be kept unchanged, for example the format:

[%s-%r]<%g>(%l) - %z

will look like this:

[Wall-Nesingwary]<of The Queue>(100) - Nagrand

## Contact

Lavindar
philipi_will@hotmail.com

Wall
Guild: of The Queue 
Server: Nesingwary-US

## Credits

Currently maintained by Lavindar (philipi_will@hotmail.com)
Guild: of The Queue
Server: Nesingwary-US

----

Former author Kjallstrom (ultranurd@gmail.com)
Guild: Mellonea
Server: Kirin Tor

----

Original IDENTITY by Ferusnox
Guild: Heaven and Earth
Server: Cenarion Circle
"Just call me Nox"
