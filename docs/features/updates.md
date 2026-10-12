# Software updates

This build has no in-app software updater or changelog entry. It does not request release metadata,
download updates, display update prompts or replace itself. Menus, About, launcher commands and
Settings expose no update controls. The old automatic-update preference is no longer read, exported
in backups or mirrored in settings.json; older backups simply omit it when decoded.

Install a newly built app manually using the packaging steps in [release.md](../release.md).
Extension Settings also performs no version checks and offers no Update / Update All controls.
Extensions can still be installed or reinstalled explicitly from the Store, GitHub or a local folder.
