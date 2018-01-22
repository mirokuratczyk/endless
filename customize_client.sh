#!/bin/bash -u -e

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

EXPORTED_APP_ICON_SET_ZIP="./AppIcon.appiconset.zip"
EXPORTED_CLIENT_CONFIG="./client_config.json"

# Export required files for customization
python psi_export_doc.py

# Substitute app icon
unzip -o "${EXPORTED_APP_ICON_SET_ZIP}" -d ./Endless/Resources/Images.xcassets/

# Update required values in Endless/Info.plist and create exportOptions.plist for signing
python customize_client.py -c "${EXPORTED_CLIENT_CONFIG}"

# Cleanup
rm "${EXPORTED_APP_ICON_SET_ZIP}"
rm "${EXPORTED_CLIENT_CONFIG}"
