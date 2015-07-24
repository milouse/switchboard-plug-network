
namespace Network {
    public class Page : Gtk.Box {
        public const int INFO_BOX_MARGIN = 16;

        public NM.Device device;
        public Gtk.Switch control_switch;
        public signal void switch_callback ();
        public signal void show_error ();

        private string _icon_name;    
        public string icon_name {
            get {
                return _icon_name;
            }

            set {
                _icon_name = value;
                device_img.icon_name = _icon_name;
            }
        }

        private string _title;
        public string title {
            get {
                return _title;
            }

            set {
                _title = value;
                device_label.label = _title;
            }
        }

        private Gtk.Box control_box;
        private Gtk.Image device_img;
        private Gtk.Label device_label;

        public Page () {
            this.orientation = Gtk.Orientation.VERTICAL;
            this.margin = 12;
            this.spacing = 24;

            device_img = new Gtk.Image.from_icon_name (_icon_name, Gtk.IconSize.DIALOG);
            device_img.pixel_size = 48;

            device_label = new Gtk.Label (Utils.type_to_string (device.get_device_type ()));
            device_label.get_style_context ().add_class ("h2");

            control_switch = new Gtk.Switch ();
            control_switch.activate.connect (control_switch_activated);

            control_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            control_box.pack_start (device_img, false, false, 0);
            control_box.pack_start (device_label, false, false, 0);
            control_box.pack_end (control_switch, false, false, 0);       

            this.add (control_box);
            this.show_all (); 
        }

        public void add_switch_title (string title) {
            var label = new Gtk.Label ("<b>" + title + "</b>");
            label.use_markup = true;
            control_box.pack_end (label, false, false, 0);
        }

        private void control_switch_activated () {
            if (device.get_state () == NM.DeviceState.ACTIVATED) {
                device.disconnect (null);
            } else {
                var connection = new NM.Connection ();
                var remote_array = device.get_available_connections ();
                if (remote_array == null) {
                    this.show_error ();
                } else {
                    connection.path = remote_array.get (0).get_path ();
                    client.activate_connection (connection, device, null, null);
                }
            }

            this.switch_callback ();            
        }

        public void get_activity_information (string iface, out string sent_bytes, out string received_bytes) {
            sent_bytes = UNKNOWN;
            received_bytes = UNKNOWN;

            string tx_bytes_path = "/sys/class/net/" + iface + "/statistics/tx_bytes";
            string rx_bytes_path = "/sys/class/net/" + iface + "/statistics/rx_bytes";

            if (!(File.new_for_path (tx_bytes_path).query_exists ()
                && File.new_for_path (rx_bytes_path).query_exists ())) {
                return;
            }

            try {
                string tx_bytes, rx_bytes;

                FileUtils.get_contents (tx_bytes_path, out tx_bytes);
                FileUtils.get_contents (rx_bytes_path, out rx_bytes);

                sent_bytes = format_size (uint64.parse (tx_bytes));
                received_bytes = format_size (uint64.parse (rx_bytes));
            } catch (FileError e) {
                error ("%s\n", e.message);
            }
        }
    }
}