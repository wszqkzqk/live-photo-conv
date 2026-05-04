/* Copyright 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
*/

/**
 * GTK4 / LibAdwaita GUI for Live Photo Converter.
 *
 * Provides a graphical interface for making, extracting and repairing
 * Android Live Photos.
 */

/**
 * A drop area widget that accepts file drops and allows browsing.
 *
 * Supports single or multiple files via {@link max_files}.
 * When max_files is 0 (default) any number of files can be selected.
 * When set to 1, only a single file is accepted — use
 * {@link file} to get it.
 */
private class LivePhotoConv.FileDropArea : Adw.Bin {

    public signal void changed ();

    private string _orig_icon;
    private Gtk.Image icon_image;
    private Gtk.Label hint_label;
    private Gtk.Label file_label;
    private Gtk.Stack label_stack;
    private GenericArray<File> _files = new GenericArray<File> ();

    /** Maximum number of files accepted. 0 means unlimited. */
    public uint max_files { get; set; default = 0; }

    /** All selected files. Assigning triggers UI update and {@link changed}. */
    public GenericArray<File> files {
        get { return _files; }
        set {
            _files = value;
            if (value.length == 0) {
                label_stack.visible_child = hint_label;
                icon_image.icon_name = _orig_icon;
                icon_image.opacity = 0.5;
            } else if (value.length == 1) {
                file_label.label = value[0].get_basename ();
                label_stack.visible_child = file_label;
                icon_image.icon_name = "emblem-documents-symbolic";
                icon_image.opacity = 1.0;
            } else {
                file_label.label = ngettext ("%u file selected", "%u files selected", value.length).printf (value.length);
                label_stack.visible_child = file_label;
                icon_image.icon_name = "emblem-documents-symbolic";
                icon_image.opacity = 1.0;
            }
            changed ();
        }
    }

    /** Convenience: first selected file or null. */
    public File? file {
        get { return _files.length > 0 ? _files[0] : null; }
    }

    public string hint { get; construct; }
    public string icon_name { get; construct; default = "document-open-symbolic"; }
    /** MIME types to restrict file selection. Empty = no filter. */
    public string[] mime_types { get; construct; default = new string[0]; }

    public FileDropArea (string hint, string? icon_name = null, string[]? mime_types = null) {
        Object (hint: hint, icon_name: icon_name ?? "document-open-symbolic",
                mime_types: mime_types ?? new string[0]);
    }

    construct {
        _orig_icon = icon_name;

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            margin_start = 16,
            margin_end = 16,
            margin_top = 24,
            margin_bottom = 24,
        };

        icon_image = new Gtk.Image.from_icon_name (icon_name) {
            pixel_size = 48,
            opacity = 0.5,
        };
        main_box.append (icon_image);

        hint_label = new Gtk.Label (hint) {
            css_classes = { "dim-label", "title-4" },
            justify = Gtk.Justification.CENTER,
            wrap = true,
            max_width_chars = 30,
        };
        file_label = new Gtk.Label ("") {
            css_classes = { "title-4" },
            justify = Gtk.Justification.CENTER,
            wrap = true,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            max_width_chars = 30,
        };

