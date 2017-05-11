#!/usr/bin/env python
# -*- coding: utf-8 -*-

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

'''
Pulls and massages our translations from Transifex.
'''

from __future__ import print_function
import os
import sys
import errno
import json
import codecs
import argparse
import requests


DEFAULT_LANGS = {
    'ar': 'ar',         # Arabic
    'de': 'de',         # German
    'el_GR': 'el',      # Greek
    'es': 'es',         # Spanish
    'fa': 'fa',         # Farsi/Persian
    'fi_FI': 'fi',      # Finnish
    'fr': 'fr',         # French
    'hr': 'hr',         # Croation
    'id': 'id',         # Indonesian
    'it': 'it',         # Italian
    #'kk': 'kk',         # Kazakh
    'ko': 'ko',         # Korean
    'nb_NO': 'nb',      # Norwegian
    'nl': 'nl',         # Dutch
    'pt_BR': 'pt_BR',   # Portuguese-Brazil
    'pt_PT': 'pt-PT',   # Portuguese-Portugal
    'ru': 'ru',         # Russian
    'th': 'th',         # Thai
    'tk': 'tk',         # Turkmen
    'tr': 'tr',         # Turkish
    #'ug': 'ug@Latn',    # Uighur (latin script)
    'vi': 'vi',         # Vietnamese
    'zh': 'zh-Hans',    # Chinese (simplified)
    'zh_TW': 'zh-Hant'  # Chinese (traditional)
}


RTL_LANGS = ('ar', 'fa', 'he')


IOS_BROWSER_RESOURCES = \
    ['ios-browser-iasklocalizablestrings', 'ios-browser-localizablestrings',
     'ios-browser-onepasswordextensionstrings', 'ios-browser-rootstrings',
     'ios-browser-app-store-assets']


def process_resource(resource, output_path_fn, output_mutator_fn, bom,
                     langs=None, skip_untranslated=False, encoding='utf-8'):
    '''
    `output_path_fn` must be callable. It will be passed the language code and
    must return the path+filename to write to.
    `output_mutator_fn` must be callable. It will be passed the output and the
    current language code. May be None.
    If `skip_untranslated` is True, translations that are less than X% complete
    will be skipped.
    '''
    if not langs:
        langs = DEFAULT_LANGS

    for in_lang, out_lang in langs.items():
        if skip_untranslated:
            stats = request('resource/%s/stats/%s' % (resource, in_lang))
            if int(stats['completed'].rstrip('%')) < 25:
                continue

        r = request('resource/%s/translation/%s' % (resource, in_lang))

        if output_mutator_fn:
            # Transifex doesn't support the special character-type
            # modifiers we need for some languages,
            # like 'ug' -> 'ug@Latn'. So we'll need to hack in the
            # character-type info.
            content = output_mutator_fn(r['content'], out_lang)
        else:
            content = r['content']

        # Make line endings consistently Unix-y.
        content = content.replace('\r\n', '\n')

        output_path = output_path_fn(out_lang)

        # Path sure the output directory exists.
        try:
            os.makedirs(os.path.dirname(output_path))
        except OSError as ex:
            if ex.errno == errno.EEXIST and os.path.isdir(os.path.dirname(output_path)):
                pass
            else:
                raise

        with codecs.open(output_path, 'w', encoding) as f:
            if bom:
                f.write(u'\uFEFF')
            f.write(content)


def gather_resource(resource, langs=None, skip_untranslated=False):
    '''
    Collect all translations for the given resource and return them.
    '''
    if not langs:
        langs = DEFAULT_LANGS

    result = {}
    for in_lang, out_lang in langs.items():
        if skip_untranslated:
            stats = request('resource/%s/stats/%s' % (resource, in_lang))
            if stats['completed'] == '0%':
                continue

        r = request('resource/%s/translation/%s' % (resource, in_lang))
        result[out_lang] = r['content'].replace('\r\n', '\n')

    return result


def request(command, params=None):
    url = 'https://www.transifex.com/api/2/project/Psiphon3/' + command + '/'
    r = requests.get(url, params=params,
                     auth=(_getconfig()['username'], _getconfig()['password']))
    if r.status_code != 200:
        raise Exception('Request failed with code %d: %s' %
                            (r.status_code, url))
    return r.json()


def yaml_lang_change(in_yaml, to_lang):
    return to_lang + in_yaml[in_yaml.find(':'):]


def html_doctype_add(in_html, to_lang):
    return '<!DOCTYPE html>\n' + in_html


def pull_ios_browser_translations():
    resources = (
        ('ios-browser-iasklocalizablestrings', 'IASKLocalizable.strings'),
        ('ios-browser-localizablestrings', 'Localizable.strings'),
        ('ios-browser-onepasswordextensionstrings', 'OnePasswordExtension.strings'),
        ('ios-browser-rootstrings', 'Root.strings')
    )

    for resname, fname in resources:
        process_resource(resname,
                         lambda lang: './Endless/%s.lproj/%s' % (lang, fname),
                         None,
                         bom=False,
                         skip_untranslated=True)
        print('%s: DONE' % (resname,))


def pull_ios_asset_translations():
    resname = 'ios-browser-app-store-assets'
    process_resource(
        resname,
        lambda lang: './StoreAssets/%s.yaml' % (lang, ),
        yaml_lang_change,
        bom=False,
        skip_untranslated=True, )
    print('%s: DONE' % (resname, ))


# Transifex credentials.
# Must be of the form:
# {"username": ..., "password": ...}
_config = None  # Don't use this directly. Call _getconfig()
def _getconfig():
    global _config
    if _config:
        return _config

    DEFAULT_CONFIG_FILENAME = 'transifex_conf.json'

    # Figure out where the config file is
    parser = argparse.ArgumentParser(description='Pull translations from Transifex')
    parser.add_argument('configfile', default=None, nargs='?',
                        help='config file (default: pwd or location of script)')
    args = parser.parse_args()
    configfile = None
    if args.configfile and os.path.exists(args.configfile):
        # Use the script argument
        configfile = args.configfile
    elif os.path.exists(DEFAULT_CONFIG_FILENAME):
        # Use the conf in pwd
        configfile = DEFAULT_CONFIG_FILENAME
    elif __file__ and os.path.exists(os.path.join(
                        os.path.dirname(os.path.realpath(__file__)),
                        DEFAULT_CONFIG_FILENAME)):
        configfile = os.path.join(
                        os.path.dirname(os.path.realpath(__file__)),
                        DEFAULT_CONFIG_FILENAME)
    else:
        print('Unable to find config file')
        sys.exit(1)

    with open(configfile) as config_fp:
        _config = json.load(config_fp)

    if not _config:
        print('Unable to load config contents')
        sys.exit(1)

    return _config


def go():
    pull_ios_browser_translations()
    pull_ios_asset_translations()

    print('FINISHED')


if __name__ == '__main__':
    go()
