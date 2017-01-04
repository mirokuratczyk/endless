/*
 * Copyright (c) 2016, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKSettingsReader.h"
#import "IASKTextField.h"
#import "IASKTextViewCell.h"
#import "RegionSelectionViewController.h"
#import "SettingsViewController.h"

@implementation RegionSelectionViewController {
    NSMutableArray *flags;
    NSString *selectedRegion;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Get currently selected region
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    selectedRegion = [userDefaults stringForKey:kRegionSelectionSpecifierKey];

    // Create an array of region keys which correspond to region flag images
    NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"RegionSelection.plist"];
    NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

    for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
        NSString *key = [pref objectForKey:@"Key"];
        if (key != nil) {
            if (flags == nil) {
                flags = [NSMutableArray arrayWithObjects: key, nil];
            } else {
                [flags addObject:key];
            }
        }
    }
}

#pragma mark - IASK UITableView delegate methods

- (UITableViewCell*)tableView:(UITableView*)tableView cellForSpecifier:(IASKSpecifier*)specifier {

    NSString *identifier = [NSString stringWithFormat:@"%@-%@-%ld-%d", specifier.key, specifier.type, (long)specifier.textAlignment, !!specifier.subtitle.length];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    cell.imageView.image = [UIImage imageNamed:[@"flag-" stringByAppendingString:specifier.key]];
    cell.textLabel.text = specifier.title;
    cell.userInteractionEnabled = YES;

    if ([specifier.key isEqualToString:selectedRegion]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender tableView:(UITableView *)tableView didSelectCustomViewSpecifier:(IASKSpecifier*)specifier {
    // New region was selected update tableview cells
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    // De-select currently selected option
    NSUInteger currentIndex[2];
    currentIndex[0] = 0;
    currentIndex[1] = [flags indexOfObject:selectedRegion];
    NSIndexPath *currentIndexPath = [[NSIndexPath alloc] initWithIndexes:currentIndex length:2];
    UITableViewCell *currentlySelectedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    currentlySelectedCell.accessoryType = UITableViewStylePlain; // Remove checkmark

    // Select newly chosen option
    selectedRegion = specifier.key;
    [userDefaults setObject:specifier.key forKey:kRegionSelectionSpecifierKey]; // Update settings

    NSIndexPath *newIndexPath = [tableView indexPathForSelectedRow];
    UITableViewCell *newlySelectedCell = [tableView cellForRowAtIndexPath:newIndexPath];
    newlySelectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
    [tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}

- (CGFloat)tableView:(UITableView*)tableView heightForSpecifier:(IASKSpecifier*)specifier {
    return 44.0f;
}

#pragma mark - IASK delegate methods

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
