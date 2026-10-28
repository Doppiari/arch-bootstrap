# Required kernel parameters are not the medium's identity

The first real development build refused before calling mkarchiso:
`01-live.conf: rendered text is not acceptable`. Its naming check inspected
the entire rendered loader entry. That entry necessarily contains
`archisobasedir` and `archisosearchuuid`, parameters owned by the archiso
initramfs hooks. They are functional inputs, not the name of the medium.

The static validator already parsed the entry and checked its title
separately. The renderer now makes the same distinction: it checks the
rendered title and motd for medium identity and unresolved template markers,
while preserving the validated kernel parameters. The rule forbidding an
Arch medium identity has not changed.

`tests/iso-profile.bats` renders the actual profile in development mode. It
checks the title, full C/S markers, motd and exact kernel options. The old
whole-entry check refuses this control; the corrected renderer passes it.
The failed build remains a refusal, not an image or boot result.
