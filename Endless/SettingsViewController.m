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


#import "FeedbackViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifierValuesViewController.h"
#import "IASKTextField.h"
#import "LogViewController.h"
#import "PsiphonSettingsTextFieldViewCell.h"
#import "RegionAdapter.h"
#import "RegionSelectionViewController.h"
#import "SettingsViewController.h"
#import "URLInterceptor.h"


static AppDelegate *appDelegate;

#define kAboutSpecifierKey @"about"
#define kFAQSpecifierKey @"faq"
#define kFeedbackSpecifierKey @"feedback"
#define kHttpsEverywhereSpecifierKey @"httpsEverywhere"
#define kLogsSpecifierKey @"logs"
#define kPrivacyPolicySpecifierKey @"privacyPolicy"
#define kTermsOfUseSpecifierKey @"termsOfUse"

@implementation SettingsViewController {
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
            cell.detailTextLabel.text = [NSString stringWithFormat:(ruleCount == 1 ? NSLocalizedString(@"%ld rule in use", @"%ld will be replaced with the number 1") : NSLocalizedString(@"%ld rules in use", @"%ld will be replaced with a natural number")), ruleCount];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
        }
    } else if ([specifier.key isEqualToString:kUpstreamProxyPort]
			   || [specifier.key isEqualToString:kUpstreamProxyHostAddress]
			   || [specifier.key isEqualToString:kProxyUsername]
			   || [specifier.key isEqualToString:kProxyDomain]
			   || [specifier.key isEqualToString:kProxyPassword]) {
        
        cell = [[PsiphonSettingsTextFieldViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kIASKPSTextFieldSpecifier];

        cell.textLabel.text = specifier.title;

        NSString *textValue = [self.settingsStore objectForKey:specifier.key] != nil ? [self.settingsStore objectForKey:specifier.key] : specifier.defaultStringValue;
        if (textValue && ![textValue isMemberOfClass:[NSString class]]) {
             textValue = [NSString stringWithFormat:@"%@", textValue];
        }
        IASKTextField *textField = ((IASKPSTextFieldSpecifierViewCell*)cell).textField;
        textField.text = textValue;
        textField.key = specifier.key;
        textField.placeholder = specifier.placeholder;
        textField.delegate = self;
        textField.keyboardType = specifier.keyboardType;
        textField.autocapitalizationType = specifier.autocapitalizationType;
        textField.autocorrectionType = specifier.autoCorrectionType;
        textField.textAlignment = specifier.textAlignment;
        textField.adjustsFontSizeToFitWidth = specifier.adjustsFontSizeToFitWidth;
    } else if ([specifier.key isEqualToString:kLogsSpecifierKey]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = specifier.title;
#ifndef DEBUGLOGS
        cell.hidden = YES;
#endif
    } else if ([specifier.key isEqualToString:kFeedbackSpecifierKey] || [specifier.key isEqualToString:kAboutSpecifierKey] || [specifier.key isEqualToString:kAboutSpecifierKey] | [specifier.key isEqualToString:kFAQSpecifierKey] || [specifier.key isEqualToString:kPrivacyPolicySpecifierKey] || [specifier.key isEqualToString:kTermsOfUseSpecifierKey]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = specifier.title;
    } else if ([specifier.key isEqualToString:kRegionSelectionSpecifierKey]) {
        // Prevent coalescing of region titles and flags by removing any existing subviews from the cell's content view
        [[cell.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

        // Get currently selected region
        Region *selectedRegion = [[RegionAdapter sharedInstance] getSelectedRegion];
        NSString *detailText = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:selectedRegion.code];

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
    if ([specifier.key isEqualToString:kFeedbackSpecifierKey]) {
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
    } else if ([specifier.key isEqualToString:kUpstreamProxyPort] || [specifier.key isEqualToString:kUpstreamProxyHostAddress]) {
        // Focus on textfield if cell pressed
        NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[IASKPSTextFieldSpecifierViewCell class]]) {
            IASKTextField *textField = ((IASKPSTextFieldSpecifierViewCell*)cell).textField;
            if ([textField.key isEqualToString:specifier.key]) {
                [textField becomeFirstResponder];
            }
        }
    } else if ([links containsObject:specifier.key]) {
        [self loadUrlForSpecifier:specifier.key];
    } else if ([specifier.key isEqualToString:kLogsSpecifierKey]) {
        LogViewController *vc = [[LogViewController alloc] init];
        vc.title = NSLocalizedString(@"Logs", @"Title screen displaying logs");
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
        url = NSLocalizedString(@"https://psiphon.ca/en/about.html", @"External link to the about page. Please update this with the correct language specific link (if available) e.g. https://psiphon.ca/fr/about.html for french.");
    } else if ([key isEqualToString:kFAQSpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/faq.html", @"External link to the FAQ page. Please update this with the correct language specific link (if available) e.g. https://psiphon.ca/fr/faq.html for french.");
    } else if ([key isEqualToString:kPrivacyPolicySpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/privacy.html", @"External link to the privacy policy page. Please update this with the correct language specific link (if available) e.g. https://psiphon.ca/fr/privacy.html for french.");
    } else if ([key isEqualToString:kTermsOfUseSpecifierKey]) {
        url = NSLocalizedString(@"https://psiphon.ca/en/license.html", @"External link to the license page. Please update this with the correct language specific link (if available) e.g. https://psiphon.ca/fr/license.html for french.");
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
    if ([specifier.key isEqualToString:kLogsSpecifierKey]) {
#ifndef DEBUGLOGS
        return 0;
#endif
    }
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
    NSArray *upstreamProxyKeys = [NSArray arrayWithObjects:kUpstreamProxyHostAddress, kUpstreamProxyPort, kUseProxyAuthentication, nil];
    NSArray *proxyAuthenticationKeys = [NSArray arrayWithObjects:kProxyUsername, kProxyPassword, kProxyDomain, nil];

    NSString *fieldName = notification.userInfo.allKeys.firstObject;

    if ([fieldName isEqual:kUseUpstreamProxy]) {
        BOOL upstreamProxyEnabled = (BOOL)[[notification.userInfo objectForKey:kUseUpstreamProxy] intValue];

        NSMutableSet *hiddenKeys = [NSMutableSet setWithSet:[self hiddenKeys]];

        if (upstreamProxyEnabled) {
            // Display proxy configuration fields
            for (NSString *key in upstreamProxyKeys) {
                [hiddenKeys removeObject:key];
            }

            BOOL useUpstreamProxyAuthentication = [[NSUserDefaults standardUserDefaults] boolForKey:kUseProxyAuthentication];

            if (useUpstreamProxyAuthentication) {
                // Display proxy authentication fields
                for (NSString *key in proxyAuthenticationKeys) {
                    [hiddenKeys removeObject:key];
                }
            }

            [self setHiddenKeys:hiddenKeys animated:YES];
        } else {
            NSMutableSet *hiddenKeys = [NSMutableSet setWithArray:upstreamProxyKeys];
            [hiddenKeys addObjectsFromArray:proxyAuthenticationKeys];
            [self setHiddenKeys:hiddenKeys animated:YES];
        }
    } else if ([fieldName isEqual:kUseProxyAuthentication]) {
        // useProxyAuthentication toggled, show or hide proxy authentication fields
        IASKAppSettingsViewController *activeController = notification.object;
        BOOL enabled = (BOOL)[[notification.userInfo objectForKey:kUseProxyAuthentication] intValue];

        NSMutableSet *hiddenKeys = [NSMutableSet setWithSet:[activeController hiddenKeys]];

        if (enabled) {
            for (NSString *key in proxyAuthenticationKeys) {
                [hiddenKeys removeObject:key];
            }
        } else {
            for (NSString *key in proxyAuthenticationKeys) {
                [hiddenKeys addObject:key];
            }
        }
        [activeController setHiddenKeys:hiddenKeys animated:YES];
    } else if  ([fieldName isEqual:appLanguage]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate reloadAndOpenSettings];
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
