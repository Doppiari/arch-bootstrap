# A revision field must match its entire scalar

A malformed YAML fixture set S to forty hexadecimal characters followed by a
newline. The static validator accepted it: the regular expression's end
anchor matched immediately before that newline. The serialized release record
would then name a value that was not a 40-character commit identity.

Revision, fingerprint, package-name, package-version and digest fields now
use full-scalar matches. The literal profile parser also rejects repeated
`file_permissions` keys instead of silently keeping the last value. A second
CLI fixture showed that `--mode` was accepted and ignored by the profile-check
action; it is now restricted to the admission-check action. Real build mode
continues to come from the committed input file.

`tests/iso-profile.bats` exercises LF, CR and CRLF suffixes, duplicate literal
permission entries and an out-of-context mode flag through the real parser
and CLI. Restoring each permissive behavior makes its corresponding fixture
fail; restoring the check makes the valid profile pass again. Valid pinned
inputs and the installer engine are unchanged.
