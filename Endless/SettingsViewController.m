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

#import "FeedbackUpload.h"
#import "HTTPSEverywhereRuleController.h"
#import "SettingsViewController.h"


static AppDelegate *appDelegate;

#define kHttpsEverywhereSpecifierKey @"httpsEverywhere"
#define kTutorialSpecifierKey @"tutorial"

@implementation SettingsViewController {
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForSpecifier:(IASKSpecifier*)specifier {
	UITableViewCell *cell = [super tableView:tableView cellForSpecifier:specifier]; // TODO: check if cell has been setup? Or just re-init if changed

	if ([specifier.key isEqualToString:kHttpsEverywhereSpecifierKey]) {
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
		[cell.textLabel setText:specifier.title];

		// Set detail text label to # of https everywhere rules in use for current browser tab
		long ruleCount = [[[AppDelegate sharedAppDelegate] webViewController] curWebViewTabHttpsRulesCount];

		if (ruleCount > 0) {
			cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
			cell.detailTextLabel.text = [NSString stringWithFormat:(ruleCount == 1 ? NSLocalizedString(@"%ld rule in use", @"%ld will be replaced with the number 1") : NSLocalizedString(@"%ld rules in use", @"%ld will be replaced with a natural number")), ruleCount];
			cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
		}
	}

	return cell;
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender tableView:(UITableView *)tableView didSelectCustomViewSpecifier:(IASKSpecifier*)specifier {
	[super settingsViewController:self tableView:tableView didSelectCustomViewSpecifier:specifier]; // TODO: abort if something changed?

	if ([specifier.key isEqualToString:kHttpsEverywhereSpecifierKey]) {
		[self menuHTTPSEverywhere];
	} else if ([specifier.key isEqualToString:kTutorialSpecifierKey]) {
		[AppDelegate sharedAppDelegate].webViewController.showTutorial = YES;
		[self dismiss:nil];
	}
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
	[super settingsViewController:sender buttonTappedForSpecifier:specifier];

	if ([specifier.key isEqualToString:kClearWebsiteData]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
														message:NSLocalizedString(@"Remove all cookies and browsing data?", @"Title of alert to clear local cookies and browsing data")
													   delegate:self
											  cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel button on alert")
											  otherButtonTitles:NSLocalizedString(@"Clear Cookies and Data", @"Accept button on alert which triggers clearing all local cookies and browsing data"), nil];

		[alert show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == [alertView cancelButtonIndex]) {
		// do nothing, user has cancelled
	} else if (buttonIndex == [alertView firstOtherButtonIndex]) {
		// clear history and website data
		[CookieJar clearAllData];
	}
}

- (void)menuHTTPSEverywhere
{
	HTTPSEverywhereRuleController *viewController = [[HTTPSEverywhereRuleController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
	[self presentViewController:navController animated:YES completion:nil];
}

@end
