# Mercurial plugin for Atom

Implemented:
- marks files added/changed in treeview
- marks lines as added/changed/deleted in gutter
- shows parent revision and change summary in footer

Note that since the current repository-provider API (0.1.0) assumes repo
interaction is synchronous, some bits are "best effort", i.e. UI may lag 
behind.

This package uses node-hg (https://www.npmjs.com/package/hg) for its VCS 
integration.

__Beware: This package is in early development state__
