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
                file_label.label = @"$(value.length) files selected";
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
                    for (uint i = 0; i < model.get_n_items (); i++)
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

    /**
     * Sets up the main window, header bar with {@link Adw.ViewSwitcher},
     * and the three-page {@link Adw.ViewStack}.
     */
    public override void activate () {
        var window = new Adw.ApplicationWindow (this) {
            title = "Live Photo Converter",
            default_width = 500,
            default_height = 750,
        };

        toast_overlay = new Adw.ToastOverlay ();

        var header = new Adw.HeaderBar ();
        var view_switcher = new Adw.ViewSwitcher ();

        var stack = new Adw.ViewStack ();
        stack.add_titled_with_icon (wrap_in_scroll (build_make_page ()), "make", "Make", "list-add-symbolic");
        stack.add_titled_with_icon (wrap_in_scroll (build_extract_page ()), "extract", "Extract", "document-send-symbolic");
        stack.add_titled_with_icon (wrap_in_scroll (build_repair_page ()), "repair", "Repair", "applications-utilities-symbolic");

        view_switcher.stack = stack;
        stack.visible_child_name = "extract";
        header.title_widget = view_switcher;

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (header);
        toolbar_view.set_content (stack);

        toast_overlay.child = toolbar_view;
        window.content = toast_overlay;
        window.present ();
    }

    /**
     * Wraps a widget in a {@link Gtk.ScrolledWindow} with both scrollbars
     * set to expand.
     */
    private Gtk.Widget wrap_in_scroll (Gtk.Widget child) {
        var scroll = new Gtk.ScrolledWindow () {
            child = child,
            vexpand = true,
            hexpand = true,
        };
        return scroll;
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

        var files_group = make_group ("Source Files",
            "Provide a video file (required) and a static image.");

        // Side-by-side drop areas: Video | Main Image
        var drop_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            homogeneous = true,
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12,
        };

        var video_col = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        video_col.append (new Gtk.Label ("Video *") {
            xalign = 0,
            css_classes = { "heading" },
        });
        make_video_area = new FileDropArea ("Drop video here\nor click to browse", "folder-videos-symbolic", {"video/*"}) {
            max_files = 1,
        };
        make_video_area.changed.connect (() => {
            if (!working)
                make_button.sensitive = (make_video_area.files.length > 0);
        });
        video_col.append (make_video_area);
        drop_row.append (video_col);

        var image_col = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        image_col.append (new Gtk.Label ("Main Image") {
            xalign = 0,
            css_classes = { "heading" },
        });
        make_image_area = new FileDropArea ("Drop image here\nor click to browse", "folder-pictures-symbolic", {"image/*"}) {
            max_files = 1,
        };
        image_col.append (make_image_area);
        drop_row.append (image_col);

        files_group.add (new Adw.ActionRow () { child = drop_row });
        box.append (files_group);

        var options_group = make_group ("Options");
        make_export_metadata_check = null;
        options_group.add (make_check_row ("Export metadata", out make_export_metadata_check, true));
        box.append (options_group);

        make_button = new Gtk.Button.with_label ("Make Live Photo") {
            halign = Gtk.Align.FILL,
            hexpand = true,
            css_classes = { "pill", "suggested-action" },
            margin_start = 24,
            margin_end = 24,
            margin_top = 18,
            margin_bottom = 12,
            sensitive = false,
        };
        make_button.clicked.connect (on_make_clicked);
        box.append (make_button);

        return box;
    }

    private void on_make_clicked () {
        var video_file = make_video_area.file;
        if (video_file == null) return;

        var dialog = new Gtk.FileDialog () {
            title = "Save Live Photo As",
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

                start_work (make_button, "Processing…");

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
                        end_work (make_button, "Make Live Photo", make_video_area.files.length > 0);
                        show_toast ("Live photo created");
                    } catch (Error e) {
                        end_work (make_button, "Make Live Photo", make_video_area.files.length > 0);
                        show_toast (@"Error: $(e.message)");
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

        var files_group = make_group ("Live Photo",
            "Select the live photo file to extract from.");

        extract_live_photo_area = new FileDropArea ("Drop live photo file here\nor click to browse", "camera-photo-symbolic", {"image/*"}) {
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

        var exports_group = make_group ("Export Items",
            "Choose what to extract from the live photo.");

        exports_group.add (make_check_row ("Export Main Image", out extract_main_image_check, true));
        exports_group.add (make_check_row ("Export Video", out extract_video_check, true));
        exports_group.add (make_check_row ("Export Frames as Photos", out extract_frames_check, false));
        exports_group.add (make_check_row ("Export Long Exposure Photo", out extract_long_exposure_check, false));
        exports_group.add (make_entry_row ("Image Format", out extract_img_format_entry, "auto"));
        box.append (exports_group);

        extract_button = new Gtk.Button.with_label ("Extract") {
            halign = Gtk.Align.FILL,
            hexpand = true,
            css_classes = { "pill", "suggested-action" },
            margin_start = 24,
            margin_end = 24,
            margin_top = 18,
            margin_bottom = 12,
            sensitive = false,
        };
        extract_button.clicked.connect (on_extract_clicked);
        box.append (extract_button);

        return box;
    }

    private void on_extract_clicked () {
        var files = extract_live_photo_area.files;
        if (files.length == 0) {
            show_toast ("Please select a live photo file first");
            return;
        }

        var dialog = new Gtk.FileDialog () {
            title = "Select Output Directory",
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

                start_work (extract_button, "Extracting…");
                extract_batch_async.begin (files, dest_dir,
                    do_image, do_video, do_long, do_frames, img_format,
                    extract_button,
                    (obj, res2) => {
                        try {
                            extract_batch_async.end (res2);
                            end_work (extract_button, "Extract", extract_live_photo_area.files.length > 0);
                            show_toast (@"$(files.length) file(s) extracted");
                        } catch (Error e) {
                            end_work (extract_button, "Extract", extract_live_photo_area.files.length > 0);
                            show_toast (@"Error: $(e.message)");
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

        var files_group = make_group ("Live Photo",
            "Select the live photo file to repair its XMP metadata.");

        repair_live_photo_area = new FileDropArea ("Drop live photo file here\nor click to browse", "camera-photo-symbolic", {"image/*"}) {
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

        var options_group = make_group ("Repair Options");

        options_group.add (make_check_row ("Force Repair",
            out repair_force_check, false,
            "If enabled, the video offset will be re-discovered by scanning\n"
            + "the entire file for the MP4 header, overriding any existing\n"
            + "offset value in the XMP metadata."));

        box.append (options_group);

        var advanced_group = make_group ("Advanced");
        var expander = new Adw.ExpanderRow () {
            title = "Manual Video Size",
            subtitle = "Specify the size of the embedded video in bytes",
            tooltip_text = "If the video size cannot be detected automatically,\n"
                            + "you can manually specify its size in bytes.\n"
                            + "Leave at 0 to use automatic detection.",
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
            tooltip_text = "Enter the exact size of the video portion in bytes.\n"
                            + "Only needed if automatic detection fails.",
        };

        var spin_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 6,
            margin_bottom = 6,
        };
        spin_box.append (new Gtk.Label ("Video size in bytes") {
            hexpand = true,
            xalign = 0,
            valign = Gtk.Align.CENTER,
        });
        spin_box.append (repair_video_size_spin);

        expander.add_row (spin_box);
        advanced_group.add (expander);
        box.append (advanced_group);

        repair_button = new Gtk.Button.with_label ("Repair") {
            halign = Gtk.Align.FILL,
            hexpand = true,
            css_classes = { "pill", "suggested-action" },
            margin_start = 24,
            margin_end = 24,
            margin_top = 18,
            margin_bottom = 12,
            sensitive = false,
        };
        repair_button.clicked.connect (on_repair_clicked);
        box.append (repair_button);

        return box;
    }

    private void on_repair_clicked () {
        var files = repair_live_photo_area.files;
        if (files.length == 0) {
            show_toast ("Please select a live photo file first");
            return;
        }

        bool force = repair_force_check.active;
        uint video_size = (uint) repair_video_size_spin.value;

        start_work (repair_button, "Repairing…");
        repair_batch_async.begin (files, force, video_size, repair_button, (obj, res) => {
            try {
                repair_batch_async.end (res);
                end_work (repair_button, "Repair", repair_live_photo_area.files.length > 0);
                show_toast (@"$(files.length) file(s) repaired");
            } catch (Error e) {
                end_work (repair_button, "Repair", repair_live_photo_area.files.length > 0);
                show_toast (@"Error: $(e.message)");
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
        string? error_msg = null;
        int total = (int) files.length;
        int processed = 0;

        report_progress (button, "Extracting", 0, total);

        new Thread<int> ("extract-batch", () => {
            foreach (unowned var file in files) {
                if (error_msg != null) break;
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
                    error_msg = @"$(path): $(e.message)";
                }
                processed += 1;
                Idle.add (() => {
                    report_progress (button, "Extracting", processed, total);
                    return false;
                });
            }
            Idle.add ((owned) callback);
            return 0;
        });
        yield;
        if (error_msg != null)
            throw new ExportError.FILE_PUSH_ERROR (error_msg);
    }

    private async void repair_batch_async (GenericArray<File> files, bool force,
                                            uint video_size,
                                            Gtk.Button button) throws Error {
        SourceFunc callback = repair_batch_async.callback;
        string? error_msg = null;
        int total = (int) files.length;
        int processed = 0;

        report_progress (button, "Repairing", 0, total);

        new Thread<int> ("repair-batch", () => {
            foreach (unowned var file in files) {
                if (error_msg != null) break;
                var path = file.get_path ();
                try {
#if ENABLE_GST
                    var live_photo = new LivePhotoGst (path);
#else
                    var live_photo = new LivePhotoFFmpeg (path);
#endif
                    live_photo.repair_live_metadata (force, video_size);
                } catch (Error e) {
                    error_msg = @"$(path): $(e.message)";
                }
                processed += 1;
                Idle.add (() => {
                    report_progress (button, "Repairing", processed, total);
                    return false;
                });
            }
            Idle.add ((owned) callback);
            return 0;
        });
        yield;
        if (error_msg != null)
            throw new ExportError.FILE_PUSH_ERROR (error_msg);
    }
    
    /**
     * Application entry point.
     *
     * @param args command-line arguments
     * @return exit code
     */
    public static int main (string[] args) {
        var app = new Application ();
        return app.run (args);
    }
}
