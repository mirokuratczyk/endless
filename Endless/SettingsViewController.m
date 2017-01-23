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

#import "PsiphonBrowser-Swift.h"

#import "FeedbackViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifierValuesViewController.h"
#import "IASKTextField.h"
#import "LogViewController.h"
#import "RegionSelectionViewController.h"
#import "SettingsViewController.h"
#import "URLInterceptor.h"
#import "NSBundle+Language.h"
#import "PsiphonSettings.h"

#import "RegionAdapter.h"

static AppDelegate *appDelegate;

#define kAboutSpecifierKey @"about"
#define kFAQSpecifierKey @"faq"
#define kFeedbackSpecifierKey @"feedback"
#define kHttpsEverywhereSpecifierKey @"httpsEverywhere"
#define kLogsSpecifierKey @"logs"
#define kPrivacyPolicySpecifierKey @"privacyPolicy"
#define kPsiphonSettingsSpecifierKey @"psiphonSettings"
#define kTermsOfUseSpecifierKey @"termsOfUse"

@implementation SettingsViewController {
    NSMutableArray *tlsVersions;
    NSMutableArray *tlsShortTitles;

    UITableViewCell *flagCell;
    UIImageView *flagImage;
    UILabel *flagLabel;

    BOOL isRTL;
}


static NSArray *links;
BOOL linksEnabled;

@synthesize webViewController;

