#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Copyright (c) 2017, Psiphon Inc.
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


import argparse
import info_plist
import json
import jsonschema
from jinja2 import Template


def export_options_xml():
    return """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>{{ bundle_identifier }}</key>
        <string>{{ provisioning_profile_name }}</string>
    </dict>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>teamID</key>
    <string>{{ team_id }}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
"""


def client_config_schema():
    return {
        'type': 'object',
        'properties': {
            'bundle_name': {"type": "string"},
            'bundle_identifier': {"type": "string"},
            'provisioning_profile_name': {"type": "string"},
            'team_id': {"type": "string"}
        },
    }


def validate_client_config(config):
    jsonschema.validate(config, client_config_schema())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        prog="info_plist",
    )

    parser.add_argument("-c",
                        "--config",
                        help="Path to the client specific config",
                        required=True,
                        type=str)
    args = parser.parse_args()

    with open(args.config, 'r') as f:
        # Load client specific config
        client_config = json.load(f)
        validate_client_config(client_config)

        # Substitute values in Endless/Info.plist
        endless_info_plist = info_plist.InfoPlist(plist_path='./Endless/Info.plist', debug=False)
        endless_info_plist.update_bundle_name(client_config['bundle_name'])
        endless_info_plist.update_bundle_identifier(client_config['bundle_identifier'])

        # Create exportOptions.plist for signing
        export_options_context = {
            'provisioning_profile_name': client_config['provisioning_profile_name'],
            'bundle_identifier': client_config['bundle_identifier'],
            'team_id': client_config['team_id']
        }
        export_options = Template(export_options_xml()).render(export_options_context)

        with open('./exportOptions.plist', "wb") as export_options_file:
            export_options_file.write(export_options.encode('utf8'))