        label_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
        };
        label_stack.add_child (hint_label);
        label_stack.add_child (file_label);
        label_stack.visible_child = hint_label;
        main_box.append (label_stack);

        this.css_classes = { "card", "activatable" };
        this.child = main_box;
        this.cursor = new Gdk.Cursor.from_name ("pointer", null);

        var drop_target = new Gtk.DropTarget (Type.INVALID, Gdk.DragAction.COPY);
        drop_target.set_gtypes ({typeof (Gdk.FileList), typeof (File)});
        drop_target.drop.connect (on_drop);
        this.add_controller (drop_target);

        var click = new Gtk.GestureClick ();
        click.pressed.connect (on_clicked);
        this.add_controller (click);
    }

    private void load_files (GenericArray<File> arr) {
        if (max_files == 1 && arr.length > 1)
            arr.remove_range (1, arr.length - 1);
        files = arr;
    }

    private bool on_drop (Value value, double x, double y) {
        var collected = new GenericArray<File> ();

        if (value.holds (typeof (File))) {
            var f = value.get_object () as File;
            if (f != null)
                collected.add (f);
        } else if (value.holds (typeof (Gdk.FileList))) {
            var file_list = (Gdk.FileList) value.get_boxed ();
            var dropped = file_list.get_files ();
            foreach (File f in dropped)
                collected.add (f);
        } else {
            return false;
        }

        load_files (collected);
        return collected.length > 0;
    }

    private Gtk.FileFilter? build_filter () {
        if (mime_types.length == 0)
            return null;

        var filter = new Gtk.FileFilter ();
        foreach (unowned var mime in mime_types)
            filter.add_mime_type (mime);
        return filter;
    }

    private void on_clicked (int n_press, double x, double y) {
        var filters = new ListStore (typeof (Gtk.FileFilter));
        var filter = build_filter ();
        if (filter != null)
            filters.append (filter);

        var dialog = new Gtk.FileDialog () {
            title = hint,
            filters = filter != null ? filters : null,
        };

        if (max_files == 1) {
            dialog.open.begin ((Gtk.Window) this.get_root (), null, (obj, res) => {
                try {
                    var f = dialog.open.end (res);
                    if (f != null) {
                        var arr = new GenericArray<File> ();
                        arr.add (f);
                        load_files (arr);
                    }
                } catch {}
            });
        } else {
            dialog.open_multiple.begin ((Gtk.Window) this.get_root (), null, (obj, res) => {
                try {
                    var model = dialog.open_multiple.end (res);
                    if (model == null) return;

                    var collected = new GenericArray<File> ();
                    for (uint i = 0; i < model.get_n_items (); i += 1)
                        collected.add ((File) model.get_item (i));
                    load_files (collected);
                } catch {}
            });
        }
    }
}

/**
 * GTK4 / LibAdwaita graphical application for Live Photo Converter.
 *
 * Provides a tabbed interface with three pages: Make, Extract, Repair
 *
 * Operations run asynchronously in background threads, keeping the UI responsive.
 * Button labels and sensitivity reflect the current working state.
 */
public class LivePhotoConv.Application : Adw.Application {

    private Adw.ToastOverlay toast_overlay;
    private bool working;

    // Make page
    private FileDropArea make_video_area;
    private FileDropArea make_image_area;
    private Gtk.CheckButton make_export_metadata_check;
    private Gtk.Button make_button;

    // Extract page
    private FileDropArea extract_live_photo_area;
    private Gtk.CheckButton extract_main_image_check;
    private Gtk.CheckButton extract_video_check;
    private Gtk.CheckButton extract_long_exposure_check;
    private Gtk.CheckButton extract_frames_check;
    private Gtk.Entry extract_img_format_entry;
    private Gtk.Button extract_button;

    // Repair page
    private FileDropArea repair_live_photo_area;
    private Gtk.CheckButton repair_force_check;
    private Gtk.SpinButton repair_video_size_spin;
    private Gtk.Button repair_button;

    construct {
        application_id = "com.github.wszqkzqk.live-photo-conv";
        flags = ApplicationFlags.DEFAULT_FLAGS;
    }

    public override void startup () {
        base.startup ();

        var style_manager = Adw.StyleManager.get_default ();
        string init_scheme;
        switch (style_manager.color_scheme) {
            case Adw.ColorScheme.FORCE_LIGHT:
                init_scheme = "force-light";
                break;
            case Adw.ColorScheme.FORCE_DARK:
                init_scheme = "force-dark";
                break;
            default:
                init_scheme = "default";
                break;
        }

        var scheme_action = new SimpleAction.stateful ("color-scheme", VariantType.STRING,
            new Variant.string (init_scheme));
        scheme_action.notify["state"].connect (() => {
            var scheme = scheme_action.state.get_string ();
            style_manager.color_scheme =
                scheme == "force-light" ? Adw.ColorScheme.FORCE_LIGHT :
                scheme == "force-dark"  ? Adw.ColorScheme.FORCE_DARK :
                                          Adw.ColorScheme.DEFAULT;
        });
        add_action (scheme_action);

        var about_action = new SimpleAction ("about", null);
        about_action.activate.connect (show_about);
        add_action (about_action);
    }