- (void)viewDidLoad
{
    [super viewDidLoad];
	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		links = @[kAboutSpecifierKey, kFAQSpecifierKey, kPrivacyPolicySpecifierKey, kTermsOfUseSpecifierKey];
	});
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	linksEnabled = (appDelegate.psiphonConectionState == PsiphonConnectionStateConnected);

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(settingDidChange:) name:kIASKAppSettingChanged object:nil];
	[center addObserver:self selector:@selector(updateLinksState:) name:kPsiphonConnectionStateNotification object:nil];
    [center addObserver:self selector:@selector(updateAvailableRegions:) name:kPsiphonAvailableRegionsNotification object:nil];

    // Get TLS keys and short (preview) titles from MinTLSSettings.plist
    NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"MinTLSSettings.plist"];
    NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

    for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
        NSString *key = [pref objectForKey:@"Key"];
        if (key != nil) {
            if (tlsVersions == nil) {
                tlsVersions = [NSMutableArray arrayWithObjects: key, nil];
            } else {
                [tlsVersions addObject:key];
            }
        }

        NSString *shortTitle = [pref objectForKey:@"ShortTitle"];
        if (shortTitle != nil) {
            if (tlsShortTitles == nil) {
                tlsShortTitles = [NSMutableArray arrayWithObjects: shortTitle, nil];
            } else {
                [tlsShortTitles addObject:shortTitle];
            }
        }
    }
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForSpecifier:(IASKSpecifier*)specifier {
    NSString *identifier = [NSString stringWithFormat:@"%@-%@-%ld-%d", specifier.key, specifier.type, (long)specifier.textAlignment, !!specifier.subtitle.length];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    }

    cell.userInteractionEnabled = YES;

    if ([specifier.key isEqualToString:kHttpsEverywhereSpecifierKey]) {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.textLabel setText:specifier.title];

        // Set detail text label to # of https everywhere rules in use for current browser tab
        long ruleCount = [self.webViewController curWebViewTabHttpsRulesCount];

        if (ruleCount > 0) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld rule%@ in use", ruleCount, (ruleCount == 1 ? @"" : @"s")];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
        }
    } else if ([specifier.key isEqualToString:kMinTlsVersion]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [cell.textLabel setText:specifier.title];
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        // Set detail text label to preview text of currently chosen minTlsVersion option
        cell.detailTextLabel.text = tlsShortTitles[[[NSUserDefaults standardUserDefaults] integerForKey:kMinTlsVersion]];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
    } else if ([tlsVersions containsObject:specifier.key]) {
        [cell.textLabel setText:specifier.title];
        cell.textLabel.attributedText = [[NSAttributedString alloc] initWithString:specifier.title attributes:nil];
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textLabel.numberOfLines = 0;
        
        // Checkmark cell of currently chosen minTlsVersion option
        BOOL selected = [tlsVersions[[[NSUserDefaults standardUserDefaults] integerForKey:kMinTlsVersion]] isEqualToString:specifier.key];

        if (selected) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else if ([specifier.key isEqualToString:kLogsSpecifierKey] || [specifier.key isEqualToString:kFeedbackSpecifierKey] || [specifier.key isEqualToString:kAboutSpecifierKey] || [specifier.key isEqualToString:kAboutSpecifierKey] | [specifier.key isEqualToString:kFAQSpecifierKey] || [specifier.key isEqualToString:kPrivacyPolicySpecifierKey] || [specifier.key isEqualToString:kTermsOfUseSpecifierKey] || [specifier.key isEqualToString:kPsiphonSettingsSpecifierKey]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = specifier.title;
    } else if ([specifier.key isEqualToString:kRegionSelectionSpecifierKey]) {
        // Prevent coalescing of region titles and flags by removing any existing subviews from the cell's content view
        [[cell.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

        // Get currently selected region
        Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
        NSString *detailText = selectedRegion.title;

        // Style and layout cell
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.textLabel setText:specifier.title];

        UIImage *flag = [UIImage imageNamed:selectedRegion.flagResourceId];
        flagImage = [[UIImageView alloc] initWithImage:flag];
        flagLabel = [[UILabel alloc] init];
        flagLabel.adjustsFontSizeToFitWidth = YES;
        flagLabel.text = detailText;
        flagLabel.textColor = cell.detailTextLabel.textColor; // Get normal detailText color
        flagLabel.textAlignment = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

        // Size and place flag image. Text is sized and placed in viewDidLayoutSubviews
        if (isRTL) {
            flagImage.frame = CGRectMake(1, (cell.frame.size.height - flagImage.frame.size.height) / 2 , flag.size.width, flag.size.height);
        } else {
            flagImage.frame = CGRectMake(cell.contentView.frame.size.width - flagImage.frame.size.width, (cell.frame.size.height - flagImage.frame.size.height) / 2, flag.size.width, flag.size.height);
        }

        flagImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

        // Add flag and region name to detailTextLabel section of cell
        [cell.contentView addSubview:flagImage];
        [cell.contentView addSubview:flagLabel];

        cell.userInteractionEnabled = linksEnabled;
        cell.textLabel.enabled = linksEnabled;

        flagCell = cell;
    }
	
	if ([links containsObject:specifier.key]) {
		cell.userInteractionEnabled = linksEnabled;
		cell.textLabel.enabled = linksEnabled;
		cell.detailTextLabel.enabled = linksEnabled;
	}
    return cell;
}

- (void)viewDidLayoutSubviews {
    // Resize detailText of region selection cell for new layout
    CGFloat newWidth;
    CGFloat xOffset;
    CGFloat offsetFromSides = 10.0f;

    if (isRTL) {
        newWidth =  flagCell.textLabel.frame.origin.x - flagImage.frame.size.width - offsetFromSides * 2;
        xOffset = flagImage.frame.size.width + offsetFromSides;
    } else {
        newWidth =  flagCell.contentView.frame.size.width - (flagCell.textLabel.frame.size.width + flagCell.textLabel.frame.origin.x) - flagImage.image.size.width - offsetFromSides * 2;
        xOffset = flagCell.contentView.frame.size.width - flagImage.image.size.width - newWidth - offsetFromSides;
    }

    flagLabel.frame = CGRectMake(xOffset, 0, newWidth, flagCell.contentView.frame.size.height);
    [flagLabel setNeedsDisplay];
}

- (BOOL)isValidPort:(NSString *)port {
    NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([port rangeOfCharacterFromSet:notDigits].location == NSNotFound)
    {
        NSInteger portNumber = [port integerValue];
        return (portNumber >= 1 && portNumber <= 65535);
    } else {
        return NO;
    }
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender tableView:(UITableView *)tableView didSelectCustomViewSpecifier:(IASKSpecifier*)specifier {
    if ([specifier.key isEqualToString:kPsiphonSettingsSpecifierKey]) {
        PsiphonSettingsViewController *vc = [[PsiphonSettingsViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:navController animated:YES completion:nil];
    } if ([specifier.key isEqualToString:kFeedbackSpecifierKey]) {
        FeedbackViewController *targetViewController = [[FeedbackViewController alloc] init];
        
        targetViewController.delegate = targetViewController;
        targetViewController.file = specifier.file;
        targetViewController.settingsStore = self.settingsStore;
        targetViewController.showDoneButton = NO;
        targetViewController.showCreditsFooter = NO; // Does not reload the tableview (but next setters do it)
        targetViewController.title = specifier.title;
        
        IASK_IF_IOS7_OR_GREATER(targetViewController.view.tintColor = self.view.tintColor;)
        
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:targetViewController];
        [self presentViewController:navController animated:YES completion:nil];
    } else if ([specifier.key isEqualToString:kHttpsEverywhereSpecifierKey]) {
        [self menuHTTPSEverywhere];
    } else if ([specifier.key isEqualToString:kMinTlsVersion]) {
        // Push new IASK view controller for custom minTlsVersion menu
        IASKAppSettingsViewController *targetViewController = [[IASKAppSettingsViewController alloc] init];

        targetViewController.delegate = self;
        targetViewController.file = specifier.file;
        targetViewController.hiddenKeys = self.hiddenKeys;
        targetViewController.settingsStore = self.settingsStore;
        targetViewController.showDoneButton = NO;
        targetViewController.showCreditsFooter = NO; // Does not reload the tableview (but next setters do it)
        targetViewController.title = specifier.title;

        IASK_IF_IOS7_OR_GREATER(targetViewController.view.tintColor = self.view.tintColor;)

        [self.navigationController pushViewController:targetViewController animated:YES];
    } else if ([tlsVersions containsObject:specifier.key]) {
        // New minTlsVersion option was selected update tableview cells
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        // De-select currently selected option
        NSUInteger currentIndex[2];
        currentIndex[0] = 0;
        currentIndex[1] = [userDefaults integerForKey:kMinTlsVersion];
        NSIndexPath *currentIndexPath = [[NSIndexPath alloc] initWithIndexes:currentIndex length:2];
        UITableViewCell *currentlySelectedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
        currentlySelectedCell.accessoryType = UITableViewStylePlain; // Remove checkmark

        // Select newly chosen option
        NSUInteger indexOfSelection = [tlsVersions indexOfObject: specifier.key];
        [userDefaults setInteger:indexOfSelection forKey:kMinTlsVersion]; // Update settings

        NSIndexPath *newIndexPath = [tableView indexPathForSelectedRow];
        UITableViewCell *newlySelectedCell = [tableView cellForRowAtIndexPath:newIndexPath];
        newlySelectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
        [tableView deselectRowAtIndexPath:newIndexPath animated:YES];
    } else if ([links containsObject:specifier.key]) {
        [self loadUrlForSpecifier:specifier.key];
    } else if ([specifier.key isEqualToString:kLogsSpecifierKey]) {
        LogViewController *vc = [[LogViewController alloc] init];
        vc.title = NSLocalizedString(@"Logs", @"Title of screen displaying logs");
        [self.navigationController pushViewController:vc animated:YES];
    } else if ([specifier.key isEqualToString:kRegionSelectionSpecifierKey]) {
        RegionSelectionViewController *targetViewController = [[RegionSelectionViewController alloc] init];
        [self.navigationController pushViewController:targetViewController animated:YES];
    }
}

- (void)loadUrlForSpecifier:(NSString *)key
{
    NSString *url;
    if ([key isEqualToString:kAboutSpecifierKey]) { // make this a hashmap
        url = NSLocalizedString(@"https://psiphon.ca/en/about.html", "");
    } else if ([key isEqualToString:kFAQSpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/faq.html", "");
    } else if ([key isEqualToString:kPrivacyPolicySpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/privacy.html", "");
    } else if ([key isEqualToString:kTermsOfUseSpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/license.html", "");
    }
    [self loadUrlInWebview:url];
}

- (void)loadUrlInWebview:(NSString *)url
{
    UIViewController *vc = [[UIViewController alloc] init];
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.navigationController.view.bounds];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    
    [vc.view addSubview:webView];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGFloat)tableView:(UITableView*)tableView heightForSpecifier:(IASKSpecifier*)specifier
{
    IASK_IF_IOS7_OR_GREATER
    (
     NSDictionary *rowHeights = @{UIContentSizeCategoryExtraSmall: @(44),
                                  UIContentSizeCategorySmall: @(44),
                                  UIContentSizeCategoryMedium: @(44),
                                  UIContentSizeCategoryLarge: @(44),
                                  UIContentSizeCategoryExtraLarge: @(47)};
     CGFloat rowHeight = (CGFloat)[rowHeights[UIApplication.sharedApplication.preferredContentSizeCategory] doubleValue];

     rowHeight = rowHeight != 0 ? rowHeight : 51;

     // Give multi-line cell more height per newline occurrence
     NSError *error = NULL;
     NSRegularExpression *newLineRegex = [NSRegularExpression regularExpressionWithPattern:@"\n" options:0 error:&error];

     // Failed to compile/init regex
     if (error != NULL)
         return rowHeight;

     NSUInteger numberOfNewLines = [newLineRegex numberOfMatchesInString:specifier.title options:0 range:NSMakeRange(0, [specifier.title length])];

     return rowHeight + numberOfNewLines * 20;
     );
    return 44;
}

- (void)settingDidChange:(NSNotification*)notification
{
    NSString *fieldName = notification.userInfo.allKeys.firstObject;

    if  ([fieldName isEqual:appLanguage]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate setAppLanguageAndReloadSettings:[notification.userInfo objectForKey:appLanguage]];
    }
}

- (void)menuHTTPSEverywhere
{
    HTTPSEverywhereRuleController *viewController = [[HTTPSEverywhereRuleController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self.webViewController settingsViewControllerDidEnd];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) updateAvailableRegions:(NSNotification*) notification {
    [self.tableView reloadData];
}

- (void) updateLinksState:(NSNotification*) notification {
	PsiphonConnectionState state = [[notification.userInfo objectForKey:kPsiphonConnectionState] unsignedIntegerValue];
	if(state == PsiphonConnectionStateConnected) {
		linksEnabled = true;
	} else {
		linksEnabled = false;
	}
	[self.tableView reloadData];
}

@end
