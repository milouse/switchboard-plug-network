/*-
 * Copyright (c) 2015-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

 namespace Network.Widgets {
    public class HotspotInterface : Network.Widgets.Page {
        public WifiInterface root_iface { get; construct; }
        private Gtk.Button hotspot_settings_btn;
        private bool switch_updating = false;

        private Gtk.Entry ssid_entry;
        private Granite.ValidatedEntry key_entry;
        private Gtk.Label conn_label;
        private Gtk.Label ssid_label;
        private Gtk.Label key_label;
        private Gtk.ComboBox conn_combo;
        private Gtk.CheckButton check_btn;

        public HotspotInterface (WifiInterface root_iface) {
            Object (
                activatable: true,
                root_iface: root_iface,
                description: _("Enabling Hotspot will disconnect from any connected wireless networks. You will not be able to connect to a wireless network while Hotspot is active."),
                device: root_iface.device,
                icon_name: "network-wireless-hotspot"
            );
        }

        construct {
            ssid_entry = new Gtk.Entry () {
                hexpand = true,
                text = GLib.Environment.get_host_name ()
            };

            key_entry = new Granite.ValidatedEntry () {
                visibility = false
            };

            check_btn = new Gtk.CheckButton.with_label (_("Show Password"));
            check_btn.bind_property ("active", key_entry, "visibility");

            ssid_label = new Gtk.Label (_("Network Name:")) {
                halign = Gtk.Align.END
            };

            key_label = new Gtk.Label (_("Password:")) {
                halign = Gtk.Align.END
            };

            var list_store = new Gtk.ListStore (2, typeof (string), typeof (NM.Connection));
            conn_combo = new Gtk.ComboBox.with_model (list_store);
            var renderer = new Gtk.CellRendererText ();
            conn_combo.pack_start (renderer, true);
            conn_combo.add_attribute (renderer, "text", 0);

            Gtk.TreeIter iter;
            list_store.append (out iter);
            list_store.set (iter, 0, _("New…"), -1);

            int i = 1;
            unowned NetworkManager network_manager = NetworkManager.get_default ();
            var connections = network_manager.client.get_connections ();
            connections.foreach ((connection) => {
                if (Utils.get_connection_is_hotspot (connection)) {
                    var setting_wireless = connection.get_setting_wireless ();
                    var ssid_name = NM.Utils.ssid_to_utf8 (setting_wireless.get_ssid ().get_data ());
                    list_store.append (out iter);
                    list_store.set (iter, 0, ssid_name, 1, connection);
                    i++;
                }
            });

            conn_combo.active = 0;
            conn_combo.changed.connect (change_selected_connection);

            conn_label = new Gtk.Label (_("Connection:")) {
                halign = Gtk.Align.END
            };

            var main_grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 6
            };
            main_grid.attach (conn_label, 1, 2);
            main_grid.attach (conn_combo, 2, 2);
            main_grid.attach (ssid_label, 1, 3);
            main_grid.attach (ssid_entry, 2, 3);
            main_grid.attach (key_label, 1, 4);
            main_grid.attach (key_entry, 2, 4);
            main_grid.attach (check_btn, 2, 5);

            content_area.attach (main_grid, 0, 0);

            hotspot_settings_btn = new SettingsButton.from_device (device, _("Hotspot Settings…"));

            action_area.append (hotspot_settings_btn);

            update ();
            validate_entries ();

            device.state_changed.connect (update);
            ssid_entry.changed.connect (validate_entries);
            key_entry.changed.connect (() => {
                key_entry.is_valid = key_entry.text.char_count () >= 8;
                validate_entries ();
            });
        }

        public override void update_name (int count) {
            if (count <= 1) {
                title = _("Hotspot");
            } else {
                title = _("Hotspot %s").printf (device.get_description ());
            }
        }

        private void validate_entries () {
            status_switch.sensitive = key_entry.is_valid || !sensitive;
            if (!key_entry.is_valid) {
                key_entry.secondary_icon_tooltip_text = _("Password needs to be at least 8 characters long");
            } else {
                key_entry.secondary_icon_tooltip_text = _("Password is at least 8 characters long");
            }
        }

        private unowned NM.Connection? get_selected_connection () {
            unowned NM.Connection? connection;
            Gtk.TreeIter iter;
            conn_combo.get_active_iter (out iter);
            conn_combo.model.get (iter, 1, out connection);
            return connection;
        }

        private void change_selected_connection () {
            bool sensitive = (conn_combo.active == 0);
            ssid_label.sensitive = sensitive;
            key_label.sensitive = sensitive;
            ssid_entry.sensitive = sensitive;
            key_entry.sensitive = sensitive;

            string? secret = null;
            unowned NM.Connection? selected_connection = get_selected_connection ();
            if (selected_connection != null) {
                unowned NM.SettingWirelessSecurity setting_wireless_security = selected_connection.get_setting_wireless_security ();

                string key_mgmt = setting_wireless_security.get_key_mgmt ();
                if (key_mgmt == "none") {
                    secret = setting_wireless_security.wep_key0;
                } else if (key_mgmt == "wpa-psk" || key_mgmt == "wpa-none") {
                    secret = setting_wireless_security.psk;
                }

                if (secret == null) {
                    Utils.update_secrets (((NM.RemoteConnection) selected_connection), change_selected_connection);
                }
            }

            if (conn_combo.active != 0) {
                ssid_entry.text = NM.Utils.ssid_to_utf8 (selected_connection.get_setting_wireless ().get_ssid ().get_data ());
                if (secret == null) {
                    secret = "";
                }

                key_entry.text = secret;
            }
        }

        protected override void update () {
            var wifi_device = (NM.DeviceWifi) device;
            bool hotspot_mode = Utils.get_device_is_hotspot (wifi_device);

            hotspot_settings_btn.sensitive = hotspot_mode;

            bool sensitive = !hotspot_mode;
            conn_combo.sensitive = sensitive;
            conn_label.sensitive = sensitive;
            ssid_label.sensitive = sensitive;
            key_label.sensitive = sensitive;
            ssid_entry.sensitive = sensitive;
            key_entry.sensitive = sensitive;

            update_switch ();

            var root_iface_is_hotspot = Utils.get_device_is_hotspot (root_iface.wifi_device);
            if (root_iface_is_hotspot) {
                state = NM.DeviceState.ACTIVATED;
            } else {
                state = NM.DeviceState.DISCONNECTED;
            }
        }

        protected override void update_switch () {
            switch_updating = true;
            status_switch.active = state == NM.DeviceState.ACTIVATED;
            switch_updating = false;
        }

        protected override void control_switch_activated () {
            if (switch_updating) {
                switch_updating = false;
                return;
            }

            var wifi_device = (NM.DeviceWifi)device;
            if (!status_switch.active && Utils.get_device_is_hotspot (wifi_device)) {
                unowned NetworkManager network_manager = NetworkManager.get_default ();
                network_manager.deactivate_hotspot.begin (wifi_device);
            } else {
                connect_to_hotspot.begin ();
            }
        }

        private async void connect_to_hotspot () {
            unowned NetworkManager network_manager = NetworkManager.get_default ();
            yield network_manager.activate_hotspot (
                (NM.DeviceWifi) device,
                ssid_entry.text,
                key_entry.text,
                get_selected_connection ()
            );
        }
    }
}