    /**
     * Sets up the main window, header bar with {@link Adw.ViewSwitcher},
     * and the three-page {@link Adw.ViewStack}.
     */
    public override void activate () {
        var window = new Adw.ApplicationWindow (this) {
            title = "Live Photo Converter",
            default_width = 520,
            default_height = 750,
        };

        Gtk.IconTheme.get_for_display (Gdk.Display.get_default ())
            .add_resource_path ("/com/github/wszqkzqk/live-photo-conv/icons");

        toast_overlay = new Adw.ToastOverlay ();

        var header = new Adw.HeaderBar ();
        var view_switcher = new Adw.ViewSwitcher ();

        var stack = new Adw.ViewStack ();

        make_button = make_action_button (_("Make Live Photo"));
        make_button.clicked.connect (on_make_clicked);

        extract_button = make_action_button (_("Extract"));
        extract_button.clicked.connect (on_extract_clicked);

        repair_button = make_action_button (_("Repair"));
        repair_button.clicked.connect (on_repair_clicked);

        stack.add_titled_with_icon (page_with_action_button (build_make_page (), make_button), "make", _("Make"), "list-add-symbolic");
        stack.add_titled_with_icon (page_with_action_button (build_extract_page (), extract_button), "extract", _("Extract"), "document-send-symbolic");
        stack.add_titled_with_icon (page_with_action_button (build_repair_page (), repair_button), "repair", _("Repair"), "applications-utilities-symbolic");

        view_switcher.stack = stack;
        stack.visible_child_name = "extract";
        header.title_widget = view_switcher;

        var appearance_menu = new Menu ();
        var section = new Menu ();
        section.append (_("Follow System"), "app.color-scheme::default");
        section.append (_("Light"), "app.color-scheme::force-light");
        section.append (_("Dark"), "app.color-scheme::force-dark");
        appearance_menu.append_section (null, section);

        var menu = new Menu ();
        menu.append_submenu (_("Appearance"), appearance_menu);
        menu.append (_("About"), "app.about");

        var menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            menu_model = menu,
            primary = true,
        };
        header.pack_end (menu_button);

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (header);
        toolbar_view.set_content (stack);

