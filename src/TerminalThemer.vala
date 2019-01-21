public class Theme : Object {
    public string description;
    public string foreground;
    public string background;
    public string[] palette;

    public Theme(string description, string foreground, string background, string[] palette) {
        this.description = description;
        this.foreground = foreground;
        this.background = background;
        this.palette = palette;
    }

}
public class MyApp : Gtk.Application {
    public MyApp () {
        Object (
            application_id: "com.github.andrewvos.terminal-themer",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        var main_window = new Gtk.ApplicationWindow (this);
        main_window.default_height = 300;
        main_window.default_width = 300;
        main_window.title = "Terminal Themer";
        this.load_style (main_window);
        this.load_themes (main_window);
        main_window.show_all ();
    }

    void load_style (Gtk.Window window) {
        var screen = window.get_screen ();
        var css_provider = new Gtk.CssProvider();

        string path = "style.css";

        if (FileUtils.test (path, FileTest.EXISTS))
        {
            try {
                css_provider.load_from_path(path);
                Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error e) {
                error ("Cannot load CSS stylesheet: %s", e.message);
            }
        }
    }
    void load_themes (Gtk.Window window) {
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", "https://raw.githubusercontent.com/AndrewVos/terminal-themer/master/themes.json");
    session.send_message (message);

	Json.Parser parser = new Json.Parser ();
	try {
            parser.load_from_data ((string) message.response_body.flatten ().data, -1);
	} catch (Error e) {
		stdout.printf ("Unable to parse json: %s\n", e.message);
		return;
	}

	Json.Node node = parser.get_root ();

        var scrollContainer = new Gtk.ScrolledWindow (null, null);
        window.add (scrollContainer);

        Gtk.Box container = new Gtk.VBox (true, 1);
        container.get_style_context ().add_class ("container");
        scrollContainer.add (container);

        foreach (unowned Json.Node item in node.get_array().get_elements ()) {
            var object = item.get_object ();
            string description = object.get_string_member ("description");
            string foreground = object.get_string_member ("foreground");
            string background = object.get_string_member ("background");

            var palette_array = object.get_array_member ("palette");
            string[] palette = new string[palette_array.get_length ()];
            for (var i = 0; i < palette_array.get_length (); i++) {
                palette[i] = palette_array.get_string_element (i);
            }

            var theme = new Theme(description, foreground, background, palette);

            Gtk.Frame themeContainer = new Gtk.Frame (theme.description);
            themeContainer.get_style_context ().add_class ("theme");
            container.add (themeContainer);

            var themeContainerBox = new Gtk.VBox (true, 1);
            themeContainer.add (themeContainerBox);

            Gtk.HBox paletteContainer = new Gtk.HBox (false, 1);
            paletteContainer.get_style_context ().add_class ("palette");
            themeContainerBox.add(paletteContainer);

            paletteContainer.add (this.create_label (theme.foreground));
            paletteContainer.add (this.create_label (theme.background));

            foreach (string i in theme.palette) {
                paletteContainer.add (this.create_label (i));
            }

            var apply = new Gtk.Button.with_label ("Apply");
            apply.get_style_context ().add_class ("apply");
            paletteContainer.add (apply);
            apply.clicked.connect (() => {
                GLib.Process.spawn_command_line_sync ("gsettings set io.elementary.terminal.settings foreground '" + theme.foreground + "'");
                GLib.Process.spawn_command_line_sync ("gsettings set io.elementary.terminal.settings background '" + theme.background + "'");
                GLib.Process.spawn_command_line_sync ("gsettings set io.elementary.terminal.settings palette '" + string.join(":", theme.palette) + "'");
            });
        }
    }

    private Gtk.Widget create_label(string colour) {
        var label = new Gtk.Label ("");

        Gdk.Color gdkColour;
        Gdk.Color.parse(colour, out gdkColour);
        label.modify_bg(Gtk.StateType.NORMAL, gdkColour);
        label.get_style_context ().add_class ("colour");

        return label;
    }

    public static int main (string[] args) {
        var app = new MyApp ();
        return app.run (args);
    }
}
