//
//  SettingsViewController.m
//  Endless
//
//  Created by Miro Kuratczyk on 2016-11-11.
//

#import "HTTPSEverywhereRuleController.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifierValuesViewController.h"
#import "SettingsViewController.h"
#import "URLInterceptor.h"

@implementation SettingsViewController {
    NSMutableArray *tlsVersions;
    NSMutableArray *tlsShortTitles;
}

@synthesize webViewController;

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(settingDidChange:) name:kIASKAppSettingChanged object:nil];

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
    NSString *identifier = [NSString stringWithFormat:@"%@-%ld-%d", specifier.type, (long)specifier.textAlignment, !!specifier.subtitle.length];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    }

    cell.userInteractionEnabled = YES;

    if ([specifier.key isEqualToString:@"httpsEverywhere"]) {
        [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
        [cell.textLabel setText:specifier.title];

        // Set detail text label to # of https everywhere rules in use for current browser tab
        long ruleCount = [self.webViewController curWebViewTabHttpsRulesCount];

        if (ruleCount > 0) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld rule%@ in use", ruleCount, (ruleCount == 1 ? @"" : @"s")];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
        }
    } else if ([specifier.key isEqualToString:minTlsVersion]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [cell.textLabel setText:specifier.title];
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        // Set detail text label to preview text of currently chosen minTlsVersion option
        cell.detailTextLabel.text = tlsShortTitles[[[NSUserDefaults standardUserDefaults] integerForKey:minTlsVersion]];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
    } else if ([tlsVersions containsObject:specifier.key]) {
        [cell.textLabel setText:specifier.title];
        cell.textLabel.attributedText = [[NSAttributedString alloc] initWithString:specifier.title attributes:nil];
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textLabel.numberOfLines = 0;

        // Checkmark cell of currently chosen minTlsVersion option
        BOOL selected = [tlsVersions[[[NSUserDefaults standardUserDefaults] integerForKey:minTlsVersion]] isEqualToString:specifier.key];

        if (selected) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }

    return cell;
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender tableView:(UITableView *)tableView didSelectCustomViewSpecifier:(IASKSpecifier*)specifier {
    if ([specifier.key isEqualToString:@"httpsEverywhere"]) {
        [self menuHTTPSEverywhere];
    } else if ([specifier.key isEqualToString:minTlsVersion]) {
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
        currentIndex[1] = [userDefaults integerForKey:minTlsVersion];
        NSIndexPath *currentIndexPath = [[NSIndexPath alloc] initWithIndexes:currentIndex length:2];
        UITableViewCell *currentlySelectedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
        currentlySelectedCell.accessoryType = UITableViewStylePlain; // Remove checkmark

        // Select newly chosen option
        NSUInteger indexOfSelection = [tlsVersions indexOfObject: specifier.key];
        [userDefaults setInteger:indexOfSelection forKey:minTlsVersion]; // Update settings

        NSUInteger newIndex[2];
        newIndex[0] = 0;
        newIndex[1] = indexOfSelection;
        NSIndexPath *newIndexPath = [[NSIndexPath alloc] initWithIndexes:newIndex length:2];
        UITableViewCell *newlySelectedCell = [tableView cellForRowAtIndexPath:newIndexPath];
        newlySelectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
        [tableView deselectRowAtIndexPath:newIndexPath animated:YES];
    }
}

- (CGFloat)tableView:(UITableView*)tableView heightForSpecifier:(IASKSpecifier*)specifier {
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

- (void)settingDidChange:(NSNotification*)notification {
    NSArray *upstreamProxyKeys = [NSArray arrayWithObjects:upstreamProxyHostAddress, upstreamProxyPort, useProxyAuthentication, nil];
    NSArray *proxyAuthenticationKeys = [NSArray arrayWithObjects:proxyUsername, proxyPassword, proxyDomain, nil];

    // If user has chosen to alter upstream proxy settings
    if ([notification.userInfo.allKeys.firstObject isEqual:useUpstreamProxy]) {
        IASKAppSettingsViewController *activeController = notification.object;
        BOOL upstreamProxyEnabled = (BOOL)[[notification.userInfo objectForKey:useUpstreamProxy] intValue];

        NSMutableSet *hiddenKeys = [NSMutableSet setWithSet:[activeController hiddenKeys]];

        if (upstreamProxyEnabled) {
            // Display proxy configuration fields
            for (NSString *key in upstreamProxyKeys) {
                [hiddenKeys removeObject:key];
            }

            BOOL useUpstreamProxyAuthentication = [[NSUserDefaults standardUserDefaults] boolForKey:useProxyAuthentication];

            if (useUpstreamProxyAuthentication) {
                // Display proxy authentication fields
                for (NSString *key in proxyAuthenticationKeys) {
                    [hiddenKeys removeObject:key];
                }
            }

            [activeController setHiddenKeys:hiddenKeys animated:YES];
        } else {
            NSMutableSet *hiddenKeys = [NSMutableSet setWithArray:upstreamProxyKeys];
            [hiddenKeys addObjectsFromArray:proxyAuthenticationKeys];
            [activeController setHiddenKeys:hiddenKeys animated:YES];
        }
    } else if ([notification.userInfo.allKeys.firstObject isEqual:useProxyAuthentication]) {
        // useProxyAuthentication toggled, show or hide proxy authentication fields
        IASKAppSettingsViewController *activeController = notification.object;
        BOOL enabled = (BOOL)[[notification.userInfo objectForKey:useProxyAuthentication] intValue];

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
    }
}

- (void)menuHTTPSEverywhere
{
    HTTPSEverywhereRuleController *httpsEverywhere = [[HTTPSEverywhereRuleController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:httpsEverywhere];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self.webViewController settingsViewControllerDidEnd];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