        toast_overlay.child = toolbar_view;
        window.content = toast_overlay;
        window.present ();
    }

    /**
     * Wraps page content in a scrollable area with the action button fixed at the bottom.
     */
    private Gtk.Widget page_with_action_button (Gtk.Widget content, Gtk.Button button) {
        var scroll = new Gtk.ScrolledWindow () {
            child = content,
            vexpand = true,
            hexpand = true,
        };
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (scroll);
        box.append (button);
        return box;
    }

    private Gtk.Button make_action_button (string label) {
        return new Gtk.Button.with_label (label) {
            halign = Gtk.Align.FILL,
            hexpand = true,
            css_classes = { "pill", "suggested-action" },
            margin_start = 24,
            margin_end = 24,
            margin_top = 12,
            margin_bottom = 12,
            sensitive = false,
        };
    }

    // ── Button state helpers ──

    private void start_work (Gtk.Button button, string label) {
        working = true;
        button.sensitive = false;
        button.label = label;
    }

    private void end_work (Gtk.Button button, string label, bool sensitive) {
        working = false;
        button.label = label;
        button.sensitive = sensitive;
    }

    private void show_toast (string msg) {
        var toast = new Adw.Toast (msg) {
            timeout = 3,
        };
        toast_overlay.add_toast (toast);
    }

    private void show_error_dialog (string title, string detail) {
        var dialog = new Adw.AlertDialog (title, detail);
        dialog.add_response ("ok", "OK");
        dialog.present (active_window);
    }

    private void show_about () {
        var about = new Adw.AboutDialog () {
            application_name = "Live Photo Converter",
            application_icon = "com.github.wszqkzqk.live-photo-conv",
            developer_name = "Zhou Qiankang (wszqkzqk)",
            version = VERSION,
            website = WEBSITE,
            issue_url = ISSUES_URL,
            developers = { "Zhou Qiankang (wszqkzqk) <wszqkzqk@qq.com>" },
            copyright = "Copyright © 2024-2026 Zhou Qiankang",
            license_type = Gtk.License.LGPL_2_1,
        };
        about.present (active_window);
    }

    // ── Page builder helpers ──

    private Adw.PreferencesGroup make_group (string title, string? description = null) {
        return new Adw.PreferencesGroup () {
            title = title,
            description = description,
            margin_start = 24,
            margin_end = 24,
            margin_top = 12,
        };
    }

    private Adw.ActionRow make_check_row (string title, out Gtk.CheckButton out_check,
                                            bool active = true, string? tooltip = null) {
        var check = new Gtk.CheckButton () {
            active = active,
            valign = Gtk.Align.CENTER,
            tooltip_text = tooltip,
        };
        out_check = check;

        var row = new Adw.ActionRow () {
            title = title,
            activatable = false,
            tooltip_text = tooltip,
        };
        row.add_suffix (check);
        return row;
    }

    private Adw.ActionRow make_entry_row (string title, out Gtk.Entry entry, string placeholder) {
        entry = new Gtk.Entry () {
            placeholder_text = placeholder,
            halign = Gtk.Align.END,
            width_chars = 10,
            valign = Gtk.Align.CENTER,
        };
        var row = new Adw.ActionRow () {
            title = title,
            activatable = false,
        };
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.END,
        };
        box.append (entry);
        row.add_suffix (box);
        return row;
    }

    // ── Make page ──

    private Gtk.Widget build_make_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 6,
        };

        var files_group = make_group (_("Source Files"),
            _("Provide a video file (required) and a static image."));

        // Side-by-side drop areas: Video | Main Image
        var drop_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            homogeneous = true,
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12,
        };

        var video_col = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        video_col.append (new Gtk.Label (_("Video")) {
            xalign = 0,
            css_classes = { "heading" },
        });
        make_video_area = new FileDropArea (_("Drop video here\nor click to browse"), "folder-videos-symbolic", {"video/*"}) {
            max_files = 1,
            vexpand = true,
            valign = Gtk.Align.FILL,
        };
        make_video_area.changed.connect (() => {
            if (!working)
                make_button.sensitive = (make_video_area.files.length > 0);
        });
        video_col.append (make_video_area);
        drop_row.append (video_col);

        var image_col = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        image_col.append (new Gtk.Label (_("Main Image")) {
            xalign = 0,
            css_classes = { "heading" },
        });
        make_image_area = new FileDropArea (_("Drop image here\nor click to browse"), "folder-pictures-symbolic", {"image/*"}) {
            max_files = 1,
            vexpand = true,
            valign = Gtk.Align.FILL,
        };
        image_col.append (make_image_area);
        drop_row.append (image_col);

        files_group.add (new Adw.ActionRow () { child = drop_row });
        box.append (files_group);

        var options_group = make_group (_("Options"));
        make_export_metadata_check = null;
        options_group.add (make_check_row (_("Export metadata"), out make_export_metadata_check, true));
        box.append (options_group);

        return box;
    }

    private void on_make_clicked () {
        var video_file = make_video_area.file;
        if (video_file == null) return;

        var dialog = new Gtk.FileDialog () {
            title = _("Save Live Photo As"),
            initial_name = "MVIMG_live_photo.jpg",
        };
        dialog.save.begin (active_window, null, (obj, res) => {
            try {
                var output_file = dialog.save.end (res);
                if (output_file == null) return;

                var video_path = video_file.get_path ();
                var image_file = make_image_area.file;
                string? image_path = image_file != null ? image_file.get_path () : null;
                var output_path = output_file.get_path ();
                bool export_metadata = make_export_metadata_check.active;

                start_work (make_button, _("Processing…"));

#if ENABLE_GST
                var maker = new LiveMakerGst (video_path, image_path, output_path) {
                    export_original_metadata = export_metadata,
                };
#else
                var maker = new LiveMakerFFmpeg (video_path, image_path, output_path) {
                    export_original_metadata = export_metadata,
                };
#endif
                maker.export_async.begin ((obj, res2) => {
                    try {
                        maker.export_async.end (res2);
                        end_work (make_button, _("Make Live Photo"), make_video_area.files.length > 0);
                        show_toast (_("Live photo created"));
                    } catch (Error e) {
                        end_work (make_button, _("Make Live Photo"), make_video_area.files.length > 0);
                        show_error_dialog (_("Error"), e.message);
                    }
                });
            } catch {}
        });
    }

    // ── Extract page ──

    private Gtk.Widget build_extract_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 6,
        };

        var files_group = make_group (_("Live Photo"),
            _("Select the live photo file to extract from."));

        extract_live_photo_area = new FileDropArea (_("Drop live photo file here\nor click to browse"), "camera-photo-symbolic", {"image/*"}) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12,
        };
        extract_live_photo_area.changed.connect (() => {
            if (!working)
                extract_button.sensitive = (extract_live_photo_area.files.length > 0);
        });
        files_group.add (new Adw.ActionRow () { child = extract_live_photo_area });
        box.append (files_group);

        var exports_group = make_group (_("Export Items"),
            _("Choose what to extract from the live photo."));

        exports_group.add (make_check_row (_("Export Main Image"), out extract_main_image_check, true));
        exports_group.add (make_check_row (_("Export Video"), out extract_video_check, true));
        exports_group.add (make_check_row (_("Export Frames as Photos"), out extract_frames_check, false));
        exports_group.add (make_check_row (_("Export Long Exposure Photo"), out extract_long_exposure_check, false));
        exports_group.add (make_entry_row (_("Image Format"), out extract_img_format_entry, _("auto")));
        box.append (exports_group);

        return box;
    }

    private void on_extract_clicked () {
        var files = extract_live_photo_area.files;
        if (files.length == 0) {
            show_toast (_("Please select a live photo file first"));
            return;
        }

        var dialog = new Gtk.FileDialog () {
            title = _("Select Output Directory"),
        };
        dialog.select_folder.begin (active_window, null, (obj, res) => {
            try {
                var folder = dialog.select_folder.end (res);
                if (folder == null) return;

                var dest_dir = folder.get_path ();
                bool do_image = extract_main_image_check.active;
                bool do_video = extract_video_check.active;
                bool do_long = extract_long_exposure_check.active;
                bool do_frames = extract_frames_check.active;
                string? img_format = extract_img_format_entry.text.strip ();
                if (img_format == "") img_format = null;

                start_work (extract_button, _("Extracting…"));
                extract_batch_async.begin (files, dest_dir,
                    do_image, do_video, do_long, do_frames, img_format,
                    extract_button,
                    (obj, res2) => {
                        try {
                            extract_batch_async.end (res2);
                            end_work (extract_button, _("Extract"), extract_live_photo_area.files.length > 0);
                            show_toast (ngettext ("%u file extracted", "%u files extracted", (uint) files.length).printf ((uint) files.length));
                        } catch (Error e) {
                            end_work (extract_button, _("Extract"), extract_live_photo_area.files.length > 0);
                            show_error_dialog (_("Error"), e.message);
                        }
                    });
            } catch {}
        });
    }

    // ── Repair page ──

    private Gtk.Widget build_repair_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 6,
        };

        var files_group = make_group (_("Live Photo"),
            _("Select the live photo file to repair its XMP metadata."));

        repair_live_photo_area = new FileDropArea (_("Drop live photo file here\nor click to browse"), "camera-photo-symbolic", {"image/*"}) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12,
        };
        repair_live_photo_area.changed.connect (() => {
            if (!working)
                repair_button.sensitive = (repair_live_photo_area.files.length > 0);
        });
        files_group.add (new Adw.ActionRow () { child = repair_live_photo_area });
        box.append (files_group);

        var options_group = make_group (_("Repair Options"));

        options_group.add (make_check_row (_("Force Repair"),
            out repair_force_check, false,
            _("If enabled, the video offset will be re-discovered by scanning\n"
            + "the entire file for the MP4 header, overriding any existing\n"
            + "offset value in the XMP metadata.")));

        box.append (options_group);

        var advanced_group = make_group (_("Advanced"));
        var expander = new Adw.ExpanderRow () {
            title = _("Manual Video Size"),
            subtitle = _("Specify the size of the embedded video in bytes"),
            tooltip_text = _("If the video size cannot be detected automatically,\n"
                            + "you can manually specify its size in bytes.\n"
                            + "Leave at 0 to use automatic detection."),
            expanded = false,
            show_enable_switch = false,
        };
        expander.add_prefix (new Gtk.Image.from_icon_name ("document-properties-symbolic"));

        repair_video_size_spin = new Gtk.SpinButton (
            new Gtk.Adjustment (0, 0, int32.MAX, 1, 10, 0),
            1, 0
        ) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            width_chars = 12,
            tooltip_text = _("Enter the exact size of the video portion in bytes.\n"
                            + "Only needed if automatic detection fails."),
        };

        var spin_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 6,
            margin_bottom = 6,
        };
        spin_box.append (new Gtk.Label (_("Video size in bytes")) {
            hexpand = true,
            xalign = 0,
            valign = Gtk.Align.CENTER,
        });
        spin_box.append (repair_video_size_spin);

        expander.add_row (spin_box);
        advanced_group.add (expander);
        box.append (advanced_group);

        return box;
    }

    private void on_repair_clicked () {
        var files = repair_live_photo_area.files;
        if (files.length == 0) {
            show_toast (_("Please select a live photo file first"));
            return;
        }

        bool force = repair_force_check.active;
        uint video_size = (uint) repair_video_size_spin.value;

        start_work (repair_button, _("Repairing…"));
        repair_batch_async.begin (files, force, video_size, repair_button, (obj, res) => {
            try {
                repair_batch_async.end (res);
                end_work (repair_button, _("Repair"), repair_live_photo_area.files.length > 0);
                show_toast (ngettext ("%u file repaired", "%u files repaired", (uint) files.length).printf ((uint) files.length));
            } catch (Error e) {
                end_work (repair_button, _("Repair"), repair_live_photo_area.files.length > 0);
                show_error_dialog (_("Error"), e.message);
            }
        });
    }

    // ── Batch async wrappers ──

    private static void report_progress (Gtk.Button button, string verb,
                                          int current, int total) {
        button.label = @"$(verb) $(current)/$(total)…";
    }

    private async void extract_batch_async (GenericArray<File> files, string dest_dir,
                                             bool do_image, bool do_video,
                                             bool do_long, bool do_frames,
                                             string? img_format,
                                             Gtk.Button button) throws Error {
        SourceFunc callback = extract_batch_async.callback;
        var sb = new StringBuilder ();
        int error_count = 0;
        int total = (int) files.length;
        int processed = 0;

        report_progress (button, _("Extracting"), 0, total);

        new Thread<void> ("extract-batch", () => {
            foreach (unowned var file in files) {
                var path = file.get_path ();
                try {
#if ENABLE_GST
                    var live_photo = new LivePhotoGst (path, dest_dir);
#else
                    var live_photo = new LivePhotoFFmpeg (path, dest_dir);
#endif
                    if (do_image)
                        live_photo.export_main_image ();
                    if (do_video)
                        live_photo.export_video ();
                    if (do_long)
                        live_photo.generate_long_exposure (
                            Path.build_filename (dest_dir,
                                Path.get_basename (path) + "_long_exposure.jpg"));
                    if (do_frames)
                        live_photo.split_images_from_video (img_format, dest_dir);
                } catch (Error e) {
                    if (error_count > 0) sb.append_c ('\n');
                    sb.append_printf ("%s: %s", path, e.message);
                    error_count += 1;
                }
                processed += 1;
                Idle.add (() => {
                    report_progress (button, _("Extracting"), processed, total);
                    return false;
                });
            }
            Idle.add ((owned) callback);
        });
        yield;
        if (error_count > 0) {
            unowned string detail = sb.str;
            throw new ExportError.FILE_PUSH_ERROR (
                error_count != total
                    ? "%u of %u files failed:\n%s".printf ((uint) error_count, (uint) total, detail)
                    : detail);
        }
    }

    private async void repair_batch_async (GenericArray<File> files, bool force,
                                            uint video_size,
                                            Gtk.Button button) throws Error {
        SourceFunc callback = repair_batch_async.callback;
        var sb = new StringBuilder ();
        int error_count = 0;
        int total = (int) files.length;
        int processed = 0;

        report_progress (button, _("Repairing"), 0, total);

        new Thread<void> ("repair-batch", () => {
            foreach (unowned var file in files) {
                var path = file.get_path ();
                try {
#if ENABLE_GST
                    var live_photo = new LivePhotoGst (path);
#else
                    var live_photo = new LivePhotoFFmpeg (path);
#endif
                    live_photo.repair_live_metadata (force, video_size);
                } catch (Error e) {
                    if (error_count > 0) sb.append_c ('\n');
                    sb.append_printf ("%s: %s", path, e.message);
                    error_count += 1;
                }
                processed += 1;
                Idle.add (() => {
                    report_progress (button, _("Repairing"), processed, total);
                    return false;
                });
            }
            Idle.add ((owned) callback);
        });
        yield;
        if (error_count > 0) {
            unowned string detail = sb.str;
            throw new ExportError.FILE_PUSH_ERROR (
                error_count != total
                    ? "%u of %u files failed:\n%s".printf ((uint) error_count, (uint) total, detail)
                    : detail);
        }
    }
    
    /**
     * Application entry point.
     *
     * @param args command-line arguments
     * @return exit code
     */
    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);
        var app = new Application ();
        return app.run (args);
    }
}
