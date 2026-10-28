# A filename mentioning a licence is not necessarily a notice

The first development inventory selected basenames beginning with `LICENSE`,
`COPYING`, `NOTICE` and similar words. A real-path fixture showed it also
counted `license.py`, its bytecode and `NOTICE.yml` as licence evidence.
Those files can be program code or configuration rather than notice texts.

The collector now excludes those code/configuration extensions before
selecting notice paths from the installed package database. It still includes
`/usr/share/doc/dosfstools/COPYING`, package licence directories and notices
under language metadata directories. It records missing evidence instead of
inventing a package-specific copyright notice from a shared generic licence.
Redirected files are not copied from outside the live root.

`tests/iso-release.bats` exercises these actual path classes through the real
collector. The unfiltered selector fails that test; the corrected selector
passes. This classification is a starting inventory for review, not approval
of package redistribution or proof that every applicable notice was found.
The historical licence report remains scoped to its own recorded revision.
