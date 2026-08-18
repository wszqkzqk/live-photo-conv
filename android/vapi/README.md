# Vendored VAPIs for Android cross builds

Android builds use no GObject-Introspection, so the VAPIs that dependency
packages normally generate at build time do not exist. These files are only
used when `host_machine.system() == 'android'`; everything else (gio,
gmodule, gstreamer-*, gdk-pixbuf, gtk4) ships with valac itself.

If the project starts using newer gexiv2/libadwaita API, re-extract these
from a matching release; `gexiv2.vapi` should match the version pinned in
`subprojects/gexiv2android.wrap`.
